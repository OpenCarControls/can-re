import sys
try:
    import webview
except ImportError:
    webview = None
import os
import json
import traceback
from pathlib import Path

import can
import cantools

class Api:
    def __init__(self):
        self.dbc = None
        self.log_messages = []
        self.is_maximized = False

    def get_window(self):
        if webview and len(webview.windows) > 0:
            return webview.windows[0]
        return None

    def hello_from_python(self, message):
        print(f"Message from frontend: {message}")
        return f"Python received: {message}"



    def prompt_load_dbc(self):
        window = self.get_window()
        if not window:
            return {"error": "Native dialogs not supported in this mode"}
        
        file_types = ('DBC Files (*.dbc)', 'All files (*.*)')
        result = window.create_file_dialog(webview.OPEN_DIALOG, allow_multiple=False, file_types=file_types)
        if result and len(result) > 0:
            file_path = result[0]
            try:
                self.dbc = cantools.database.load_file(file_path)
                return {"success": True, "file": os.path.basename(file_path), "messages_count": len(self.dbc.messages)}
            except Exception as e:
                traceback.print_exc()
                return {"error": str(e)}
        return {"cancelled": True}

    def load_dbc_from_buffer(self, content: str, filename: str):
        try:
            self.dbc = cantools.database.load_string(content)
            return {"success": True, "file": filename, "messages_count": len(self.dbc.messages)}
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    def prompt_load_log(self):
        window = self.get_window()
        if not window:
            return {"error": "Native dialogs not supported in this mode"}
        
        file_types = ('CAN Logs (*.asc *.blf *.csv *.trc)', 'All files (*.*)')
        result = window.create_file_dialog(webview.OPEN_DIALOG, allow_multiple=False, file_types=file_types)
        if result and len(result) > 0:
            file_path = result[0]
            try:
                reader = can.LogReader(file_path)
                self.log_messages = list(reader)
                return {"success": True, "file": os.path.basename(file_path), "total_count": len(self.log_messages)}
            except Exception as e:
                traceback.print_exc()
                return {"error": str(e)}
        return {"cancelled": True}

    def load_log_from_buffer(self, buffer: str, filename: str):
        try:
            # We write the buffer to a temporary file so can.LogReader can guess the format from the filename
            import tempfile
            # Web mode (Pyodide) passes strings mostly, but could be bytes.
            mode = "w" if isinstance(buffer, str) else "wb"
            tmp_path = os.path.join(tempfile.gettempdir(), filename)
            with open(tmp_path, mode) as f:
                f.write(buffer)
            
            reader = can.LogReader(tmp_path)
            self.log_messages = list(reader)
            # optionally remove the file to save memory/space
            try:
                os.remove(tmp_path)
            except:
                pass
            
            return {"success": True, "file": filename, "total_count": len(self.log_messages)}
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    def get_log_chunk(self, start: int, length: int, reverse: bool = False):
        try:
            total = len(self.log_messages)
            if total == 0:
                return []
            
            if reverse:
                # If reverse, start from the end
                # e.g., total=100. start=0, length=10 -> idx: 90..99, reversed
                end_idx = total - start
                start_idx = max(0, end_idx - length)
                slice_msgs = self.log_messages[start_idx:end_idx]
                slice_msgs = slice_msgs[::-1]
            else:
                slice_msgs = self.log_messages[start:start + length]
            
            result = []
            for msg in slice_msgs:
                msg_dict = {
                    "timestamp": msg.timestamp,
                    "id": msg.arbitration_id,
                    "dlc": msg.dlc,
                    "data": list(msg.data),
                    "is_extended_id": msg.is_extended_id,
                    "decoded": None
                }
                
                if self.dbc:
                    try:
                        decoded = self.dbc.decode_message(msg.arbitration_id, msg.data)
                        message_def = self.dbc.get_message_by_frame_id(msg.arbitration_id)
                        msg_dict["decoded"] = {
                            "name": message_def.name,
                            "signals": decoded
                        }
                    except Exception:
                        pass # Decode failed (not in DBC or malformed)
                
                result.append(msg_dict)
            return result
        except Exception as e:
            traceback.print_exc()
            return []

def get_entrypoint():
    if "CAN_RE_DIST_PATH" in os.environ:
        return str(Path(os.environ["CAN_RE_DIST_PATH"]) / "index.html")
    elif getattr(sys, 'frozen', False):
        # The application is frozen (packaged by PyInstaller)
        # We assume the UI is bundled inside the MEIPASS directory under 'dist'
        base_path = Path(sys._MEIPASS)
        return str(base_path / "dist" / "index.html")
    else:
        # Development mode (Vite default port)
        return "http://localhost:5173"

def get_version_string():
    dist_path = None
    if "CAN_RE_DIST_PATH" in os.environ:
        dist_path = Path(os.environ["CAN_RE_DIST_PATH"])
    elif getattr(sys, 'frozen', False):
        dist_path = Path(sys._MEIPASS) / "dist"
        
    if dist_path:
        try:
            with open(dist_path / "version.json", "r") as f:
                data = json.load(f)
                return f" - v{data.get('version', '?')} ({data.get('hash', '?')})"
        except Exception:
            pass
    return ""

def main():
    api = Api()
    entry = get_entrypoint()
    
    if webview:
        title = f"CAN RE{get_version_string()}"
        # create_window exposes the 'api' object as window.pywebview.api in JavaScript
        window = webview.create_window(title, entry, js_api=api)
        
        # Ensure process exits when window is closed
        def on_closed():
            os._exit(0)
        window.events.closed += on_closed
        
        # Allow Ctrl+C to terminate the application
        import signal
        signal.signal(signal.SIGINT, signal.SIG_DFL)
        
        is_dev = not getattr(sys, 'frozen', False)
        webview.start(debug=is_dev)
    else:
        print("Error: pywebview is not installed. Did you forget to install the 'desktop' optional dependencies?", file=sys.stderr)
        print("Run with: uv run --extra desktop can-re", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()

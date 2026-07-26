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

from can_re.core import EventBus, ServiceRegistry, StateManager

class Api:
    def __init__(self):
        self.events = EventBus()
        self.services = ServiceRegistry()
        self.state = StateManager(self.events)
        
        self.dbc = None
        self.is_maximized = False
        if sys.platform == 'emscripten':
            self.request_file = self._request_file_async
            self.load_dbc = self._load_dbc_async
            self.load_log = self._load_log_async
            self.call_service = self._call_service_async
            
        # Temporarily register services until we extract features to plugins
        self.services.register('core.load_log', self.load_log)
        self.services.register('core.load_dbc', self.load_dbc)
        self.services.register('core.get_log_chunk', self.get_log_chunk)

    def call_service(self, service_name: str, *args):
        return self.services.call(service_name, *args)

    async def _call_service_async(self, service_name: str, *args):
        res = self.services.call(service_name, *args)
        import inspect
        if inspect.iscoroutine(res):
            return await res
        return res

    def get_window(self):
        if webview and len(webview.windows) > 0:
            return webview.windows[0]
        return None

    def hello_from_python(self, message):
        print(f"Message from frontend: {message}")
        return f"Python received: {message}"



    def _get_settings_path(self):
        config_dir = Path.home() / ".can-re"
        config_dir.mkdir(exist_ok=True)
        return config_dir / "settings.json"

    def get_settings(self, namespace: str):
        if sys.platform == 'emscripten':
            import js
            try:
                data = json.loads(js.window.localStorage.getItem('can_re_settings') or "{}")
                return data.get(namespace)
            except Exception:
                return None
        else:
            path = self._get_settings_path()
            if path.exists():
                try:
                    with open(path, "r") as f:
                        data = json.load(f)
                        return data.get(namespace)
                except Exception:
                    pass
            return None

    def set_settings(self, namespace: str, data: dict):
        if sys.platform == 'emscripten':
            import js
            try:
                current_data = json.loads(js.window.localStorage.getItem('can_re_settings') or "{}")
                current_data[namespace] = data
                js.window.localStorage.setItem('can_re_settings', json.dumps(current_data))
                return True
            except Exception as e:
                print(f"Failed to save settings: {e}")
                return False
        else:
            path = self._get_settings_path()
            current_data = {}
            if path.exists():
                try:
                    with open(path, "r") as f:
                        current_data = json.load(f)
                except Exception:
                    pass
            current_data[namespace] = data
            try:
                with open(path, "w") as f:
                    json.dump(current_data, f)
                return True
            except Exception as e:
                print(f"Failed to save settings: {e}")
                return False

    def request_file(self, file_types=None):
        window = self.get_window()
        if not window:
            return None, None
        
        result = window.create_file_dialog(webview.OPEN_DIALOG, allow_multiple=False, file_types=file_types)
        if result and len(result) > 0:
            file_path = result[0]
            return os.path.basename(file_path), file_path
        return None, None

    async def _request_file_async(self, file_types=None):
        import js
        import tempfile
        try:
            res = await js.window.webFileProxy(file_types)
            if res and res.name:
                name = res.name
                content_bytes = res.content.to_py()
                tmp_path = os.path.join(tempfile.gettempdir(), name)
                with open(tmp_path, "wb") as f:
                    f.write(content_bytes)
                return name, tmp_path
        except Exception:
            traceback.print_exc()
        return None, None

    def load_dbc(self):
        try:
            name, path = self.request_file(file_types=('DBC Files (*.dbc)', 'All files (*.*)'))
            if path:
                self.dbc = cantools.database.load_file(path)
                return {"success": True, "file": name, "messages_count": len(self.dbc.messages)}
            return {"cancelled": True}
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    async def _load_dbc_async(self):
        try:
            name, path = await self._request_file_async(file_types=('DBC Files (*.dbc)', 'All files (*.*)'))
            if path:
                self.dbc = cantools.database.load_file(path)
                return {"success": True, "file": name, "messages_count": len(self.dbc.messages)}
            return {"cancelled": True}
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    def _parse_log_file(self, file_path: str):
        try:
            reader = can.LogReader(file_path)
            return list(reader)
        except ValueError as e:
            if "too many values to unpack" in str(e) and file_path.lower().endswith('.csv'):
                # Fallback for SavvyCAN Generic CSV
                messages = []
                import csv
                with open(file_path, 'r', encoding='utf-8') as f:
                    reader = csv.reader(f)
                    header = next(reader, None)
                    if header and header[0] == 'Time Stamp':
                        for row in reader:
                            if len(row) < 6:
                                continue
                            dlc = int(row[5])
                            data = [int(x, 16) for x in row[6:6+dlc]]
                            msg = can.Message(
                                timestamp=float(row[0]) / 1000000.0,
                                arbitration_id=int(row[1], 16),
                                is_extended_id=(row[2].lower() == 'true'),
                                is_rx=(row[3].lower() == 'rx'),
                                channel=row[4],
                                dlc=dlc,
                                data=data
                            )
                            messages.append(msg)
                        return messages
            raise e

    def load_log(self):
        try:
            name, path = self.request_file(file_types=('CAN Logs (*.asc;*.blf;*.csv;*.trc)', 'All files (*.*)'))
            if path:
                frames = self._parse_log_file(path)
                self.state.clear()
                self.state.add_frames(frames)
                return {"success": True, "file": name, "total_count": len(self.state.frames)}
            return {"cancelled": True}
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    async def _load_log_async(self):
        try:
            name, path = await self._request_file_async(file_types=('CAN Logs (*.asc;*.blf;*.csv;*.trc)', 'All files (*.*)'))
            if path:
                frames = self._parse_log_file(path)
                self.state.clear()
                self.state.add_frames(frames)
                return {"success": True, "file": name, "total_count": len(self.state.frames)}
            return {"cancelled": True}
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    def get_log_chunk(self, start: int, length: int, reverse: bool = False):
        try:
            total = len(self.state.frames)
            if total == 0:
                return []
            
            if reverse:
                end_idx = total - start
                start_idx = max(0, end_idx - length)
                slice_msgs = self.state.frames[start_idx:end_idx]
                slice_msgs = slice_msgs[::-1]
            else:
                slice_msgs = self.state.frames[start:start + length]
            
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

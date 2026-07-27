import sys
try:
    import webview
except ImportError:
    webview = None
import os
import json
import traceback
from pathlib import Path

from can_re.core import EventBus, ServiceRegistry, StateManager
from can_re.core.plugins import PluginManager

class Api:
    def __init__(self):
        self.events = EventBus()
        self.services = ServiceRegistry()
        self.state = StateManager(self.events)
        
        self.is_maximized = False
        self.plugin_manager = PluginManager(self)
        self.plugin_manager.discover_and_load_builtin_plugins()
        
        # Load local desktop plugins if in desktop mode
        if sys.platform != 'emscripten':
            plugins_dir = Path.home() / ".can-re" / "plugins"
            plugins_dir.mkdir(parents=True, exist_ok=True)
            self.plugin_manager.discover_local_plugins(plugins_dir)

        if sys.platform == 'emscripten':
            self.request_file = self._request_file_async
            self.call_service = self._call_service_async

    def get_active_plugins(self):
        return self.plugin_manager.get_active_plugins()

    def get_plugin_bundle(self, plugin_id: str):
        return self.plugin_manager.get_plugin_bundle(plugin_id)
            

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
        if hasattr(data, "to_py"):
            data = data.to_py()
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

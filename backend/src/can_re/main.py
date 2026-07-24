import sys
try:
    import webview
except ImportError:
    webview = None
import os
import json
from pathlib import Path

class Api:
    def hello_from_python(self, message):
        print(f"Message from frontend: {message}")
        return f"Python received: {message}"

def get_entrypoint():
    if getattr(sys, 'frozen', False):
        # The application is frozen (packaged by PyInstaller)
        # We assume the UI is bundled inside the MEIPASS directory under 'dist'
        base_path = Path(sys._MEIPASS)
        return str(base_path / "dist" / "index.html")
    else:
        # Development mode (Vite default port)
        return "http://localhost:5173"

def get_version_string():
    if getattr(sys, 'frozen', False):
        try:
            base_path = Path(sys._MEIPASS)
            with open(base_path / "dist" / "version.json", "r") as f:
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
        webview.start(debug=True)

if __name__ == '__main__':
    main()

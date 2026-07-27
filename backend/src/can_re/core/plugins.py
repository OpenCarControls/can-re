import os
import sys
import json
import importlib
import importlib.util
import traceback
import subprocess
from pathlib import Path

class PluginManager:
    def __init__(self, api):
        self.api = api
        self.discovered_plugins = {}
        self.active_plugins = {}
        self.plugin_bundles = {} # Store frontend bundle bytes

        self.environments = ['desktop', 'web']
        self.current_env = 'web' if sys.platform == 'emscripten' else 'desktop'

    def get_discovered_plugins(self):
        """Returns a list of discovered plugins and their metadata to the frontend."""
        return [
            {
                "id": p_id,
                "name": data["name"],
                "version": data["version"]
            } for p_id, data in self.discovered_plugins.items()
        ]

    def get_active_plugins(self):
        """Returns a list of active plugins and their metadata to the frontend."""
        return [
            {
                "id": p_id,
                "name": data["name"],
                "version": data["version"]
            } for p_id, data in self.active_plugins.items()
        ]

    def get_python_dependencies(self):
        deps = set()
        for manifest in self.discovered_plugins.values():
            py_deps = manifest.get("dependencies", {}).get("python", [])
            deps.update(py_deps)
        return list(deps)

    def install_desktop_dependencies(self):
        if self.current_env != 'desktop':
            return False
            
        deps = self.get_python_dependencies()
        if not deps:
            return True
            
        try:
            print(f"Installing dependencies: {deps}")
            subprocess.run([sys.executable, "-m", "pip", "install", *deps], check=True)
            return True
        except subprocess.CalledProcessError as e:
            print(f"Failed to install dependencies: {e}")
            return False

    def load_plugin_backends(self):
        for p_id, plugin_data in self.discovered_plugins.items():
            self._execute_backend(plugin_data)

    def get_plugin_bundle(self, plugin_id: str):
        """Returns the JS bundle content for a given plugin ID."""
        if plugin_id in self.plugin_bundles:
            # We return as string because it's text/javascript
            try:
                return self.plugin_bundles[plugin_id].decode('utf-8')
            except Exception:
                return self.plugin_bundles[plugin_id]
        return None

    def discover_builtin_plugins(self):
        """Discover and load built-in plugins packaged inside the wheel."""
        current_dir = Path(__file__).parent.parent
        plugins_dir = current_dir / "plugins"
        
        if not plugins_dir.exists():
            # Dev mode fallback
            dev_plugins_dir = current_dir.parent.parent.parent / "plugins"
            if dev_plugins_dir.exists():
                plugins_dir = dev_plugins_dir

        if plugins_dir.exists():
            self._scan_directory(plugins_dir, is_builtin=True)

    def discover_local_plugins(self, directory: str):
        """Scan a local directory for third-party plugins (Desktop)."""
        path = Path(directory)
        if path.exists() and path.is_dir():
            self._scan_directory(path, is_builtin=False)

    def _scan_directory(self, plugins_dir: Path, is_builtin: bool):
        for item in plugins_dir.iterdir():
            if item.is_dir():
                manifest_path = item / "manifest.json"
                if manifest_path.exists():
                    self._discover_plugin(item, manifest_path, is_builtin)

    def _discover_plugin(self, plugin_dir: Path, manifest_path: Path, is_builtin: bool):
        try:
            with open(manifest_path, 'r', encoding='utf-8') as f:
                manifest = json.load(f)
            
            plugin_id = manifest.get('id')
            if not plugin_id:
                print(f"Plugin at {plugin_dir} is missing 'id'. Skipping.")
                return

            if self.current_env not in manifest.get('environments', []):
                print(f"Plugin {plugin_id} does not support {self.current_env}. Skipping.")
                return

            manifest['_plugin_dir'] = str(plugin_dir)
            manifest['_is_builtin'] = is_builtin
            
            self.discovered_plugins[plugin_id] = manifest

        except Exception as e:
            print(f"Failed to discover plugin from {plugin_dir}: {e}")
            traceback.print_exc()

    def _execute_backend(self, manifest):
        plugin_id = manifest['id']
        plugin_dir = Path(manifest['_plugin_dir'])
        
        try:
            entry = manifest.get('entry', {})
            backend_entry = entry.get('backend')
            frontend_entry = entry.get('frontend')

            if backend_entry:
                # Load python backend
                module_name = f"can_re_plugin_{plugin_id.replace('.', '_')}"
                
                if backend_entry.endswith('.py'):
                    backend_path = plugin_dir / backend_entry
                else:
                    backend_path = plugin_dir / backend_entry.replace('.', '/') / "__init__.py"
                    if not backend_path.exists():
                        backend_path = plugin_dir / f"{backend_entry.replace('.', '/')}.py"

                if backend_path.exists():
                    spec = importlib.util.spec_from_file_location(module_name, backend_path)
                    module = importlib.util.module_from_spec(spec)
                    sys.modules[module_name] = module
                    spec.loader.exec_module(module)
                    
                    if hasattr(module, 'setup'):
                        module.setup(self.api)
                    else:
                        print(f"Plugin {plugin_id} has no setup(api) method.")
                else:
                    print(f"Backend entry {backend_path} not found for plugin {plugin_id}.")

            if frontend_entry:
                frontend_path = plugin_dir / frontend_entry
                if frontend_path.exists():
                    with open(frontend_path, 'rb') as f:
                        self.plugin_bundles[plugin_id] = f.read()
                else:
                    print(f"Frontend entry {frontend_path} not found for plugin {plugin_id}.")

            self.active_plugins[plugin_id] = manifest
            print(f"Loaded backend for plugin: {plugin_id}")

        except Exception as e:
            print(f"Failed to load backend for plugin {plugin_id}: {e}")
            traceback.print_exc()

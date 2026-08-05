import traceback
import inspect
import cantools
import cantools.database
from .serialization import db_to_json, json_to_db
class DbcParserPlugin:
    def __init__(self, api):
        self.api = api
        self.db = None
        self.current_file_path = None

    def load_dbc(self):
        try:
            res = self.api.request_file(file_types=('DBC Files (*.dbc)', 'All files (*.*)'))
            if inspect.iscoroutine(res):
                return self._load_dbc_async_handler(res)
            
            name, path = res
            return self._process_dbc(name, path)
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    async def _load_dbc_async_handler(self, coro):
        try:
            name, path = await coro
            return self._process_dbc(name, path)
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    def _process_dbc(self, name, path):
        if path:
            try:
                self.db = cantools.database.load_file(path)
                self.current_file_path = path
                print(f"Loaded DBC: {name} with {len(self.db.messages)} messages")
                
                # Register this plugin as the active generic parser
                if hasattr(self.api, 'parsing'):
                    self.api.parsing.set_parser(self)
                    
                return {"success": True, "file": name, "messages_count": len(self.db.messages)}
            except Exception as e:
                traceback.print_exc()
                return {"error": f"Failed to parse DBC: {e}"}
        return {"cancelled": True}

    def new_file(self):
        self.db = cantools.database.Database()
        self.current_file_path = None
        if hasattr(self.api, 'parsing'):
            self.api.parsing.set_parser(self)
        return {"success": True, "file": "New DBC", "messages_count": 0}

    def unload_file(self):
        self.db = None
        self.current_file_path = None
        if hasattr(self.api, 'parsing'):
            self.api.parsing.set_parser(None)
        return {"success": True}

    def get_state(self):
        if not self.db:
            return {"error": "No DBC loaded"}
        return {
            "success": True, 
            "data": db_to_json(self.db),
            "file_path": self.current_file_path
        }

    def save_state(self, data, path=None):
        try:
            self.db = json_to_db(data)
            save_path = path or self.current_file_path
            if not save_path:
                return {"error": "No file path provided"}
            
            cantools.database.dump_file(self.db, save_path)
            self.current_file_path = save_path
            return {"success": True, "file_path": save_path}
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    def decode_message(self, frame_id, data, is_extended_id=False):
        if not self.db:
            return None
        try:
            if isinstance(data, list):
                data = bytes(data)
            msg = self.db.get_message_by_frame_id(frame_id)
            decoded = msg.decode(data)
            # Convert cantools NamedSignalValue to string for JSON serialization
            for k, v in decoded.items():
                if type(v).__name__ == 'NamedSignalValue':
                    decoded[k] = str(v)
            return decoded
        except KeyError:
            # Message ID not found in DBC
            return None
        except Exception as e:
            # Decode error (e.g. invalid length)
            return None

    def get_database(self):
        if not self.db:
            return None
        return {"messages_count": len(self.db.messages)}

def setup(api):
    plugin = DbcParserPlugin(api)
    api.services.register('dbc.load_file', plugin.load_dbc)
    api.services.register('dbc.new_file', plugin.new_file)
    api.services.register('dbc.unload_file', plugin.unload_file)
    api.services.register('dbc.get_state', plugin.get_state)
    api.services.register('dbc.save_state', plugin.save_state)

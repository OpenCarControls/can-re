import traceback
import inspect
import cantools

class DbcParserPlugin:
    def __init__(self, api):
        self.api = api
        self.db = None

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
                print(f"Loaded DBC: {name} with {len(self.db.messages)} messages")
                
                # Register this plugin as the active generic parser
                if hasattr(self.api, 'parsing'):
                    self.api.parsing.set_parser(self)
                    
                return {"success": True, "file": name, "messages_count": len(self.db.messages)}
            except Exception as e:
                traceback.print_exc()
                return {"error": f"Failed to parse DBC: {e}"}
        return {"cancelled": True}

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

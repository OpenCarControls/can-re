import traceback
import can
import inspect

class CanLogProviderPlugin:
    def __init__(self, api):
        self.api = api

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
            res = self.api.request_file(file_types=('CAN Logs (*.asc;*.blf;*.csv;*.trc)', 'All files (*.*)'))
            if inspect.iscoroutine(res):
                return self._load_log_async_handler(res)
            
            name, path = res
            return self._process_log(name, path)
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    async def _load_log_async_handler(self, coro):
        try:
            name, path = await coro
            return self._process_log(name, path)
        except Exception as e:
            traceback.print_exc()
            return {"error": str(e)}

    def _process_log(self, name, path):
        if path:
            frames = self._parse_log_file(path)
            self.api.state.clear()
            self.api.state.add_frames(frames)
            return {"success": True, "file": name, "total_count": len(self.api.state.frames)}
        return {"cancelled": True}

def setup(api):
    plugin = CanLogProviderPlugin(api)
    api.services.register('canlog_provider.load_file', plugin.load_log)

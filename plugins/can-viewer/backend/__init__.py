import traceback

class CanViewerPlugin:
    def __init__(self, api):
        self.api = api

    def get_log_chunk(self, start: int, length: int, reverse: bool = False):
        try:
            total = len(self.api.state.frames)
            if total == 0:
                return []
            
            if reverse:
                end_idx = total - start
                start_idx = max(0, end_idx - length)
                slice_msgs = self.api.state.frames[start_idx:end_idx]
                slice_msgs = slice_msgs[::-1]
            else:
                slice_msgs = self.api.state.frames[start:start + length]
            
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
                result.append(msg_dict)
            
            if hasattr(self.api, 'parsing') and self.api.parsing.is_available():
                result = self.api.parsing.decode_chunk(result)

            return result
        except Exception as e:
            traceback.print_exc()
            return []

def setup(api):
    plugin = CanViewerPlugin(api)
    api.services.register('can_log.get_chunk', plugin.get_log_chunk)

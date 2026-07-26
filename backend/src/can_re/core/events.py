import asyncio
import traceback

class EventBus:
    def __init__(self):
        self._listeners = {}

    def on(self, event_name: str, callback):
        if event_name not in self._listeners:
            self._listeners[event_name] = []
        self._listeners[event_name].append(callback)

    def off(self, event_name: str, callback):
        if event_name in self._listeners:
            try:
                self._listeners[event_name].remove(callback)
            except ValueError:
                pass

    def emit(self, event_name: str, data=None):
        if event_name in self._listeners:
            for callback in self._listeners[event_name]:
                try:
                    if asyncio.iscoroutinefunction(callback):
                        asyncio.ensure_future(callback(data))
                    else:
                        callback(data)
                except Exception:
                    traceback.print_exc()

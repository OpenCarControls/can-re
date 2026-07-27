class ServiceRegistry:
    def __init__(self):
        self._services = {}

    def register(self, service_name: str, handler):
        if service_name in self._services:
            print(f"Warning: Overwriting service {service_name}")
        self._services[service_name] = handler

    def unregister(self, service_name: str):
        if service_name in self._services:
            del self._services[service_name]

    def has_service(self, service_name: str) -> bool:
        return service_name in self._services

    def call(self, service_name: str, *args, **kwargs):
        if service_name not in self._services:
            raise ValueError(f"Service {service_name} not found")
        
        handler = self._services[service_name]
        return handler(*args, **kwargs)

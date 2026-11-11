## Service Locator. Swappable global services (audio, haptics, analytics, save, ads) register here
## so tests can inject fakes. Note: the lookup is named locate() because Object.get() is a native
## method that GDScript scripts are not allowed to override.
class_name Services
extends RefCounted

static var _services: Dictionary = {}


## Registers (or replaces) a service.
static func provide(id: StringName, service: Object) -> void:
	_services[id] = service


## Returns the service registered under id, or null.
static func locate(id: StringName) -> Object:
	return _services.get(id) as Object


## True when a service is registered.
static func has(id: StringName) -> bool:
	return _services.has(id)


## Removes a service (used by tests to restore the previous one).
static func remove(id: StringName) -> void:
	_services.erase(id)

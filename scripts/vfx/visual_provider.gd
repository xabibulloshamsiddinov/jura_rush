## Asset-swap indirection. Every visual is requested by id: if res://assets/meshes/<id>.glb (or
## .tscn) exists it is instanced, otherwise the caller's primitive builder runs.
## Conventions for replacement art: 1 unit = 1 m, +Y up, forward = -Z, pivot at ground centre.
class_name VisualProvider
extends RefCounted

const MESH_DIR: String = "res://assets/meshes/"

static var _scene_cache: Dictionary = {}


## Builds the visual for `id`. `fallback` is a Callable returning a Node3D made of primitives.
static func build(id: StringName, fallback: Callable) -> Node3D:
	var scene: PackedScene = _find_scene(id)
	if scene != null:
		var instance: Node3D = scene.instantiate() as Node3D
		if instance != null:
			return instance
	return fallback.call() as Node3D


## True when replacement art exists for an id.
static func has_override(id: StringName) -> bool:
	return _find_scene(id) != null


static func _find_scene(id: StringName) -> PackedScene:
	if _scene_cache.has(id):
		return _scene_cache[id] as PackedScene
	var found: PackedScene = null
	for ext: String in [".glb", ".gltf", ".tscn"]:
		var path: String = MESH_DIR + String(id) + ext
		if ResourceLoader.exists(path):
			found = ResourceLoader.load(path) as PackedScene
			break
	_scene_cache[id] = found
	return found

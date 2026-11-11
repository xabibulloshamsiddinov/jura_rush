## Generic object pool. Builds items from a PackedScene or a factory Callable, never frees them
## during play. Items may implement on_acquire() / on_release() to reset their state.
class_name ObjectPool
extends RefCounted

const META_POOLED: StringName = &"_pooled"

var id: StringName = &""
## Total nodes ever created by this pool.
var created: int = 0
## Nodes currently handed out.
var in_use: int = 0

var _free: Array[Node] = []
var _scene: PackedScene = null
var _factory: Callable = Callable()
var _can_grow: bool = true


func _init(p_id: StringName, scene: PackedScene, factory: Callable, initial: int,
		can_grow: bool = true) -> void:
	id = p_id
	_scene = scene
	_factory = factory
	_can_grow = can_grow
	for i in range(initial):
		_free.append(_create())


## Takes an item out of the pool (creating one if empty and growth is allowed).
func acquire() -> Node:
	var node: Node = null
	if _free.is_empty():
		if not _can_grow:
			return null
		node = _create()
	else:
		node = _free.pop_back() as Node
	node.set_meta(META_POOLED, false)
	in_use += 1
	if node.has_method(&"on_acquire"):
		node.call(&"on_acquire")
	return node


## Returns an item. It is detached from its parent and kept alive for reuse.
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_meta(META_POOLED, true):
		return
	node.set_meta(META_POOLED, true)
	if node.has_method(&"on_release"):
		node.call(&"on_release")
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	in_use -= 1
	_free.append(node)


## Number of idle items.
func free_count() -> int:
	return _free.size()


## Frees every idle item. Call only on shutdown.
func dispose() -> void:
	for node in _free:
		if is_instance_valid(node):
			node.free()
	_free.clear()


func _create() -> Node:
	var node: Node = null
	if _scene != null:
		node = _scene.instantiate()
	else:
		node = _factory.call() as Node
	node.set_meta(META_POOLED, true)
	created += 1
	return node

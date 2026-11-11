## Owns every ObjectPool in the game (obstacles, pickups, VFX, floating texts, chunks).
## After pre-warm, a run performs zero instantiate() calls.
extends Node

var _pools: Dictionary = {}


func _exit_tree() -> void:
	for pool: ObjectPool in _pools.values():
		pool.dispose()
	_pools.clear()


## Creates a pool that instantiates a PackedScene.
func register_scene(id: StringName, scene: PackedScene, initial: int) -> void:
	if not _pools.has(id):
		_pools[id] = ObjectPool.new(id, scene, Callable(), initial)


## Creates a pool whose items are built by a factory Callable returning a Node.
## Fixed-size pools (can_grow = false) return null from acquire() when empty.
func register_factory(id: StringName, factory: Callable, initial: int, can_grow: bool = true) -> void:
	if not _pools.has(id):
		_pools[id] = ObjectPool.new(id, null, factory, initial, can_grow)


## True when a pool exists.
func has_pool(id: StringName) -> bool:
	return _pools.has(id)


## Takes a node from a pool (null when the pool is unknown).
func acquire(id: StringName) -> Node:
	var pool: ObjectPool = _pools.get(id) as ObjectPool
	if pool == null:
		Log.error(&"pool", "unknown pool %s" % id)
		return null
	return pool.acquire()


## Returns a node to its pool.
func release(id: StringName, node: Node) -> void:
	var pool: ObjectPool = _pools.get(id) as ObjectPool
	if pool != null:
		pool.release(node)
	elif is_instance_valid(node):
		node.queue_free()


## Total nodes created by all pools (used by leak tests).
func total_created() -> int:
	var total: int = 0
	for pool: ObjectPool in _pools.values():
		total += pool.created
	return total


## Total nodes currently handed out.
func total_in_use() -> int:
	var total: int = 0
	for pool: ObjectPool in _pools.values():
		total += pool.in_use
	return total


## One line per pool: "id used/created" (debug overlay).
func stats_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for pool: ObjectPool in _pools.values():
		parts.append("%s %d/%d" % [pool.id, pool.in_use, pool.created])
	return ", ".join(parts)

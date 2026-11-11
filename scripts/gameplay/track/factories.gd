## Factory pattern: the only place that turns definitions into nodes. Everything comes out of
## PoolManager pools, so track generation never calls instantiate() or new() on scene nodes
## during a run.
class_name Factories
extends RefCounted

const CHUNK_POOL: StringName = &"chunk"


## Registers and pre-warms every gameplay pool. Call once at boot.
static func register_pools(chunk_count: int) -> void:
	for def: ObstacleDef in ContentDB.OBSTACLES:
		PoolManager.register_factory(def.id, Obstacles.build.bind(def), def.pool_size)
	PoolManager.register_factory(&"pickup_powerup", func() -> Node: return PowerupPickup.new(), 4)
	PoolManager.register_factory(&"pickup_box", func() -> Node: return MysteryBox.new(), 5)
	PoolManager.register_factory(CHUNK_POOL, func() -> Node: return TrackChunk.new(), chunk_count)


## Builds obstacles from ObstacleDef ids.
class Obstacles extends RefCounted:
	## Pool factory callback: creates one node for a definition.
	static func build(def: ObstacleDef) -> Node:
		var node: ObstacleBase = null
		match def.kind:
			&"train":
				node = Train.new()
			&"barrier_low":
				node = BarrierLow.new()
			&"barrier_high":
				node = BarrierHigh.new()
			&"barrier_full":
				node = BarrierFull.new()
			&"ramp":
				node = Ramp.new()
			&"gap":
				node = Gap.new()
			&"hazard_light":
				node = HazardLight.new()
			_:
				node = ObstacleBase.new()
		node.setup(def)
		return node

	## Takes a configured obstacle from its pool.
	static func create(id: StringName, lane: int, x: float, z_center: float, run_length: float) -> ObstacleBase:
		var node: ObstacleBase = PoolManager.acquire(id) as ObstacleBase
		if node != null:
			node.configure(lane, x, z_center, run_length)
		return node


## Builds non-coin pickups.
class Pickups extends RefCounted:
	## A power-up item for a definition id (null when the id is unknown).
	static func create_powerup(id: StringName) -> PowerupPickup:
		var def: PowerupDef = ContentDB.powerup(id)
		if def == null:
			return null
		var node: PowerupPickup = PoolManager.acquire(&"pickup_powerup") as PowerupPickup
		node.set_powerup(def)
		return node

	## A mystery box.
	static func create_box() -> MysteryBox:
		return PoolManager.acquire(&"pickup_box") as MysteryBox


## Hands out track chunks.
class Chunks extends RefCounted:
	## Takes a cleared chunk from the pool.
	static func create() -> TrackChunk:
		return PoolManager.acquire(CHUNK_POOL) as TrackChunk

	## Returns a chunk (its contents go back to their own pools).
	static func recycle(chunk: TrackChunk) -> void:
		PoolManager.release(CHUNK_POOL, chunk)

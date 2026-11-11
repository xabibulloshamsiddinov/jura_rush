## A chunk's coins: one MultiMesh, no per-coin nodes. Positions live in packed arrays and are
## tested by PickupSystem with a single distance sweep. Spinning happens in coin.gdshader.
class_name CoinField
extends MultiMeshInstance3D

const CAPACITY: int = 96
const DEAD: int = 0
const ALIVE: int = 1
const PULLED: int = 2

## Number of coin slots in use (dead ones included until the next clear()).
var count: int = 0
var positions: PackedVector3Array = PackedVector3Array()
var states: PackedByteArray = PackedByteArray()
## Seconds each coin has been pulled by the magnet (ease-in attraction).
var pull_time: PackedFloat32Array = PackedFloat32Array()

var _upright: Basis = Basis(Vector3.RIGHT, PI * 0.5)
var _hidden: Transform3D = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0.0, -50.0, 0.0))


func _init() -> void:
	positions.resize(CAPACITY)
	states.resize(CAPACITY)
	pull_time.resize(CAPACITY)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshLib.coin()
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = Mats.coin()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 40.0
	custom_aabb = AABB(Vector3(-6.0, -2.0, -40.0), Vector3(12.0, 14.0, 50.0))


## Removes every coin.
func clear() -> void:
	count = 0
	multimesh.visible_instance_count = 0


## Adds a coin at a position local to this node. Silently ignored when full.
func add(local_pos: Vector3) -> void:
	if count >= CAPACITY:
		return
	positions[count] = local_pos
	states[count] = ALIVE
	pull_time[count] = 0.0
	multimesh.set_instance_transform(count, Transform3D(_upright, local_pos))
	count += 1
	multimesh.visible_instance_count = count


## Hides a coin (collected or expired).
func kill(index: int) -> void:
	states[index] = DEAD
	multimesh.set_instance_transform(index, _hidden)


## Moves a coin (magnet attraction).
func move(index: int, local_pos: Vector3) -> void:
	positions[index] = local_pos
	multimesh.set_instance_transform(index, Transform3D(_upright, local_pos))

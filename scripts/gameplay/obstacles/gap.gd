## Gap / pit in a lane. It has no collision box: it removes the ground, so a runner who does not
## jump simply falls in. Drawn as a dark slab with glowing warning edges.
class_name Gap
extends ObstacleBase

const DEPTH: float = -30.0

var _pit: MeshInstance3D = null
var _edge_near: MeshInstance3D = null
var _edge_far: MeshInstance3D = null


func setup(p_def: ObstacleDef) -> void:
	super.setup(p_def)
	shapes_ground = true


func ground_height_at(_dz: float) -> float:
	return DEPTH


func blocks(_feet_y: float, _top_y: float, _dz: float, _step: float) -> bool:
	return false


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	_pit = MeshLib.mi(MeshLib.box(), Mats.lit(def.color), Vector3(0.0, 0.02, 0.0))
	_edge_near = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, 2.4))
	_edge_far = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, 2.4))
	root.add_child(_pit)
	root.add_child(_edge_near)
	root.add_child(_edge_far)
	return root


func _apply_length() -> void:
	if _pit == null:
		return
	var w: float = def.size.x
	_pit.scale = Vector3(w, 0.16, length)
	_edge_near.position = Vector3(0.0, 0.1, length * 0.5)
	_edge_near.scale = Vector3(w, 0.06, 0.12)
	_edge_far.position = Vector3(0.0, 0.1, -length * 0.5)
	_edge_far.scale = Vector3(w, 0.06, 0.12)

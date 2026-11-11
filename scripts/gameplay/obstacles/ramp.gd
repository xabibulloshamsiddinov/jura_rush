## Ramp leading up to a train roof. Running into its low end is safe (the ground just rises);
## stepping into its side while it is already tall is a stumble.
class_name Ramp
extends ObstacleBase

var _wedge: MeshInstance3D = null
var _arrow: MeshInstance3D = null


func setup(p_def: ObstacleDef) -> void:
	super.setup(p_def)
	shapes_ground = true


func ground_height_at(dz: float) -> float:
	return _height_at(dz)


func blocks(feet_y: float, _top_y: float, dz: float, step: float) -> bool:
	return feet_y < _height_at(dz) - step


## Ramp surface height: 0 at the near end, def.size.y at the far end.
func _height_at(dz: float) -> float:
	return def.size.y * clampf((length * 0.5 - dz) / maxf(length, 0.01), 0.0, 1.0)


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	_wedge = MeshLib.mi(MeshLib.wedge(), Mats.lit(def.color))
	# The wedge is high at local x = -0.5; turning it -90 deg about Y maps that to the far end.
	_wedge.rotation.y = -PI * 0.5
	_wedge.extra_cull_margin = 8.0
	root.add_child(_wedge)
	_arrow = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, 2.2))
	root.add_child(_arrow)
	return root


func _apply_length() -> void:
	if _wedge == null:
		return
	var h: float = def.size.y
	_wedge.scale = Vector3(length, h, def.size.x)
	_wedge.position = Vector3(0.0, h * 0.5, 0.0)
	var slope: float = atan2(h, length)
	_arrow.position = Vector3(0.0, h * 0.5 + 0.03, 0.0)
	_arrow.rotation = Vector3(slope, 0.0, 0.0)
	_arrow.scale = Vector3(0.25, 0.03, sqrt(h * h + length * length) * 0.8)

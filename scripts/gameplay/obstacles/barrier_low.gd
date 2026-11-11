## Low barrier: jump over it. A frontal hit is a stumble.
class_name BarrierLow
extends ObstacleBase


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	var w: float = def.size.x
	var h: float = def.size.y
	root.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(def.color), Vector3(0.0, h * 0.5, 0.0),
			Vector3(w, h, def.size.z)))
	root.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, 2.2),
			Vector3(0.0, h - 0.12, 0.0), Vector3(w + 0.04, 0.14, def.size.z + 0.04)))
	root.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, 1.2),
			Vector3(0.0, h * 0.4, 0.0), Vector3(w + 0.04, 0.08, def.size.z + 0.04)))
	_add_lane_warning(root, def.glow)
	return root

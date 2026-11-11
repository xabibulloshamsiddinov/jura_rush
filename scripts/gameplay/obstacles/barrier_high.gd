## High barrier / overhead sign: roll under it. A frontal hit is a stumble.
class_name BarrierHigh
extends ObstacleBase


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	var w: float = def.size.x
	var h: float = def.size.y
	var mid: float = def.y_offset + h * 0.5
	var post: ShaderMaterial = Mats.lit(def.color)
	root.add_child(MeshLib.mi(MeshLib.box(), post, Vector3(-w * 0.5, y_max * 0.5, 0.0),
			Vector3(0.12, y_max, 0.12)))
	root.add_child(MeshLib.mi(MeshLib.box(), post, Vector3(w * 0.5, y_max * 0.5, 0.0),
			Vector3(0.12, y_max, 0.12)))
	root.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(def.color), Vector3(0.0, mid, 0.0),
			Vector3(w, h, def.size.z)))
	root.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, 2.2),
			Vector3(0.0, def.y_offset + 0.08, 0.0), Vector3(w + 0.04, 0.16, def.size.z + 0.04)))
	root.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, 1.4),
			Vector3(0.0, mid + 0.15, def.size.z * 0.5 + 0.01), Vector3(w * 0.6, 0.35, 0.02)))
	return root

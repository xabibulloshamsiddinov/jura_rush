## Full-height barrier: cannot be jumped or rolled, the lane must be changed. Frontal hit is lethal.
class_name BarrierFull
extends ObstacleBase


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	var w: float = def.size.x
	var h: float = def.size.y
	root.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(def.color), Vector3(0.0, h * 0.5, 0.0),
			Vector3(w, h, def.size.z)))
	# Pulsing warning glow that also shows through the fog, so the X reads from far away.
	var glow_mat: ShaderMaterial = Mats.warning(def.glow, 2.4)
	var front: float = def.size.z * 0.5 + 0.015
	for sign_dir: float in [-1.0, 1.0]:
		var bar: MeshInstance3D = MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.0, h * 0.55, front),
				Vector3(0.14, h * 0.78, 0.02))
		bar.rotation.z = sign_dir * 0.6
		root.add_child(bar)
	root.add_child(MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.0, h - 0.07, 0.0),
			Vector3(w + 0.04, 0.14, def.size.z + 0.04)))
	_add_lane_warning(root, def.glow)
	return root

## Flickering torch on a pole, planted on the grass strip between two lanes. Harmless: it only
## telegraphs trouble ahead. The flame flickers in flame.gdshader, so it needs no tick.
class_name HazardLight
extends ObstacleBase

static var _pole: ArrayMesh = null
static var _flame: ArrayMesh = null


func configure(p_lane: int, x: float, z_center: float, run_length: float) -> void:
	super.configure(p_lane, x, z_center, run_length)
	# Stand between lanes so it never sits in the running line.
	position.x += 0.98 if p_lane <= 1 else -0.98


func blocks(_feet_y: float, _top_y: float, _dz: float, _step: float) -> bool:
	return false


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	var h: float = def.size.y
	if _pole == null:
		_pole = _build_pole(h, def.color)
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		TrackFeatures.add_flame(st, Vector3(0.0, h - 0.12, 0.0), 0.36, 0.62, 0.37)
		TrackFeatures.add_pool(st, Vector3(0.0, 0.06, 0.0), 2.4, 0.37)
		_flame = st.commit()
	var pole: MeshInstance3D = MeshInstance3D.new()
	pole.mesh = _pole
	pole.material_override = Mats.nature()
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(pole)
	var flame: MeshInstance3D = MeshInstance3D.new()
	flame.mesh = _flame
	flame.material_override = Mats.flame()
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flame)
	return root


static func _build_pole(h: float, wood: Color) -> ArrayMesh:
	var st: SurfaceTool = NatureMesh.begin()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 612
	NatureMesh.tube(st, PackedVector3Array([Vector3(0.0, -0.1, 0.0), Vector3(0.02, h * 0.5, 0.0),
			Vector3(0.0, h - 0.22, 0.0)]), PackedFloat32Array([0.075, 0.065, 0.06]), 6,
			PackedColorArray([NatureMesh.shade(wood, 0.8), wood]), PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, false)
	# Lashed head soaked in resin (glows) and a binding band under it.
	NatureMesh.tube(st, PackedVector3Array([Vector3(0.0, h - 0.42, 0.0), Vector3(0.0, h - 0.34, 0.0)]),
			PackedFloat32Array([0.085, 0.085]), 6, PackedColorArray([Color(0.62, 0.5, 0.3)]),
			PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, false)
	NatureMesh.rock(st, Vector3(0.0, h - 0.2, 0.0), Vector3(0.13, 0.12, 0.13), rng, Color(0.95, 0.5, 0.18), 0,
			0.15, 0.9, Color(0, 0, 0, 0), NatureMesh.TAG_GLOW)
	# Little cairn holding the pole.
	for i in range(5):
		var a: float = TAU * float(i) / 5.0
		NatureMesh.rock(st, Vector3(cos(a) * 0.17, 0.07, sin(a) * 0.17), Vector3(0.12, 0.1, 0.11), rng,
				Color(0.55, 0.51, 0.46), 0, 0.2, 0.5)
	return NatureMesh.commit(st)

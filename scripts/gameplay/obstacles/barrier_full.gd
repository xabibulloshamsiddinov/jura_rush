## Full-height barrier: a wall of tall standing stones (menhirs) with ochre warning bands painted
## on - cannot be jumped or rolled, the lane must be changed. Frontal hit is lethal. Collision is
## the def box (1.8 x 2.8 x 0.4); the tallest stone reaches the top of it.
class_name BarrierFull
extends ObstacleBase

const VARIANTS: int = 2

static var _meshes: Array[ArrayMesh] = []
static var _next: int = 0


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	if _meshes.is_empty():
		for v in range(VARIANTS):
			_meshes.append(_build_mesh(v))
	var stones: MeshInstance3D = MeshInstance3D.new()
	stones.mesh = _meshes[_next % VARIANTS]
	_next += 1
	stones.material_override = Mats.nature()
	stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(stones)
	_add_lane_warning(root, def.glow)
	return root


func _build_mesh(variant: int) -> ArrayMesh:
	var st: SurfaceTool = NatureMesh.begin()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 500 + variant * 31
	var w: float = def.size.x
	var h: float = def.size.y
	var c: Color = def.color
	var paint: Color = def.glow
	var mirror: float = -1.0 if variant == 1 else 1.0
	var bands: PackedFloat32Array = PackedFloat32Array([h * 0.32, h * 0.44, h * 0.6, h * 0.7])
	NatureMesh.rock(st, Vector3(0.04 * mirror, h * 0.5, 0.0), Vector3(w * 0.28, h * 0.515, 0.36), rng, c,
			1, 0.1, 0.95, Color(0, 0, 0, 0), NatureMesh.TAG_ROCK, 0.0, 0.0, paint, bands)
	var left_h: float = h * 0.84
	NatureMesh.rock(st, Vector3(-w * 0.35 * mirror, left_h * 0.5, 0.04), Vector3(w * 0.2, left_h * 0.52, 0.32), rng,
			NatureMesh.shade(c, 1.07), 1, 0.12, 0.95, Color(0, 0, 0, 0), NatureMesh.TAG_ROCK, 0.0, 0.1,
			paint, PackedFloat32Array([left_h * 0.4, left_h * 0.52]))
	var right_h: float = h * 0.92
	NatureMesh.rock(st, Vector3(w * 0.36 * mirror, right_h * 0.5, -0.03), Vector3(w * 0.2, right_h * 0.52, 0.32), rng,
			NatureMesh.shade(c, 0.94), 1, 0.12, 0.95, Color(0, 0, 0, 0), NatureMesh.TAG_ROCK, 0.0, -0.08,
			paint, PackedFloat32Array([right_h * 0.36, right_h * 0.48]))
	for i in range(3):
		var x: float = rng.randf_range(-w * 0.45, w * 0.45)
		var s: float = rng.randf_range(0.18, 0.28)
		NatureMesh.rock(st, Vector3(x, s * 0.45, rng.randf_range(0.32, 0.45)), Vector3(s * 1.2, s, s), rng,
				NatureMesh.shade(c, rng.randf_range(0.9, 1.1)), 0, 0.2, 0.5)
	return NatureMesh.commit(st)

## Low barrier: a knee-high pile of boulders across the lane - jump over it. A frontal hit is a
## stumble. Collision is the def box (1.8 x 1.0 x 0.3); the rocks fill it and stay below 1 m.
class_name BarrierLow
extends ObstacleBase

const VARIANTS: int = 3

static var _meshes: Array[ArrayMesh] = []
static var _next: int = 0


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	if _meshes.is_empty():
		for v in range(VARIANTS):
			_meshes.append(_build_mesh(v))
	var rocks: MeshInstance3D = MeshInstance3D.new()
	rocks.mesh = _meshes[_next % VARIANTS]
	_next += 1
	rocks.material_override = Mats.nature()
	rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(rocks)
	_add_lane_warning(root, def.glow)
	return root


func _build_mesh(variant: int) -> ArrayMesh:
	var st: SurfaceTool = NatureMesh.begin()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 300 + variant * 17
	var w: float = def.size.x
	var h: float = def.size.y
	var mirror: float = -1.0 if variant == 1 else 1.0
	var c: Color = def.color
	NatureMesh.rock(st, Vector3(0.05 * mirror, h * 0.48, 0.0), Vector3(w * 0.3, h * 0.52, 0.42), rng, c, 1, 0.16, 0.85)
	NatureMesh.rock(st, Vector3(-w * 0.33 * mirror, h * 0.36, 0.05), Vector3(w * 0.23, h * 0.4, 0.38), rng,
			NatureMesh.shade(c, 1.08), 1, 0.18, 0.85)
	NatureMesh.rock(st, Vector3(w * 0.35 * mirror, h * 0.3, -0.04), Vector3(w * 0.21, h * 0.34, 0.36), rng,
			NatureMesh.shade(c, 0.93), 1, 0.18, 0.85)
	for i in range(4):
		var x: float = rng.randf_range(-w * 0.45, w * 0.45)
		var s: float = rng.randf_range(0.1, 0.18)
		NatureMesh.rock(st, Vector3(x, s * 0.4, rng.randf_range(0.3, 0.45)), Vector3(s, s * 0.8, s), rng,
				NatureMesh.shade(c, rng.randf_range(0.85, 1.1)), 0, 0.2, 0.5)
	return NatureMesh.commit(st)

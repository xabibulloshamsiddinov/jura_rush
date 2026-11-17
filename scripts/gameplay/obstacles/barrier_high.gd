## High barrier: a stone dolmen - a heavy capstone on two standing stones, with a low dark opening
## under it - roll under. A frontal hit is a stumble. Collision is the def box (1.8 wide, from
## y_offset 1.2 up to 2.8): the capstone fills it and its flat underside sits just above 1.2 m.
class_name BarrierHigh
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
	rng.seed = 400 + variant * 23
	var w: float = def.size.x
	var bottom: float = def.y_offset + 0.04
	var c: Color = def.color
	var post: Color = NatureMesh.shade(c, 0.78)
	# Chunky standing stones at the lane edges, reaching up into the lintel.
	for side: float in [-1.0, 1.0]:
		var post_h: float = bottom + 0.3
		NatureMesh.rock(st, Vector3(side * (w * 0.5 - 0.2), post_h * 0.5, 0.0), Vector3(0.28, post_h * 0.52, 0.32),
				rng, post, 1, 0.1, 0.96)
		NatureMesh.rock(st, Vector3(side * w * 0.55, 0.14, 0.25), Vector3(0.24, 0.16, 0.2), rng,
				NatureMesh.shade(post, 0.95), 0, 0.2, 0.5)
	# The lintel: a long flat slab wider than the lane, its flat underside at `bottom`.
	var flat: float = 0.97
	var slab_ry: float = 0.34
	var slab_top: float = bottom + slab_ry * (1.0 + flat)
	var tilt: float = 0.04 if variant == 0 else -0.04
	NatureMesh.rock(st, Vector3(0.0, bottom + slab_ry * flat, 0.0), Vector3(w * 0.68, slab_ry, 0.4), rng,
			c, 1, 0.07, flat, Color(0, 0, 0, 0), NatureMesh.TAG_ROCK, 0.0, tilt)
	# Cap stones piled on the lintel up to the top of the collision box (y_max).
	var cap_ry: float = (y_max - slab_top + 0.05) / 1.9
	for side: float in [-1.0, 1.0]:
		var x: float = side * w * (0.2 if variant == 0 else 0.16)
		NatureMesh.rock(st, Vector3(x, slab_top - 0.05 + cap_ry * 0.9, 0.0), Vector3(0.42, cap_ry, 0.34), rng,
				NatureMesh.shade(c, 0.92 if side < 0.0 else 1.05), 1, 0.12, 0.9)
	return NatureMesh.commit(st)

## Builds the static look of a chunk: one merged track mesh shared by all chunks (2 draw calls)
## and the per-chunk MultiMesh of side buildings.
class_name TrackVisuals
extends RefCounted

const DECOR_CAPACITY: int = 24
const GROUND_COLOR: Color = Color(0.05, 0.055, 0.1)
const SIDE_COLOR: Color = Color(0.025, 0.028, 0.06)
const TIE_COLOR: Color = Color(0.09, 0.08, 0.1)
const RAIL_COLOR: Color = Color(0.45, 0.5, 0.62)
const POLE_COLOR: Color = Color(0.1, 0.1, 0.16)

static var _track_mesh: ArrayMesh = null
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## The merged static mesh of one chunk: bed, rails, ties, lamp posts (surface 0, vertex
## coloured) and glowing edge strips, lane dashes and lamp heads (surface 1).
static func track_mesh(cfg: GameConfig) -> ArrayMesh:
	if _track_mesh != null:
		return _track_mesh
	var length: float = cfg.chunk_length
	var half_bed: float = cfg.lane_width * float(cfg.lane_count) * 0.5 + 0.6
	var solid: SurfaceTool = SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow: SurfaceTool = SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid_z: float = -length * 0.5
	MeshLib.add_box(solid, Vector3(0.0, -0.1, mid_z), Vector3(half_bed * 2.0, 0.2, length), GROUND_COLOR)
	MeshLib.add_box(solid, Vector3(0.0, -0.3, mid_z), Vector3(90.0, 0.2, length), SIDE_COLOR)
	for lane in range(cfg.lane_count):
		var x: float = cfg.lane_x(lane)
		for side: float in [-0.55, 0.55]:
			MeshLib.add_box(solid, Vector3(x + side, 0.06, mid_z), Vector3(0.08, 0.12, length), RAIL_COLOR)
		var ties: int = int(length / 1.5)
		for i in range(ties):
			MeshLib.add_box(solid, Vector3(x, 0.02, -(float(i) + 0.5) * 1.5), Vector3(1.5, 0.05, 0.32), TIE_COLOR)
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(glow, Vector3(side * half_bed, 0.04, mid_z), Vector3(0.12, 0.08, length))
		for i in range(int(length / 10.0)):
			var z: float = -(float(i) + 0.5) * 10.0
			MeshLib.add_box(solid, Vector3(side * (half_bed + 0.9), 2.6, z), Vector3(0.14, 5.2, 0.14), POLE_COLOR)
			MeshLib.add_box(solid, Vector3(side * (half_bed + 0.55), 5.2, z), Vector3(0.9, 0.1, 0.14), POLE_COLOR)
			MeshLib.add_box(glow, Vector3(side * (half_bed + 0.25), 5.1, z), Vector3(0.5, 0.1, 0.3))
	for boundary in range(1, cfg.lane_count):
		var bx: float = cfg.lane_x(boundary) - cfg.lane_width * 0.5
		for i in range(int(length / 3.0)):
			MeshLib.add_box(glow, Vector3(bx, 0.015, -(float(i) + 0.5) * 3.0), Vector3(0.07, 0.03, 1.2))
	_track_mesh = ArrayMesh.new()
	solid.commit(_track_mesh)
	glow.commit(_track_mesh)
	_track_mesh.surface_set_material(0, Mats.lit(Color.WHITE))
	_track_mesh.surface_set_material(1, Mats.lit(Color.BLACK, Color.WHITE, 1.5, 1.0))
	return _track_mesh


## Creates the (empty) decor MultiMesh for a chunk.
static func new_decor_multimesh() -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MeshLib.box()
	mm.instance_count = DECOR_CAPACITY
	mm.visible_instance_count = 0
	return mm


## Fills a decor MultiMesh. decor_set: 0 towers, 1 warehouses, 2 pylons and tanks.
static func fill_decor(mm: MultiMesh, decor_set: int, decor_seed: int, per_side: int,
		cfg: GameConfig) -> void:
	_rng.seed = decor_seed
	var count: int = 0
	var slot: float = cfg.chunk_length / float(per_side)
	for side: float in [-1.0, 1.0]:
		for i in range(per_side):
			if count >= DECOR_CAPACITY:
				break
			var w: float = _rng.randf_range(4.0, 8.0)
			var h: float = _rng.randf_range(10.0, 34.0)
			var d: float = _rng.randf_range(slot * 0.55, slot * 0.9)
			if decor_set == 1:
				w = _rng.randf_range(7.0, 12.0)
				h = _rng.randf_range(5.0, 11.0)
			elif decor_set == 2:
				w = _rng.randf_range(1.2, 3.5)
				h = _rng.randf_range(14.0, 40.0)
				d = w
			var x: float = side * (_rng.randf_range(9.0, 15.0) + w * 0.5)
			var z: float = -(float(i) + 0.5) * slot + _rng.randf_range(-1.0, 1.0)
			var basis: Basis = Basis().scaled(Vector3(w, h, d))
			mm.set_instance_transform(count, Transform3D(basis, Vector3(x, h * 0.5 - 0.3, z)))
			var shade: float = _rng.randf_range(0.7, 1.4)
			mm.set_instance_color(count, Color(shade, shade, shade * 1.1))
			count += 1
	mm.visible_instance_count = count

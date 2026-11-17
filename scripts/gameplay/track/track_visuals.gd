## Builds the static look of a chunk: one merged stone-path track mesh shared by all chunks
## (1 draw call; the ground style is per chunk through instance uniforms) and the per-chunk decor
## MultiMeshes (FloraLibrary.SLOT_COUNT of them, one per decor slot). Tunnels and bridges are
## built by TrackFeatures.
class_name TrackVisuals
extends RefCounted

## Instances per decor slot MultiMesh.
const DECOR_CAPACITY: int = 24
## Flagstone path: half width, top height and the bevel that rounds its edge into the earth.
const PATH_HALF: float = 0.8
const PATH_TOP: float = 0.045
const PATH_BEVEL: float = 0.07
## Ground columns beyond the outer path edges (metres from the track centre).
const OUTER_X: Array[float] = [3.25, 3.9, 4.8, 6.0, 7.6, 9.6, 12.2, 15.5, 20.0, 26.0, 34.0, 45.0, 60.0]
const GROUND_ROWS: int = 15
## Pale path stone (sRGB), tinted per style by the track shader.
const STONE_COLOR: Color = Color(0.63, 0.59, 0.53)
const TUFT_BASE: Color = Color(0.2, 0.42, 0.14)
const TUFT_TIP: Color = Color(0.44, 0.68, 0.26)

static var _track_mesh: ArrayMesh = null
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Track features a chunk can carry (TrackChunk.set_feature).
enum Feature { NONE, TUNNEL, BRIDGE }
## Cave roof height at the centre: above the jetpack flight line and the camera while flying.
const TUNNEL_HEIGHT: float = 10.0


## The merged static mesh of one chunk: three flagstone paths with bevelled edges, earth and grass
## between and beside them, rolling terrain further out, border stones along the outer edges,
## pebbles and grass tufts. One surface, one material (track_ground.gdshader).
static func track_mesh(cfg: GameConfig) -> ArrayMesh:
	if _track_mesh != null:
		return _track_mesh
	FloraLibrary.prewarm()
	var length: float = cfg.chunk_length
	var st: SurfaceTool = NatureMesh.begin()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var outer_edge: float = cfg.lane_x(cfg.lane_count - 1) + PATH_HALF + PATH_BEVEL
	# Flagstone paths (tag 1).
	var path_rows: int = 20
	for lane in range(cfg.lane_count):
		var cx: float = cfg.lane_x(lane)
		for i in range(path_rows):
			var z0: float = -length * float(i) / float(path_rows)
			var z1: float = -length * float(i + 1) / float(path_rows)
			NatureMesh.quad(st, Vector3(cx - PATH_HALF, PATH_TOP, z0), Vector3(cx + PATH_HALF, PATH_TOP, z0),
					Vector3(cx + PATH_HALF, PATH_TOP, z1), Vector3(cx - PATH_HALF, PATH_TOP, z1),
					Color(1, 1, 1, 1), 1.0, Vector3.UP)
			for side: float in [-1.0, 1.0]:
				var a: float = cx + side * PATH_HALF
				var b: float = cx + side * (PATH_HALF + PATH_BEVEL)
				var n: Vector3 = Vector3(side * 0.55, 1.0, 0.0).normalized()
				NatureMesh.quad(st, Vector3(a, PATH_TOP, z0), Vector3(b, 0.0, z0), Vector3(b, 0.0, z1),
						Vector3(a, PATH_TOP, z1), Color(1, 1, 1, 0.85), 1.0, n)
	# Ground (tag 0): strips between the paths, then columns out to the hills.
	var xs: Array[float] = []
	for i in range(OUTER_X.size() - 1, -1, -1):
		xs.append(-OUTER_X[i])
	xs.append(-outer_edge)
	for lane in range(cfg.lane_count - 1):
		var mid: float = (cfg.lane_x(lane) + cfg.lane_x(lane + 1)) * 0.5
		var half_gap: float = cfg.lane_width * 0.5 - PATH_HALF - PATH_BEVEL
		xs.append(mid - half_gap)
		xs.append(mid + half_gap)
	xs.append(outer_edge)
	for x: float in OUTER_X:
		xs.append(x)
	for i in range(xs.size() - 1):
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		# Skip the spans covered by a path.
		if _inside_path(cfg, (xa + xb) * 0.5):
			continue
		for r in range(GROUND_ROWS):
			var z0: float = -length * float(r) / float(GROUND_ROWS)
			var z1: float = -length * float(r + 1) / float(GROUND_ROWS)
			_ground_quad(st, xa, xb, z0, z1, length)
	# Border stones along the outer path edges (tag 2).
	for side: float in [-1.0, 1.0]:
		var z: float = -0.2
		while z > -length + 0.2:
			if rng.randf() > 0.08:
				var rx: float = rng.randf_range(0.14, 0.22)
				var ry: float = rng.randf_range(0.08, 0.13)
				var at: Vector3 = Vector3(side * (outer_edge + rx * 0.45 + rng.randf_range(-0.03, 0.05)), 0.02, z)
				var col: Color = NatureMesh.shade(STONE_COLOR, rng.randf_range(0.82, 1.08))
				NatureMesh.rock(st, at, Vector3(rx, ry, rng.randf_range(0.14, 0.2)), rng, col, 0, 0.2, 0.45,
						Color(0, 0, 0, 0), 2.0, 0.0, rng.randf() * TAU)
			z -= rng.randf_range(0.36, 0.48)
	# Grass tufts and pebbles on the strips between the paths.
	for lane in range(cfg.lane_count - 1):
		var mid: float = (cfg.lane_x(lane) + cfg.lane_x(lane + 1)) * 0.5
		var z: float = -rng.randf_range(0.1, 0.5)
		while z > -length + 0.2:
			var at: Vector3 = Vector3(mid + rng.randf_range(-0.08, 0.08), 0.0, z)
			if rng.randf() < 0.82:
				NatureMesh.tuft(st, at, rng.randf_range(0.1, 0.2), 0.08, 4, TUFT_BASE, TUFT_TIP, rng, 3.0)
			else:
				NatureMesh.rock(st, at + Vector3(0.0, 0.01, 0.0), Vector3(0.07, 0.04, 0.06), rng,
						NatureMesh.shade(STONE_COLOR, rng.randf_range(0.75, 1.0)), 0, 0.25, 0.4,
						Color(0, 0, 0, 0), 2.0)
			z -= rng.randf_range(0.45, 0.8)
	# Verges: pebbles and taller tufts.
	for side: float in [-1.0, 1.0]:
		for i in range(34):
			var x: float = side * rng.randf_range(outer_edge + 0.35, 6.5)
			var z: float = -rng.randf_range(0.2, length - 0.2)
			var s: float = rng.randf_range(0.05, 0.16) * (1.0 + 0.4 * (absf(x) - outer_edge) / 3.0)
			NatureMesh.rock(st, Vector3(x, 0.0, z), Vector3(s, s * 0.6, s * 0.9), rng,
					NatureMesh.shade(STONE_COLOR, rng.randf_range(0.7, 1.0)), 0, 0.25, 0.4,
					Color(0, 0, 0, 0), 2.0, 0.0, rng.randf() * TAU)
		for i in range(46):
			var x: float = side * rng.randf_range(outer_edge + 0.3, 6.2)
			var z: float = -rng.randf_range(0.2, length - 0.2)
			NatureMesh.tuft(st, Vector3(x, 0.0, z), rng.randf_range(0.18, 0.36), 0.12, 5,
					TUFT_BASE, TUFT_TIP, rng, 3.0)
	_track_mesh = NatureMesh.commit(st)
	_track_mesh.surface_set_material(0, Mats.track_ground(cfg))
	return _track_mesh


static func _inside_path(cfg: GameConfig, x: float) -> bool:
	for lane in range(cfg.lane_count):
		if absf(x - cfg.lane_x(lane)) < PATH_HALF + PATH_BEVEL - 0.001:
			return true
	return false


static func _ground_quad(st: SurfaceTool, xa: float, xb: float, z0: float, z1: float, length: float) -> void:
	var p00: Vector3 = Vector3(xa, terrain_height(xa, z0, length), z0)
	var p10: Vector3 = Vector3(xb, terrain_height(xb, z0, length), z0)
	var p11: Vector3 = Vector3(xb, terrain_height(xb, z1, length), z1)
	var p01: Vector3 = Vector3(xa, terrain_height(xa, z1, length), z1)
	var n00: Vector3 = terrain_normal(xa, z0, length)
	var n10: Vector3 = terrain_normal(xb, z0, length)
	var n11: Vector3 = terrain_normal(xb, z1, length)
	var n01: Vector3 = terrain_normal(xa, z1, length)
	var c: Color = Color(1, 1, 1, 1)
	NatureMesh.tri_smooth(st, p00, p10, p11, n00, n10, n11, c, c, c, 0.0, 0.0, 0.0, 0.0)
	NatureMesh.tri_smooth(st, p00, p11, p01, n00, n11, n01, c, c, c, 0.0, 0.0, 0.0, 0.0)


## Ground height of the shared terrain at chunk-local (x, z): flat near the track, rising into
## rolling hills further out. Periodic along z with the chunk length (seamless joins).
static func terrain_height(x: float, z: float, length: float = 30.0) -> float:
	var ax: float = absf(x)
	if ax <= 4.6:
		return 0.0
	var side: float = 0.0 if x < 0.0 else 1.7
	var w: float = TAU / length
	var wave: float = 0.55 + 0.25 * sin(z * w + side) + 0.2 * sin(z * w * 2.0 + side * 2.3 + ax * 0.15)
	var rise: float = smoothstep(4.6, 42.0, ax)
	return rise * rise * (2.5 + 5.5 * wave)


## Terrain normal (finite differences of terrain_height).
static func terrain_normal(x: float, z: float, length: float = 30.0) -> Vector3:
	var e: float = 0.25
	var dx: float = terrain_height(x + e, z, length) - terrain_height(x - e, z, length)
	var dz: float = terrain_height(x, z + e, length) - terrain_height(x, z - e, length)
	return Vector3(-dx / (2.0 * e), 1.0, -dz / (2.0 * e)).normalized()


## Creates the (empty) decor MultiMesh of slot 0 (kept for callers of the old single-slot API).
static func new_decor_multimesh() -> MultiMesh:
	return new_decor_slot(0)


## Creates the (empty) MultiMesh of one decor slot.
static func new_decor_slot(slot: int) -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = FloraLibrary.mesh(0, slot)
	mm.instance_count = DECOR_CAPACITY
	mm.visible_instance_count = 0
	return mm


## Fills slot 0 of a decor set (old single-slot API; TrackChunk fills every slot).
static func fill_decor(mm: MultiMesh, decor_set: int, decor_seed: int, per_side: int,
		cfg: GameConfig) -> void:
	fill_decor_slot(mm, 0, decor_set, decor_seed, per_side, cfg)


## Fills one decor slot with the props of a biome style: out of the lanes, random yaw and scale,
## standing on the terrain. decor_set = BiomeDef.decor_set (the style index).
static func fill_decor_slot(mm: MultiMesh, slot: int, decor_set: int, decor_seed: int, per_side: int,
		cfg: GameConfig) -> void:
	var style: int = clampi(decor_set, 0, BiomeStyle.COUNT - 1)
	mm.mesh = FloraLibrary.mesh(style, slot)
	_rng.seed = decor_seed * 7 + slot * 1013
	var row: Array = FloraLibrary.placement(style, slot)
	var x_min: float = float(row[0])
	var x_max: float = float(row[1])
	var s_min: float = float(row[2])
	var s_max: float = float(row[3])
	var per: int = clampi(roundi(float(per_side) * float(row[4])), 1, int(DECOR_CAPACITY * 0.5))
	var sink: float = float(row[5])
	var length: float = cfg.chunk_length
	var slot_len: float = length / float(per)
	var count: int = 0
	for side: float in [-1.0, 1.0]:
		for i in range(per):
			if count >= DECOR_CAPACITY:
				break
			var s: float = _rng.randf_range(s_min, s_max)
			var x: float = side * _rng.randf_range(x_min, x_max)
			var z: float = -(float(i) + _rng.randf_range(0.15, 0.85)) * slot_len
			var y: float = terrain_height(x, z, length) - sink * s
			var basis: Basis = Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
			mm.set_instance_transform(count, Transform3D(basis, Vector3(x, y, z)))
			var k: float = _rng.randf_range(0.88, 1.1)
			var hue: float = _rng.randf_range(-0.04, 0.04)
			mm.set_instance_color(count, Color(k * (1.0 + hue), k, k * (1.0 - hue), 1.0))
			count += 1
	mm.visible_instance_count = count


## A cave section filling one chunk (TrackFeatures.cave_mesh).
static func tunnel_mesh(cfg: GameConfig) -> ArrayMesh:
	return TrackFeatures.cave_mesh(cfg)


## A log bridge section filling one chunk (TrackFeatures.bridge_mesh).
static func bridge_mesh(cfg: GameConfig) -> ArrayMesh:
	return TrackFeatures.bridge_mesh(cfg)

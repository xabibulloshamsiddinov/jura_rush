## Track features of Jura Rush, each a mesh shared by every chunk that carries it:
##   cave   rough rock tunnel with stalactites and wall torches (warm flames + light pools on the
##          floor), a mountain hull over it, a mouth cap on the first chunk of a run and an end cap
##          on the last one (consecutive cave chunks join seamlessly: all noise is periodic in z).
##   bridge wooden log-plank bridge with rope rails on posts, beams and pillars, the river far
##          below, and a far river bank on the last chunk (the normal track mesh is hidden).
## Surfaces: 0 = lit nature material; cave: 1 = floor shade, 2 = flames and light pools;
## bridge: 1 = river water.
class_name TrackFeatures
extends RefCounted

## Interior arch, right half from the floor to the apex (x, y); mirrored for the left half.
const CAVE_INNER: Array[Vector2] = [Vector2(4.9, -0.3), Vector2(5.15, 1.8), Vector2(5.05, 4.2),
	Vector2(4.5, 6.6), Vector2(3.4, 8.5), Vector2(1.8, 9.65), Vector2(0.0, 10.0)]
## Mountain hull over the cave, same point count.
const CAVE_OUTER: Array[Vector2] = [Vector2(13.5, -0.6), Vector2(12.2, 2.4), Vector2(10.6, 5.4),
	Vector2(8.6, 8.5), Vector2(6.2, 11.3), Vector2(3.3, 14.0), Vector2(0.0, 15.6)]
const CAVE_ROCK: Color = Color(0.42, 0.36, 0.3)
## Grass and moss on the mountain over the cave (tinted by the biome foliage).
const CAVE_GRASS: Color = Color(0.3, 0.52, 0.2)
## Multiplier the cave floor shade applies to the track inside caves.
const CAVE_FLOOR_SHADE: Color = Color(0.64, 0.58, 0.52)
const WOOD: Color = Color(0.56, 0.38, 0.22)
const WOOD_DARK: Color = Color(0.4, 0.27, 0.16)
const ROPE: Color = Color(0.66, 0.53, 0.33)
const BANK: Color = Color(0.5, 0.38, 0.27)
## River surface height under bridges.
const WATER_Y: float = -7.0

static var _cave: ArrayMesh = null
static var _cave_mouth: ArrayMesh = null
static var _cave_end: ArrayMesh = null
static var _bridge: ArrayMesh = null
static var _bridge_near: ArrayMesh = null
static var _bridge_far: ArrayMesh = null


## Full arch profile (13 points, right floor -> apex -> left floor).
static func _arch(half: Array[Vector2]) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for p: Vector2 in half:
		pts.append(p)
	for i in range(half.size() - 2, -1, -1):
		pts.append(Vector2(-half[i].x, half[i].y))
	return pts


## Periodic rock displacement of arch point k at chunk-local z (seamless at z = 0 / -length).
static func _bump(k: int, z: float, length: float, amount: float) -> float:
	var w: float = TAU / length
	var kf: float = float(k)
	return amount * (0.5 * sin(z * w * 2.0 + kf * 1.7) + 0.32 * sin(z * w * 5.0 + kf * 3.1)
			+ 0.18 * sin(z * w * 9.0 + kf * 0.7))


static func _arch_point(profile: Array[Vector2], k: int, z: float, length: float, amount: float) -> Vector3:
	var p: Vector2 = profile[k]
	var out: Vector2 = (p - Vector2(0.0, 3.5)).normalized()
	var ground: float = 0.25 if (k == 0 or k == profile.size() - 1) else 1.0
	var d: float = _bump(k, z, length, amount) * ground
	return Vector3(p.x + out.x * d, p.y + out.y * d, z)


## The cave section of one chunk.
static func cave_mesh(cfg: GameConfig) -> ArrayMesh:
	if _cave != null:
		return _cave
	var length: float = cfg.chunk_length
	var st: SurfaceTool = NatureMesh.begin()
	var flames: SurfaceTool = SurfaceTool.new()
	flames.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777
	var inner: Array[Vector2] = _arch(CAVE_INNER)
	var outer: Array[Vector2] = _arch(CAVE_OUTER)
	# Interior walls and roof (faces inward).
	var rings: int = 20
	for i in range(rings):
		var z0: float = -length * float(i) / float(rings)
		var z1: float = -length * float(i + 1) / float(rings)
		for k in range(inner.size() - 1):
			var a: Vector3 = _arch_point(inner, k, z0, length, 0.45)
			var b: Vector3 = _arch_point(inner, k + 1, z0, length, 0.45)
			var c: Vector3 = _arch_point(inner, k + 1, z1, length, 0.45)
			var d: Vector3 = _arch_point(inner, k, z1, length, 0.45)
			var centre: Vector3 = (a + b + c + d) * 0.25
			var facing: Vector3 = Vector3(0.0, 3.5, centre.z) - centre
			# Interior rock is darker than the sunlit outside: it reads as a cave even where
			# the shadow fades out (far away, or on Low quality without shadows).
			var shade: float = 0.68 + 0.18 * rng.randf()
			var col: Color = NatureMesh.shade(CAVE_ROCK, shade)
			col.a = clampf(0.6 - centre.y * 0.035, 0.25, 0.6)
			NatureMesh.quad(st, a, b, c, d, col, NatureMesh.TAG_ROCK, facing)
	# Mountain hull over the cave (faces outward; moss on top from the shader).
	var hull_rings: int = 10
	for i in range(hull_rings):
		var z0: float = -length * float(i) / float(hull_rings)
		var z1: float = -length * float(i + 1) / float(hull_rings)
		for k in range(outer.size() - 1):
			var a: Vector3 = _arch_point(outer, k, z0, length, 1.1)
			var b: Vector3 = _arch_point(outer, k + 1, z0, length, 1.1)
			var c: Vector3 = _arch_point(outer, k + 1, z1, length, 1.1)
			var d: Vector3 = _arch_point(outer, k, z1, length, 1.1)
			var centre: Vector3 = (a + b + c + d) * 0.25
			var facing: Vector3 = centre - Vector3(0.0, 3.5, centre.z)
			var col: Color = NatureMesh.shade(CAVE_ROCK, 0.85 + 0.2 * rng.randf())
			var tag: float = NatureMesh.TAG_ROCK
			# Grass on the gentler upper slopes (the face normal points up enough).
			var up: float = (c - a).cross(b - a).normalized().y
			if absf(up) > 0.55 and centre.y > 6.0:
				col = NatureMesh.shade(CAVE_GRASS, 0.9 + 0.2 * rng.randf())
				tag = NatureMesh.TAG_FOLIAGE
			NatureMesh.quad(st, a, b, c, d, col, tag, facing)
	# Stalactites (tips stay clear of the jetpack flight line in the middle).
	for i in range(14):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * (rng.randf_range(2.9, 4.3) if i % 3 != 0 else rng.randf_range(0.6, 2.6))
		var z: float = -rng.randf_range(0.8, length - 0.8)
		var roof: float = _roof_y(absf(x))
		var floor_limit: float = 8.9 if absf(x) < 2.8 else 5.8
		var drop: float = minf(rng.randf_range(0.7, 2.0), roof - floor_limit)
		if drop < 0.25:
			continue
		var r: float = rng.randf_range(0.16, 0.3)
		NatureMesh.cone(st, Vector3(x, roof + 0.3, z), Vector3(x + rng.randf_range(-0.1, 0.1), roof - drop, z),
				r, 5, NatureMesh.shade(CAVE_ROCK, 0.95), NatureMesh.shade(CAVE_ROCK, 1.15), 0.0, 0.0,
				NatureMesh.TAG_ROCK)
	# Stalagmites and rubble on the floor beside the paths.
	for i in range(8):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * rng.randf_range(3.5, 4.6)
		var z: float = -rng.randf_range(0.5, length - 0.5)
		if i < 5:
			NatureMesh.cone(st, Vector3(x, -0.1, z), Vector3(x, rng.randf_range(0.5, 1.2), z),
					rng.randf_range(0.18, 0.32), 5, NatureMesh.shade(CAVE_ROCK, 0.9),
					NatureMesh.shade(CAVE_ROCK, 1.1), 0.0, 0.0, NatureMesh.TAG_ROCK)
		else:
			NatureMesh.rock(st, Vector3(x, 0.15, z), Vector3(0.45, 0.32, 0.4), rng, CAVE_ROCK, 0)
	# Wall torches every quarter chunk, alternating sides, with a warm light pool on the floor.
	for i in range(4):
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var z: float = -(float(i) + 0.5) * length / 4.0
		var root: Vector3 = Vector3(side * 4.98, 1.9, z)
		var tip: Vector3 = Vector3(side * 4.5, 2.7, z)
		NatureMesh.tube(st, PackedVector3Array([root, tip]), PackedFloat32Array([0.07, 0.06]), 5,
				PackedColorArray([WOOD_DARK, WOOD]), PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, false)
		NatureMesh.rock(st, tip, Vector3(0.12, 0.13, 0.12), rng, Color(1.0, 0.55, 0.2), 0, 0.15, 1.0,
				Color(0, 0, 0, 0), NatureMesh.TAG_GLOW)
		add_flame(flames, tip + Vector3(0.0, 0.08, 0.0), 0.42, 0.75, rng.randf())
		add_pool(flames, Vector3(side * 3.4, 0.09, z), 3.6, rng.randf())
	# Floor shade: darkens the stone path and ground inside the cave (surface 2, multiplied).
	var shade_st: SurfaceTool = SurfaceTool.new()
	shade_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shade_rows: int = 10
	for r in range(shade_rows):
		var z0: float = -length * float(r) / float(shade_rows)
		var z1: float = -length * float(r + 1) / float(shade_rows)
		var a: Vector3 = Vector3(-5.3, 0.075, z0)
		var b: Vector3 = Vector3(5.3, 0.075, z0)
		var c: Vector3 = Vector3(5.3, 0.075, z1)
		var d: Vector3 = Vector3(-5.3, 0.075, z1)
		for p: Vector3 in [a, c, b, a, d, c]:
			shade_st.set_normal(Vector3.UP)
			shade_st.add_vertex(p)
	# Shade (surface 1) before flames and light pools (surface 2), so the pools add on top.
	_cave = NatureMesh.commit(st)
	shade_st.commit(_cave)
	flames.commit(_cave)
	_cave.surface_set_material(0, Mats.nature())
	_cave.surface_set_material(1, Mats.floor_shade(CAVE_FLOOR_SHADE))
	_cave.surface_set_material(2, Mats.flame())
	return _cave


static func _roof_y(ax: float) -> float:
	for k in range(CAVE_INNER.size() - 1):
		var a: Vector2 = CAVE_INNER[k]
		var b: Vector2 = CAVE_INNER[k + 1]
		if ax <= a.x and ax >= b.x and k >= 2:
			return lerpf(a.y, b.y, (a.x - ax) / maxf(a.x - b.x, 0.001))
	return CAVE_INNER[CAVE_INNER.size() - 1].y


## Rock face around the cave mouth (first chunk of a run, at z = 0, facing the runner).
static func cave_mouth_mesh(cfg: GameConfig) -> ArrayMesh:
	if _cave_mouth == null:
		_cave_mouth = _cave_cap(cfg, 0.0, 1.0, 31)
	return _cave_mouth


## Back face of the mountain (last chunk of a run, at z = -length).
static func cave_end_mesh(cfg: GameConfig) -> ArrayMesh:
	if _cave_end == null:
		_cave_end = _cave_cap(cfg, -cfg.chunk_length, -1.0, 32)
	return _cave_end


static func _cave_cap(cfg: GameConfig, z: float, facing_z: float, seed_value: int) -> ArrayMesh:
	var length: float = cfg.chunk_length
	var st: SurfaceTool = NatureMesh.begin()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var inner: Array[Vector2] = _arch(CAVE_INNER)
	var outer: Array[Vector2] = _arch(CAVE_OUTER)
	var facing: Vector3 = Vector3(0.0, 0.0, facing_z)
	for k in range(inner.size() - 1):
		var a: Vector3 = _arch_point(inner, k, z, length, 0.45)
		var b: Vector3 = _arch_point(inner, k + 1, z, length, 0.45)
		var c: Vector3 = _arch_point(outer, k + 1, z, length, 1.1)
		var d: Vector3 = _arch_point(outer, k, z, length, 1.1)
		# The rim around the opening bulges toward the viewer a little.
		var mid: Vector3 = (a + b + c + d) * 0.25 + Vector3(0.0, 0.0, facing_z * rng.randf_range(0.3, 0.9))
		var col: Color = NatureMesh.shade(CAVE_ROCK, 0.85 + 0.2 * rng.randf())
		for pair: Array in [[a, b], [b, c], [c, d], [d, a]]:
			NatureMesh.tri(st, pair[0] as Vector3, pair[1] as Vector3, mid, col, NatureMesh.TAG_ROCK,
					0.0, 0.0, 0.0, facing)
	# Boulders framing the mouth and hiding where the hull meets the ground.
	for i in range(9):
		var k: int = i % (inner.size() - 1)
		var p: Vector3 = _arch_point(outer, k, z, length, 1.1).lerp(_arch_point(inner, k, z, length, 0.45),
				rng.randf_range(0.25, 0.6))
		var s: float = rng.randf_range(0.9, 1.8)
		NatureMesh.rock(st, p + Vector3(0.0, 0.0, facing_z * 0.6), Vector3(s, s * 0.8, s), rng,
				NatureMesh.shade(CAVE_ROCK, 0.95), 0, 0.25, 0.6)
	for side: float in [-1.0, 1.0]:
		for i in range(3):
			var s: float = rng.randf_range(1.4, 2.6)
			NatureMesh.rock(st, Vector3(side * rng.randf_range(11.0, 16.0), 0.3, z + facing_z * rng.randf_range(0.5, 2.5)),
					Vector3(s * 1.3, s, s), rng, NatureMesh.shade(CAVE_ROCK, 0.9), 0, 0.25, 0.5)
	# Hanging moss / vines over the mouth.
	if facing_z > 0.0:
		for i in range(10):
			var k: int = 3 + i % 7
			var top: Vector3 = _arch_point(inner, k, z, length, 0.45) + Vector3(0.0, 0.2, 0.25)
			if top.y < 7.2:
				continue
			NatureMesh.frond(st, top, Vector3(0.0, 0.0, 1.0), rng.randf_range(0.8, 1.7), 0.1, -1.4, 0.0, 3,
					Color(0.24, 0.45, 0.18), Color(0.36, 0.6, 0.24), 0.4, 1.0, false, NatureMesh.TAG_FOLIAGE, 0.0)
	var mesh: ArrayMesh = NatureMesh.commit(st)
	mesh.surface_set_material(0, Mats.nature())
	return mesh


# --- Bridge -------------------------------------------------------------------------------------

## The log bridge section of one chunk: plank deck, lane-divider logs, rope rails, beams, pillars
## and the river below (surface 1).
static func bridge_mesh(cfg: GameConfig) -> ArrayMesh:
	if _bridge != null:
		return _bridge
	var length: float = cfg.chunk_length
	var half_deck: float = cfg.lane_width * float(cfg.lane_count) * 0.5 + 0.25
	var rail_x: float = half_deck + 0.15
	var st: SurfaceTool = NatureMesh.begin()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 991
	# Deck planks across the whole width (top at the path height).
	var z: float = -0.18
	while z > -length:
		var w: float = half_deck * 2.0 + rng.randf_range(-0.2, 0.2)
		var basis: Basis = Basis(Vector3.UP, rng.randf_range(-0.025, 0.025))
		var col: Color = NatureMesh.shade(WOOD, rng.randf_range(0.82, 1.14))
		col.a = 0.95
		NatureMesh.box(st, Vector3(rng.randf_range(-0.08, 0.08), TrackVisuals.PATH_TOP - 0.06, z),
				Vector3(w, 0.12, 0.31), basis, col, NatureMesh.TAG_PLAIN, 0.06, rng)
		z -= 0.36
	# Logs along the deck: lane dividers (flush) and edge curbs.
	for lane in range(cfg.lane_count - 1):
		var x: float = (cfg.lane_x(lane) + cfg.lane_x(lane + 1)) * 0.5
		_log_along(st, x, 0.03, 0.075, length, NatureMesh.shade(WOOD_DARK, 1.05))
	for side: float in [-1.0, 1.0]:
		_log_along(st, side * (half_deck - 0.05), 0.07, 0.13, length, WOOD_DARK)
		_log_along(st, side * (half_deck - 0.9), -0.32, 0.22, length, WOOD_DARK)
	# Cross beams and pillars down to the river.
	for i in range(5):
		var bz: float = -(float(i) + 0.5) * length / 5.0
		NatureMesh.tube(st, PackedVector3Array([Vector3(-half_deck - 0.2, -0.22, bz), Vector3(half_deck + 0.2, -0.22, bz)]),
				PackedFloat32Array([0.12, 0.12]), 5, PackedColorArray([WOOD_DARK]), PackedFloat32Array([0.0]),
				NatureMesh.TAG_PLAIN, false)
	for bz: float in [-length * 0.25, -length * 0.75]:
		for side: float in [-1.0, 1.0]:
			NatureMesh.tube(st, PackedVector3Array([Vector3(side * (half_deck - 0.6), -0.3, bz),
					Vector3(side * (half_deck - 0.45), WATER_Y - 1.0, bz)]), PackedFloat32Array([0.3, 0.34]), 6,
					PackedColorArray([WOOD_DARK, NatureMesh.shade(WOOD_DARK, 0.7)]), PackedFloat32Array([0.0]),
					NatureMesh.TAG_PLAIN, false)
			NatureMesh.rock(st, Vector3(side * (half_deck - 0.45), WATER_Y, bz), Vector3(0.9, 0.5, 0.9), rng,
					Color(0.45, 0.43, 0.4), 0)
	# Posts and sagging rope rails.
	var spans: int = 10
	for side: float in [-1.0, 1.0]:
		for i in range(spans + 1):
			var pz: float = -length * float(i) / float(spans)
			if i < spans:
				NatureMesh.tube(st, PackedVector3Array([Vector3(side * rail_x, -0.3, pz - 0.0),
						Vector3(side * rail_x, 1.38, pz)]), PackedFloat32Array([0.1, 0.085]), 6,
						PackedColorArray([WOOD_DARK, WOOD]), PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, false)
				NatureMesh.rock(st, Vector3(side * rail_x, 1.42, pz), Vector3(0.11, 0.07, 0.11), rng, WOOD, 0)
			if i == spans:
				continue
			var nz: float = -length * float(i + 1) / float(spans)
			for h: float in [1.22, 0.74]:
				var pts: PackedVector3Array = PackedVector3Array()
				for k in range(7):
					var t: float = float(k) / 6.0
					pts.append(Vector3(side * rail_x, h - 0.17 * 4.0 * t * (1.0 - t), lerpf(pz, nz, t)))
				NatureMesh.tube(st, pts, PackedFloat32Array([0.032]), 3, PackedColorArray([ROPE]),
						PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, true)
	_bridge = NatureMesh.commit(st)
	var water: SurfaceTool = _water_surface(length)
	water.commit(_bridge)
	_bridge.surface_set_material(0, Mats.nature())
	_bridge.surface_set_material(1, Mats.water())
	return _bridge


static func _log_along(st: SurfaceTool, x: float, y: float, r: float, length: float, col: Color) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	for i in range(11):
		pts.append(Vector3(x, y, -length * float(i) / 10.0))
	NatureMesh.tube(st, pts, PackedFloat32Array([r]), 5, PackedColorArray([col, NatureMesh.shade(col, 1.1)]),
			PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, false)


static func _water_surface(length: float) -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs: Array[float] = [-70.0, -40.0, -22.0, -12.0, -5.0, 0.0, 5.0, 12.0, 22.0, 40.0, 70.0]
	var rows: int = 10
	for r in range(rows):
		var z0: float = -length * float(r) / float(rows)
		var z1: float = -length * float(r + 1) / float(rows)
		for i in range(xs.size() - 1):
			var a: Vector3 = Vector3(xs[i], WATER_Y, z0)
			var b: Vector3 = Vector3(xs[i + 1], WATER_Y, z0)
			var c: Vector3 = Vector3(xs[i + 1], WATER_Y, z1)
			var d: Vector3 = Vector3(xs[i], WATER_Y, z1)
			for p: Vector3 in [a, c, b, a, d, c]:
				st.set_normal(Vector3.UP)
				st.set_color(Color.WHITE)
				st.set_uv(Vector2(p.x, p.z))
				st.add_vertex(p)
	return st


## Near river bank (first bridge chunk, z = 0, facing the river).
static func bridge_near_mesh(cfg: GameConfig) -> ArrayMesh:
	if _bridge_near == null:
		_bridge_near = _bank(cfg, 0.0, -1.0, 51)
	return _bridge_near


## Far river bank (last bridge chunk, z = -length, facing the runner).
static func bridge_far_mesh(cfg: GameConfig) -> ArrayMesh:
	if _bridge_far == null:
		_bridge_far = _bank(cfg, -cfg.chunk_length, 1.0, 52)
	return _bridge_far


static func _bank(cfg: GameConfig, z: float, facing_z: float, seed_value: int) -> ArrayMesh:
	var length: float = cfg.chunk_length
	var st: SurfaceTool = NatureMesh.begin()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var xs: Array[float] = []
	for i in range(TrackVisuals.OUTER_X.size() - 1, -1, -1):
		xs.append(-TrackVisuals.OUTER_X[i])
	for x: float in [-2.0, 0.0, 2.0]:
		xs.append(x)
	for x: float in TrackVisuals.OUTER_X:
		xs.append(x)
	var facing: Vector3 = Vector3(0.0, 0.35, facing_z).normalized()
	var levels: Array[float] = [1.0, 0.55, 0.0]
	for i in range(xs.size() - 1):
		for lv in range(levels.size() - 1):
			var pts: Array[Vector3] = []
			for x: float in [xs[i], xs[i + 1]]:
				for f: float in [levels[lv], levels[lv + 1]]:
					var top: float = TrackVisuals.terrain_height(x, z, length)
					var y: float = lerpf(WATER_Y - 1.0, top, f)
					var jut: float = (1.0 - f) * 3.0 + sin(x * 0.7 + f * 4.0) * 0.4 * f * (1.0 - f) * 4.0
					pts.append(Vector3(x, y, z + facing_z * jut))
			var col: Color = NatureMesh.shade(BANK if lv == 1 else Color(0.42, 0.36, 0.3), rng.randf_range(0.88, 1.08))
			col.a = 0.75 + 0.25 * float(lv)
			NatureMesh.quad(st, pts[0], pts[2], pts[3], pts[1], col, NatureMesh.TAG_ROCK, facing)
	for i in range(14):
		var x: float = rng.randf_range(-45.0, 45.0)
		var s: float = rng.randf_range(0.8, 2.2)
		NatureMesh.rock(st, Vector3(x, WATER_Y + 0.2, z + facing_z * rng.randf_range(2.6, 4.0)),
				Vector3(s * 1.3, s * 0.7, s), rng, Color(0.47, 0.44, 0.4), 0, 0.25, 0.5,
				Color(0.3, 0.45, 0.22, 0.4))
	var mesh: ArrayMesh = NatureMesh.commit(st)
	mesh.surface_set_material(0, Mats.nature())
	return mesh


# --- Flames (torches) ---------------------------------------------------------------------------

## Two crossed flame quads (flame.gdshader: UV.y 0 = base, 1 = tip; COLOR.r = flicker seed).
static func add_flame(st: SurfaceTool, base: Vector3, width: float, height: float, seed_value: float) -> void:
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var hw: Vector3 = axis * width * 0.5
		var up: Vector3 = Vector3.UP * height
		var corners: Array[Vector3] = [base - hw, base + hw, base + hw + up, base - hw + up]
		var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for idx: int in [0, 2, 1, 0, 3, 2]:
			st.set_color(Color(seed_value, 0.0, 0.0, 1.0))
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])


## A soft warm light pool on the ground (flame.gdshader pool mode: UV.x >= 2).
static func add_pool(st: SurfaceTool, center: Vector3, size: float, seed_value: float) -> void:
	var h: float = size * 0.5
	var corners: Array[Vector3] = [center + Vector3(-h, 0, h), center + Vector3(h, 0, h),
			center + Vector3(h, 0, -h), center + Vector3(-h, 0, -h)]
	var uvs: Array[Vector2] = [Vector2(2, 0), Vector2(3, 0), Vector2(3, 1), Vector2(2, 1)]
	for idx: int in [0, 2, 1, 0, 3, 2]:
		st.set_color(Color(seed_value, 0.0, 0.0, 1.0))
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[idx])
		st.add_vertex(corners[idx])

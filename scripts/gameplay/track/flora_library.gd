## The side decor of every biome style, built once from NatureMesh primitives and drawn through
## the per-chunk decor MultiMeshes (one MultiMesh per slot, so a chunk costs SLOT_COUNT draw calls
## for all of its vegetation and terrain). Every mesh stays well under 1.5k triangles.
##   slot 0  tall plant near the track   (tree ferns, hoodoos, swamp cypress, dead trees)
##   slot 1  second tall / mid plant       (araucarias, cycads, giant horsetails, basalt columns)
##   slot 2  low clumps on the verge        (cycad + ferns, boulders, ferns + logs, glowing rocks)
##   slot 3  far terrain                   (conifer hills, mesas, misty tree lines, basalt cliffs)
## Colours are baked into vertex colours from the BiomeDef tints at build time.
class_name FloraLibrary
extends RefCounted

const SLOT_COUNT: int = 4
## Slot 3 (far terrain) does not cast shadows (always outside the shadow range).
const SLOT_CASTS_SHADOW: Array[bool] = [true, true, true, false]
## Placement per style and slot: x_min, x_max (distance from the track centre), scale min / max,
## count factor (x per_side density), sink into the ground.
const PLACEMENT: Array[Array] = [
	[[7.0, 12.5, 0.8, 1.35, 1.0, 0.1], [9.5, 17.0, 0.75, 1.25, 0.5, 0.1],
			[4.7, 8.5, 0.75, 1.3, 1.0, 0.05], [22.0, 46.0, 0.8, 1.4, 0.5, 0.6]],
	[[8.0, 16.0, 0.7, 1.3, 0.55, 0.3], [6.2, 11.0, 0.8, 1.2, 0.5, 0.05],
			[4.8, 9.0, 0.6, 1.5, 0.9, 0.1], [24.0, 50.0, 0.8, 1.6, 0.6, 0.5]],
	[[9.5, 15.0, 0.8, 1.3, 0.9, 0.1], [4.6, 8.5, 0.7, 1.3, 1.0, 0.05],
			[9.5, 13.0, 0.8, 1.2, 0.6, 0.1], [20.0, 40.0, 0.8, 1.4, 0.6, 0.5]],
	[[6.5, 13.0, 0.8, 1.3, 0.8, 0.1], [7.5, 15.0, 0.7, 1.3, 0.55, 0.2],
			[4.8, 9.0, 0.6, 1.4, 0.9, 0.1], [22.0, 46.0, 0.8, 1.5, 0.6, 0.6]],
]

const BARK: Color = Color(0.4, 0.27, 0.17)
const BARK_DARK: Color = Color(0.27, 0.18, 0.11)
const FERN: Color = Color(0.24, 0.56, 0.2)
const CYCAD: Color = Color(0.36, 0.62, 0.26)
const CONIFER: Color = Color(0.13, 0.36, 0.19)
const LAVA: Color = Color(1.0, 0.42, 0.08)

static var _meshes: Dictionary = {}


## The decor mesh of a style and slot (built on first use; prewarm() builds all of them).
static func mesh(style: int, slot: int) -> ArrayMesh:
	var key: int = style * SLOT_COUNT + slot
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var built: ArrayMesh = _build(style, slot)
	_meshes[key] = built
	return built


## Builds every decor mesh up front (boot), so entering a biome never hitches.
static func prewarm() -> void:
	for style in range(BiomeStyle.COUNT):
		for slot in range(SLOT_COUNT):
			mesh(style, slot)


## Placement row [x_min, x_max, scale_min, scale_max, count_factor, sink].
static func placement(style: int, slot: int) -> Array:
	return PLACEMENT[clampi(style, 0, PLACEMENT.size() - 1)][slot] as Array


static func _build(style: int, slot: int) -> ArrayMesh:
	var st: SurfaceTool = NatureMesh.begin()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1000 + style * 37 + slot * 11
	var tint: Color = _foliage_tint(style)
	var rock: Color = BiomeStyle.CLIFF[clampi(style, 0, BiomeStyle.COUNT - 1)]
	match style:
		BiomeStyle.RED_CANYON:
			match slot:
				0: _hoodoo(st, rng, rock)
				1: _cycad(st, rng, Vector3.ZERO, 1.6, 1.25, tint, 13)
				2: _boulders(st, rng, rock, tint, false)
				_: _mesa(st, rng, rock)
		BiomeStyle.MISTY_SWAMP:
			match slot:
				0: _swamp_tree(st, rng, tint)
				1: _horsetails(st, rng, tint)
				2: _fern_log(st, rng, tint)
				_: _tree_line(st, rng, tint)
		BiomeStyle.VOLCANO_RIDGE:
			match slot:
				0: _dead_tree(st, rng)
				1: _basalt_columns(st, rng, rock)
				2: _boulders(st, rng, rock, tint, true)
				_: _basalt_cliff(st, rng, rock)
		_:
			match slot:
				0: _tree_fern(st, rng, tint)
				1: _araucaria(st, rng, tint)
				2: _fern_clump(st, rng, tint)
				_: _conifer_hill(st, rng, tint)
	return NatureMesh.commit(st)


static func _foliage_tint(style: int) -> Color:
	var f: Color = BiomeStyle.foliage(style)
	return Color(f.r / 0.34, f.g / 0.6, f.b / 0.22)


static func _t(c: Color, tint: Color, k: float = 1.0) -> Color:
	return Color(c.r * tint.r * k, c.g * tint.g * k, c.b * tint.b * k)


static func _dir(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))


# --- Fern Valley -------------------------------------------------------------------------------

static func _tree_fern(st: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var h: float = 4.3
	var lean: Vector3 = Vector3(0.25, 0.0, 0.1)
	var pts: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array([0.36, 0.24, 0.21, 0.2, 0.22, 0.26])
	var cols: PackedColorArray = PackedColorArray()
	var sways: PackedFloat32Array = PackedFloat32Array()
	for i in range(6):
		var s: float = float(i) / 5.0
		pts.append(Vector3(0.0, h * s, 0.0) + lean * s * s + Vector3(0.05 * sin(s * 6.0), 0.0, 0.0))
		cols.append(NatureMesh.shade(BARK_DARK if i % 2 == 0 else BARK, 0.9 + 0.2 * s))
		sways.append(s * s * 0.25)
	NatureMesh.tube(st, pts, radii, 7, cols, sways, NatureMesh.TAG_PLAIN, false)
	var top: Vector3 = pts[5] + Vector3(0.0, 0.05, 0.0)
	var count: int = 11
	for i in range(count):
		var a: float = TAU * float(i) / float(count) + rng.randf_range(-0.2, 0.2)
		NatureMesh.frond(st, top, _dir(a), rng.randf_range(2.3, 2.9), rng.randf_range(0.34, 0.42),
				rng.randf_range(0.45, 0.7), rng.randf_range(0.95, 1.25), 6,
				_t(FERN, tint, 0.78), _t(FERN, tint, 1.22), 0.25, 1.0)
	for i in range(3):
		var a: float = TAU * float(i) / 3.0 + 0.5
		NatureMesh.frond(st, top, _dir(a), 0.9, 0.16, 1.25, 0.6, 3,
				_t(FERN, tint, 1.0), _t(CYCAD, tint, 1.25), 0.25, 0.7)


static func _araucaria(st: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var h: float = 15.0
	NatureMesh.tube(st, PackedVector3Array([Vector3.ZERO, Vector3(0.1, h * 0.5, 0.0), Vector3(0.15, h, 0.05)]),
			PackedFloat32Array([0.42, 0.28, 0.15]), 6,
			PackedColorArray([BARK_DARK, BARK, BARK]), PackedFloat32Array([0.0, 0.05, 0.2]),
			NatureMesh.TAG_PLAIN, false)
	var green: Color = _t(CONIFER, tint)
	var light: Color = _t(CONIFER, tint, 1.6)
	var whorls: int = 5
	for w in range(whorls):
		var f: float = float(w) / float(whorls - 1)
		var y: float = h * lerpf(0.52, 0.93, f)
		var reach: float = lerpf(3.4, 1.4, f)
		var base: Vector3 = Vector3(0.1 + 0.05 * f, y, 0.0)
		var offset: float = rng.randf() * TAU
		for b in range(5):
			var a: float = offset + TAU * float(b) / 5.0
			var dir: Vector3 = _dir(a)
			var tip: Vector3 = base + dir * reach + Vector3(0.0, 0.5 - 0.3 * f, 0.0)
			var sway: float = 0.15 + 0.5 * f
			NatureMesh.tube(st, PackedVector3Array([base, tip]), PackedFloat32Array([0.09, 0.04]), 4,
					PackedColorArray([BARK, BARK]), PackedFloat32Array([0.1, sway]), NatureMesh.TAG_PLAIN, false)
			var clump: Vector3 = base + dir * reach * 0.62 + Vector3(0.0, 0.42 - 0.2 * f, 0.0)
			NatureMesh.rock(st, clump, Vector3(reach * 0.5, 0.36, 0.42), rng, green, 0, 0.18, 1.0,
					Color(light.r, light.g, light.b, 0.6), NatureMesh.TAG_FOLIAGE, sway, -a)
	NatureMesh.rock(st, Vector3(0.15, h + 0.1, 0.05), Vector3(1.35, 0.75, 1.35), rng, green, 0, 0.2, 1.0,
			Color(light.r, light.g, light.b, 0.7), NatureMesh.TAG_FOLIAGE, 0.6)


static func _cycad(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, trunk_h: float,
		frond_len: float, tint: Color, fronds: int) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var cols: PackedColorArray = PackedColorArray()
	for i in range(5):
		var s: float = float(i) / 4.0
		pts.append(at + Vector3(0.0, trunk_h * s, 0.0))
		radii.append(lerpf(0.34, 0.24, s) * (1.08 if i % 2 == 1 else 1.0))
		cols.append(Color(0.47, 0.36, 0.22) if i % 2 == 0 else Color(0.36, 0.27, 0.16))
	NatureMesh.tube(st, pts, radii, 7, cols, PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, false)
	var top: Vector3 = at + Vector3(0.0, trunk_h, 0.0)
	for i in range(fronds):
		var a: float = TAU * float(i) / float(fronds) + rng.randf_range(-0.15, 0.15)
		NatureMesh.frond(st, top, _dir(a), frond_len * rng.randf_range(0.85, 1.1), 0.2,
				rng.randf_range(0.6, 0.85), rng.randf_range(0.3, 0.45), 5,
				_t(CYCAD, tint, 0.8), _t(CYCAD, tint, 1.15), 0.2, 0.75)


static func _ground_fern(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, size: float,
		tint: Color, fronds: int) -> void:
	for i in range(fronds):
		var a: float = TAU * float(i) / float(fronds) + rng.randf_range(-0.25, 0.25)
		NatureMesh.frond(st, at + Vector3(0.0, 0.05, 0.0), _dir(a), size * rng.randf_range(0.8, 1.15),
				size * 0.2, rng.randf_range(0.8, 1.1), rng.randf_range(1.3, 1.6), 5,
				_t(FERN, tint, 0.85), _t(FERN, tint, 1.3), 0.1, 1.0)


static func _fern_clump(st: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	_cycad(st, rng, Vector3.ZERO, 0.85, 1.35, tint, 11)
	_ground_fern(st, rng, Vector3(1.1, 0.0, 0.5), 1.0, tint, 7)
	_ground_fern(st, rng, Vector3(-0.8, 0.0, -0.9), 0.85, tint, 6)


static func _conifer_hill(st: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var grass: Color = _t(Color(0.3, 0.52, 0.2), tint)
	NatureMesh.rock(st, Vector3(0.0, -1.0, 0.0), Vector3(9.0, 3.4, 7.0), rng, grass, 0, 0.15, 0.3,
			Color(0, 0, 0, 0), NatureMesh.TAG_PLAIN)
	for i in range(6):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(0.0, 5.5)
		var at: Vector3 = Vector3(cos(a) * r, 1.4 - r * 0.25, sin(a) * r * 0.75)
		var h: float = rng.randf_range(9.0, 17.0)
		NatureMesh.tube(st, PackedVector3Array([at - Vector3(0, 0.5, 0), at + Vector3(0, h * 0.3, 0)]),
				PackedFloat32Array([0.3, 0.22]), 5, PackedColorArray([BARK_DARK]), PackedFloat32Array([0.0]))
		for k in range(3):
			var y0: float = h * (0.22 + 0.24 * float(k))
			var rad: float = h * (0.2 - 0.045 * float(k))
			NatureMesh.cone(st, at + Vector3(0.0, y0, 0.0), at + Vector3(0.0, y0 + h * 0.42, 0.0), rad, 8,
					_t(CONIFER, tint, 0.85 + 0.1 * float(k)), _t(CONIFER, tint, 1.3), 0.0, 0.0)


# --- Red Canyon ---------------------------------------------------------------------------------

static func _band(rock: Color, i: int) -> Color:
	var bands: Array[float] = [1.0, 0.86, 1.1, 0.93, 1.16]
	var k: float = bands[i % bands.size()]
	var c: Color = NatureMesh.shade(rock, k)
	if i % 3 == 2:
		c = c.lerp(Color(0.95, 0.82, 0.62), 0.35)
	return c


static func _hoodoo(st: SurfaceTool, rng: RandomNumberGenerator, rock: Color) -> void:
	var y: float = 0.0
	var radius: float = 1.5
	for i in range(4):
		var h: float = rng.randf_range(1.6, 2.4)
		NatureMesh.rock(st, Vector3(rng.randf_range(-0.15, 0.15), y + h * 0.5, 0.0),
				Vector3(radius, h * 0.62, radius * 0.9), rng, _band(rock, i), 1, 0.12, 0.85)
		y += h * 0.9
		radius *= 0.78
	NatureMesh.rock(st, Vector3(0.1, y + 0.35, 0.0), Vector3(1.6, 0.55, 1.4), rng,
			_band(rock, 4), 0, 0.15, 0.6)
	NatureMesh.rock(st, Vector3(1.4, 0.3, 0.6), Vector3(0.7, 0.5, 0.6), rng, _band(rock, 1), 0)


static func _boulders(st: SurfaceTool, rng: RandomNumberGenerator, rock: Color, tint: Color,
		lava: bool) -> void:
	var base: Color = rock if not lava else Color(0.2, 0.18, 0.18)
	NatureMesh.rock(st, Vector3(0.0, 0.5, 0.0), Vector3(1.0, 0.75, 0.85), rng, base, 1, 0.2, 0.55,
			Color(0.35, 0.3, 0.25, 0.4) if lava else Color(0, 0, 0, 0))
	NatureMesh.rock(st, Vector3(1.05, 0.3, 0.55), Vector3(0.55, 0.45, 0.5), rng, NatureMesh.shade(base, 1.08), 0)
	NatureMesh.rock(st, Vector3(-0.8, 0.22, 0.7), Vector3(0.4, 0.32, 0.4), rng, NatureMesh.shade(base, 0.92), 0)
	if lava:
		for i in range(4):
			var a: float = rng.randf() * TAU
			var at: Vector3 = Vector3(cos(a) * 0.95, 0.08, sin(a) * 0.8)
			NatureMesh.rock(st, at, Vector3(0.32, 0.06, 0.07), rng, LAVA, 0, 0.1, 0.5,
					Color(0, 0, 0, 0), NatureMesh.TAG_GLOW, 0.0, a)
	else:
		NatureMesh.tuft(st, Vector3(0.6, 0.0, -0.7), 0.45, 0.25, 6,
				_t(Color(0.4, 0.42, 0.18), tint, 0.8), _t(Color(0.66, 0.6, 0.3), tint), rng)
		NatureMesh.tuft(st, Vector3(-1.1, 0.0, -0.2), 0.35, 0.2, 5,
				_t(Color(0.4, 0.42, 0.18), tint, 0.8), _t(Color(0.66, 0.6, 0.3), tint), rng)


static func _mesa(st: SurfaceTool, rng: RandomNumberGenerator, rock: Color) -> void:
	var sides: int = 11
	var radii: Array[float] = []
	for i in range(sides):
		radii.append(rng.randf_range(0.75, 1.15))
	var levels: Array[float] = [-2.0, 6.0, 12.5, 17.5, 21.0]
	var widths: Array[float] = [15.0, 13.0, 11.2, 10.2, 9.6]
	for lv in range(levels.size() - 1):
		var col: Color = _band(rock, lv)
		for i in range(sides):
			var a0: float = TAU * float(i) / float(sides)
			var a1: float = TAU * float(i + 1) / float(sides)
			var r0: float = radii[i]
			var r1: float = radii[(i + 1) % sides]
			var lo0: Vector3 = Vector3(cos(a0) * r0 * widths[lv], levels[lv], sin(a0) * r0 * widths[lv] * 0.7)
			var lo1: Vector3 = Vector3(cos(a1) * r1 * widths[lv], levels[lv], sin(a1) * r1 * widths[lv] * 0.7)
			var hi0: Vector3 = Vector3(cos(a0) * r0 * widths[lv + 1], levels[lv + 1], sin(a0) * r0 * widths[lv + 1] * 0.7)
			var hi1: Vector3 = Vector3(cos(a1) * r1 * widths[lv + 1], levels[lv + 1], sin(a1) * r1 * widths[lv + 1] * 0.7)
			var out: Vector3 = Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
			var fc: Color = NatureMesh.shade(col, rng.randf_range(0.92, 1.06))
			fc.a = 0.7 + 0.3 * float(lv) / 3.0
			NatureMesh.quad(st, lo0, lo1, hi1, hi0, fc, NatureMesh.TAG_PLAIN, out)
	var top_y: float = levels[levels.size() - 1]
	var top_w: float = widths[widths.size() - 1]
	var top_col: Color = _band(rock, 2).lerp(Color(0.78, 0.6, 0.38), 0.3)
	for i in range(sides):
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var p0: Vector3 = Vector3(cos(a0) * radii[i] * top_w, top_y, sin(a0) * radii[i] * top_w * 0.7)
		var p1: Vector3 = Vector3(cos(a1) * radii[(i + 1) % sides] * top_w, top_y,
				sin(a1) * radii[(i + 1) % sides] * top_w * 0.7)
		NatureMesh.tri(st, Vector3(0.0, top_y, 0.0), p0, p1, top_col, NatureMesh.TAG_PLAIN, 0.0, 0.0, 0.0, Vector3.UP)
	for i in range(4):
		var a: float = rng.randf() * TAU
		NatureMesh.rock(st, Vector3(cos(a) * 14.0, 0.8, sin(a) * 9.0), Vector3(2.2, 1.6, 1.8), rng,
				_band(rock, i), 0)


# --- Misty Swamp --------------------------------------------------------------------------------

static func _swamp_tree(st: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var bark: Color = Color(0.33, 0.27, 0.2)
	NatureMesh.lathe(st, Vector3.ZERO, PackedVector2Array([
			Vector2(1.25, -0.3), Vector2(0.95, 0.4), Vector2(0.55, 1.5), Vector2(0.42, 3.5), Vector2(0.35, 6.0),
			Vector2(0.28, 9.0)]), 7,
			PackedColorArray([NatureMesh.shade(bark, 0.7), bark, bark, NatureMesh.shade(bark, 1.1)]), false,
			PackedFloat32Array([0.0, 0.0, 0.0, 0.03, 0.08, 0.15]))
	for i in range(5):
		var a: float = TAU * float(i) / 5.0 + rng.randf_range(-0.3, 0.3)
		NatureMesh.tube(st, PackedVector3Array([Vector3(0.0, 0.9, 0.0), _dir(a) * 1.0 + Vector3(0.0, 0.3, 0.0),
				_dir(a) * 1.7 + Vector3(0.0, -0.15, 0.0)]), PackedFloat32Array([0.28, 0.18, 0.08]), 5,
				PackedColorArray([bark]), PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, false)
	var canopy: Color = _t(Color(0.18, 0.38, 0.17), tint)
	var moss: Color = _t(Color(0.48, 0.55, 0.38), tint)
	var clumps: Array[Vector3] = [Vector3(0.0, 9.6, 0.0), Vector3(2.3, 8.0, 0.8), Vector3(-2.0, 8.5, -0.9),
			Vector3(0.6, 7.2, -2.2)]
	for i in range(clumps.size()):
		var c: Vector3 = clumps[i]
		if i > 0:
			NatureMesh.tube(st, PackedVector3Array([Vector3(0.0, c.y - 2.0, 0.0), c * Vector3(0.6, 1.0, 0.6),
					c]), PackedFloat32Array([0.18, 0.12, 0.07]), 4, PackedColorArray([bark]),
					PackedFloat32Array([0.05, 0.15, 0.3]), NatureMesh.TAG_PLAIN, false)
		NatureMesh.rock(st, c + Vector3(0.0, 0.3, 0.0), Vector3(2.0, 0.75, 1.8), rng, canopy, 0, 0.22, 0.9,
				Color(canopy.r * 1.4, canopy.g * 1.4, canopy.b * 1.3, 0.6), NatureMesh.TAG_PLAIN, 0.3, rng.randf() * TAU)
		for k in range(3):
			var a: float = rng.randf() * TAU
			var at: Vector3 = c + Vector3(cos(a) * 1.4, -0.1, sin(a) * 1.2)
			NatureMesh.frond(st, at, _dir(a), rng.randf_range(1.4, 2.2), 0.09, -1.35, 0.0, 3,
					moss, NatureMesh.shade(moss, 1.15), 0.4, 1.0, false, NatureMesh.TAG_PLAIN, 0.0)


static func _horsetails(st: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var stalk: Color = _t(Color(0.38, 0.55, 0.24), tint)
	var node: Color = Color(0.25, 0.25, 0.16)
	for i in range(6):
		var a: float = rng.randf() * TAU
		var at: Vector3 = Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.9)
		var h: float = rng.randf_range(2.4, 4.8)
		var lean: Vector3 = Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
		var pts: PackedVector3Array = PackedVector3Array()
		var cols: PackedColorArray = PackedColorArray()
		var sways: PackedFloat32Array = PackedFloat32Array()
		for k in range(5):
			var s: float = float(k) / 4.0
			pts.append(at + Vector3(0.0, h * s, 0.0) + lean * s * s)
			cols.append(node if k % 2 == 1 else stalk)
			sways.append(s * 0.8)
		NatureMesh.tube(st, pts, PackedFloat32Array([0.09, 0.08, 0.075, 0.06, 0.045]), 5, cols, sways,
				NatureMesh.TAG_PLAIN, false)
		for k in range(1, 4):
			NatureMesh.tuft(st, pts[k] - Vector3(0.0, 0.25, 0.0), 0.42, 0.05, 6,
					NatureMesh.shade(stalk, 0.85), NatureMesh.shade(stalk, 1.2), rng, NatureMesh.TAG_PLAIN)
		NatureMesh.cone(st, pts[4], pts[4] + Vector3(0.0, 0.32, 0.0), 0.075, 5, Color(0.45, 0.33, 0.18),
				Color(0.55, 0.42, 0.25), 0.8, 0.85)


static func _fern_log(st: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var bark: Color = Color(0.36, 0.27, 0.18)
	NatureMesh.tube(st, PackedVector3Array([Vector3(-1.8, 0.28, -0.3), Vector3(0.0, 0.33, 0.0),
			Vector3(1.7, 0.26, 0.35)]), PackedFloat32Array([0.32, 0.3, 0.26]), 7,
			PackedColorArray([bark, NatureMesh.shade(bark, 1.1)]), PackedFloat32Array([0.0]), NatureMesh.TAG_ROCK)
	_ground_fern(st, rng, Vector3(0.3, 0.0, 0.9), 1.15, tint, 7)
	_ground_fern(st, rng, Vector3(-1.0, 0.0, -0.9), 0.9, tint, 6)


static func _tree_line(st: SurfaceTool, rng: RandomNumberGenerator, tint: Color) -> void:
	var canopy: Color = _t(Color(0.16, 0.34, 0.18), tint)
	for i in range(5):
		var at: Vector3 = Vector3(rng.randf_range(-7.0, 7.0), 0.0, rng.randf_range(-4.0, 4.0))
		var h: float = rng.randf_range(7.0, 13.0)
		NatureMesh.tube(st, PackedVector3Array([at, at + Vector3(0, h * 0.7, 0)]), PackedFloat32Array([0.4, 0.25]), 5,
				PackedColorArray([Color(0.3, 0.25, 0.2)]), PackedFloat32Array([0.0]))
		NatureMesh.rock(st, at + Vector3(0.0, h * 0.8, 0.0), Vector3(3.2, 2.2, 3.0), rng, canopy, 0, 0.25, 1.0,
				Color(canopy.r * 1.35, canopy.g * 1.35, canopy.b * 1.2, 0.5), NatureMesh.TAG_PLAIN)


# --- Volcano Ridge ------------------------------------------------------------------------------

static func _dead_tree(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var wood: Color = Color(0.25, 0.21, 0.19)
	var pale: Color = Color(0.42, 0.37, 0.33)
	var pts: PackedVector3Array = PackedVector3Array()
	var h: float = 7.5
	for i in range(6):
		var s: float = float(i) / 5.0
		pts.append(Vector3(0.35 * sin(s * 4.0), h * s, 0.25 * sin(s * 2.6)))
	NatureMesh.tube(st, pts, PackedFloat32Array([0.42, 0.3, 0.24, 0.18, 0.12, 0.04]), 6,
			PackedColorArray([wood, pale, wood]), PackedFloat32Array([0.0, 0.0, 0.02, 0.05, 0.08, 0.1]),
			NatureMesh.TAG_PLAIN, false)
	for b in range(5):
		var start: Vector3 = pts[2 + b % 3] + Vector3(0.0, rng.randf_range(-0.3, 0.3), 0.0)
		var a: float = rng.randf() * TAU
		var dir: Vector3 = _dir(a)
		var length: float = rng.randf_range(1.6, 3.0)
		var mid: Vector3 = start + dir * length * 0.5 + Vector3(0.0, length * 0.35, 0.0)
		var tip: Vector3 = start + dir * length + Vector3(0.0, length * rng.randf_range(0.5, 0.9), 0.0)
		NatureMesh.tube(st, PackedVector3Array([start, mid, tip]), PackedFloat32Array([0.13, 0.07, 0.0]), 4,
				PackedColorArray([wood, pale]), PackedFloat32Array([0.04, 0.08, 0.12]), NatureMesh.TAG_PLAIN, false)
	NatureMesh.rock(st, Vector3(0.0, 0.1, 0.0), Vector3(0.9, 0.3, 0.8), rng, Color(0.22, 0.2, 0.19), 0)


## Jagged lava-rock spires: leaning, tapering stacks of faceted rock (no straight columns, which
## read as a city skyline from the run camera).
static func _basalt_columns(st: SurfaceTool, rng: RandomNumberGenerator, rock: Color) -> void:
	var dark: Color = NatureMesh.shade(rock, 0.8)
	var ash: Color = Color(0.45, 0.4, 0.37, 0.35)
	for i in range(3):
		var a: float = TAU * float(i) / 3.0 + rng.randf_range(-0.4, 0.4)
		var at: Vector3 = Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.4, 1.3)
		var h: float = rng.randf_range(3.0, 7.5)
		var lean: Vector3 = Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		var pieces: int = 3
		for k in range(pieces):
			var f: float = (float(k) + 0.5) / float(pieces)
			var r: float = lerpf(1.0, 0.35, f) * rng.randf_range(0.85, 1.1)
			NatureMesh.rock(st, at + lean * f * h * 0.25 + Vector3(0.0, h * f, 0.0),
					Vector3(r, h / float(pieces) * 0.75, r * 0.85), rng,
					NatureMesh.shade(dark, rng.randf_range(0.9, 1.1)), 0, 0.3, 0.9, ash,
					NatureMesh.TAG_PLAIN, 0.0, rng.randf() * TAU)
		NatureMesh.cone(st, at + lean * h * 0.25 + Vector3(0.0, h * 0.95, 0.0),
				at + lean * h * 0.3 + Vector3(0.0, h * 1.25, 0.0), 0.35, 5,
				NatureMesh.shade(dark, 1.05), NatureMesh.shade(dark, 1.2))
	for i in range(3):
		var a: float = rng.randf() * TAU
		NatureMesh.rock(st, Vector3(cos(a) * 1.9, 0.05, sin(a) * 1.9), Vector3(0.6, 0.08, 0.12), rng, LAVA,
				0, 0.1, 0.5, Color(0, 0, 0, 0), NatureMesh.TAG_GLOW, 0.0, a)


static func _basalt_cliff(st: SurfaceTool, rng: RandomNumberGenerator, rock: Color) -> void:
	var dark: Color = NatureMesh.shade(rock, 0.8)
	NatureMesh.rock(st, Vector3(0.0, 4.0, 0.0), Vector3(11.0, 13.0, 8.0), rng, dark, 1, 0.32, 0.35,
			Color(0.45, 0.33, 0.27, 0.35))
	NatureMesh.rock(st, Vector3(7.0, 2.0, 3.0), Vector3(5.0, 6.0, 4.0), rng, NatureMesh.shade(dark, 1.1), 0, 0.3, 0.4)
	for i in range(3):
		var x: float = rng.randf_range(-6.0, 6.0)
		NatureMesh.tube(st, PackedVector3Array([Vector3(x, 12.0, 6.5), Vector3(x * 1.1 + 1.0, 6.0, 8.0),
				Vector3(x * 1.2 + 1.5, 0.2, 9.0)]), PackedFloat32Array([0.2, 0.35, 0.5]), 4,
				PackedColorArray([LAVA]), PackedFloat32Array([0.0]), NatureMesh.TAG_GLOW, false)

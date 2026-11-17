## Procedural organic mesh kit for stylised, toy-like creatures and props. Everything is built
## ONCE and shared (see cached()); nothing here should run per frame or per spawn.
##
## Shapes: lofted tubes along Catmull-Rom spines with per-point elliptical (or superelliptical)
## radii and end caps, lathes, ellipsoids, tapered limbs and horns / teeth / claws. Every part gets
## smooth normals (area weighted, seams and poles welded), UVs, a vertex colour from a painter
## callback, shader masks (UV2 and CUSTOM0) and, for rigged meshes, skin weights.
##
##   var om: OrganicMesh = OrganicMesh.new()
##   om.paint = func(p: Vector3, n: Vector3, u: float, v: float) -> Color: return Color.WHITE
##   om.loft(points, radii, 16, 4, {"cap1": OrganicMesh.CAP_ROUND})
##   var mesh: ArrayMesh = om.commit()
##
## Conventions: 1 unit = 1 m, +Y up, creatures face -Z. Triangles come out clockwise seen from
## outside (Godot's front face) whatever the input order; mirrored transforms are handled.
class_name OrganicMesh
extends RefCounted

const CAP_NONE: int = 0
const CAP_ROUND: int = 1
const CAP_FLAT: int = 2

static var _cache: Dictionary = {}
static var _noise: FastNoiseLite = null

## Vertex painter for the next parts: func(p: Vector3, n: Vector3, u: float, v: float) -> Color.
## p and n are in mesh space; u runs around a ring (0 = the ring's "up" side, 0.5 = underside),
## v runs along the part (0..1 by arc length).
var paint: Callable = Callable()
## Colour used while `paint` is not set.
var color: Color = Color.WHITE
## CUSTOM0 shader masks for the next parts: constant, or custom_fn(p, n, u, v) -> Color.
var custom: Color = Color(0.0, 0.0, 0.0, 0.0)
var custom_fn: Callable = Callable()
## UV2 shader masks for the next parts: constant, or mask2_fn(p, n, u, v) -> Vector2.
var mask2: Vector2 = Vector2.ZERO
var mask2_fn: Callable = Callable()
## Skinning (meshes created with skinned = true): the next vertices are bound to `bone`, unless
## skin_fn is set: func(p: Vector3, s: float) -> Vector3(bone_a, bone_b, blend 0..1).
## For lofts s is the spine parameter in control points (0 .. points - 1); 0 elsewhere.
var bone: int = 0
var skin_fn: Callable = Callable()
## Placement of the next parts in mesh space.
var xform: Transform3D = Transform3D.IDENTITY
## Optional surface displacement for the next parts (rocks, bumps), applied before normals:
## func(p: Vector3, outward: Vector3) -> Vector3 offset (mesh space).
var displace: Callable = Callable()

var _skinned: bool = false
var _surfaces: Array[Surf] = []
var _cur: Surf = null


## One material slot worth of geometry.
class Surf extends RefCounted:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var uv2s: PackedVector2Array = PackedVector2Array()
	var customs: PackedFloat32Array = PackedFloat32Array()
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var indices: PackedInt32Array = PackedInt32Array()


func _init(skinned: bool = false) -> void:
	_skinned = skinned
	surface(0)


## Selects the material slot (surface) the next parts go into.
func surface(index: int) -> void:
	while _surfaces.size() <= index:
		_surfaces.append(Surf.new())
	_cur = _surfaces[index]


## Resets painter, masks, bone binding and placement to their defaults.
func reset_style() -> void:
	paint = Callable()
	color = Color.WHITE
	custom = Color(0.0, 0.0, 0.0, 0.0)
	custom_fn = Callable()
	mask2 = Vector2.ZERO
	mask2_fn = Callable()
	bone = 0
	skin_fn = Callable()
	xform = Transform3D.IDENTITY
	displace = Callable()


# --- Shapes ------------------------------------------------------------------------------------

## Lofts a tube along a Catmull-Rom spine through `points`. radii[i] = (rx, ry) at points[i]:
## rx sideways, ry toward the ring's up vector. Options:
##   up: Vector3          initial up hint (default +Y); frames are then parallel-transported
##   ups: PackedVector3Array  per-point up hints (overrides transport, keeps rings upright)
##   exps: PackedFloat32Array per-point superellipse exponent (2 = ellipse, 3-4 = flatter/boxier)
##   cap0 / cap1: CAP_NONE, CAP_ROUND (default) or CAP_FLAT at the first / last point
##   cap_len0 / cap_len1: round cap length as a factor of the end radius (default 1)
##   cap_rings: rings per round cap (default 3)
##   bones: PackedInt32Array  per-point bone ids; skin weights blend between neighbouring points
func loft(points: PackedVector3Array, radii: PackedVector2Array, sides: int = 12, steps: int = 4,
		opts: Dictionary = {}) -> void:
	var n: int = points.size()
	if n < 2 or radii.size() != n:
		push_error("OrganicMesh.loft: need >= 2 points and one radius per point")
		return
	var up0: Vector3 = opts.get("up", Vector3.UP)
	var ups: PackedVector3Array = opts.get("ups", PackedVector3Array())
	var exps: PackedFloat32Array = opts.get("exps", PackedFloat32Array())
	var cap0: int = opts.get("cap0", CAP_ROUND)
	var cap1: int = opts.get("cap1", CAP_ROUND)
	var cap_len0: float = opts.get("cap_len0", 1.0)
	var cap_len1: float = opts.get("cap_len1", 1.0)
	var cap_rings: int = maxi(int(opts.get("cap_rings", 3)), 1)
	var point_bones: PackedInt32Array = opts.get("bones", PackedInt32Array())
	# 1. Sample the spine.
	var sp: PackedVector3Array = PackedVector3Array()
	var st: PackedVector3Array = PackedVector3Array()
	var sr: PackedVector2Array = PackedVector2Array()
	var se: PackedFloat32Array = PackedFloat32Array()
	var su: PackedVector3Array = PackedVector3Array()
	var ss: PackedFloat32Array = PackedFloat32Array()
	for i in range(n - 1):
		var last: int = steps if i == n - 2 else steps - 1
		for k in range(last + 1):
			var t: float = float(k) / float(steps)
			sp.append(_cr_point(points, i, t))
			var tan: Vector3 = _cr_tangent(points, i, t)
			if tan.length_squared() < 1e-10:
				tan = points[i + 1] - points[i]
			st.append(tan.normalized())
			sr.append(Vector2(maxf(_cr_scalar(radii, i, t, 0), 0.0015), maxf(_cr_scalar(radii, i, t, 1), 0.0015)))
			se.append(lerpf(exps[i], exps[i + 1], t) if exps.size() == n else 2.0)
			su.append(ups[i].lerp(ups[i + 1], t) if ups.size() == n else Vector3.ZERO)
			ss.append(float(i) + t)
	var count: int = sp.size()
	# Arc length -> v.
	var lengths: PackedFloat32Array = PackedFloat32Array()
	lengths.resize(count)
	var total: float = 0.0
	for j in range(1, count):
		total += sp[j].distance_to(sp[j - 1])
		lengths[j] = total
	total = maxf(total, 1e-5)
	# 2. Frames (parallel transport, or per-point up hints).
	var fu: PackedVector3Array = PackedVector3Array()
	fu.resize(count)
	var up: Vector3 = up0
	for j in range(count):
		var tan: Vector3 = st[j]
		if su[j] != Vector3.ZERO:
			up = su[j]
		elif j > 0:
			var axis: Vector3 = st[j - 1].cross(tan)
			if axis.length_squared() > 1e-12:
				up = up.rotated(axis.normalized(), st[j - 1].angle_to(tan))
		up = up - tan * tan.dot(up)
		if up.length_squared() < 1e-8:
			up = tan.cross(Vector3.RIGHT if absf(tan.x) < 0.9 else Vector3.FORWARD)
		up = up.normalized()
		fu[j] = up
	# 3. Rings (with caps).
	var rows: Array[PackedVector3Array] = []
	var centers: PackedVector3Array = PackedVector3Array()
	var vs: PackedFloat32Array = PackedFloat32Array()
	var row_s: PackedFloat32Array = PackedFloat32Array()
	if cap0 == CAP_ROUND:
		var clen: float = minf(sr[0].x, sr[0].y) * cap_len0
		for m in range(cap_rings, 0, -1):
			var th: float = PI * 0.5 * float(m) / float(cap_rings)
			rows.append(_ring(sp[0] - st[0] * clen * sin(th), st[0], fu[0], sr[0] * cos(th), se[0], sides))
			centers.append(sp[0])
			vs.append(0.0)
			row_s.append(0.0)
	elif cap0 == CAP_FLAT:
		rows.append(_ring(sp[0], st[0], fu[0], Vector2.ZERO, se[0], sides))
		rows.append(_ring(sp[0], st[0], fu[0], sr[0], se[0], sides))
		for m in range(2):
			centers.append(sp[0] + st[0] * 0.001)
			vs.append(0.0)
			row_s.append(0.0)
	for j in range(count):
		rows.append(_ring(sp[j], st[j], fu[j], sr[j], se[j], sides))
		centers.append(sp[j])
		vs.append(lengths[j] / total)
		row_s.append(ss[j])
	var e: int = count - 1
	if cap1 == CAP_ROUND:
		var clen: float = minf(sr[e].x, sr[e].y) * cap_len1
		for m in range(1, cap_rings + 1):
			var th: float = PI * 0.5 * float(m) / float(cap_rings)
			rows.append(_ring(sp[e] + st[e] * clen * sin(th), st[e], fu[e], sr[e] * cos(th), se[e], sides))
			centers.append(sp[e])
			vs.append(1.0)
			row_s.append(float(n - 1))
	elif cap1 == CAP_FLAT:
		rows.append(_ring(sp[e], st[e], fu[e], sr[e], se[e], sides))
		rows.append(_ring(sp[e], st[e], fu[e], Vector2.ZERO, se[e], sides))
		for m in range(2):
			centers.append(sp[e] - st[e] * 0.001)
			vs.append(1.0)
			row_s.append(float(n - 1))
	var us: PackedFloat32Array = PackedFloat32Array()
	for c in range(sides + 1):
		us.append(float(c) / float(sides))
	var old_skin: Callable = skin_fn
	if point_bones.size() == n and _skinned:
		skin_fn = func(_p: Vector3, s: float) -> Vector3:
			var i0: int = clampi(int(floor(s)), 0, n - 1)
			var i1: int = mini(i0 + 1, n - 1)
			var f: float = smoothstep(0.0, 1.0, s - float(i0))
			return Vector3(point_bones[i0], point_bones[i1], f)
	_emit(rows, centers, us, vs, row_s, true)
	skin_fn = old_skin


## Tapered limb (round cross-section) through `points` with one radius per point.
func limb(points: PackedVector3Array, radius: PackedFloat32Array, sides: int = 10, steps: int = 3,
		opts: Dictionary = {}) -> void:
	var radii: PackedVector2Array = PackedVector2Array()
	for r: float in radius:
		radii.append(Vector2(r, r))
	loft(points, radii, sides, steps, opts)


## Pointed cone-like part (horn, tooth, claw, spike) from `base` to `tip`, bent by `bend` at the
## middle. The base is left open (bury it in the body).
func horn(base: Vector3, tip: Vector3, radius: float, bend: Vector3 = Vector3.ZERO, sides: int = 6,
		steps: int = 2, up: Vector3 = Vector3.UP) -> void:
	var mid: Vector3 = base.lerp(tip, 0.5) + bend
	loft(PackedVector3Array([base, mid, tip]),
			PackedVector2Array([Vector2(radius, radius), Vector2(radius * 0.55, radius * 0.55),
					Vector2(radius * 0.06, radius * 0.06)]),
			sides, steps, {"cap0": CAP_NONE, "cap1": CAP_ROUND, "cap_len1": 1.5, "cap_rings": 1, "up": up})


## Ellipsoid with semi-axes `radii` (local x, y, z), rotated by `basis`.
## u runs around the y axis (0 = local +z), v from the top pole (0) to the bottom pole (1).
func ellipsoid(center: Vector3, radii: Vector3, rings: int = 8, sides: int = 12,
		basis: Basis = Basis.IDENTITY) -> void:
	var rows: Array[PackedVector3Array] = []
	var centers: PackedVector3Array = PackedVector3Array()
	var vs: PackedFloat32Array = PackedFloat32Array()
	var row_s: PackedFloat32Array = PackedFloat32Array()
	for r in range(rings + 1):
		var phi: float = PI * float(r) / float(rings)
		var row: PackedVector3Array = PackedVector3Array()
		for c in range(sides + 1):
			var lam: float = TAU * float(c) / float(sides)
			var local: Vector3 = Vector3(radii.x * sin(phi) * sin(lam), radii.y * cos(phi),
					radii.z * sin(phi) * cos(lam))
			row.append(center + basis * local)
		rows.append(row)
		centers.append(center)
		vs.append(float(r) / float(rings))
		row_s.append(0.0)
	var us: PackedFloat32Array = PackedFloat32Array()
	for c in range(sides + 1):
		us.append(float(c) / float(sides))
	_emit(rows, centers, us, vs, row_s, true)


## Revolves a profile of (radius, height) points around the local Y axis of (basis, origin).
## Use radius 0 at an end to close it with a pole.
func lathe(profile: PackedVector2Array, sides: int = 12, origin: Vector3 = Vector3.ZERO,
		basis: Basis = Basis.IDENTITY) -> void:
	var rows: Array[PackedVector3Array] = []
	var centers: PackedVector3Array = PackedVector3Array()
	var vs: PackedFloat32Array = PackedFloat32Array()
	var row_s: PackedFloat32Array = PackedFloat32Array()
	var total: float = 0.0
	var acc: PackedFloat32Array = PackedFloat32Array([0.0])
	for i in range(1, profile.size()):
		total += profile[i].distance_to(profile[i - 1])
		acc.append(total)
	for i in range(profile.size()):
		var row: PackedVector3Array = PackedVector3Array()
		for c in range(sides + 1):
			var lam: float = TAU * float(c) / float(sides)
			row.append(origin + basis * Vector3(profile[i].x * sin(lam), profile[i].y, profile[i].x * cos(lam)))
		rows.append(row)
		centers.append(origin + basis * Vector3(0.0, profile[i].y, 0.0))
		vs.append(acc[i] / maxf(total, 1e-5))
		row_s.append(0.0)
	var us: PackedFloat32Array = PackedFloat32Array()
	for c in range(sides + 1):
		us.append(float(c) / float(sides))
	_emit(rows, centers, us, vs, row_s, true)


## Builds an open height-field sheet (rows x cols points, row-major) such as a rock top surface.
## `inside` is a point under / behind the sheet used to orient it.
func sheet(points: PackedVector3Array, cols: int, inside: Vector3) -> void:
	var rows: Array[PackedVector3Array] = []
	var centers: PackedVector3Array = PackedVector3Array()
	var vs: PackedFloat32Array = PackedFloat32Array()
	var row_s: PackedFloat32Array = PackedFloat32Array()
	@warning_ignore("integer_division")
	var nr: int = points.size() / cols
	for r in range(nr):
		rows.append(points.slice(r * cols, (r + 1) * cols))
		centers.append(inside)
		vs.append(float(r) / float(maxi(nr - 1, 1)))
		row_s.append(0.0)
	var us: PackedFloat32Array = PackedFloat32Array()
	for c in range(cols):
		us.append(float(c) / float(maxi(cols - 1, 1)))
	_emit(rows, centers, us, vs, row_s, false)


# --- Output ------------------------------------------------------------------------------------

## Builds the ArrayMesh (one surface per material slot used). The builder can be discarded.
func commit(custom_aabb: AABB = AABB()) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for s: Surf in _surfaces:
		if s.indices.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.verts
		arrays[Mesh.ARRAY_NORMAL] = s.normals
		arrays[Mesh.ARRAY_COLOR] = s.colors
		arrays[Mesh.ARRAY_TEX_UV] = s.uvs
		arrays[Mesh.ARRAY_TEX_UV2] = s.uv2s
		arrays[Mesh.ARRAY_CUSTOM0] = s.customs
		if _skinned:
			arrays[Mesh.ARRAY_BONES] = s.bones
			arrays[Mesh.ARRAY_WEIGHTS] = s.weights
		arrays[Mesh.ARRAY_INDEX] = s.indices
		var flags: int = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	if custom_aabb.size != Vector3.ZERO:
		mesh.custom_aabb = custom_aabb
	return mesh


## Triangles added so far (all surfaces).
func triangle_count() -> int:
	var total: int = 0
	for s: Surf in _surfaces:
		@warning_ignore("integer_division")
		total += s.indices.size() / 3
	return total


## Triangles of a built mesh (all surfaces).
static func mesh_triangles(mesh: Mesh) -> int:
	var total: int = 0
	if mesh == null:
		return 0
	for i in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(i)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		@warning_ignore("integer_division")
		total += idx.size() / 3 if not idx.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## Shared-resource cache: returns the resource stored under `key`, building it once with
## `build` (a Callable returning a Resource, usually a Mesh).
static func cached(key: String, build: Callable) -> Resource:
	if _cache.has(key):
		return _cache[key] as Resource
	var res: Resource = build.call() as Resource
	_cache[key] = res
	return res


## True when a resource is already cached under `key`.
static func is_cached(key: String) -> bool:
	return _cache.has(key)


# --- Painting helpers --------------------------------------------------------------------------

## Smooth 3D noise in -1..1 (simplex), for dapples, mottling and organic bumps.
static func noise3(p: Vector3, frequency: float = 1.0, seed_offset: float = 0.0) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.seed = 1337
		_noise.frequency = 1.0
	var q: Vector3 = p * frequency + Vector3(seed_offset * 17.13, seed_offset * 3.7, seed_offset * 9.1)
	return _noise.get_noise_3dv(q)


## Dark back to light belly. `up` = -1 (pointing down) .. 1 (pointing up), e.g. normal.y.
## `line` moves the transition, `soft` widens it.
static func countershade(up: float, back: Color, belly: Color, line: float = -0.1,
		soft: float = 0.45) -> Color:
	return belly.lerp(back, smoothstep(line - soft, line + soft, up))


# --- Internals ---------------------------------------------------------------------------------

func _ring(c: Vector3, tan: Vector3, up: Vector3, r: Vector2, ex: float, sides: int) -> PackedVector3Array:
	var side: Vector3 = tan.cross(up).normalized()
	var row: PackedVector3Array = PackedVector3Array()
	row.resize(sides + 1)
	var pw: float = 2.0 / maxf(ex, 0.5)
	for k in range(sides + 1):
		var a: float = TAU * float(k % sides) / float(sides)
		var sa: float = sin(a)
		var ca: float = cos(a)
		var fx: float = signf(sa) * pow(absf(sa), pw)
		var fy: float = signf(ca) * pow(absf(ca), pw)
		row[k] = c + side * (r.x * fx) + up * (r.y * fy)
	return row


static func _cr_pts(points: PackedVector3Array, i: int) -> Array[Vector3]:
	var n: int = points.size()
	var p1: Vector3 = points[i]
	var p2: Vector3 = points[i + 1]
	var p0: Vector3 = points[i - 1] if i > 0 else p1 * 2.0 - p2
	var p3: Vector3 = points[i + 2] if i + 2 < n else p2 * 2.0 - p1
	return [p0, p1, p2, p3]


static func _cr_point(points: PackedVector3Array, i: int, t: float) -> Vector3:
	var q: Array[Vector3] = _cr_pts(points, i)
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (2.0 * q[1] + (q[2] - q[0]) * t + (2.0 * q[0] - 5.0 * q[1] + 4.0 * q[2] - q[3]) * t2
			+ (-q[0] + 3.0 * q[1] - 3.0 * q[2] + q[3]) * t3)


static func _cr_tangent(points: PackedVector3Array, i: int, t: float) -> Vector3:
	var q: Array[Vector3] = _cr_pts(points, i)
	return 0.5 * ((q[2] - q[0]) + 2.0 * (2.0 * q[0] - 5.0 * q[1] + 4.0 * q[2] - q[3]) * t
			+ 3.0 * (-q[0] + 3.0 * q[1] - 3.0 * q[2] + q[3]) * t * t)


static func _cr_scalar(values: PackedVector2Array, i: int, t: float, axis: int) -> float:
	var n: int = values.size()
	var v1: float = values[i][axis]
	var v2: float = values[i + 1][axis]
	var v0: float = values[i - 1][axis] if i > 0 else v1
	var v3: float = values[i + 2][axis] if i + 2 < n else v2
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (2.0 * v1 + (v2 - v0) * t + (2.0 * v0 - 5.0 * v1 + 4.0 * v2 - v3) * t2
			+ (-v0 + 3.0 * v1 - 3.0 * v2 + v3) * t3)


## Emits a grid (rows of points; with wrap the last point of a row duplicates the first) as
## triangles oriented outward from centers[row], with welded smooth normals.
func _emit(rows: Array[PackedVector3Array], centers: PackedVector3Array, us: PackedFloat32Array,
		vs: PackedFloat32Array, row_s: PackedFloat32Array, wrap: bool) -> void:
	var nr: int = rows.size()
	if nr < 2:
		return
	var nc: int = rows[0].size()
	var pos: PackedVector3Array = PackedVector3Array()
	pos.resize(nr * nc)
	for r in range(nr):
		var row: PackedVector3Array = rows[r]
		for c in range(nc):
			pos[r * nc + c] = xform * row[c]
	var ctr: PackedVector3Array = PackedVector3Array()
	ctr.resize(nr)
	for r in range(nr):
		ctr[r] = xform * centers[r]
	if displace.is_valid():
		for r in range(nr):
			for c in range(nc):
				var i: int = r * nc + c
				var out: Vector3 = pos[i] - ctr[r]
				pos[i] += displace.call(pos[i], out.normalized() if out.length_squared() > 1e-12 else Vector3.UP) as Vector3
	# Triangles, dropping degenerate ones (poles, flat cap rims).
	var tris: PackedInt32Array = PackedInt32Array()
	var score: float = 0.0
	for r in range(nr - 1):
		for c in range(nc - 1):
			var a: int = r * nc + c
			var b: int = a + 1
			var d: int = a + nc
			var f: int = d + 1
			for tri: Array in [[a, f, b], [a, d, f]]:
				var pa: Vector3 = pos[tri[0]]
				var pb: Vector3 = pos[tri[1]]
				var pc: Vector3 = pos[tri[2]]
				var fn: Vector3 = (pc - pa).cross(pb - pa)
				if fn.length_squared() < 1e-14:
					continue
				tris.append(tri[0])
				tris.append(tri[1])
				tris.append(tri[2])
				score += fn.dot((pa + pb + pc) / 3.0 - ctr[r])
	if score < 0.0:
		for t in range(0, tris.size(), 3):
			var tmp: int = tris[t + 1]
			tris[t + 1] = tris[t + 2]
			tris[t + 2] = tmp
	# Area-weighted normals.
	var nrm: PackedVector3Array = PackedVector3Array()
	nrm.resize(nr * nc)
	for t in range(0, tris.size(), 3):
		var pa: Vector3 = pos[tris[t]]
		var fn: Vector3 = (pos[tris[t + 2]] - pa).cross(pos[tris[t + 1]] - pa)
		nrm[tris[t]] += fn
		nrm[tris[t + 1]] += fn
		nrm[tris[t + 2]] += fn
	var half: int = nc >> 1
	for r in range(nr):
		var base: int = r * nc
		if pos[base].distance_squared_to(pos[base + half]) < 1e-10:
			# Pole / collapsed row: one shared normal.
			var sum: Vector3 = Vector3.ZERO
			for c in range(nc):
				sum += nrm[base + c]
			for c in range(nc):
				nrm[base + c] = sum
		elif wrap:
			var seam: Vector3 = nrm[base] + nrm[base + nc - 1]
			nrm[base] = seam
			nrm[base + nc - 1] = seam
	# Append to the current surface.
	var s: Surf = _cur
	var offset: int = s.verts.size()
	for r in range(nr):
		for c in range(nc):
			var i: int = r * nc + c
			var p: Vector3 = pos[i]
			var nn: Vector3 = nrm[i].normalized() if nrm[i].length_squared() > 1e-20 else (p - ctr[r]).normalized()
			var u: float = us[c]
			var v: float = vs[r]
			s.verts.append(p)
			s.normals.append(nn)
			s.colors.append(paint.call(p, nn, u, v) as Color if paint.is_valid() else color)
			s.uvs.append(Vector2(u, v))
			s.uv2s.append(mask2_fn.call(p, nn, u, v) as Vector2 if mask2_fn.is_valid() else mask2)
			var cu: Color = custom_fn.call(p, nn, u, v) as Color if custom_fn.is_valid() else custom
			s.customs.append_array(PackedFloat32Array([cu.r, cu.g, cu.b, cu.a]))
			if _skinned:
				var bw: Vector3 = Vector3(bone, bone, 0.0)
				if skin_fn.is_valid():
					bw = skin_fn.call(p, row_s[r]) as Vector3
				var b0: int = int(bw.x)
				var b1: int = int(bw.y)
				var w1: float = clampf(bw.z, 0.0, 1.0)
				if b0 == b1 or w1 <= 0.0:
					s.bones.append_array(PackedInt32Array([b0, 0, 0, 0]))
					s.weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				elif w1 >= 1.0:
					s.bones.append_array(PackedInt32Array([b1, 0, 0, 0]))
					s.weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				else:
					s.bones.append_array(PackedInt32Array([b0, b1, 0, 0]))
					s.weights.append_array(PackedFloat32Array([1.0 - w1, w1, 0.0, 0.0]))
	for t in range(tris.size()):
		s.indices.append(tris[t] + offset)

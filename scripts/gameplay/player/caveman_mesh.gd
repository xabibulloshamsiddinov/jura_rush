## Small procedural modelling kit for the organic characters (caveman, pterosaur).
## Every primitive is a parametric grid (ellipsoid, lathe, swept tube, open sheet) with smooth
## area-weighted normals. Vertex colours carry the material data read by character_toon.gdshader:
## palette slot, baked occlusion, fur-pattern mask and gloss; UV2 carries the flutter weight.
## Meshes are built once and cached by their owners; nothing here runs per frame.
class_name CavemanMesh
extends RefCounted

## Palette slots (COLOR.r = slot / 15). Must match character_toon.gdshader.
enum Slot { SKIN, FUR, HAIR, LEATHER, BONE, EYE_WHITE, PUPIL, ACCENT, MARK, STONE, DARK, BLUSH }

## Placement of the next primitives (bone space).
var xf: Transform3D = Transform3D.IDENTITY
var slot: int = Slot.SKIN
var ao: float = 1.0
var pattern: float = 0.0
var gloss: float = 0.0
## Optional per-vertex hooks, all called with (local_point: Vector3, u: float, v: float):
##   deform  -> Vector3  reshapes the point before `xf`
##   ao_fn   -> float    occlusion multiplier
##   flutter_fn -> float flutter weight (0 = rigid)
##   slot_fn -> int      palette slot override (-1 = keep `slot`)
var deform: Callable = Callable()
var ao_fn: Callable = Callable()
var flutter_fn: Callable = Callable()
var slot_fn: Callable = Callable()
var flutter_phase: float = 0.0
## Rings in each rounded tube cap (2 = smooth, 1 = cheap for tiny parts).
var cap_rings: int = 2

var _v: PackedVector3Array = PackedVector3Array()
var _n: PackedVector3Array = PackedVector3Array()
var _c: PackedColorArray = PackedColorArray()
var _uv2: PackedVector2Array = PackedVector2Array()
var _i: PackedInt32Array = PackedInt32Array()
var _tmp: PackedInt32Array = PackedInt32Array()


## Sets the material data for the next primitives and clears the per-vertex hooks.
func style(p_slot: int, p_ao: float = 1.0, p_pattern: float = 0.0, p_gloss: float = 0.0) -> CavemanMesh:
	slot = p_slot
	ao = p_ao
	pattern = p_pattern
	gloss = p_gloss
	deform = Callable()
	ao_fn = Callable()
	flutter_fn = Callable()
	slot_fn = Callable()
	cap_rings = 2
	return self


## Triangle count so far.
func triangles() -> int:
	@warning_ignore("integer_division")
	return _i.size() / 3


## Ellipsoid (UV sphere) with poles on local Y.
func ellipsoid(center: Vector3, radii: Vector3, nu: int = 12, nv: int = 8,
		basis: Basis = Basis.IDENTITY) -> void:
	grid(func(u: float, v: float) -> Vector3:
		var th: float = u * TAU
		var y: float = -cos(v * PI)
		var ring: float = sin(v * PI)
		return center + basis * (Vector3(ring * cos(th), y, ring * sin(th)) * radii),
			nu, nv, true, true, true)


## Surface of revolution around local Y. `profile` = (radius, y) points from bottom to top;
## a point with radius 0 at either end closes that end with a pole.
func lathe(profile: PackedVector2Array, nu: int = 12) -> void:
	var rows: int = profile.size() - 1
	var pole0: bool = profile[0].x <= 0.0001
	var pole1: bool = profile[rows].x <= 0.0001
	grid(func(u: float, v: float) -> Vector3:
		var i: int = clampi(roundi(v * float(rows)), 0, rows)
		var th: float = u * TAU
		return Vector3(profile[i].x * cos(th), profile[i].y, profile[i].x * sin(th)),
			nu, rows, pole0, pole1, true)


## Tube swept along a polyline with per-point radii and rounded (pole) end caps.
## flat scales the cross-section (x = side, y = the "up" axis of the frame).
func tube(points: PackedVector3Array, radii: PackedFloat32Array, nu: int = 10,
		cap0: bool = true, cap1: bool = true, flat: Vector2 = Vector2.ONE,
		up_hint: Vector3 = Vector3(0, 0, -1)) -> void:
	# Extend the polyline with rounded caps: two shrinking rings and a pole on each end
	# (a slightly flattened hemisphere).
	var pts: PackedVector3Array = PackedVector3Array()
	var rad: PackedFloat32Array = PackedFloat32Array()
	var n: int = points.size()
	var t0: Vector3 = (points[1] - points[0]).normalized()
	var t1: Vector3 = (points[n - 1] - points[n - 2]).normalized()
	var cap_angles: PackedFloat32Array = PackedFloat32Array([deg_to_rad(40.0), deg_to_rad(70.0), PI * 0.5])
	if cap_rings <= 1:
		cap_angles = PackedFloat32Array([deg_to_rad(60.0), PI * 0.5])
	var last: int = cap_angles.size() - 1
	if cap0:
		for k in range(last, -1, -1):
			var a: float = cap_angles[k]
			pts.append(points[0] - t0 * radii[0] * sin(a) * 0.85)
			rad.append(0.0 if k == last else radii[0] * cos(a))
	pts.append_array(points)
	rad.append_array(radii)
	if cap1:
		for k in range(last + 1):
			var a: float = cap_angles[k]
			pts.append(points[n - 1] + t1 * radii[n - 1] * sin(a) * 0.85)
			rad.append(0.0 if k == last else radii[n - 1] * cos(a))
	# Parallel-transport frames.
	var m: int = pts.size()
	var tangents: Array[Vector3] = []
	for i in range(m):
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, m - 1)]
		var t: Vector3 = (b - a)
		tangents.append(t.normalized() if t.length() > 0.00001 else Vector3.DOWN)
	var normals: Array[Vector3] = []
	var ref: Vector3 = up_hint
	if absf(ref.normalized().dot(tangents[0])) > 0.95:
		ref = Vector3.RIGHT
	var nrm: Vector3 = (ref - tangents[0] * ref.dot(tangents[0])).normalized()
	for i in range(m):
		if i > 0:
			nrm = (nrm - tangents[i] * nrm.dot(tangents[i])).normalized()
		normals.append(nrm)
	var pole0: bool = cap0
	var pole1: bool = cap1
	grid(func(u: float, v: float) -> Vector3:
		var i: int = clampi(roundi(v * float(m - 1)), 0, m - 1)
		var th: float = u * TAU
		var side: Vector3 = tangents[i].cross(normals[i]).normalized()
		return pts[i] + (side * cos(th) * flat.x + normals[i] * sin(th) * flat.y) * rad[i],
			nu, m - 1, pole0, pole1, true)


## Open two-sided sheet (wing membranes, leaves, feathers). fn(u, v) -> point, u and v in 0..1.
func sheet(fn: Callable, nu: int, nv: int, thickness: float = 0.0) -> void:
	var start: int = _v.size()
	var tri_start: int = _i.size()
	grid(fn, nu, nv, false, false, false, false)
	_back_side(start, tri_start, thickness, 1.0)


## Two-sided surface wrapped around local Y (skirts, shawls): the outside faces away from the
## centroid, the inside is darkened by inner_ao.
func sheet_wrapped(fn: Callable, nu: int, nv: int, thickness: float, inner_ao: float,
		wrap_u: bool = true) -> void:
	var start: int = _v.size()
	var tri_start: int = _i.size()
	grid(fn, nu, nv, false, false, wrap_u, true)
	_back_side(start, tri_start, thickness, inner_ao)


## Duplicates the vertices / triangles added since (start, tri_start) as a back face.
func _back_side(start: int, tri_start: int, thickness: float, inner_ao: float) -> void:
	var end: int = _v.size()
	var tri_end: int = _i.size()
	var offset: int = end - start
	for k in range(start, end):
		_v.append(_v[k] - _n[k] * thickness)
		_n.append(-_n[k])
		var col: Color = _c[k]
		col.g *= inner_ao
		_c.append(col)
		_uv2.append(_uv2[k])
	for k in range(tri_start, tri_end, 3):
		_i.append(_i[k] + offset)
		_i.append(_i[k + 2] + offset)
		_i.append(_i[k + 1] + offset)


## Generic parametric grid: u around (wraps when wrap_u), v along (0..1, nv + 1 rows).
## pole0 / pole1 collapse the first / last row into one vertex. When orient is true the
## winding is chosen so normals point away from the primitive's centroid.
func grid(fn: Callable, nu: int, nv: int, pole0: bool, pole1: bool, wrap_u: bool,
		orient: bool = true) -> void:
	var base: int = _v.size()
	var cols: int = nu if wrap_u else nu + 1
	var row_start: PackedInt32Array = PackedInt32Array()
	var row_size: PackedInt32Array = PackedInt32Array()
	var local: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for r in range(nv + 1):
		var v: float = float(r) / float(nv)
		row_start.append(local.size())
		if (r == 0 and pole0) or (r == nv and pole1):
			row_size.append(1)
			local.append(fn.call(0.0, v))
			uvs.append(Vector2(0.0, v))
			continue
		row_size.append(cols)
		for c in range(cols):
			var u: float = float(c) / float(nu)
			local.append(fn.call(u, v))
			uvs.append(Vector2(u, v))
	# Triangles in local index space.
	_tmp.clear()
	for r in range(nv):
		var a0: int = row_start[r]
		var b0: int = row_start[r + 1]
		var an: int = row_size[r]
		var bn: int = row_size[r + 1]
		var steps: int = nu
		for c in range(steps):
			var c1: int = (c + 1) % cols if wrap_u else c + 1
			if an == 1 and bn == 1:
				continue
			if an == 1:
				_tri(a0, b0 + c1, b0 + c)
			elif bn == 1:
				_tri(a0 + c, a0 + c1, b0)
			else:
				_tri(a0 + c, a0 + c1, b0 + c1)
				_tri(a0 + c, b0 + c1, b0 + c)
	var tris: PackedInt32Array = _tmp.duplicate()
	# Final positions (deform, then placement).
	var world: PackedVector3Array = PackedVector3Array()
	world.resize(local.size())
	for k in range(local.size()):
		var p: Vector3 = local[k]
		if deform.is_valid():
			p = deform.call(p, uvs[k].x, uvs[k].y)
		world[k] = xf * p
	# Winding: outward normals (away from the centroid) unless told otherwise.
	if orient:
		var centroid: Vector3 = Vector3.ZERO
		for p: Vector3 in world:
			centroid += p
		centroid /= maxf(float(world.size()), 1.0)
		var s: float = 0.0
		for k in range(0, tris.size(), 3):
			var a: Vector3 = world[tris[k]]
			var b: Vector3 = world[tris[k + 1]]
			var c: Vector3 = world[tris[k + 2]]
			s += (b - a).cross(c - a).dot((a + b + c) / 3.0 - centroid)
		if s < 0.0:
			for k in range(0, tris.size(), 3):
				var tmp: int = tris[k + 1]
				tris[k + 1] = tris[k + 2]
				tris[k + 2] = tmp
	# Smooth area-weighted normals.
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(world.size())
	for k in range(0, tris.size(), 3):
		var a: Vector3 = world[tris[k]]
		var b: Vector3 = world[tris[k + 1]]
		var c: Vector3 = world[tris[k + 2]]
		var fn_: Vector3 = (b - a).cross(c - a)
		normals[tris[k]] += fn_
		normals[tris[k + 1]] += fn_
		normals[tris[k + 2]] += fn_
	for k in range(world.size()):
		var nn: Vector3 = normals[k]
		var p: Vector3 = local[k]
		var u: float = uvs[k].x
		var v: float = uvs[k].y
		_v.append(world[k])
		_n.append(nn.normalized() if nn.length_squared() > 0.0 else Vector3.UP)
		var s_id: int = slot
		if slot_fn.is_valid():
			var o: int = slot_fn.call(p, u, v)
			if o >= 0:
				s_id = o
		var occ: float = ao * (ao_fn.call(p, u, v) as float if ao_fn.is_valid() else 1.0)
		_c.append(Color(float(s_id) / 15.0, clampf(occ, 0.0, 1.0), pattern, gloss))
		var fw: float = flutter_fn.call(p, u, v) as float if flutter_fn.is_valid() else 0.0
		_uv2.append(Vector2(fw, flutter_phase + u * TAU * 2.0))
	# Godot's front faces wind clockwise seen from outside: emit (a, c, b).
	for k in range(0, tris.size(), 3):
		_i.append(base + tris[k])
		_i.append(base + tris[k + 2])
		_i.append(base + tris[k + 1])


func _tri(a: int, b: int, c: int) -> void:
	_tmp.append(a)
	_tmp.append(b)
	_tmp.append(c)


## The finished mesh (one surface).
func build() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_INDEX] = _i
	var mesh: ArrayMesh = ArrayMesh.new()
	if _v.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

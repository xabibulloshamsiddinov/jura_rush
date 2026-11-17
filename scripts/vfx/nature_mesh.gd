## Procedural low-poly building blocks of the Jura Rush world: faceted rocks, lathed shapes,
## tubes (trunks, branches, ropes, stalks), fronds, grass tufts and boxes (planks).
## Everything appends to a SurfaceTool in PRIMITIVE_TRIANGLES with:
##   COLOR  rgb = albedo, a = baked ambient occlusion (1 = open sky)
##   NORMAL facet or smooth normal
##   UV     x = wind sway weight (0 rooted .. 1 tip), y = material tag (TAG_*)
## The nature shaders (building / nature_lit / track_ground) read these. 1 unit = 1 m.
## Triangles are oriented automatically (outward / along the given hint), so callers never have
## to think about Godot's clockwise front faces.
class_name NatureMesh
extends RefCounted

## Material tags stored in UV.y.
const TAG_PLAIN: float = 0.0
## Multiplied by the foliage tint (biome_accent) in nature_lit.gdshader.
const TAG_FOLIAGE: float = 1.0
## Multiplied by the rock tint (biome_accent2) in nature_lit.gdshader.
const TAG_ROCK: float = 2.0
## Emissive (lava cracks, embers): the vertex colour is light.
const TAG_GLOW: float = 3.0
## Warning paint (the bands on lethal standing stones): drawn as its vertex colour; with the
## colour-blind setting on, nature_lit.gdshader draws yellow / black hazard stripes instead.
const TAG_PAINT: float = 4.0
## Warning-edge rock (stones lining a gap): an ordinary rock (rock tint, moss); hazard stripes
## with the colour-blind setting on.
const TAG_EDGE_ROCK: float = 5.0

const ICO_FACES: Array[Vector3i] = [
	Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
	Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
	Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
	Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
]


## A SurfaceTool ready for triangles.
static func begin() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Commits a SurfaceTool into a new ArrayMesh (or appends a surface to `into`).
static func commit(st: SurfaceTool, into: ArrayMesh = null) -> ArrayMesh:
	var mesh: ArrayMesh = into if into != null else ArrayMesh.new()
	st.commit(mesh)
	return mesh


## One vertex. Colours are authored in sRGB (colour-picker values) and stored linear, because the
## nature shaders use COLOR directly as linear albedo.
static func vert(st: SurfaceTool, p: Vector3, n: Vector3, c: Color, sway: float, tag: float) -> void:
	var lin: Color = c.srgb_to_linear()
	st.set_color(Color(lin.r, lin.g, lin.b, c.a))
	st.set_normal(n)
	st.set_uv(Vector2(sway, tag))
	st.add_vertex(p)


## Flat-shaded triangle. `facing` (optional) is a direction the face should point along; without
## it the winding given is kept (a, b, c clockwise seen from the front).
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, tag: float,
		sway_a: float = 0.0, sway_b: float = 0.0, sway_c: float = 0.0,
		facing: Vector3 = Vector3.ZERO) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	if facing != Vector3.ZERO and n.dot(facing) < 0.0:
		vert(st, a, -n, col, sway_a, tag)
		vert(st, c, -n, col, sway_c, tag)
		vert(st, b, -n, col, sway_b, tag)
		return
	vert(st, a, n, col, sway_a, tag)
	vert(st, b, n, col, sway_b, tag)
	vert(st, c, n, col, sway_c, tag)


## Smooth triangle with per-vertex normals / colours / sway; oriented to agree with the normals.
static func tri_smooth(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color,
		sa: float, sb: float, sc: float, tag: float) -> void:
	var g: Vector3 = (c - a).cross(b - a)
	if g.length_squared() < 1e-14:
		return
	if g.dot(na + nb + nc) < 0.0:
		vert(st, a, na, ca, sa, tag)
		vert(st, c, nc, cc, sc, tag)
		vert(st, b, nb, cb, sb, tag)
	else:
		vert(st, a, na, ca, sa, tag)
		vert(st, b, nb, cb, sb, tag)
		vert(st, c, nc, cc, sc, tag)


## Flat quad a-b-c-d (any winding) facing `facing`.
static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color,
		tag: float, facing: Vector3, sway_ab: float = 0.0, sway_cd: float = 0.0) -> void:
	tri(st, a, b, c, col, tag, sway_ab, sway_ab, sway_cd, facing)
	tri(st, a, c, d, col, tag, sway_ab, sway_cd, sway_cd, facing)


## Faceted, irregular low-poly rock (icosphere, detail 0 = 20 faces, 1 = 80 faces).
## radii: half extents. flat: the bottom is cut flat at -radii.y * flat (it sits on the ground).
## top_color.a > 0: faces turned up blend toward top_color by that amount (moss, sand, ash).
## paint.a > 0: faces turned toward +Z (the runner) inside the height bands `paint_bands`
## (pairs of local heights from the rock bottom) are painted that colour (ochre warning marks).
static func rock(st: SurfaceTool, center: Vector3, radii: Vector3, rng: RandomNumberGenerator,
		col: Color, detail: int = 0, jitter: float = 0.22, flat: float = 0.6,
		top_color: Color = Color(0, 0, 0, 0), tag: float = TAG_ROCK, sway: float = 0.0,
		yaw: float = 0.0, paint: Color = Color(0, 0, 0, 0),
		paint_bands: PackedFloat32Array = PackedFloat32Array()) -> void:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in range(verts.size()):
		verts[i] = verts[i].normalized()
	var faces: Array[Vector3i] = ICO_FACES.duplicate()
	if detail > 0:
		var mids: Dictionary = {}
		var split: Array[Vector3i] = []
		for f: Vector3i in faces:
			var ab: int = _mid(verts, mids, f.x, f.y)
			var bc: int = _mid(verts, mids, f.y, f.z)
			var ca: int = _mid(verts, mids, f.z, f.x)
			split.append(Vector3i(f.x, ab, ca))
			split.append(Vector3i(f.y, bc, ab))
			split.append(Vector3i(f.z, ca, bc))
			split.append(Vector3i(ab, bc, ca))
		faces = split
	var basis: Basis = Basis(Vector3.UP, yaw)
	var bottom: float = -radii.y * flat
	var pts: Array[Vector3] = []
	for v: Vector3 in verts:
		var r: float = 1.0 + rng.randf_range(-jitter, jitter)
		var p: Vector3 = Vector3(v.x * radii.x, v.y * radii.y, v.z * radii.z) * r
		p.y = maxf(p.y, bottom)
		pts.append(center + basis * p)
	var low: float = center.y + bottom
	var height: float = maxf(radii.y * (1.0 + flat), 0.01)
	for f: Vector3i in faces:
		var a: Vector3 = pts[f.x]
		var b: Vector3 = pts[f.y]
		var c: Vector3 = pts[f.z]
		var centroid: Vector3 = (a + b + c) / 3.0
		var n: Vector3 = (c - a).cross(b - a)
		if n.length_squared() < 1e-14:
			continue
		n = n.normalized()
		var out: Vector3 = (centroid - center)
		if n.dot(out) < 0.0:
			n = -n
		var shade: float = 1.0 + rng.randf_range(-0.07, 0.07)
		var fc: Color = Color(col.r * shade, col.g * shade, col.b * shade)
		if top_color.a > 0.0 and n.y > 0.5:
			fc = fc.lerp(Color(top_color.r, top_color.g, top_color.b), top_color.a * smoothstep(0.5, 0.9, n.y))
		var face_tag: float = tag
		if paint.a > 0.0 and n.z > 0.3:
			var local_y: float = centroid.y - low
			for bi in range(0, paint_bands.size() - 1, 2):
				if local_y >= paint_bands[bi] and local_y <= paint_bands[bi + 1]:
					fc = Color(paint.r, paint.g, paint.b) * (1.0 + rng.randf_range(-0.05, 0.05))
					face_tag = TAG_PAINT
		fc.a = clampf(0.55 + 0.45 * (centroid.y - low) / height, 0.55, 1.0)
		tri(st, a, b, c, fc, face_tag, sway, sway, sway, n)


static func _mid(verts: Array[Vector3], mids: Dictionary, a: int, b: int) -> int:
	var key: int = mini(a, b) * 4096 + maxi(a, b)
	if mids.has(key):
		return int(mids[key])
	verts.append(((verts[a] + verts[b]) * 0.5).normalized())
	mids[key] = verts.size() - 1
	return verts.size() - 1


## Surface of revolution around +Y through `base`. profile: (radius, height) pairs bottom -> top.
## colors: one per profile point (or a single colour). sways: per profile point (optional).
## smooth: smooth normals (eggs, pots) instead of facets.
static func lathe(st: SurfaceTool, base: Vector3, profile: PackedVector2Array, segments: int,
		colors: PackedColorArray, smooth: bool = true, sways: PackedFloat32Array = PackedFloat32Array(),
		tag: float = TAG_PLAIN, phase: float = 0.0) -> void:
	var rings: int = profile.size()
	var normals: Array[Vector2] = []
	for i in range(rings):
		var prev: Vector2 = profile[maxi(i - 1, 0)]
		var next: Vector2 = profile[mini(i + 1, rings - 1)]
		var tangent: Vector2 = next - prev
		var n2: Vector2 = Vector2(tangent.y, -tangent.x)
		if n2.length_squared() < 1e-10:
			n2 = Vector2(0.0, 1.0 if i == rings - 1 else -1.0)
		normals.append(n2.normalized())
	for i in range(rings - 1):
		for j in range(segments):
			var a0: float = TAU * float(j) / float(segments) + phase
			var a1: float = TAU * float(j + 1) / float(segments) + phase
			var p: Array[Vector3] = [
				_ring_point(base, profile[i], a0), _ring_point(base, profile[i], a1),
				_ring_point(base, profile[i + 1], a1), _ring_point(base, profile[i + 1], a0)]
			var n: Array[Vector3] = [
				_ring_normal(normals[i], a0), _ring_normal(normals[i], a1),
				_ring_normal(normals[i + 1], a1), _ring_normal(normals[i + 1], a0)]
			var c0: Color = colors[mini(i, colors.size() - 1)]
			var c1: Color = colors[mini(i + 1, colors.size() - 1)]
			var s0: float = sways[i] if i < sways.size() else 0.0
			var s1: float = sways[i + 1] if i + 1 < sways.size() else 0.0
			if smooth:
				tri_smooth(st, p[0], p[1], p[2], n[0], n[1], n[2], c0, c0, c1, s0, s0, s1, tag)
				tri_smooth(st, p[0], p[2], p[3], n[0], n[2], n[3], c0, c1, c1, s0, s1, s1, tag)
			else:
				var mid_n: Vector3 = (n[0] + n[1] + n[2] + n[3]).normalized()
				var fc: Color = c0.lerp(c1, 0.5)
				tri(st, p[0], p[1], p[2], fc, tag, s0, s0, s1, mid_n)
				tri(st, p[0], p[2], p[3], fc, tag, s0, s1, s1, mid_n)


static func _ring_point(base: Vector3, rh: Vector2, angle: float) -> Vector3:
	return base + Vector3(cos(angle) * rh.x, rh.y, sin(angle) * rh.x)


static func _ring_normal(n2: Vector2, angle: float) -> Vector3:
	return Vector3(cos(angle) * n2.x, n2.y, sin(angle) * n2.x)


## Tube along a polyline (trunks, branches, ropes, stalks). radii / colors / sways per point
## (arrays shorter than the polyline repeat their last value). The last radius may be 0 (spike).
static func tube(st: SurfaceTool, pts: PackedVector3Array, radii: PackedFloat32Array, sides: int,
		colors: PackedColorArray, sways: PackedFloat32Array, tag: float = TAG_PLAIN,
		smooth: bool = true) -> void:
	var count: int = pts.size()
	if count < 2:
		return
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	var ref: Vector3 = Vector3.UP
	for i in range(count):
		var tangent: Vector3 = (pts[mini(i + 1, count - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if absf(tangent.dot(ref)) > 0.95:
			ref = Vector3.RIGHT if absf(tangent.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var side: Vector3 = tangent.cross(ref).normalized()
		var up: Vector3 = side.cross(tangent).normalized()
		var r: float = radii[mini(i, radii.size() - 1)]
		var ring: PackedVector3Array = PackedVector3Array()
		var normals: PackedVector3Array = PackedVector3Array()
		for j in range(sides):
			var a: float = TAU * float(j) / float(sides)
			var dir: Vector3 = side * cos(a) + up * sin(a)
			ring.append(pts[i] + dir * r)
			normals.append(dir)
		rings.append(ring)
		ring_normals.append(normals)
	for i in range(count - 1):
		var c0: Color = colors[mini(i, colors.size() - 1)]
		var c1: Color = colors[mini(i + 1, colors.size() - 1)]
		var s0: float = sways[mini(i, sways.size() - 1)] if sways.size() > 0 else 0.0
		var s1: float = sways[mini(i + 1, sways.size() - 1)] if sways.size() > 0 else 0.0
		for j in range(sides):
			var k: int = (j + 1) % sides
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][k]
			var c: Vector3 = rings[i + 1][k]
			var d: Vector3 = rings[i + 1][j]
			if smooth:
				var na: Vector3 = ring_normals[i][j]
				var nb: Vector3 = ring_normals[i][k]
				var nc: Vector3 = ring_normals[i + 1][k]
				var nd: Vector3 = ring_normals[i + 1][j]
				tri_smooth(st, a, b, c, na, nb, nc, c0, c0, c1, s0, s0, s1, tag)
				tri_smooth(st, a, c, d, na, nc, nd, c0, c1, c1, s0, s1, s1, tag)
			else:
				var out: Vector3 = (ring_normals[i][j] + ring_normals[i][k]).normalized()
				var fc: Color = c0.lerp(c1, 0.5)
				tri(st, a, b, c, fc, tag, s0, s0, s1, out)
				tri(st, a, c, d, fc, tag, s0, s1, s1, out)


## An arching, drooping frond / leaf (double-sided in the nature shaders).
## dir: horizontal growth direction. rise: initial upward angle (radians). droop: gravity bend.
## serrate: alternate widths so the edge reads as leaflets.
static func frond(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float,
		rise: float, droop: float, segments: int, col_base: Color, col_tip: Color,
		sway_base: float, sway_tip: float, serrate: bool = true, tag: float = TAG_FOLIAGE,
		fold: float = 0.25) -> void:
	var h: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	if h == Vector3.ZERO:
		h = Vector3.FORWARD
	var side: Vector3 = h.cross(Vector3.UP).normalized()
	var spine: Array[Vector3] = []
	var widths: Array[float] = []
	var pos: Vector3 = base
	var step: float = length / float(segments)
	for i in range(segments + 1):
		spine.append(pos)
		var s: float = float(i) / float(segments)
		var w: float = width * pow(sin(PI * clampf(s * 0.92 + 0.04, 0.0, 1.0)), 0.6)
		if serrate and i % 2 == 1:
			w *= 0.62
		widths.append(w)
		var ang: float = rise - droop * s * 1.6
		pos += (h * cos(ang) + Vector3.UP * sin(ang)) * step
	for i in range(segments):
		var s0: float = float(i) / float(segments)
		var s1: float = float(i + 1) / float(segments)
		var c0: Color = col_base.lerp(col_tip, s0)
		var c1: Color = col_base.lerp(col_tip, s1)
		var w0: float = sway_base + (sway_tip - sway_base) * s0
		var w1: float = sway_base + (sway_tip - sway_base) * s1
		var l0: Vector3 = spine[i] - side * widths[i] - Vector3.UP * widths[i] * fold
		var r0: Vector3 = spine[i] + side * widths[i] - Vector3.UP * widths[i] * fold
		var l1: Vector3 = spine[i + 1] - side * widths[i + 1] - Vector3.UP * widths[i + 1] * fold
		var r1: Vector3 = spine[i + 1] + side * widths[i + 1] - Vector3.UP * widths[i + 1] * fold
		# Two halves meeting at the spine (a shallow V fold).
		tri(st, spine[i], l0, l1, c0.lerp(c1, 0.5), tag, w0, w0, w1, Vector3.UP)
		tri(st, spine[i], l1, spine[i + 1], c0.lerp(c1, 0.5), tag, w0, w1, w1, Vector3.UP)
		tri(st, spine[i], spine[i + 1], r1, c0.lerp(c1, 0.5), tag, w0, w1, w1, Vector3.UP)
		tri(st, spine[i], r1, r0, c0.lerp(c1, 0.5), tag, w0, w1, w0, Vector3.UP)


## A tuft of grass blades (one triangle per blade, double-sided in the shaders).
static func tuft(st: SurfaceTool, center: Vector3, height: float, radius: float, blades: int,
		col_base: Color, col_tip: Color, rng: RandomNumberGenerator, tag: float = TAG_FOLIAGE) -> void:
	for i in range(blades):
		var a: float = rng.randf() * TAU
		var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var root: Vector3 = center + dir * rng.randf_range(0.0, radius * 0.5)
		var w: float = rng.randf_range(0.025, 0.05) * maxf(height / 0.3, 0.6)
		var hgt: float = height * rng.randf_range(0.65, 1.15)
		var tip: Vector3 = root + dir * hgt * rng.randf_range(0.25, 0.6) + Vector3.UP * hgt
		var tip_col: Color = col_tip.lerp(col_base, rng.randf_range(0.0, 0.3))
		var base_col: Color = Color(col_base.r, col_base.g, col_base.b, 0.7)
		tri_smooth(st, root - side * w, root + side * w, tip, Vector3.UP, Vector3.UP, Vector3.UP,
				base_col, base_col, tip_col, 0.0, 0.0, 1.0, tag)


## Oriented box (planks, posts, slabs).
static func box(st: SurfaceTool, center: Vector3, size: Vector3, basis: Basis, col: Color,
		tag: float = TAG_PLAIN, shade_vary: float = 0.0, rng: RandomNumberGenerator = null) -> void:
	var h: Vector3 = size * 0.5
	var axes: Array[Vector3] = [basis.x, basis.y, basis.z]
	var ext: Array[float] = [h.x, h.y, h.z]
	for ai in range(3):
		var n_axis: Vector3 = axes[ai]
		var u_axis: Vector3 = axes[(ai + 1) % 3]
		var v_axis: Vector3 = axes[(ai + 2) % 3]
		var eu: float = ext[(ai + 1) % 3]
		var ev: float = ext[(ai + 2) % 3]
		for sgn: float in [-1.0, 1.0]:
			var n: Vector3 = n_axis * sgn
			var c: Vector3 = center + n * ext[ai]
			var fc: Color = col
			if shade_vary > 0.0 and rng != null:
				var s: float = 1.0 + rng.randf_range(-shade_vary, shade_vary)
				fc = Color(col.r * s, col.g * s, col.b * s, col.a)
			quad(st, c - u_axis * eu - v_axis * ev, c + u_axis * eu - v_axis * ev,
					c + u_axis * eu + v_axis * ev, c - u_axis * eu + v_axis * ev, fc, tag, n)


## A cone (base ring -> apex) built from tube().
static func cone(st: SurfaceTool, base: Vector3, apex: Vector3, radius: float, sides: int,
		col_base: Color, col_tip: Color, sway_base: float = 0.0, sway_tip: float = 0.0,
		tag: float = TAG_PLAIN, smooth: bool = false) -> void:
	tube(st, PackedVector3Array([base, apex]), PackedFloat32Array([radius, 0.0]), sides,
			PackedColorArray([col_base, col_tip]), PackedFloat32Array([sway_base, sway_tip]), tag, smooth)


## Colour helper: c scaled by k (alpha kept).
static func shade(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

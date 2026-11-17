## The jetpack power-up, Jurassic style: a pterosaur swoops in, grips the caveman's shoulders and
## carries him; when the power-up ends it lets go and flies off. Purely visual (the flight itself
## is JetpackState). ~3.8 m wingspan, crest, long beak, two-part membrane wings.
##
## Space: origin = the grip point between the caveman's shoulders, facing -Z.
class_name PterosaurRide
extends Node3D

enum Mode { HIDDEN, GRAB, CARRY, RELEASE }

const S := CavemanMesh.Slot
const GRAB_TIME: float = 0.38
const RELEASE_TIME: float = 1.0
## Where it swoops in from / flies off to, relative to the grip.
const SWOOP_FROM: Vector3 = Vector3(0.0, 2.6, -3.2)
const FLY_OFF: Vector3 = Vector3(0.0, 4.0, -5.5)
const FLAP_SPEED: float = 7.2
const SHOULDER: Vector3 = Vector3(0.12, 1.08, -0.2)
## Upper body height above the grip (clears the caveman's head).
const LIFT: float = 0.28
const WRIST: Vector3 = Vector3(0.82, 0.02, 0.02)

static var _meshes: Dictionary = {}
static var _material: ShaderMaterial = null

var mode: Mode = Mode.HIDDEN

var _body: Node3D = null
var _wing_l: Node3D = null
var _wing_r: Node3D = null
var _outer_l: Node3D = null
var _outer_r: Node3D = null
var _time: float = 0.0
var _phase: float = 0.0
var _bank: float = 0.0


func _ready() -> void:
	visible = false
	var mat: ShaderMaterial = material()
	_body = Node3D.new()
	add_child(_body)
	_add_mesh(_body, &"body", mat)
	for s: float in [-1.0, 1.0]:
		var key: String = "l" if s < 0.0 else "r"
		var wing: Node3D = Node3D.new()
		wing.position = Vector3(s * SHOULDER.x, SHOULDER.y, SHOULDER.z)
		_body.add_child(wing)
		_add_mesh(wing, StringName("inner_" + key), mat)
		var outer: Node3D = Node3D.new()
		outer.position = Vector3(s * WRIST.x, WRIST.y, WRIST.z)
		wing.add_child(outer)
		_add_mesh(outer, StringName("outer_" + key), mat)
		if s < 0.0:
			_wing_l = wing
			_outer_l = outer
		else:
			_wing_r = wing
			_outer_r = outer


## Starts the swoop-in.
func grab() -> void:
	if mode == Mode.CARRY:
		return
	mode = Mode.GRAB
	_time = 0.0
	visible = true
	scale = Vector3.ONE


## Lets go and flies away.
func release() -> void:
	if mode == Mode.HIDDEN or mode == Mode.RELEASE:
		return
	mode = Mode.RELEASE
	_time = 0.0


## Per-frame update. anchor = grip point (shoulders) in the parent's space, lean = lane lean.
func tick(delta: float, anchor: Vector3, lean: float) -> void:
	if mode == Mode.HIDDEN or _body == null:
		return
	_time += delta
	var offset: Vector3 = Vector3.ZERO
	var flap_rate: float = 1.0
	match mode:
		Mode.GRAB:
			var p: float = clampf(_time / GRAB_TIME, 0.0, 1.0)
			var e: float = 1.0 - pow(1.0 - p, 3.0)
			offset = SWOOP_FROM * (1.0 - e)
			flap_rate = 1.5
			if p >= 1.0:
				mode = Mode.CARRY
		Mode.RELEASE:
			var p: float = clampf(_time / RELEASE_TIME, 0.0, 1.0)
			offset = FLY_OFF * (p * p * (3.0 - 2.0 * p))
			flap_rate = 1.6
			scale = Vector3.ONE * lerpf(1.0, 0.55, smoothstep(0.5, 1.0, p))
			if p >= 1.0:
				mode = Mode.HIDDEN
				visible = false
				return
	_phase += delta * FLAP_SPEED * flap_rate
	_bank = lerpf(_bank, lean, 1.0 - exp(-delta * 8.0))
	position = anchor + offset
	rotation = Vector3(0.05 * sin(_phase) - 0.04, 0.0, _bank * 0.9)
	# Fast down-stroke, slower recovery; the outer wing lags behind and whips.
	var flap: float = 0.12 + 0.55 * sin(_phase) - 0.12 * sin(2.0 * _phase)
	var fold: float = 0.08 + 0.32 * sin(_phase - 0.9)
	_wing_r.rotation = Vector3(0.0, 0.0, flap)
	_wing_l.rotation = Vector3(0.0, 0.0, -flap)
	_outer_r.rotation = Vector3(0.0, 0.0, fold)
	_outer_l.rotation = Vector3(0.0, 0.0, -fold)
	_body.position.y = -0.03 * cos(_phase)


func _add_mesh(parent: Node3D, part: StringName, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh(part)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Shared material (palette: body, belly, membrane, legs, beak, eyes, crest, wing tips, claws).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = CavemanModel.SHADER
		_material.set_shader_parameter(&"palette", PackedColorArray([
				Color(0.72, 0.43, 0.25), Color(0.94, 0.82, 0.62), Color(0.88, 0.58, 0.40),
				Color(0.46, 0.29, 0.19), Color(0.97, 0.85, 0.55), Color(0.98, 0.97, 0.94),
				Color(0.08, 0.06, 0.05), Color(0.92, 0.26, 0.14), Color(0.56, 0.27, 0.16),
				Color(0.22, 0.18, 0.16), Color(0.3, 0.1, 0.08), Color(0.95, 0.6, 0.5)]))
		_material.set_shader_parameter(&"pattern_kind", 0)
		CavemanModel.apply_rim(_material)
	return _material


## Cached meshes: body, inner_l, inner_r, outer_l, outer_r.
static func mesh(part: StringName) -> ArrayMesh:
	if not _meshes.has(part):
		var built: ArrayMesh
		match part:
			&"body":
				built = _build_body()
			&"inner_l":
				built = _build_inner(-1.0)
			&"inner_r":
				built = _build_inner(1.0)
			&"outer_l":
				built = _build_outer(-1.0)
			_:
				built = _build_outer(1.0)
		_meshes[part] = built
	return _meshes[part] as ArrayMesh


## Triangle count of the whole pterosaur (budget check).
static func triangles() -> int:
	var total: int = 0
	for part: StringName in [&"body", &"inner_l", &"inner_r", &"outer_l", &"outer_r"]:
		var arrays: Array = mesh(part).surface_get_arrays(0)
		@warning_ignore("integer_division")
		total += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return total


static func _pts(values: Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for v: Variant in values:
		out.append(v as Vector3)
	return out


static func _radii(values: Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for v: Variant in values:
		out.append(float(v))
	return out


static func _build_body() -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	var b: Vector3 = Vector3(0.0, 0.74, -0.1)
	m.xf = Transform3D(Basis.IDENTITY, Vector3(0.0, LIFT, 0.0))
	# Torso with a pale belly.
	m.style(S.SKIN)
	m.slot_fn = func(p: Vector3, _u: float, _v: float) -> int:
		return S.FUR if p.y < b.y - 0.05 else -1
	m.ellipsoid(b, Vector3(0.14, 0.125, 0.3), 12, 8, Basis(Vector3.RIGHT, 0.12))
	# Neck, head, long beak, crest.
	m.style(S.SKIN)
	m.tube(_pts([b + Vector3(0.0, 0.04, -0.22), Vector3(0.0, 0.9, -0.48), Vector3(0.0, 0.96, -0.6)]),
			_radii([0.075, 0.058, 0.052]), 7, true, false)
	m.style(S.SKIN)
	m.ellipsoid(Vector3(0.0, 0.99, -0.66), Vector3(0.07, 0.075, 0.115), 10, 6)
	m.style(S.BONE, 1.0, 0.0, 0.3)
	m.tube(_pts([Vector3(0.0, 0.99, -0.72), Vector3(0.0, 0.965, -0.9), Vector3(0.0, 0.925, -1.1)]),
			_radii([0.05, 0.03, 0.008]), 6, false, true, Vector2(0.7, 1.0), Vector3.UP)
	m.style(S.BONE, 0.85, 0.0, 0.2)
	m.tube(_pts([Vector3(0.0, 0.95, -0.72), Vector3(0.0, 0.925, -0.88), Vector3(0.0, 0.905, -1.02)]),
			_radii([0.04, 0.024, 0.006]), 6, false, true, Vector2(0.65, 0.8), Vector3.UP)
	m.style(S.ACCENT, 1.0)
	m.tube(_pts([Vector3(0.0, 1.03, -0.62), Vector3(0.0, 1.12, -0.48), Vector3(0.0, 1.19, -0.3)]),
			_radii([0.06, 0.045, 0.012]), 6, true, true, Vector2(0.28, 1.0), Vector3.UP)
	for s: float in [-1.0, 1.0]:
		m.style(S.EYE_WHITE, 1.0, 0.0, 0.5)
		m.ellipsoid(Vector3(s * 0.056, 1.01, -0.69), Vector3(0.018, 0.026, 0.028), 6, 4)
		m.style(S.PUPIL, 1.0, 0.0, 1.0)
		m.ellipsoid(Vector3(s * 0.068, 1.01, -0.695), Vector3(0.01, 0.017, 0.017), 5, 3)
	# Tail.
	m.style(S.SKIN, 0.9)
	m.tube(_pts([b + Vector3(0.0, -0.02, 0.26), Vector3(0.0, 0.68, 0.45)]), _radii([0.05, 0.012]), 5)
	# Legs down to the caveman's shoulders, feet with claws gripping them.
	m.xf = Transform3D.IDENTITY
	for s: float in [-1.0, 1.0]:
		m.style(S.LEATHER)
		m.tube(_pts([Vector3(s * 0.07, 0.66 + LIFT, 0.06), Vector3(s * 0.17, 0.5, 0.14), Vector3(s * 0.2, 0.15, 0.04)]),
				_radii([0.045, 0.032, 0.026]), 6)
		m.style(S.LEATHER)
		m.ellipsoid(Vector3(s * 0.205, 0.12, 0.0), Vector3(0.04, 0.03, 0.06), 6, 4)
		for k: float in [-1.0, 0.0, 1.0]:
			m.style(S.STONE, 1.0, 0.0, 0.3)
			m.tube(_pts([Vector3(s * 0.205 + k * 0.022, 0.11, -0.045), Vector3(s * 0.205 + k * 0.03, 0.065, -0.07),
					Vector3(s * 0.205 + k * 0.03, 0.035, -0.05)]), _radii([0.013, 0.01, 0.003]), 4, false, true)
	return m.build()


static func _build_inner(side: float) -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	var lead: PackedVector3Array = _pts([Vector3.ZERO, Vector3(side * 0.42, 0.04, -0.06), Vector3(side * WRIST.x, WRIST.y, WRIST.z)])
	m.style(S.SKIN)
	m.tube(lead, _radii([0.045, 0.036, 0.03]), 6)
	m.style(S.HAIR, 1.0)
	m.ao_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return lerpf(0.8, 1.0, smoothstep(0.0, 0.3, v)) * lerpf(1.0, 0.88, v)
	m.sheet(func(u: float, v: float) -> Vector3:
		var l: Vector3 = _along(lead, u)
		var trail: Vector3 = Vector3(0.0, -0.1, 0.42).lerp(Vector3(side * 0.8, -0.01, 0.24), u)
		trail.z -= 0.06 * sin(u * PI)
		var p: Vector3 = l.lerp(trail, v)
		p.y -= 0.035 * sin(v * PI) * sin(u * PI)
		return p, 6, 3, 0.005)
	return m.build()


static func _build_outer(side: float) -> ArrayMesh:
	var m: CavemanMesh = CavemanMesh.new()
	var lead: PackedVector3Array = _pts([Vector3.ZERO, Vector3(side * 0.45, -0.01, 0.06), Vector3(side * 0.95, -0.04, 0.17)])
	m.style(S.SKIN)
	m.tube(lead, _radii([0.03, 0.022, 0.008]), 5, true, true)
	m.style(S.HAIR, 1.0)
	m.slot_fn = func(_p: Vector3, u: float, _v: float) -> int:
		return S.MARK if u > 0.72 else -1
	m.ao_fn = func(_p: Vector3, _u: float, v: float) -> float:
		return lerpf(1.0, 0.88, v)
	m.sheet(func(u: float, v: float) -> Vector3:
		var l: Vector3 = _along(lead, u)
		var trail: Vector3 = Vector3(side * -0.02, -0.02, 0.24).lerp(Vector3(side * 0.95, -0.04, 0.17), u)
		trail.z -= 0.05 * sin(u * PI)
		var p: Vector3 = l.lerp(trail, v)
		p.y -= 0.025 * sin(v * PI) * sin(u * PI)
		return p, 6, 3, 0.005)
	return m.build()


## Point at fraction t along a polyline (by segment count, good enough for 3 points).
static func _along(points: PackedVector3Array, t: float) -> Vector3:
	var segs: int = points.size() - 1
	var x: float = clampf(t, 0.0, 1.0) * float(segs)
	var i: int = mini(int(x), segs - 1)
	return points[i].lerp(points[i + 1], x - float(i))

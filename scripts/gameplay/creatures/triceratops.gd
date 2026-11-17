## Triceratops (the moving "train"). One skinned mesh (built once, shared) on a small procedural
## Skeleton3D rig. Three behaviours:
##   IDLE       standing, breathing, a lazy tail
##   TELEGRAPH  the warning before the charge: pawing the ground with a front foot, head shakes,
##              snorting dust (replaces the old blinking headlight)
##   CHARGE     heavy gallop synced to the ground speed, head low with the horns forward, dust kicks
## Faces -Z; the origin is on the ground under the hips. Pure visual.
class_name Triceratops
extends Node3D

enum Mode { IDLE, TELEGRAPH, CHARGE }

const BODY: Color = Color(0.76, 0.52, 0.30)
const SADDLE: Color = Color(0.6, 0.38, 0.2)
const BELLY: Color = Color(0.9, 0.79, 0.6)
const RUST: Color = Color(0.55, 0.24, 0.14)
const CREAM: Color = Color(0.95, 0.89, 0.72)
const IVORY: Color = Color(0.96, 0.92, 0.8)
const BEAK: Color = Color(0.25, 0.25, 0.27)
## Frill placement (centre, radii, tilt back from vertical).
const FRILL_CENTER: Vector3 = Vector3(0.0, 2.08, -1.28)
const FRILL_RADII: Vector3 = Vector3(1.02, 0.9, 0.1)
const FRILL_TILT: float = 0.72
## Nose-to-tail length of one animal (for stampede spacing).
const LENGTH: float = 4.9

enum B {
	ROOT, PELVIS, CHEST, NECK, HEAD, JAW, TAIL1, TAIL2,
	UP_FL, LO_FL, FT_FL, UP_FR, LO_FR, FT_FR,
	UP_HL, LO_HL, FT_HL, UP_HR, LO_HR, FT_HR,
}

const REST: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.55, 0.55), Vector3(0.0, 1.45, -0.7),
	Vector3(0.0, 1.45, -1.3), Vector3(0.0, 1.55, -1.55), Vector3(0.0, 1.24, -1.9),
	Vector3(0.0, 1.45, 1.3), Vector3(0.0, 1.15, 1.85),
	Vector3(-0.52, 1.3, -0.85), Vector3(-0.6, 0.65, -0.8), Vector3(-0.6, 0.14, -0.84),
	Vector3(0.52, 1.3, -0.85), Vector3(0.6, 0.65, -0.8), Vector3(0.6, 0.14, -0.84),
	Vector3(-0.52, 1.45, 0.62), Vector3(-0.58, 0.8, 0.42), Vector3(-0.58, 0.22, 0.62),
	Vector3(0.52, 1.45, 0.62), Vector3(0.58, 0.8, 0.42), Vector3(0.58, 0.22, 0.62),
]
const PARENT: Array[int] = [
	-1, B.ROOT, B.PELVIS, B.CHEST, B.NECK, B.HEAD, B.PELVIS, B.TAIL1,
	B.CHEST, B.UP_FL, B.LO_FL, B.CHEST, B.UP_FR, B.LO_FR,
	B.PELVIS, B.UP_HL, B.LO_HL, B.PELVIS, B.UP_HR, B.LO_HR,
]
## Gallop footfall offsets (front left, front right, hind left, hind right).
const GAIT_OFFSET: Array[float] = [0.0, 0.12, 0.52, 0.64]

static var _skin: Skin = null

var skeleton: Skeleton3D = null
var mesh_instance: MeshInstance3D = null
var dust: CreatureDust = null
## Ground velocity for dust (world space; the treadmill moves toward +Z).
var ground_drift: Vector3 = Vector3.ZERO

var _t: float = 0.0
var _cycle: float = 0.0
var _charge: float = 0.0
var _warn: float = 0.0
var _was_down: Array[bool] = [true, true, true, true]
var _paw_was_down: bool = true
var _next_snort: float = 0.5
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	skeleton = Skeleton3D.new()
	for i in range(REST.size()):
		var idx: int = skeleton.add_bone(String(B.keys()[i]).to_lower())
		var parent: int = PARENT[i]
		skeleton.set_bone_parent(idx, parent)
		skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, REST[i] - (REST[parent] if parent >= 0 else Vector3.ZERO)))
	skeleton.reset_bone_poses()
	add_child(skeleton)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = Triceratops.mesh()
	mesh_instance.material_override = CreatureMats.skin(&"trike")
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.extra_cull_margin = 3.0
	if _skin == null:
		_skin = skeleton.create_skin_from_rest_transforms()
	mesh_instance.skin = _skin
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	dust = CreatureDust.new(14)
	add_child(dust)
	_rng.seed = 991 + seed_value
	_cycle = _rng.randf()
	_t = _rng.randf() * 10.0


## Back to a calm stance (pool reuse).
func reset_pose() -> void:
	_charge = 0.0
	_warn = 0.0
	skeleton.reset_bone_poses()
	dust.clear()


## Advances the animation. ground_speed = the animal's own speed over the ground (m/s).
func animate(delta: float, mode: Mode, ground_speed: float) -> void:
	_t += delta
	_charge = MathUtils.damp(_charge, 1.0 if mode == Mode.CHARGE else 0.0, 0.18, delta)
	_warn = MathUtils.damp(_warn, 1.0 if mode == Mode.TELEGRAPH else 0.0, 0.2, delta)
	var calm: float = 1.0 - maxf(_charge, _warn)
	var freq: float = clampf(ground_speed / 2.7, 1.2, 3.4)
	_cycle = fposmod(_cycle + freq * delta * _charge, 1.0)
	var c: float = TAU * _cycle
	# Body: one big bounce and a rocking pitch per stride while galloping; crouched to charge.
	var bob: float = (0.5 + 0.5 * sin(c + 0.6)) * 0.16 * _charge - 0.08 * _warn
	var pitch: float = sin(c + 2.2) * 0.07 * _charge + 0.04 * _warn
	var breath: float = sin(_t * 1.7) * calm
	var pelvis_basis: Basis = Basis.from_euler(Vector3(pitch, sin(_t * 0.5) * 0.03 * calm, sin(c) * 0.03 * _charge))
	_pose(B.PELVIS, pelvis_basis, Vector3(0.0, bob + 0.015 * breath, 0.0))
	_pose(B.CHEST, Basis.from_euler(Vector3(-pitch * 0.4, 0.0, 0.0)))
	skeleton.set_bone_pose_scale(B.CHEST, Vector3(1.0 + 0.025 * breath, 1.0 + 0.02 * breath, 1.0))
	# Head: low with the horns forward when charging; shakes while telegraphing.
	var shake_env: float = maxf(sin(_t * 1.9), 0.0)
	var shake: float = sin(_t * 26.0) * 0.32 * shake_env * _warn
	var head_pitch: float = -0.3 * _charge - 0.22 * _warn + sin(_t * 0.8) * 0.06 * calm - pitch * 0.7
	_pose(B.NECK, Basis.from_euler(Vector3(-0.12 * _charge - 0.1 * _warn, shake * 0.4, 0.0)))
	_pose(B.HEAD, Basis.from_euler(Vector3(head_pitch, shake, shake * 0.3)), Vector3(0.0, -bob * 0.5, 0.0))
	var snort_open: float = 0.0
	if _warn > 0.5:
		_next_snort -= delta
		if _next_snort <= 0.0:
			_next_snort = _rng.randf_range(0.55, 0.9)
			_snort()
		snort_open = 0.15 * maxf(0.0, 1.0 - (_next_snort / 0.3))
	_pose(B.JAW, Basis(Vector3.RIGHT, -0.12 * _charge - snort_open - 0.04 * breath))
	# Tail: up and whipping in the charge, lazy otherwise.
	_pose(B.TAIL1, Basis.from_euler(Vector3(-0.2 * _charge, sin(c * 1.0) * 0.25 * _charge + sin(_t * 0.9) * 0.15 * calm, 0.0)))
	_pose(B.TAIL2, Basis.from_euler(Vector3(-0.1 * _charge, sin(c - 0.8) * 0.3 * _charge + sin(_t * 0.9 - 0.7) * 0.2 * calm, 0.0)))
	# Legs.
	for leg in range(4):
		var up_bone: int = [B.UP_FL, B.UP_FR, B.UP_HL, B.UP_HR][leg]
		var front: bool = leg < 2
		var lp: float = TAU * (_cycle - GAIT_OFFSET[leg])
		var s: float = sin(lp)
		var co: float = cos(lp)
		var swing: float = s * (0.62 if front else 0.55) * _charge
		var flex: float = maxf(co, 0.0) * (0.9 if front else 0.8) * _charge
		var down: bool = co < 0.0
		# Pawing: the front right foot scrapes the ground.
		if leg == 1 and _warn > 0.05:
			var pp: float = TAU * fposmod(_t * 1.5, 1.0)
			swing += (0.35 * sin(pp)) * _warn
			flex += maxf(cos(pp), 0.0) * 0.9 * _warn
			var paw_down: bool = cos(pp) < 0.0
			if paw_down and not _paw_was_down and is_inside_tree():
				dust.puff(skeleton.global_transform * (REST[B.FT_FR] + Vector3(0.0, 0.0, 0.25)),
						Vector3(0.0, 0.8, 1.2), 3, 0.8 * global_transform.basis.get_scale().x, 0.7, 1.0, 0.6)
			_paw_was_down = paw_down
		var lower: float = -flex if front else flex * 0.9
		_pose(up_bone, Basis(Vector3.RIGHT, swing - (pitch if front else 0.0) * 0.5))
		_pose(up_bone + 1, Basis(Vector3.RIGHT, lower))
		_pose(up_bone + 2, Basis(Vector3.RIGHT, -(swing + lower) * 0.7))
		if down and not _was_down[leg] and _charge > 0.5 and front and is_inside_tree():
			dust.puff(skeleton.global_transform * REST[up_bone + 2], Vector3(0.0, 0.7, 0.0), 2,
					1.0 * global_transform.basis.get_scale().x, 0.55, 1.4, 0.5)
		_was_down[leg] = down
	dust.drift = ground_drift
	dust.tick(delta)


func _snort() -> void:
	if not is_inside_tree():
		return
	var nose: Vector3 = skeleton.global_transform * (skeleton.get_bone_global_pose(B.HEAD) * Vector3(0.0, -0.15, -1.0))
	var fwd: Vector3 = global_transform.basis * Vector3(0.0, -0.3, -1.0)
	dust.puff(nose, fwd.normalized() * 2.2, 2, 0.55, 0.6, 0.4, 0.55)


func _pose(bone: int, basis: Basis, offset: Vector3 = Vector3.ZERO) -> void:
	var parent: int = PARENT[bone]
	skeleton.set_bone_pose_rotation(bone, basis.get_rotation_quaternion())
	skeleton.set_bone_pose_position(bone, REST[bone] - (REST[parent] if parent >= 0 else Vector3.ZERO) + offset)


# --- Mesh (built once, shared) -----------------------------------------------------------------

## The shared skinned Triceratops mesh.
static func mesh() -> ArrayMesh:
	return OrganicMesh.cached("trike", Triceratops._build_mesh) as ArrayMesh


static func _hide(p: Vector3, n: Vector3) -> Color:
	var c: Color = OrganicMesh.countershade(n.y, BODY, BELLY, -0.35, 0.35)
	var band: float = smoothstep(0.35, 0.7, sin(p.z * 3.4 + OrganicMesh.noise3(p, 0.8) * 1.4))
	c = c.lerp(SADDLE, band * smoothstep(0.0, 0.6, n.y) * 0.85)
	return c.darkened(0.06 * OrganicMesh.noise3(p, 4.0, 3.0))


static func _build_mesh() -> ArrayMesh:
	var om: OrganicMesh = OrganicMesh.new(true)
	om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		return Triceratops._hide(p, n)
	# Barrel body: tail tip -> hips -> belly -> shoulders -> neck.
	om.loft(PackedVector3Array([
			Vector3(0.0, 0.85, 2.3), Vector3(0.0, 1.12, 1.85), Vector3(0.0, 1.42, 1.3),
			Vector3(0.0, 1.62, 0.55), Vector3(0.0, 1.5, -0.2), Vector3(0.0, 1.45, -0.85),
			Vector3(0.0, 1.47, -1.38)]),
		PackedVector2Array([Vector2(0.06, 0.06), Vector2(0.2, 0.22), Vector2(0.42, 0.44),
			Vector2(0.86, 0.78), Vector2(0.96, 0.86), Vector2(0.82, 0.76), Vector2(0.54, 0.54)]),
		16, 4, {"cap1": OrganicMesh.CAP_NONE,
			"bones": PackedInt32Array([B.TAIL2, B.TAIL2, B.TAIL1, B.PELVIS, B.PELVIS, B.CHEST, B.NECK])})
	_build_head(om)
	_build_legs(om)
	return om.commit()


static func _build_head(om: OrganicMesh) -> void:
	om.bone = B.HEAD
	# Skull: deep, tapering to a hooked dark beak.
	om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		var c: Color = Triceratops._hide(p, n)
		return c.lerp(BEAK, smoothstep(-2.38, -2.52, p.z))
	om.loft(PackedVector3Array([Vector3(0.0, 1.62, -1.38), Vector3(0.0, 1.55, -1.85), Vector3(0.0, 1.38, -2.3),
			Vector3(0.0, 1.16, -2.62), Vector3(0.0, 1.0, -2.76)]),
		PackedVector2Array([Vector2(0.44, 0.46), Vector2(0.35, 0.4), Vector2(0.23, 0.27), Vector2(0.13, 0.15),
			Vector2(0.06, 0.07)]),
		16, 3, {"exps": PackedFloat32Array([2.3, 2.5, 2.5, 2.3, 2.0]), "cap_len1": 1.0})
	# Frill: tilted shield, rust pattern, cream rim, scalloped edge.
	var frill_basis: Basis = Basis(Vector3.RIGHT, FRILL_TILT)
	var inv: Basis = frill_basis.inverse()
	om.paint = func(p: Vector3, _n: Vector3, _u: float, _v: float) -> Color:
		var l: Vector3 = inv * (p - FRILL_CENTER)
		var r: float = Vector2(l.x / FRILL_RADII.x, l.y / FRILL_RADII.y).length()
		var ang: float = atan2(l.x, l.y)
		var c: Color = BODY.lerp(RUST, smoothstep(0.35, 0.55, r) * 0.85)
		# Radial rust rays and a ring of spots.
		c = c.lerp(RUST.darkened(0.2), smoothstep(0.55, 0.9, sin(ang * 7.0)) * smoothstep(0.25, 0.5, r) * 0.6)
		c = c.lerp(CREAM, smoothstep(0.62, 0.7, r) * (1.0 - smoothstep(0.72, 0.8, r)) * 0.8)
		return c.lerp(CREAM, smoothstep(0.82, 0.9, r))
	om.ellipsoid(FRILL_CENTER, FRILL_RADII, 8, 22, frill_basis)
	om.paint = Callable()
	om.color = CREAM
	for k in range(11):
		var a: float = lerpf(-1.75, 1.75, float(k) / 10.0)
		var edge: Vector3 = FRILL_CENTER + frill_basis * Vector3(sin(a) * FRILL_RADII.x * 0.97, cos(a) * FRILL_RADII.y * 0.97, 0.0)
		om.ellipsoid(edge, Vector3(0.1, 0.1, 0.07), 3, 6, frill_basis)
	# Horns: two long brow horns forward-up, a short nose horn.
	om.color = IVORY
	om.mask2 = Vector2(0.0, 0.6)
	for side: float in [-1.0, 1.0]:
		om.horn(Vector3(side * 0.24, 1.78, -1.82), Vector3(side * 0.34, 2.12, -2.72), 0.12,
				Vector3(0.0, 0.12, 0.05), 7, 3)
	om.horn(Vector3(0.0, 1.5, -2.28), Vector3(0.0, 1.8, -2.48), 0.085, Vector3(0.0, 0.0, 0.04), 6, 2)
	om.mask2 = Vector2.ZERO
	# Lower beak (snorts / opens).
	om.bone = B.JAW
	om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		return OrganicMesh.countershade(n.y, BODY, BELLY, 0.2, 0.3).lerp(BEAK, smoothstep(-2.2, -2.4, p.z))
	om.loft(PackedVector3Array([Vector3(0.0, 1.22, -1.8), Vector3(0.0, 1.1, -2.2), Vector3(0.0, 0.98, -2.55)]),
		PackedVector2Array([Vector2(0.28, 0.14), Vector2(0.18, 0.1), Vector2(0.08, 0.06)]), 12, 2,
		{"exps": PackedFloat32Array([2.4, 2.4, 2.2]), "cap_len1": 1.2})
	# Eyes with a heavy brow.
	om.bone = B.HEAD
	om.paint = Callable()
	for side: float in [-1.0, 1.0]:
		var eye: Vector3 = Vector3(side * 0.33, 1.7, -1.86)
		om.mask2 = Vector2(1.0, 1.0)
		om.color = Color(0.1, 0.06, 0.03)
		om.ellipsoid(eye, Vector3(0.075, 0.075, 0.075), 5, 8)
		om.color = Color(1.0, 1.0, 0.95)
		om.ellipsoid(eye + Vector3(side * 0.06, 0.03, -0.035), Vector3(0.018, 0.018, 0.012), 3, 5)
		om.mask2 = Vector2.ZERO
		om.color = SADDLE
		om.ellipsoid(eye + Vector3(-side * 0.02, 0.08, 0.0), Vector3(0.1, 0.045, 0.13), 4, 7)
		om.color = Color(0.2, 0.14, 0.1)
		om.ellipsoid(Vector3(side * 0.08, 1.32, -2.42), Vector3(0.035, 0.03, 0.045), 3, 5)


static func _build_legs(om: OrganicMesh) -> void:
	for leg in range(4):
		var up_bone: int = [B.UP_FL, B.UP_FR, B.UP_HL, B.UP_HR][leg]
		var front: bool = leg < 2
		var s: float = -1.0 if leg % 2 == 0 else 1.0
		om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
			return Triceratops._hide(p, n).darkened(smoothstep(0.7, 0.0, p.y) * 0.2)
		var top: Vector3 = REST[up_bone] + Vector3(-s * 0.06, 0.25, 0.0)
		var joint: Vector3 = REST[up_bone + 1]
		var foot: Vector3 = REST[up_bone + 2]
		var r0: float = 0.45 if front else 0.54
		om.loft(PackedVector3Array([top, REST[up_bone].lerp(joint, 0.5), joint, foot, Vector3(foot.x, 0.0, foot.z)]),
			PackedVector2Array([Vector2(r0, r0), Vector2(r0 * 0.78, r0 * 0.84), Vector2(0.26, 0.28),
				Vector2(0.24, 0.24), Vector2(0.3, 0.3)]),
			12, 2, {"cap0": OrganicMesh.CAP_NONE, "cap1": OrganicMesh.CAP_FLAT, "up": Vector3.FORWARD,
				"bones": PackedInt32Array([up_bone, up_bone, up_bone + 1, up_bone + 2, up_bone + 2])})
		om.paint = Callable()
		om.color = CREAM
		om.bone = up_bone + 2
		for k in range(3):
			var a: float = (float(k) - 1.0) * 0.6
			om.ellipsoid(Vector3(foot.x + sin(a) * 0.22, 0.07, foot.z - cos(a) * 0.22), Vector3(0.07, 0.07, 0.055), 3, 6)

## Tyrannosaurus (the chaser). One skinned mesh (OrganicMesh lofts, built once and shared) on a
## procedural Skeleton3D rig: digitigrade legs solved with 2-bone IK so the feet plant at the
## ground speed, heavy body bob with a stabilised head, travelling-wave tail, hinged jaw.
## Faces -Z; the origin is on the ground under the hips. Pure visual: it never touches gameplay.
##
## Drive it every frame with animate(delta) after setting ground_speed / hunt / lunge;
## one-shots: roar(), snap().
class_name TRex
extends Node3D

const BACK: Color = Color(0.40, 0.38, 0.20)
const STRIPE: Color = Color(0.25, 0.22, 0.12)
const BELLY: Color = Color(0.85, 0.78, 0.58)
const MOUTH: Color = Color(0.72, 0.30, 0.30)
const TOOTH: Color = Color(0.96, 0.93, 0.82)
const CLAW: Color = Color(0.86, 0.82, 0.70)
const EYE: Color = Color(1.0, 0.55, 0.08)
const ROAR_TIME: float = 1.7
const SNAP_TIME: float = 0.34

enum B {
	ROOT, PELVIS, CHEST, NECK, HEAD, JAW, TAIL1, TAIL2, TAIL3, TAIL4,
	THIGH_L, SHIN_L, META_L, TOE_L, THIGH_R, SHIN_R, META_R, TOE_R,
	ARM_L, FOREARM_L, ARM_R, FOREARM_R,
}

## Global rest position of every joint (model space).
const REST: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0), Vector3(0.0, 2.9, 0.4), Vector3(0.0, 3.05, -1.3),
	Vector3(0.0, 3.4, -2.25), Vector3(0.0, 3.95, -2.9), Vector3(0.0, 3.62, -2.95),
	Vector3(0.0, 2.95, 1.6), Vector3(0.0, 2.8, 3.0), Vector3(0.0, 2.6, 4.3), Vector3(0.0, 2.35, 5.5),
	Vector3(-0.66, 2.75, 0.45), Vector3(-0.72, 1.6, -0.3), Vector3(-0.7, 0.58, 0.32), Vector3(-0.7, 0.14, 0.02),
	Vector3(0.66, 2.75, 0.45), Vector3(0.72, 1.6, -0.3), Vector3(0.7, 0.58, 0.32), Vector3(0.7, 0.14, 0.02),
	Vector3(-0.58, 2.85, -1.85), Vector3(-0.7, 2.5, -2.05), Vector3(0.58, 2.85, -1.85), Vector3(0.7, 2.5, -2.05),
]
const PARENT: Array[int] = [
	-1, B.ROOT, B.PELVIS, B.CHEST, B.NECK, B.HEAD, B.PELVIS, B.TAIL1, B.TAIL2, B.TAIL3,
	B.PELVIS, B.THIGH_L, B.SHIN_L, B.META_L, B.PELVIS, B.THIGH_R, B.SHIN_R, B.META_R,
	B.CHEST, B.ARM_L, B.CHEST, B.ARM_R,
]

static var _skin: Skin = null

## Ground speed in m/s: the stride (and the planted feet) follow it.
var ground_speed: float = 0.0
## 0 = proud stance (menu), 1 = head low, hunting (chase).
var hunt: float = 0.0
## 0..1: jaws wide, head thrust forward (the catch).
var lunge: float = 0.0
## Snap the jaws now and then while hunting.
var auto_snap: bool = false
## Ground velocity for the footstep dust (world space; the treadmill moves toward +Z).
var ground_drift: Vector3 = Vector3.ZERO
## Head yaw (radians, + = toward -X / its left) for looking around.
var look_yaw: float = 0.0
## 0..1: keep the idle head play (tilts, sniffs, looking around) even while walking (menu).
var showcase: float = 0.0

var skeleton: Skeleton3D = null
var mesh_instance: MeshInstance3D = null
var dust: CreatureDust = null

var _t: float = 0.0
var _cycle: float = 0.0
var _gait: float = 0.0
var _hunt: float = 0.0
var _lunge: float = 0.0
var _roar_t: float = -1.0
var _snap_t: float = -1.0
var _next_snap: float = 1.0
var _was_stance: Array[bool] = [true, true]
var _len: Array[float] = []
var _rest_phi: Array[float] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	skeleton = Skeleton3D.new()
	for i in range(REST.size()):
		var idx: int = skeleton.add_bone(String(B.keys()[i]).to_lower())
		var parent: int = PARENT[i]
		skeleton.set_bone_parent(idx, parent)
		var local: Vector3 = REST[i] - (REST[parent] if parent >= 0 else Vector3.ZERO)
		skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, local))
	skeleton.reset_bone_poses()
	add_child(skeleton)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = TRex.mesh()
	mesh_instance.material_override = CreatureMats.skin(&"trex")
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.extra_cull_margin = 4.0
	if _skin == null:
		_skin = skeleton.create_skin_from_rest_transforms()
	mesh_instance.skin = _skin
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	dust = CreatureDust.new(18)
	add_child(dust)
	for side: int in [0, 1]:
		var thigh: int = B.THIGH_L if side == 0 else B.THIGH_R
		_len.append(REST[thigh].distance_to(REST[thigh + 1]))
		_len.append(REST[thigh + 1].distance_to(REST[thigh + 2]))
		_len.append(REST[thigh + 2].distance_to(REST[thigh + 3]))
	for b: int in [B.THIGH_L, B.SHIN_L, B.META_L]:
		_rest_phi.append(_phi(REST[b + 1] - REST[b]))
	_rng.seed = 77


## Starts a roar (head up, jaws wide). Returns false while one is already playing.
func roar() -> bool:
	if _roar_t >= 0.0 and _roar_t < ROAR_TIME * 0.8:
		return false
	_roar_t = 0.0
	return true


## True while a roar is playing.
func is_roaring() -> bool:
	return _roar_t >= 0.0 and _roar_t < ROAR_TIME


## Snaps the jaws once.
func snap() -> void:
	_snap_t = 0.0


## Puts every bone back to the rest pose and stops one-shots (pool / state reset).
func reset_pose() -> void:
	_roar_t = -1.0
	_snap_t = -1.0
	_lunge = lunge
	_hunt = hunt
	skeleton.reset_bone_poses()
	dust.clear()


## Advances the procedural animation.
func animate(delta: float) -> void:
	_t += delta
	_hunt = MathUtils.damp(_hunt, hunt, 0.35, delta)
	_lunge = MathUtils.damp(_lunge, lunge, 0.12, delta)
	_gait = MathUtils.damp(_gait, clampf(ground_speed / 3.0, 0.0, 1.0), 0.3, delta)
	var run: float = clampf((ground_speed - 4.0) / 8.0, 0.0, 1.0)
	var duty: float = lerpf(0.62, 0.42, run)
	var stride: float = lerpf(4.0, 6.5, run)
	var freq: float = clampf(ground_speed / stride, 0.5, 2.8) if ground_speed > 0.2 else 0.5 * _gait
	_cycle = fposmod(_cycle + freq * delta, 1.0)
	var stance_len: float = minf(ground_speed * duty / maxf(freq, 0.05), 3.3) * _gait
	# One-shots.
	var roar_k: float = 0.0
	if _roar_t >= 0.0:
		_roar_t += delta
		roar_k = smoothstep(0.0, 0.3, _roar_t) * (1.0 - smoothstep(ROAR_TIME - 0.45, ROAR_TIME, _roar_t))
		if _roar_t >= ROAR_TIME:
			_roar_t = -1.0
	var snap_k: float = 0.0
	if _snap_t >= 0.0:
		_snap_t += delta
		snap_k = smoothstep(0.0, 0.16, _snap_t) * (1.0 - smoothstep(0.2, SNAP_TIME, _snap_t))
		if _snap_t >= SNAP_TIME:
			_snap_t = -1.0
	if auto_snap and _snap_t < 0.0 and _roar_t < 0.0:
		_next_snap -= delta
		if _next_snap <= 0.0:
			snap()
			_next_snap = _rng.randf_range(0.7, 1.6)
	var idle: float = 1.0 - _gait
	var play: float = maxf(idle, showcase)
	# --- Body -----------------------------------------------------------------------------
	var bob: float = -cos(TAU * 2.0 * (_cycle - duty * 0.5)) * lerpf(0.05, 0.11, run) * _gait
	var breath: float = sin(_t * 1.6) * idle
	var pelvis_pos: Vector3 = Vector3(0.0, bob - 0.22 * _hunt - 0.12 * _lunge + 0.03 * breath, 0.0)
	pelvis_pos.x = sin(TAU * (_cycle - duty * 0.5)) * 0.05 * _gait
	var pitch: float = -0.07 * _hunt - 0.05 * run * _gait + 0.13 * roar_k - 0.08 * _lunge
	var roll: float = sin(TAU * (_cycle - duty * 0.5)) * 0.04 * _gait
	var yaw: float = sin(TAU * _cycle) * 0.035 * _gait + sin(_t * 0.37) * 0.05 * idle
	var pelvis_basis: Basis = Basis.from_euler(Vector3(pitch, yaw, roll))
	_pose(B.PELVIS, pelvis_basis, pelvis_pos)
	var chest_basis: Basis = Basis.from_euler(Vector3(0.05 * roar_k - 0.04 * _hunt, -yaw * 0.6, -roll * 0.5))
	_pose(B.CHEST, chest_basis)
	skeleton.set_bone_pose_scale(B.CHEST, Vector3(1.0 + 0.025 * breath, 1.0 + 0.02 * breath, 1.0))
	# --- Neck and head: lowered while hunting, raised for the roar, steady while running ---
	var sniff: float = 0.0
	var sniff_cycle: float = fposmod(_t, 5.3)
	if sniff_cycle < 0.9:
		sniff = sin(sniff_cycle * TAU * 3.3) * 0.06 * play
	var tilt: float = sin(_t * 0.55) * 0.12 * play + sin(_t * 0.23 + 1.0) * 0.06 * play
	var neck_pitch: float = -0.38 * _hunt + 0.35 * roar_k - 0.12 * _lunge - pitch * 0.5
	var head_pitch: float = 0.22 * _hunt + 0.32 * roar_k - 0.15 * _lunge - pitch * 0.5 + sniff \
			+ 0.12 * snap_k - bob * 0.6
	var neck_yaw: float = look_yaw * 0.5 + sin(_t * 0.31) * 0.14 * play
	var shake: float = sin(_t * 47.0) * 0.035 * roar_k
	_pose(B.NECK, Basis.from_euler(Vector3(neck_pitch, neck_yaw - yaw * 0.5, 0.0)))
	_pose(B.HEAD, Basis.from_euler(Vector3(head_pitch, look_yaw * 0.5 + shake, tilt)),
			Vector3(0.0, -bob * 0.8, -0.35 * _lunge - 0.12 * snap_k))
	var jaw_open: float = 0.06 * run * _gait + 0.9 * roar_k + 0.8 * snap_k + 0.95 * _lunge
	jaw_open = clampf(jaw_open, 0.0, 1.0)
	_pose(B.JAW, Basis(Vector3.RIGHT, -0.85 * jaw_open))
	# --- Tail: travelling wave, lifted for the roar --------------------------------------------
	for k in range(4):
		var amp: float = (0.05 + 0.04 * float(k)) * (_gait + 0.8 * idle)
		var wave: float = sin(TAU * _cycle - float(k) * 0.7) if _gait > 0.1 else sin(_t * 0.9 - float(k) * 0.8)
		var lift: float = -0.06 * roar_k + 0.03 * sin(TAU * 2.0 * _cycle - float(k) * 0.6) * _gait
		_pose(B.TAIL1 + k, Basis.from_euler(Vector3(lift + 0.04 * _hunt, wave * amp - yaw * 0.3, 0.0)))
	# --- Arms: tiny, but they wave ------------------------------------------------------------
	for side: int in [0, 1]:
		var s: float = -1.0 if side == 0 else 1.0
		var arm: int = B.ARM_L if side == 0 else B.ARM_R
		var swing: float = sin(TAU * _cycle + float(side) * PI) * 0.25 * _gait
		_pose(arm, Basis.from_euler(Vector3(swing - 0.5 * roar_k + 0.2 * breath * 0.2, 0.0, s * 0.25 * roar_k)))
		_pose(arm + 1, Basis(Vector3.RIGHT, -0.4 - 0.5 * roar_k + 0.15 * sin(_t * 2.0 + s)))
	# --- Legs: IK to feet planted at the ground speed ------------------------------------------
	for side: int in [0, 1]:
		var p: float = fposmod(_cycle + 0.5 * float(side), 1.0)
		var thigh: int = B.THIGH_L if side == 0 else B.THIGH_R
		var rest_ball: Vector3 = REST[thigh + 3]
		var foot: Vector3 = rest_ball
		var meta_angle: float = 0.55
		var toe_angle: float = 0.0
		var stance: bool = p < duty
		var z_mid: float = rest_ball.z - 0.15 * _gait
		if stance:
			var s_t: float = p / duty
			foot.z = z_mid + stance_len * (s_t - 0.5)
			meta_angle = lerpf(0.5, 0.95, smoothstep(0.55, 1.0, s_t) * _gait)
		else:
			var w: float = (p - duty) / (1.0 - duty)
			var e: float = w * w * (3.0 - 2.0 * w)
			foot.z = z_mid + stance_len * (0.5 - e)
			foot.y += sin(PI * w) * lerpf(0.45, 0.8, run) * _gait
			meta_angle = lerpf(0.55, 1.25, sin(PI * w) * _gait)
			toe_angle = -0.7 * sin(PI * w) * _gait
		foot.y -= 0.22 * _hunt + 0.12 * _lunge
		foot.y = maxf(foot.y, 0.14)
		foot.x = rest_ball.x
		_solve_leg(side, foot, meta_angle, toe_angle, pelvis_basis, REST[B.PELVIS] + pelvis_pos)
		if stance and not _was_stance[side] and _gait > 0.4 and is_inside_tree():
			dust.puff(skeleton.global_transform * (foot + Vector3(0.0, -0.1, -0.2)),
					Vector3(0.0, 0.6, 0.0), 3, 1.1 * global_transform.basis.get_scale().x, 0.6, 1.3, 0.5)
		_was_stance[side] = stance
	dust.drift = ground_drift
	dust.tick(delta)


func _pose(bone: int, basis: Basis, offset: Vector3 = Vector3.ZERO) -> void:
	var parent: int = PARENT[bone]
	skeleton.set_bone_pose_rotation(bone, basis.get_rotation_quaternion())
	skeleton.set_bone_pose_position(bone, REST[bone] - (REST[parent] if parent >= 0 else Vector3.ZERO) + offset)


## Angle of a vector in the YZ plane, measured from +Y toward +Z (rotation about +X adds to it).
static func _phi(v: Vector3) -> float:
	return atan2(v.z, v.y)


## Two-bone IK (thigh, shin) to the ankle, metatarsus at `meta_angle` (from vertical, leaning
## back), toes rotated by `toe_angle` (global). Planar in YZ: the knee points forward (-Z).
func _solve_leg(side: int, foot: Vector3, meta_angle: float, toe_angle: float, pelvis_basis: Basis,
		pelvis_origin: Vector3) -> void:
	var thigh: int = B.THIGH_L if side == 0 else B.THIGH_R
	var l1: float = _len[side * 3]
	var l2: float = _len[side * 3 + 1]
	var l3: float = _len[side * 3 + 2]
	var hip: Vector3 = pelvis_origin + pelvis_basis * (REST[thigh] - REST[B.PELVIS])
	var ankle: Vector3 = foot + Vector3(0.0, cos(meta_angle), sin(meta_angle)) * l3
	var d: Vector2 = Vector2(ankle.z - hip.z, ankle.y - hip.y)
	var dist: float = clampf(d.length(), absf(l1 - l2) + 0.02, l1 + l2 - 0.01)
	var a1: float = acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var phi_t: float = atan2(d.x, d.y) + a1
	var knee: Vector3 = Vector3(hip.x, hip.y + cos(phi_t) * l1, hip.z + sin(phi_t) * l1)
	var dir_s: Vector3 = (hip + Vector3(0.0, d.y, d.x).normalized() * dist) - knee
	var dt: float = wrapf(phi_t - _rest_phi[0], -PI, PI)
	var ds: float = wrapf(_phi(dir_s) - _rest_phi[1], -PI, PI)
	var dm: float = wrapf(_phi(foot - ankle) - _rest_phi[2], -PI, PI)
	skeleton.set_bone_pose_rotation(thigh, (pelvis_basis.inverse() * Basis(Vector3.RIGHT, dt)).get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(thigh + 1, Quaternion(Vector3.RIGHT, ds - dt))
	skeleton.set_bone_pose_rotation(thigh + 2, Quaternion(Vector3.RIGHT, dm - ds))
	skeleton.set_bone_pose_rotation(thigh + 3, Quaternion(Vector3.RIGHT, toe_angle - dm))


# --- Mesh (built once, shared by every instance) ---------------------------------------------

## The shared skinned T-Rex mesh.
static func mesh() -> ArrayMesh:
	return OrganicMesh.cached("trex", TRex._build_mesh) as ArrayMesh


## Olive back with bold dark bands, cream belly, a little mottling.
static func _skin_color(p: Vector3, n: Vector3, line: float, band_freq: float, stripes: float) -> Color:
	var c: Color = OrganicMesh.countershade(n.y, BACK, BELLY, line, 0.3)
	var band: float = sin(p.z * band_freq + OrganicMesh.noise3(p, 0.7) * 1.6)
	var top: float = smoothstep(-0.25, 0.35, n.y)
	c = c.lerp(STRIPE, smoothstep(0.25, 0.55, band) * top * stripes)
	return c.darkened(0.08 * OrganicMesh.noise3(p, 3.5, 2.0))


static func _build_mesh() -> ArrayMesh:
	var om: OrganicMesh = OrganicMesh.new(true)
	om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		return TRex._skin_color(p, n, -0.3, 3.6, 1.0)
	# Body: tail tip -> hips -> big belly -> chest -> thick neck, skinned along the spine.
	om.loft(PackedVector3Array([
			Vector3(0.0, 2.05, 6.9), Vector3(0.0, 2.38, 5.7), Vector3(0.0, 2.64, 4.4),
			Vector3(0.0, 2.86, 3.0), Vector3(0.0, 3.03, 1.65), Vector3(0.0, 3.1, 0.45),
			Vector3(0.0, 3.0, -0.55), Vector3(0.0, 3.1, -1.45), Vector3(0.0, 3.38, -2.2),
			Vector3(0.0, 3.68, -2.62), Vector3(0.0, 3.92, -2.92)]),
		PackedVector2Array([
			Vector2(0.06, 0.06), Vector2(0.17, 0.2), Vector2(0.3, 0.35), Vector2(0.46, 0.54),
			Vector2(0.64, 0.72), Vector2(0.82, 0.9), Vector2(0.9, 1.04), Vector2(0.8, 0.98),
			Vector2(0.62, 0.74), Vector2(0.54, 0.62), Vector2(0.5, 0.56)]),
		16, 4, {"cap1": OrganicMesh.CAP_NONE,
			"bones": PackedInt32Array([B.TAIL4, B.TAIL4, B.TAIL3, B.TAIL2, B.TAIL1, B.PELVIS,
					B.PELVIS, B.CHEST, B.CHEST, B.NECK, B.HEAD])})
	_build_head(om)
	_build_arms(om)
	_build_legs(om)
	return om.commit()


## Skull spine samples (z, centre y, rx, ry) used to seat the teeth on the lip line.
const SKULL: Array[Vector4] = [
	Vector4(-2.78, 4.06, 0.5, 0.52), Vector4(-3.2, 4.12, 0.53, 0.56), Vector4(-3.75, 4.0, 0.42, 0.47),
	Vector4(-4.25, 3.87, 0.33, 0.38), Vector4(-4.62, 3.78, 0.26, 0.3),
]


static func _skull_at(z: float) -> Vector4:
	for i in range(SKULL.size() - 1):
		var a: Vector4 = SKULL[i]
		var b: Vector4 = SKULL[i + 1]
		if z <= a.x and z >= b.x:
			return a.lerp(b, (a.x - z) / (a.x - b.x))
	return SKULL[SKULL.size() - 1]


static func _build_head(om: OrganicMesh) -> void:
	# Skull (upper jaw): massive, deep and boxy, wide cheeks, pink palate underneath.
	om.bone = B.HEAD
	om.paint = func(p: Vector3, n: Vector3, u: float, v: float) -> Color:
		var c: Color = TRex._skin_color(p, n, -0.5, 4.6, 0.75)
		var palate: float = (1.0 - smoothstep(0.07, 0.11, absf(u - 0.5))) * smoothstep(0.12, 0.25, v)
		return c.lerp(MOUTH, palate)
	var pts: PackedVector3Array = PackedVector3Array()
	var radii: PackedVector2Array = PackedVector2Array()
	for k: Vector4 in SKULL:
		pts.append(Vector3(0.0, k.y, k.x))
		radii.append(Vector2(k.z, k.w))
	om.loft(pts, radii, 18, 3, {"exps": PackedFloat32Array([2.5, 2.7, 2.8, 2.8, 2.6]),
			"cap0": OrganicMesh.CAP_ROUND, "cap_len0": 0.6, "cap_len1": 0.75})
	# Lower jaw: deep, hinged at the cheek, pink tongue on top.
	om.bone = B.JAW
	om.paint = func(p: Vector3, n: Vector3, u: float, _v: float) -> Color:
		var c: Color = OrganicMesh.countershade(n.y, BACK, BELLY, 0.15, 0.3)
		c = c.darkened(0.06 * OrganicMesh.noise3(p, 3.5, 2.0))
		return c.lerp(MOUTH, 1.0 - smoothstep(0.1, 0.15, minf(u, 1.0 - u)))
	om.loft(PackedVector3Array([
			Vector3(0.0, 3.56, -2.9), Vector3(0.0, 3.43, -3.48), Vector3(0.0, 3.38, -4.05),
			Vector3(0.0, 3.43, -4.52)]),
		PackedVector2Array([Vector2(0.46, 0.27), Vector2(0.38, 0.26), Vector2(0.29, 0.21),
			Vector2(0.22, 0.15)]),
		16, 3, {"exps": PackedFloat32Array([2.6, 2.7, 2.7, 2.4]), "cap_len1": 0.9})
	# Teeth: the upper row hangs over the lower jaw (the classic grin), the lower row points up.
	om.paint = Callable()
	om.color = TOOTH
	om.mask2 = Vector2(0.0, 0.6)
	om.bone = B.HEAD
	for side: float in [-1.0, 1.0]:
		for i in range(7):
			var f: float = float(i) / 6.0
			var z: float = lerpf(-3.3, -4.5, f)
			var k: Vector4 = _skull_at(z)
			var x: float = k.z * 0.84
			var lip: float = k.y - k.w * 0.82
			var size: float = lerpf(0.062, 0.042, f) * (1.0 + 0.25 * sin(float(i) * 2.7))
			om.horn(Vector3(side * x, lip + 0.08, z), Vector3(side * (x - 0.015), lip - size * 2.6, z - 0.015),
					size, Vector3.ZERO, 4, 1)
	om.bone = B.JAW
	for side: float in [-1.0, 1.0]:
		for i in range(5):
			var f: float = float(i) / 4.0
			var z: float = lerpf(-3.45, -4.35, f)
			var half_w: float = lerpf(0.3, 0.18, f)
			var top: float = lerpf(3.62, 3.55, f)
			var size: float = lerpf(0.046, 0.034, f)
			om.horn(Vector3(side * half_w, top - 0.06, z), Vector3(side * half_w, top + size * 2.2, z + 0.01),
					size, Vector3.ZERO, 4, 1)
	# Eyes: big orange iris, slit pupil, white glint, heavy brow ridge (the scowl).
	om.bone = B.HEAD
	for side: float in [-1.0, 1.0]:
		var eye_pos: Vector3 = Vector3(side * 0.44, 4.3, -3.28)
		var out: Vector3 = Vector3(side, 0.2, -0.5).normalized()
		om.mask2 = Vector2(1.0, 1.0)
		om.color = EYE
		om.ellipsoid(eye_pos, Vector3(0.125, 0.12, 0.125), 7, 10)
		om.color = Color(0.04, 0.03, 0.02)
		om.ellipsoid(eye_pos + out * 0.108, Vector3(0.03, 0.095, 0.035), 4, 6, _facing(out))
		om.color = Color(1.0, 1.0, 0.95)
		om.ellipsoid(eye_pos + out * 0.115 + Vector3(0.0, 0.05, -0.04), Vector3(0.024, 0.024, 0.014), 3, 5,
				_facing(out))
		om.mask2 = Vector2.ZERO
		om.color = STRIPE
		om.ellipsoid(Vector3(side * 0.38, 4.47, -3.24), Vector3(0.17, 0.085, 0.27), 5, 9,
				Basis.from_euler(Vector3(0.3, side * -0.3, side * -0.4)))
		# Lacrimal hornlet behind the brow.
		om.ellipsoid(Vector3(side * 0.34, 4.55, -2.98), Vector3(0.1, 0.09, 0.12), 4, 7)
		# Nostril.
		om.color = Color(0.12, 0.1, 0.06)
		om.ellipsoid(Vector3(side * 0.13, 4.02, -4.5), Vector3(0.05, 0.03, 0.06), 3, 6)
	om.mask2 = Vector2.ZERO


static func _build_arms(om: OrganicMesh) -> void:
	for side: int in [0, 1]:
		var s: float = -1.0 if side == 0 else 1.0
		var arm: int = B.ARM_L if side == 0 else B.ARM_R
		om.paint = func(_p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
			return OrganicMesh.countershade(n.y, BACK, BELLY, -0.2, 0.35)
		om.bone = arm
		om.limb(PackedVector3Array([Vector3(s * 0.45, 2.95, -1.75), REST[arm], REST[arm + 1]]),
				PackedFloat32Array([0.19, 0.15, 0.11]), 8, 2, {"cap0": OrganicMesh.CAP_NONE})
		om.bone = arm + 1
		var wrist: Vector3 = Vector3(s * 0.68, 2.4, -2.44)
		om.limb(PackedVector3Array([REST[arm + 1], wrist]), PackedFloat32Array([0.1, 0.075]), 8, 2)
		om.paint = Callable()
		om.color = CLAW
		om.mask2 = Vector2(0.0, 0.4)
		for f: float in [-1.0, 1.0]:
			om.horn(wrist + Vector3(f * 0.035, -0.02, -0.03), wrist + Vector3(f * 0.06, -0.19, -0.12),
					0.032, Vector3(0.0, 0.0, -0.035), 4, 1)
		om.mask2 = Vector2.ZERO


static func _build_legs(om: OrganicMesh) -> void:
	for side: int in [0, 1]:
		var s: float = -1.0 if side == 0 else 1.0
		var t: int = B.THIGH_L if side == 0 else B.THIGH_R
		var leg_paint: Callable = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
			var c: Color = TRex._skin_color(p, n, -0.4, 3.6, smoothstep(1.4, 2.4, p.y))
			return c.darkened(smoothstep(1.0, 0.0, p.y) * 0.22)
		om.paint = leg_paint
		# Massive drumstick thigh -> knee -> shin -> ankle -> metatarsus -> ball of the foot.
		om.loft(PackedVector3Array([
				Vector3(s * 0.5, 3.02, 0.55), Vector3(s * 0.72, 2.3, 0.15), REST[t + 1] + Vector3(0.0, 0.04, -0.03),
				Vector3(s * 0.71, 1.08, 0.04), REST[t + 2], Vector3(s * 0.7, 0.34, 0.17), REST[t + 3]]),
			PackedVector2Array([Vector2(0.54, 0.64), Vector2(0.52, 0.62), Vector2(0.31, 0.33),
				Vector2(0.23, 0.25), Vector2(0.18, 0.18), Vector2(0.16, 0.16), Vector2(0.17, 0.15)]),
			12, 3, {"cap0": OrganicMesh.CAP_NONE, "up": Vector3.FORWARD,
				"bones": PackedInt32Array([t, t, t + 1, t + 1, t + 2, t + 2, t + 3])})
		# Three forward toes with claws.
		om.bone = t + 3
		var ball: Vector3 = REST[t + 3]
		for k in range(3):
			var spread: float = float(k - 1)
			var tip: Vector3 = ball + Vector3(s * 0.02 + spread * 0.22, -0.05, -0.6 + absf(spread) * 0.13)
			om.paint = leg_paint
			om.limb(PackedVector3Array([ball + Vector3(spread * 0.07, 0.0, 0.02), ball.lerp(tip, 0.55) + Vector3(0.0, 0.025, 0.0), tip]),
					PackedFloat32Array([0.12, 0.095, 0.07]), 8, 2, {"cap0": OrganicMesh.CAP_NONE})
			om.paint = Callable()
			om.color = CLAW
			om.mask2 = Vector2(0.0, 0.4)
			var dir: Vector3 = (tip - ball).normalized()
			om.horn(tip - dir * 0.03, tip + dir * 0.19 + Vector3(0.0, -0.06, 0.0), 0.058, Vector3(0.0, 0.025, 0.0), 4, 1)
			om.mask2 = Vector2.ZERO


## Basis whose local +Z points along `dir` (for parts that face outward).
static func _facing(dir: Vector3) -> Basis:
	var z: Vector3 = dir.normalized()
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	if x.length_squared() < 0.01:
		x = Vector3.RIGHT
	return Basis(x, z.cross(x), z)

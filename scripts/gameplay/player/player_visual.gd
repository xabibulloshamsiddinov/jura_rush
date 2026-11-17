## The caveman runner: organic procedural body parts (CavemanModel, built once and shared) hung on
## a small bone hierarchy and animated with transforms only.
##
## Animation model: every pose is a function that writes joint "channels" (angles, offsets).
## A pose change cross-fades from a snapshot of what was on screen (smoothstep, 0.07-0.45 s by
## pose). On top come spring layers: lane lean, landing squash and knee dip, take-off stretch,
## stumble wobble, menu facing turn; and spring-driven secondary motion for hair, beard, skirt
## hem and feathers. Feet stay planted in the idle / ready stances.
## Skins are CharacterDef resources (colours, fur pattern, hair style, bulk, accessory).
## Replace with real art by dropping assets/meshes/player.glb (see VisualProvider).
class_name PlayerVisual
extends Node3D

## Values 0-7 are unchanged from the first release; READY (countdown stance) was appended.
enum Pose { IDLE, RUN, JUMP, FALL, ROLL, STUMBLE, FLY, DEAD, READY }
enum IdleAct { NONE, SCRATCH, HIPS, STRETCH, LOOK, FLEX }

## A foot planted during the run cycle (side -1 = left, 1 = right; foot position in world space).
signal footstep(side: int, foot_position: Vector3)

var pose: Pose = Pose.IDLE
## Vertical speed of the runner (m/s). Set by Player before animate(); drives the air poses.
var vertical_speed: float = 0.0
## Small vertical arc while changing lanes (metres). Set by Player.
var lane_hop: float = 0.0
## World speed (m/s), blows hair and fur back.
var run_speed: float = 0.0
## Extra head yaw in the idle pose (menu: look toward the camera).
var idle_look_yaw: float = 0.0

# --- Channels -----------------------------------------------------------------------------------
const RPX: int = 0
const RPY: int = 1
const RPZ: int = 2
const RRX: int = 3
const RRY: int = 4
const RRZ: int = 5
## Height (root space) the body rotates around: 0 = feet, ball centre in a roll, grip in flight.
const PIV: int = 6
const HPX: int = 7
const HRX: int = 8
const HRY: int = 9
const HRZ: int = 10
const SRX: int = 11
const SRY: int = 12
const SRZ: int = 13
const NRX: int = 14
const NRY: int = 15
const NRZ: int = 16
const LSX: int = 17
const LSY: int = 18
const LSZ: int = 19
const LE: int = 20
const RSX: int = 21
const RSY: int = 22
const RSZ: int = 23
const RE: int = 24
const LTX: int = 25
const LTZ: int = 26
const LK: int = 27
const LA: int = 28
const RTX: int = 29
const RTZ: int = 30
const RK: int = 31
const RA: int = 32
## Squash (-) / stretch (+) of the whole body.
const SQ: int = 33
## How strongly the lane lean applies (negative = pendulum, while carried).
const LEAN_GAIN: int = 34
## Foot planting weight (idle / ready stances keep the soles on the ground).
const PLANT: int = 35
const CH_COUNT: int = 36
const ANGLE_CHANNELS: Array[int] = [RRX, RRY, RRZ]

## Cross-fade time into each pose (seconds).
const BLEND_TIME: Dictionary = {
	Pose.IDLE: 0.3, Pose.RUN: 0.14, Pose.JUMP: 0.09, Pose.FALL: 0.16, Pose.ROLL: 0.07,
	Pose.STUMBLE: 0.08, Pose.FLY: 0.3, Pose.DEAD: 0.07, Pose.READY: 0.45,
}
## Contact angles of the run cycle (left foot, right foot).
const CONTACT_L: float = PI * 0.5 + 0.3
const CONTACT_R: float = PI * 1.5 + 0.3
## Pseudo-acceleration per m/s of world speed that blows hair and fur back.
const WIND_PER_SPEED: float = 12.0

var _root: Node3D = null
var _skin: Node3D = null
var _hips: Node3D = null
var _spine: Node3D = null
var _neck: Node3D = null
var _shoulder_l: Node3D = null
var _shoulder_r: Node3D = null
var _elbow_l: Node3D = null
var _elbow_r: Node3D = null
var _thigh_l: Node3D = null
var _thigh_r: Node3D = null
var _knee_l: Node3D = null
var _knee_r: Node3D = null
var _ankle_l: Node3D = null
var _ankle_r: Node3D = null
var _hem: Node3D = null
var _hair_pivot: Node3D = null
var _beard_pivot: Node3D = null
var _feather_pivot: Node3D = null
var _lids: MeshInstance3D = null
var _hair_cap: MeshInstance3D = null
var _hair_locks: MeshInstance3D = null
var _beard: MeshInstance3D = null
var _meshes: Array[MeshInstance3D] = []
var _bulk_meshes: Array[MeshInstance3D] = []
var _limb_meshes: Array[MeshInstance3D] = []
var _accessories: Array[MeshInstance3D] = []
var _ride: PterosaurRide = null
var _custom: bool = false
var _def: CharacterDef = null
var _height_scale: float = 1.0
var _bulk: float = 1.0

var _t: PackedFloat32Array = PackedFloat32Array()
var _out: PackedFloat32Array = PackedFloat32Array()
var _from: PackedFloat32Array = PackedFloat32Array()
var _f: PackedFloat32Array = PackedFloat32Array()
var _blend: float = 1.0
var _blend_time: float = 0.14
var _pose_time: float = 0.0
var _pose_duration: float = 0.55
var _phase: float = 0.0
var _time: float = 0.0
var _speed_k: float = 0.0

# Spring layers: value, velocity.
var _lean: Vector2 = Vector2.ZERO
var _squash: Vector2 = Vector2.ZERO
var _dip: Vector2 = Vector2.ZERO
var _wobble_x: Vector2 = Vector2.ZERO
var _wobble_z: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.ZERO
var _facing_target: float = 0.0

# Secondary motion.
var _jiggles: Array[Jiggle] = []

# Idle behaviour.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _act: IdleAct = IdleAct.NONE
var _last_act: IdleAct = IdleAct.NONE
var _act_time: float = 0.0
var _act_len: float = 0.0
var _act_wait: float = 1.2
var _look: Vector2 = Vector2.ZERO
var _look_target: Vector2 = Vector2.ZERO
var _look_wait: float = 0.0
var _blink_wait: float = 2.0
var _blink_time: float = -1.0


## Spring-driven rotation of an appendage pivot (hair, beard, skirt, feathers). The pivot's
## acceleration (plus wind) bends it: rotation ~ accel x rest_direction.
class Jiggle:
	var node: Node3D = null
	var dir: Vector3 = Vector3.DOWN
	var omega: float = 14.0
	var zeta: float = 0.35
	var gain: float = 0.0035
	var limit: float = 0.4
	var angle: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var last_pos: Vector3 = Vector3.ZERO
	var last_vel: Vector3 = Vector3.ZERO
	var accel: Vector3 = Vector3.ZERO
	var primed: int = 0

	func _init(p_node: Node3D, p_dir: Vector3, p_omega: float, p_zeta: float, p_gain: float, p_limit: float) -> void:
		node = p_node
		dir = p_dir.normalized()
		omega = p_omega
		zeta = p_zeta
		gain = p_gain
		limit = p_limit

	func reset() -> void:
		angle = Vector2.ZERO
		vel = Vector2.ZERO
		accel = Vector3.ZERO
		primed = 0

	func step(dt: float, wind: Vector3) -> void:
		if node == null or not node.is_inside_tree() or dt <= 0.0:
			return
		var parent: Node3D = node.get_parent() as Node3D
		var pos: Vector3 = node.global_position
		var v: Vector3 = (pos - last_pos) / dt
		if primed >= 2:
			var a: Vector3 = (v - last_vel) / dt
			if a.length() > 250.0:
				a = a.normalized() * 250.0
			accel = accel.lerp(a, 1.0 - exp(-dt * 30.0))
		primed = mini(primed + 1, 2)
		last_pos = pos
		last_vel = v
		var local: Vector3 = parent.global_basis.orthonormalized().inverse() * (accel + wind)
		var torque: Vector3 = local.cross(dir) * gain
		var target: Vector2 = Vector2(clampf(torque.x, -limit, limit), clampf(torque.z, -limit, limit))
		# Semi-implicit spring, sub-stepped for stability.
		var steps: int = maxi(1, ceili(dt / 0.01))
		var h: float = dt / float(steps)
		for i in range(steps):
			var acc: Vector2 = (target - angle) * omega * omega - vel * 2.0 * zeta * omega
			vel += acc * h
			angle += vel * h
		node.rotation = Vector3(angle.x, 0.0, angle.y)


func _ready() -> void:
	_custom = VisualProvider.has_override(&"player")
	if _custom:
		add_child(VisualProvider.build(&"player", func() -> Node3D: return Node3D.new()))
		return
	_rng.randomize()
	_t.resize(CH_COUNT)
	_out.resize(CH_COUNT)
	_from.resize(CH_COUNT)
	_f.resize(CH_COUNT)
	_build_rig()
	apply_character(ContentDB.CHARACTERS[0])
	_eval(pose, 0.0)
	_out = _t.duplicate()
	_from = _t.duplicate()
	_finish_frame(0.0)


func _build_rig() -> void:
	_root = Node3D.new()
	add_child(_root)
	_skin = _bone(_root, Vector3.ZERO)
	_hips = _bone(_skin, Vector3(0.0, CavemanModel.HIP_Y, 0.0))
	_mesh(_hips, &"hips", Vector3.ZERO, _bulk_meshes)
	_hem = _bone(_hips, CavemanModel.HEM_PIVOT)
	_mesh(_hem, &"skirt", -CavemanModel.HEM_PIVOT, _bulk_meshes)
	_spine = _bone(_hips, Vector3(0.0, CavemanModel.SPINE_Y, 0.0))
	_mesh(_spine, &"chest", Vector3.ZERO, _bulk_meshes)
	_neck = _bone(_spine, CavemanModel.NECK)
	_mesh(_neck, &"head", Vector3.ZERO, null)
	_hair_cap = _mesh(_neck, &"hair_cap_mop", Vector3.ZERO, null)
	_hair_pivot = _bone(_neck, CavemanModel.HAIR_PIVOT)
	_hair_locks = _mesh(_hair_pivot, &"hair_locks_mop", Vector3.ZERO, null)
	_beard_pivot = _bone(_neck, CavemanModel.BEARD_PIVOT)
	_beard = _mesh(_beard_pivot, &"beard", Vector3.ZERO, null)
	_lids = _mesh(_neck, &"lids", Vector3(0.0, CavemanModel.HEAD_C.y + 0.012, CavemanModel.HEAD_C.z), null)
	_lids.visible = false
	_feather_pivot = _bone(_neck, CavemanModel.FEATHER_PIVOT)
	for s: float in [-1.0, 1.0]:
		var side: String = "l" if s < 0.0 else "r"
		var shoulder: Node3D = _bone(_spine, Vector3(s * CavemanModel.SHOULDER.x, CavemanModel.SHOULDER.y, CavemanModel.SHOULDER.z))
		shoulder.rotation_order = EULER_ORDER_ZXY
		_mesh(shoulder, StringName("upper_arm_" + side), Vector3.ZERO, _limb_meshes)
		var elbow: Node3D = _bone(shoulder, Vector3(0.0, -CavemanModel.UPPER_ARM, 0.0))
		_mesh(elbow, StringName("forearm_" + side), Vector3.ZERO, _limb_meshes)
		var thigh: Node3D = _bone(_hips, Vector3(s * CavemanModel.HIP_X, 0.0, 0.0))
		thigh.rotation_order = EULER_ORDER_ZXY
		_mesh(thigh, &"thigh", Vector3.ZERO, _limb_meshes)
		var knee: Node3D = _bone(thigh, Vector3(0.0, -CavemanModel.THIGH, 0.0))
		_mesh(knee, &"shin", Vector3.ZERO, _limb_meshes)
		var ankle: Node3D = _bone(knee, Vector3(0.0, -CavemanModel.SHIN, 0.0))
		_mesh(ankle, StringName("foot_" + side), Vector3.ZERO, _limb_meshes)
		if s < 0.0:
			_shoulder_l = shoulder
			_elbow_l = elbow
			_thigh_l = thigh
			_knee_l = knee
			_ankle_l = ankle
		else:
			_shoulder_r = shoulder
			_elbow_r = elbow
			_thigh_r = thigh
			_knee_r = knee
			_ankle_r = ankle
	_jiggles = [
		Jiggle.new(_hair_pivot, Vector3(0.0, -0.4, 0.9), 13.0, 0.3, 0.0036, 0.45),
		Jiggle.new(_beard_pivot, Vector3(0.0, -1.0, 0.15), 19.0, 0.28, 0.003, 0.3),
		Jiggle.new(_hem, Vector3(0.0, -1.0, 0.0), 12.0, 0.38, 0.0024, 0.22),
		Jiggle.new(_feather_pivot, Vector3(0.0, 1.0, 0.25), 15.0, 0.22, 0.004, 0.45),
	]


func _bone(parent: Node3D, pos: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	node.position = pos
	parent.add_child(node)
	return node


func _mesh(parent: Node3D, part: StringName, offset: Vector3, group: Variant) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = CavemanModel.mesh(part)
	mi.position = offset
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_meshes.append(mi)
	if group is Array:
		(group as Array).append(mi)
	return mi


## Recolours / reshapes the body for a skin (no mesh is rebuilt; skins share geometry).
func apply_character(def: CharacterDef) -> void:
	if _custom or _root == null or def == null:
		return
	_def = def
	var mat: ShaderMaterial = CavemanModel.material(def)
	_hair_cap.mesh = CavemanModel.mesh(StringName("hair_cap_" + String(def.hair_style)))
	_hair_locks.mesh = CavemanModel.mesh(StringName("hair_locks_" + String(def.hair_style)))
	_beard_pivot.visible = def.beard_size > 0.05
	_beard_pivot.scale = Vector3.ONE * lerpf(0.8, 1.0, clampf(def.beard_size, 0.0, 1.0))
	_height_scale = def.height_scale
	_skin.scale = Vector3.ONE * def.height_scale
	_bulk = def.bulk
	var torso: Vector3 = Vector3(def.bulk, 1.0, lerpf(1.0, def.bulk, 0.8))
	for mi: MeshInstance3D in _bulk_meshes:
		mi.scale = torso
	var limb: float = lerpf(1.0, def.bulk, 0.75)
	for mi: MeshInstance3D in _limb_meshes:
		mi.scale = Vector3(limb, 1.0, limb)
	_shoulder_l.position.x = -CavemanModel.SHOULDER.x * def.bulk
	_shoulder_r.position.x = CavemanModel.SHOULDER.x * def.bulk
	_thigh_l.position.x = -CavemanModel.HIP_X * lerpf(1.0, def.bulk, 0.8)
	_thigh_r.position.x = CavemanModel.HIP_X * lerpf(1.0, def.bulk, 0.8)
	for mi: MeshInstance3D in _accessories:
		mi.get_parent().remove_child(mi)
		_meshes.erase(mi)
		mi.queue_free()
	_accessories.clear()
	for part: Array in CavemanModel.accessory_parts(def.accessory):
		var bone: Node3D = _neck
		if part[1] == &"spine":
			bone = _spine
		elif part[1] == &"feather":
			bone = _feather_pivot
		var mi: MeshInstance3D = _mesh(bone, part[0], Vector3.ZERO, null)
		if bone == _spine:
			mi.scale = torso
		_accessories.append(mi)
	for mi: MeshInstance3D in _meshes:
		mi.material_override = mat


## Switches the animation pose. `duration` is the length of timed poses (roll); restart replays
## the current pose from its start.
func set_pose(new_pose: Pose, duration: float = -1.0, restart: bool = false) -> void:
	if duration > 0.0:
		_pose_duration = duration
	if pose == new_pose and not restart:
		return
	var old: Pose = pose
	pose = new_pose
	_pose_time = 0.0
	if _custom or _root == null:
		return
	_from = _out.duplicate()
	for ch: int in ANGLE_CHANNELS:
		_from[ch] = wrapf(_from[ch], -PI, PI)
	_blend = 0.0
	_blend_time = BLEND_TIME.get(new_pose, 0.14)
	if new_pose == Pose.RUN and old == Pose.READY:
		_blend_time = 0.28
	elif new_pose == Pose.RUN and (old == Pose.JUMP or old == Pose.FALL):
		_blend_time = 0.1
	elif old == Pose.DEAD:
		# Revive: get back up instead of flipping upright.
		_blend_time = 0.4
	match new_pose:
		Pose.JUMP:
			# Take-off: a quick stretch.
			_squash.y += 2.6
			_dip.y -= 1.5
		Pose.STUMBLE:
			_wobble_x.y += 9.0
			_wobble_z.y += 7.0 * (1.0 if _rng.randf() < 0.5 else -1.0)
		Pose.FLY:
			if _ride == null:
				prepare_ride()
			_ride.grab()
		Pose.DEAD:
			_lids.visible = true
	if old == Pose.FLY and new_pose != Pose.FLY and _ride != null:
		_ride.release()
	if old == Pose.IDLE:
		_act = IdleAct.NONE


## Landing reaction: squash and knee dip scaled by the impact speed (m/s, from player_landed).
func land(impact: float) -> void:
	var k: float = clampf(impact / 14.0, 0.15, 1.6)
	_squash.y -= 2.4 * k
	_dip.y += 5.5 * k


## Body yaw the idle / ready poses turn toward (menu: toward the camera). instant skips the turn.
func set_facing(yaw: float, instant: bool = false) -> void:
	_facing_target = yaw
	if instant:
		_facing = Vector2(yaw, 0.0)


## Clears springs and secondary motion (teleports: reset, revive).
func reset_motion() -> void:
	_lean = Vector2.ZERO
	_squash = Vector2.ZERO
	_dip = Vector2.ZERO
	_wobble_x = Vector2.ZERO
	_wobble_z = Vector2.ZERO
	for j: Jiggle in _jiggles:
		j.reset()


## Builds the pterosaur used by the jetpack (once; meshes are cached and shared).
func prepare_ride() -> void:
	if _ride != null or _custom:
		return
	_ride = PterosaurRide.new()
	add_child(_ride)


## Dev / lab: starts an idle action now (1 scratch, 2 hands on hips, 3 stretch, 4 look, 5 flex).
func play_idle_action(act: int, at_time: float = 1.0) -> void:
	_act = act as IdleAct
	_act_time = at_time
	_act_len = 2.6
	_act_wait = 99.0


## World position of a foot (dust kicks).
func foot_position(side: int) -> Vector3:
	if _ankle_l == null:
		return global_position
	return (_ankle_l if side < 0 else _ankle_r).global_position


## Advances the procedural animation. cadence = run-cycle speed (rad/s), lean = lane lean target
## (rad, + = moving toward +x).
func animate(delta: float, cadence: float, lean: float) -> void:
	if _custom or _root == null:
		return
	var dt: float = clampf(delta, 0.0, 0.1)
	_pose_time += dt
	_time += dt
	var prev_phase: float = _phase
	if pose == Pose.RUN or pose == Pose.STUMBLE:
		_phase += dt * cadence
	_speed_k = clampf((cadence - 11.5) / 4.5, 0.0, 1.0)
	if pose == Pose.IDLE:
		_idle_director(dt)
	_eval(pose, _pose_time)
	if _blend < 1.0:
		_blend = minf(_blend + dt / maxf(_blend_time, 0.001), 1.0)
		var w: float = smoothstep(0.0, 1.0, _blend)
		for i in range(CH_COUNT):
			_out[i] = lerpf(_from[i], _t[i], w)
	else:
		_out = _t.duplicate()
	_step_springs(dt, lean)
	_finish_frame(dt)
	if pose == Pose.RUN:
		_detect_footsteps(prev_phase, _phase)


func _finish_frame(dt: float) -> void:
	_f = _out.duplicate()
	_layers()
	_apply()
	var wind: Vector3 = Vector3(0.0, 0.0, -run_speed * WIND_PER_SPEED)
	# Stepped even while the runner blinks invisible, so nothing jumps when he reappears.
	for j: Jiggle in _jiggles:
		j.step(dt, wind)
	_update_blink(dt)
	if _ride != null:
		var hs: float = _height_scale
		var anchor: Vector3 = Vector3(_f[RPX] * hs, _f[PIV] * hs + _f[RPY] * hs, _f[RPZ] * hs)
		_ride.tick(dt, anchor, _lean.x)


# --- Pose functions -------------------------------------------------------------------------------

func _eval(p: Pose, t: float) -> void:
	_t.fill(0.0)
	_t[LEAN_GAIN] = 1.0
	_t[LSZ] = 0.18
	_t[RSZ] = 0.18
	match p:
		Pose.IDLE:
			_pose_idle(t)
		Pose.READY:
			_pose_ready(t)
		Pose.RUN:
			_pose_run(_phase)
		Pose.JUMP, Pose.FALL:
			_pose_air(t)
		Pose.ROLL:
			_pose_roll(t)
		Pose.STUMBLE:
			_pose_stumble(t)
		Pose.FLY:
			_pose_fly(t)
		Pose.DEAD:
			_pose_dead(t)


func _pose_idle(_t_pose: float) -> void:
	var t: float = _time
	var breath: float = sin(t * 2.1)
	var shift: float = sin(t * 0.75)
	_t[PLANT] = 1.0
	_t[LEAN_GAIN] = 0.4
	_t[HPX] = shift * 0.025
	_t[HRZ] = shift * 0.035
	_t[SRX] = 0.03 + breath * 0.02
	_t[SRZ] = -shift * 0.03
	_t[SQ] = breath * 0.006
	_t[NRX] = -0.03 + _look.y
	_t[NRY] = _look.x
	_t[NRZ] = shift * 0.02
	_t[LSX] = 0.04 + breath * 0.025
	_t[RSX] = 0.04 + sin(t * 2.1 + 0.6) * 0.025
	_t[LSZ] = 0.2 + breath * 0.02
	_t[RSZ] = 0.2 + breath * 0.02
	_t[LSY] = -0.25
	_t[RSY] = 0.25
	_t[LE] = 0.28
	_t[RE] = 0.28
	_t[LTZ] = 0.07
	_t[RTZ] = 0.07
	_t[LTX] = 0.04
	_t[RTX] = 0.04
	_t[LK] = -0.1 - maxf(shift, 0.0) * 0.12
	_t[RK] = -0.1 - maxf(-shift, 0.0) * 0.12
	_t[LA] = 0.06 + maxf(shift, 0.0) * 0.08
	_t[RA] = 0.06 + maxf(-shift, 0.0) * 0.08
	if _act != IdleAct.NONE:
		_idle_action()


## Occasional idle actions, blended in and out over the base idle.
func _idle_action() -> void:
	var t: float = _act_time
	var e: float = smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(_act_len - 0.45, _act_len, t))
	match _act:
		IdleAct.SCRATCH:
			var scratch: float = sin(t * 21.0) * 0.16 * smoothstep(0.35, 0.6, t)
			_mix(RSX, 0.4, e)
			_mix(RSZ, 1.85, e)
			_mix(RSY, -1.45, e)
			_mix(RE, 2.7 + scratch, e)
			_mix(NRZ, -0.16, e)
			_mix(NRX, 0.08, e)
			_mix(SRZ, 0.05, e)
		IdleAct.HIPS:
			for s: Array in [[LSX, LSY, LSZ, LE, -1.0], [RSX, RSY, RSZ, RE, 1.0]]:
				_mix(s[0], -0.35, e)
				_mix(s[1], s[4] * 1.3, e)
				_mix(s[2], 0.7, e)
				_mix(s[3], 1.85, e)
			_mix(SRX, 0.12, e)
			_mix(NRX, 0.1 + _look.y, e)
			_mix(LTZ, 0.14, e)
			_mix(RTZ, 0.14, e)
		IdleAct.STRETCH:
			var up: float = smoothstep(0.2, 0.9, t) * (1.0 - smoothstep(_act_len - 0.7, _act_len - 0.2, t))
			_mix(LSX, 2.9, e)
			_mix(RSX, 2.9, e)
			_mix(LSZ, -0.3, e)
			_mix(RSZ, -0.3, e)
			_mix(LE, 0.2, e)
			_mix(RE, 0.2, e)
			_mix(SRX, 0.24 * up + 0.03, e)
			_mix(NRX, 0.28 * up, e)
			_mix(LA, -0.25 * up, e)
			_mix(RA, -0.25 * up, e)
			_t[SQ] += 0.04 * up * e
		IdleAct.LOOK:
			var k: float = t / _act_len
			_mix(RSX, 2.0, e)
			_mix(RSZ, 0.15, e)
			_mix(RSY, 0.4, e)
			_mix(RE, 2.25, e)
			_mix(NRY, sin(k * TAU) * 0.55, e)
			_mix(NRX, 0.06, e)
			_mix(SRX, -0.08, e)
		IdleAct.FLEX:
			var pump: float = 0.12 * sin(t * 7.0) * smoothstep(0.4, 0.7, t)
			for s: Array in [[LSX, LSY, LSZ, LE, -1.0], [RSX, RSY, RSZ, RE, 1.0]]:
				_mix(s[0], 0.15, e)
				_mix(s[1], s[4] * -1.45, e)
				_mix(s[2], 1.35, e)
				_mix(s[3], 1.95 + pump, e)
			_mix(SRX, 0.1, e)
			_mix(NRX, 0.12, e)
			_t[SQ] += 0.02 * e


func _mix(ch: int, value: float, w: float) -> void:
	_t[ch] = lerpf(_t[ch], value, w)


func _idle_director(dt: float) -> void:
	_look_wait -= dt
	if _look_wait <= 0.0:
		_look_wait = _rng.randf_range(1.2, 3.0)
		var glance: bool = _rng.randf() < 0.35
		_look_target = Vector2(idle_look_yaw + (_rng.randf_range(-0.5, 0.5) if glance else _rng.randf_range(-0.12, 0.12)),
				_rng.randf_range(-0.08, 0.1))
	_look = _look.lerp(_look_target, 1.0 - exp(-dt * 5.0))
	if _act == IdleAct.NONE:
		_act_wait -= dt
		if _act_wait <= 0.0:
			var choices: Array[IdleAct] = [IdleAct.SCRATCH, IdleAct.HIPS, IdleAct.STRETCH, IdleAct.LOOK, IdleAct.FLEX]
			choices.erase(_last_act)
			_act = choices[_rng.randi_range(0, choices.size() - 1)]
			_last_act = _act
			_act_time = 0.0
			_act_len = {IdleAct.SCRATCH: 2.3, IdleAct.HIPS: 2.8, IdleAct.STRETCH: 2.6, IdleAct.LOOK: 2.8,
					IdleAct.FLEX: 2.2}[_act]
	else:
		_act_time += dt
		if _act_time >= _act_len:
			_act = IdleAct.NONE
			_act_wait = _rng.randf_range(1.8, 3.6)


## Countdown stance: turned forward, crouched, eager bounce.
func _pose_ready(t: float) -> void:
	var bounce: float = sin(t * 8.0)
	_t[PLANT] = 1.0
	_t[LEAN_GAIN] = 0.6
	_t[SRX] = -0.32
	_t[NRX] = 0.3
	_t[LTX] = 0.75
	_t[LK] = -1.2 - bounce * 0.06
	_t[LA] = 0.45
	_t[RTX] = 0.05
	_t[RK] = -0.85 - bounce * 0.06
	_t[RA] = 0.8
	_t[LTZ] = 0.1
	_t[RTZ] = 0.1
	_t[LSX] = 0.75
	_t[LE] = 2.0
	_t[RSX] = 0.45
	_t[RE] = 2.1
	_t[LSZ] = 0.32
	_t[RSZ] = 0.36
	_t[HRY] = 0.12
	_t[SRY] = -0.15
	_t[SQ] = bounce * 0.012


func _pose_run(phase: float) -> void:
	var k: float = _speed_k
	var s: float = sin(phase)
	var amp: float = 0.82 + 0.16 * k
	_leg(LTX, LK, LA, phase, amp)
	_leg(RTX, RK, RA, phase + PI, amp)
	_t[LTZ] = 0.05
	_t[RTZ] = 0.05
	var arm: float = 0.72 + 0.15 * k
	_t[LSX] = 0.05 - arm * s
	_t[RSX] = 0.05 + arm * s
	_t[LE] = 1.2 + 0.4 * maxf(0.0, -s)
	_t[RE] = 1.2 + 0.4 * maxf(0.0, s)
	_t[LSZ] = 0.24 + 0.06 * absf(s)
	_t[RSZ] = 0.24 + 0.06 * absf(s)
	_t[LSY] = -0.2
	_t[RSY] = 0.2
	_t[HRY] = -0.17 * s
	_t[SRY] = 0.26 * s
	_t[HRZ] = 0.05 * s
	_t[HPX] = 0.02 * cos(phase)
	_t[SRX] = -(0.2 + 0.07 * k) + 0.035 * cos(2.0 * phase)
	_t[RRX] = -0.05 - 0.03 * k
	# Head stays level and looks down the track.
	_t[NRX] = -(_t[SRX] + _t[RRX]) * 0.8 + 0.04
	_t[NRY] = -(_t[HRY] + _t[SRY]) * 0.95
	_t[NRZ] = -_t[HRZ] * 0.6
	# Lowest at mid-stance, highest in the flight phase.
	_t[RPY] = -0.035 + (0.07 + 0.02 * k) * s * s


## One leg of the run cycle: reach forward, straight push back, heel kicks up on the swing.
func _leg(thigh: int, knee: int, ankle: int, phase: float, amp: float) -> void:
	var s: float = sin(phase)
	_t[thigh] = 0.14 + amp * s
	_t[knee] = -(0.22 + 1.55 * pow(maxf(0.0, cos(phase + 0.3)), 1.5) + 0.12 * maxf(0.0, -sin(phase - 0.4)))
	_t[ankle] = 0.12 + 0.3 * sin(phase + 0.9)


## Jump and fall share one function of the vertical speed, so the apex switch is seamless.
func _pose_air(t: float) -> void:
	var vn: float = clampf(vertical_speed / 12.0, -2.0, 1.0)
	var rise: float = clampf(vn, 0.0, 1.0)
	var tuck: float = 1.0 - absf(clampf(vn, -1.0, 1.0))
	var fall: float = clampf(-vn, 0.0, 1.0)
	# Legs: the lead knee comes up, both tuck at the apex, then reach down for the landing.
	_t[LTX] = lerpf(0.75, 1.25, tuck) * (1.0 - fall) + lerpf(1.25, 0.4, fall) * fall
	_t[LK] = -(lerpf(0.75, 1.75, tuck) * (1.0 - fall) + lerpf(1.6, 0.35, fall) * fall)
	_t[RTX] = lerpf(-0.35, 0.75, tuck) * (1.0 - fall) + lerpf(0.75, 0.1, fall) * fall
	_t[RK] = -(lerpf(1.05, 1.7, tuck) * (1.0 - fall) + lerpf(1.7, 0.55, fall) * fall)
	_t[LA] = -0.25
	_t[RA] = -0.35
	_t[LTZ] = 0.08 + 0.06 * fall
	_t[RTZ] = 0.08 + 0.06 * fall
	# Arms: thrown up on take-off, pulled in at the apex, out for balance on the way down.
	# Raised arms splay outward with a negative abduction (the shoulder's Z is applied last).
	var up: float = 2.75 * rise + 1.0 * tuck * (1.0 - fall) + 2.1 * fall
	_t[LSX] = up
	_t[RSX] = up * 0.94
	_t[LSZ] = lerpf(0.4, -0.45, rise) * (1.0 - fall) + 0.75 * fall
	_t[RSZ] = lerpf(0.4, -0.45, rise) * (1.0 - fall) + 0.75 * fall
	_t[LE] = lerpf(1.5, 0.7, maxf(rise, fall))
	_t[RE] = lerpf(1.5, 0.8, maxf(rise, fall))
	if vn < -1.15:
		# Long drop: cartoon windmill.
		var wm: float = smoothstep(-1.15, -1.6, vn)
		_t[LSX] += sin(t * 13.0) * 0.8 * wm
		_t[RSX] += sin(t * 13.0 + PI) * 0.8 * wm
	_t[SRX] = -0.06 - 0.22 * tuck * (1.0 - fall) + 0.04 * fall
	_t[RRX] = -0.08 * tuck
	_t[NRX] = -_t[SRX] * 0.6 + 0.05
	_t[SQ] = -0.04 * tuck * (1.0 - fall)


## One readable forward roll timed to the roll duration: tuck, one full turn, open up.
func _pose_roll(t: float) -> void:
	var u: float = clampf(t / maxf(_pose_duration, 0.1), 0.0, 1.0)
	var w: float = smoothstep(0.0, 0.16, u) * (1.0 - smoothstep(0.82, 1.0, u))
	var turn: float = smoothstep(0.08, 0.86, u)
	turn = turn * turn * (3.0 - 2.0 * turn)
	_t[PIV] = 0.88
	_t[RRX] = -TAU * turn
	_t[RPY] = -0.4 * w
	_t[RPZ] = 0.0
	_t[LTX] = lerpf(0.3, 2.35, w)
	_t[RTX] = lerpf(0.3, 2.25, w)
	_t[LK] = -lerpf(0.5, 2.45, w)
	_t[RK] = -lerpf(0.5, 2.45, w)
	_t[LA] = -0.3 * w
	_t[RA] = -0.3 * w
	_t[SRX] = -lerpf(0.35, 0.95, w)
	_t[NRX] = -0.55 * w
	_t[LSX] = lerpf(0.4, 1.15, w)
	_t[RSX] = lerpf(0.4, 1.15, w)
	_t[LSZ] = 0.12
	_t[RSZ] = 0.12
	_t[LE] = lerpf(1.2, 2.2, w)
	_t[RE] = lerpf(1.2, 2.2, w)
	_t[SQ] = -0.05 * w
	_t[LEAN_GAIN] = 0.5


## Stumble: pitched forward, arms pinwheeling, the run cycle keeps going underneath.
func _pose_stumble(t: float) -> void:
	_pose_run(_phase)
	var e: float = 1.0 - smoothstep(0.22, 0.4, t)
	_mix(SRX, -0.5, e)
	_mix(NRX, 0.35, e)
	_mix(LSX, 1.5 + sin(t * 17.0) * 0.6, e)
	_mix(RSX, 1.0 + sin(t * 17.0 + 2.0) * 0.6, e)
	_mix(LSZ, 0.6, e)
	_mix(RSZ, 0.7, e)
	_mix(LE, 0.5, e)
	_mix(RE, 0.6, e)
	_t[RPY] -= 0.05 * e


## Carried by the pterosaur: hanging from the grip at the shoulders, legs dangling.
func _pose_fly(t: float) -> void:
	_t[PIV] = CavemanModel.HIP_Y + CavemanModel.SPINE_Y + CavemanModel.SHOULDER.y
	_t[LEAN_GAIN] = -0.7
	_t[RRX] = -0.17 + 0.05 * sin(t * 2.3)
	_t[LSX] = 2.75
	_t[RSX] = 2.75
	_t[LSZ] = 0.2
	_t[RSZ] = 0.2
	_t[LE] = 0.45
	_t[RE] = 0.45
	_t[SRX] = 0.06
	_t[NRX] = 0.12
	var kick: float = t * 3.4
	_t[LTX] = 0.18 + 0.3 * sin(kick)
	_t[RTX] = 0.18 + 0.3 * sin(kick + PI)
	_t[LK] = -0.35 - 0.35 * (0.5 + 0.5 * sin(kick + 1.2))
	_t[RK] = -0.35 - 0.35 * (0.5 + 0.5 * sin(kick + 1.2 + PI))
	_t[LA] = -0.35
	_t[RA] = -0.35
	_t[LTZ] = 0.08
	_t[RTZ] = 0.08


## Knocked over backward with a small bounce, legs up, dazed.
func _pose_dead(t: float) -> void:
	var p: float = minf(t / 0.42, 1.0)
	p = 1.0 - pow(1.0 - p, 3.0)
	var after: float = maxf(t - 0.42, 0.0)
	var bounce: float = 0.1 * sin(after * 16.0) * exp(-after * 7.0)
	_t[RRX] = 1.47 * p - bounce
	_t[LTX] = 0.95 * p
	_t[RTX] = 0.55 * p
	_t[LK] = -0.6 * p
	_t[RK] = -0.9 * p
	_t[LSX] = 2.5 * p
	_t[RSX] = 2.2 * p
	_t[LSZ] = 0.9 * p
	_t[RSZ] = 1.0 * p
	_t[LE] = 0.4
	_t[RE] = 0.5
	_t[NRX] = 0.25 * p
	_t[NRZ] = 0.12 * sin(t * 4.0) * p
	_t[LEAN_GAIN] = 0.0


# --- Layers and application -----------------------------------------------------------------------

func _spring(state: Vector2, target: float, omega: float, zeta: float, dt: float) -> Vector2:
	var steps: int = maxi(1, ceili(dt / 0.01))
	var h: float = dt / float(steps)
	var s: Vector2 = state
	for i in range(steps):
		var acc: float = (target - s.x) * omega * omega - s.y * 2.0 * zeta * omega
		s.y += acc * h
		s.x += s.y * h
	return s


func _step_springs(dt: float, lean: float) -> void:
	_lean = _spring(_lean, lean, 15.0, 0.55, dt)
	_squash = _spring(_squash, 0.0, 19.0, 0.3, dt)
	_dip = _spring(_dip, 0.0, 13.0, 0.75, dt)
	_wobble_x = _spring(_wobble_x, 0.0, 11.0, 0.3, dt)
	_wobble_z = _spring(_wobble_z, 0.0, 10.0, 0.3, dt)
	var face: float = _facing_target if (pose == Pose.IDLE or pose == Pose.READY) else 0.0
	_facing = _spring(_facing, face, 6.5, 1.0, dt)
	_squash.x = clampf(_squash.x, -0.3, 0.3)
	_dip.x = clampf(_dip.x, -0.4, 1.0)


func _layers() -> void:
	var g: float = _f[LEAN_GAIN]
	var lean: float = _lean.x * g
	_f[RRZ] += -lean
	_f[SRZ] += lean * 0.3
	_f[NRZ] += lean * 0.45
	_f[RRY] += -_lean.x * 0.25 * absf(g) + _facing.x
	_f[RPY] += lane_hop
	_f[SQ] += _squash.x
	var dip: float = maxf(_dip.x, 0.0)
	var lift: float = minf(_dip.x, 0.0)
	_f[RPY] += -dip * 0.15 - lift * 0.05
	_f[LK] -= dip * 0.75
	_f[RK] -= dip * 0.75
	_f[LTX] += dip * 0.38
	_f[RTX] += dip * 0.38
	_f[LA] += dip * 0.35
	_f[RA] += dip * 0.35
	_f[SRX] -= dip * 0.22
	_f[NRX] += dip * 0.15
	_f[LSX] -= dip * 0.25
	_f[RSX] -= dip * 0.25
	_f[RRX] += _wobble_x.x
	_f[RRZ] += _wobble_z.x
	var plant: float = _f[PLANT]
	if plant > 0.0:
		var drop: float = minf(_leg_drop(_f[LTX], _f[LK]), _leg_drop(_f[RTX], _f[RK]))
		_f[RPY] -= drop * plant


## How far the hip drops when a leg bends (thigh / knee angles), with the foot on the ground.
func _leg_drop(thigh: float, knee: float) -> float:
	return (CavemanModel.THIGH + CavemanModel.SHIN) - (CavemanModel.THIGH * cos(thigh) + CavemanModel.SHIN * cos(thigh + knee))


func _apply() -> void:
	var f: PackedFloat32Array = _f
	var hs: float = _height_scale
	var sq: float = 1.0 + clampf(f[SQ], -0.35, 0.4)
	var side: float = 1.0 / sqrt(sq)
	var rot: Basis = Basis.from_euler(Vector3(f[RRX], f[RRY], f[RRZ]))
	var b: Basis = rot * Basis.from_scale(Vector3(side, sq, side))
	var piv: Vector3 = Vector3(0.0, f[PIV] * hs, 0.0)
	_root.transform = Transform3D(b, piv - b * piv + Vector3(f[RPX], f[RPY], f[RPZ]) * hs)
	_hips.position = Vector3(f[HPX], CavemanModel.HIP_Y, 0.0)
	_hips.rotation = Vector3(f[HRX], f[HRY], f[HRZ])
	_spine.rotation = Vector3(f[SRX], f[SRY], f[SRZ])
	_neck.rotation = Vector3(f[NRX], f[NRY], f[NRZ])
	_shoulder_l.rotation = Vector3(f[LSX], f[LSY], -f[LSZ])
	_shoulder_r.rotation = Vector3(f[RSX], f[RSY], f[RSZ])
	_elbow_l.rotation.x = f[LE]
	_elbow_r.rotation.x = f[RE]
	_thigh_l.rotation = Vector3(f[LTX], 0.0, -f[LTZ])
	_thigh_r.rotation = Vector3(f[RTX], 0.0, f[RTZ])
	_knee_l.rotation.x = f[LK]
	_knee_r.rotation.x = f[RK]
	_ankle_l.rotation.x = f[LA]
	_ankle_r.rotation.x = f[RA]


func _update_blink(dt: float) -> void:
	if pose == Pose.DEAD:
		_lids.visible = true
		_lids.scale = Vector3.ONE
		return
	if _blink_time < 0.0:
		_blink_wait -= dt
		if _blink_wait <= 0.0:
			_blink_time = 0.0
		_lids.visible = false
		return
	_blink_time += dt
	var k: float = _blink_time / 0.16
	if k >= 1.0:
		_blink_time = -1.0
		_blink_wait = _rng.randf_range(1.8, 4.5)
		_lids.visible = false
		return
	_lids.visible = true
	_lids.scale = Vector3(1.0, maxf(sin(k * PI), 0.05), 1.0)


func _detect_footsteps(prev: float, now: float) -> void:
	if footstep.get_connections().is_empty():
		return
	for contact: float in [CONTACT_L, CONTACT_R]:
		if floorf((prev - contact) / TAU) != floorf((now - contact) / TAU):
			var side: int = -1 if contact == CONTACT_L else 1
			footstep.emit(side, foot_position(side))

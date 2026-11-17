## The run camera, the menu showcase and the crash view.
##
## RUN: behind and above the runner. Follows the lane x and the height with critically damped
## springs (cam_lag_x / cam_lag_y are the smoothing times), so a lane change, a jump, a landing
## or a slam never snaps. The roll tilt comes from the camera's own sideways speed (it rises and
## settles with the move), FOV widens with speed and punches (near miss, boosts) through springs,
## and trauma shake comes on top.
## MENU: in front of the caveman, a little to his right (3/4 front view), low and looking up so
## the idle T-Rex behind him stays in frame.
## Mode changes blend in orbit space around the runner (yaw / distance / height eased with
## smootherstep), so the camera swings around him instead of cutting through him.
class_name CameraRig
extends Node3D

enum Mode { MENU, RUN, DEATH }

## Menu framing in runner space (runner at the origin, facing -Z). Orbit yaw 0 = behind (+Z),
## 180 = straight in front; 166 puts the camera in front, 14 degrees to the runner's right.
## With these numbers (1080x1920 portrait) the feet sit at ~69 % of the screen height, the
## body spans ~25 %, and the idle T-Rex (Chaser.MENU_POS, head ~4.5 m up) shows its head at ~30 %
## height, just under the logo (8.5-26 %), centre-left of the caveman.
const MENU_YAW_DEG: float = 166.0
const MENU_DISTANCE: float = 8.0
const MENU_EYE_HEIGHT: float = 1.0
const MENU_LOOK: Vector3 = Vector3(0.0, 1.4, 0.0)
const MENU_FOV: float = 50.0
## Slow breathing drift of the menu camera (degrees of yaw, metres of height).
const MENU_SWAY_YAW_DEG: float = 1.5
const MENU_SWAY_HEIGHT: float = 0.05
## Body yaw of the caveman in the menu (turned a little toward the camera's side) and the
## extra yaw of his head toward the camera.
const MENU_FACING: float = 0.32
const MENU_HEAD_YAW: float = -0.3
## Blend time of the menu -> run swing when a run starts.
const START_BLEND: float = 1.1
## How much a big swing pulls in toward the runner / rises at its middle (metres, scaled by the
## share of a half turn), so it stays on the track and clears the decor.
const SWING_TIGHTEN: float = 2.6
const SWING_LIFT: float = 1.4
## Sideways offset of the death camera from the runner's lane: behind-LEFT, opposite the T-Rex
## (Chaser.CATCH_X, behind-right), so the blend from the run view never passes through the T-Rex.
const DEATH_SIDE: float = -1.2
## Peak follow speed (m/s) that gives the full cam_tilt_deg roll.
const TILT_REF_SPEED: float = 9.0

var mode: Mode = Mode.MENU
var camera: Camera3D = null
var shake: ScreenShake = null
var target: Node3D = null

var _cfg: GameConfig = GameConfig.current()
var _follow_x: Vector2 = Vector2.ZERO
var _follow_y: Vector2 = Vector2.ZERO
var _tilt: Vector2 = Vector2.ZERO
var _punch: Vector2 = Vector2.ZERO
var _boost: Vector2 = Vector2.ZERO
var _boost_target: float = 0.0
var _speed_fov: Vector2 = Vector2.ZERO
var _speed_fraction: float = 0.0
var _blend: float = 1.0
var _blend_time: float = 0.8
var _from: Shot = null
var _shot: Shot = null
var _time: float = 0.0
var _death_time: float = 0.0


## One camera placement: eye, look-at point, field of view and roll.
class Shot:
	var eye: Vector3 = Vector3.ZERO
	var look: Vector3 = Vector3.FORWARD
	var fov: float = 65.0
	var roll: float = 0.0

	func _init(p_eye: Vector3 = Vector3.ZERO, p_look: Vector3 = Vector3.FORWARD, p_fov: float = 65.0,
			p_roll: float = 0.0) -> void:
		eye = p_eye
		look = p_look
		fov = p_fov
		roll = p_roll

	func copy() -> Shot:
		return Shot.new(eye, look, fov, roll)


func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 0.2
	camera.far = 400.0
	camera.fov = _cfg.fov_min
	camera.current = true
	# Doppler for passing trains. Set through set() because the property is not available in
	# every 4.x release; a missing property is simply ignored.
	camera.set(&"doppler_tracking", 2)
	add_child(camera)
	shake = ScreenShake.new()
	add_child(shake)
	_speed_fov = Vector2(_cfg.fov_min, 0.0)
	GameEvents.speed_changed.connect(func(speed: float) -> void:
		_speed_fraction = _cfg.speed_fraction(speed))
	GameEvents.near_miss.connect(func(_lane: int) -> void: kick_fov(_cfg.fov_punch_near))
	GameEvents.powerup_activated.connect(func(id: StringName, _d: float) -> void:
		if id == &"dash" or id == &"jetpack":
			_boost_target = _cfg.fov_punch_boost)
	GameEvents.powerup_expired.connect(func(id: StringName) -> void:
		if id == &"dash" or id == &"jetpack":
			_boost_target = 0.0)
	GameEvents.camera_trauma.connect(func(amount: float) -> void: shake.add_trauma(amount))
	GameEvents.player_stumbled.connect(func(_k: StringName) -> void: shake.add_trauma(0.45))
	GameEvents.player_crashed.connect(func(_k: StringName) -> void: shake.add_trauma(0.9))
	GameEvents.player_landed.connect(func(impact: float) -> void:
		if impact > 16.0:
			shake.add_trauma(clampf((impact - 16.0) / 30.0, 0.1, 0.4)))
	GameEvents.obstacle_smashed.connect(func(_p: Vector3) -> void: shake.add_trauma(0.3))


## Switches camera behaviour, blending from the current view over `blend_time` seconds.
func set_mode(new_mode: Mode, blend_time: float = 0.8) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	_death_time = 0.0
	if mode != Mode.RUN:
		_boost_target = 0.0
	if target != null:
		_follow_x = Vector2(target.position.x, 0.0)
	if _shot == null or blend_time <= 0.0:
		_blend = 1.0
		return
	_from = _shot.copy()
	_blend = 0.0
	_blend_time = blend_time


## Smooth FOV punch (rises over ~0.08 s, then settles) of about `degrees` at its peak.
func kick_fov(degrees: float) -> void:
	_punch.y += degrees * 12.0 * 2.718


## Updates the camera. Call once per rendered frame after the world and the player moved.
func tick(delta: float) -> void:
	if target == null:
		return
	_time += delta
	shake.tick(delta)
	_punch = _spring(_punch, 0.0, 12.0, 1.0, delta)
	_boost = _smooth(_boost, _boost_target, 0.35, delta)
	_speed_fov = _smooth(_speed_fov, lerpf(_cfg.fov_min, _cfg.fov_max, _speed_fraction), 0.4, delta)
	var goal: Shot = null
	match mode:
		Mode.MENU:
			goal = _menu_shot()
		Mode.RUN:
			goal = _run_shot(delta)
		_:
			goal = _death_shot(delta)
	if _blend < 1.0 and _from != null:
		_blend = minf(_blend + delta / maxf(_blend_time, 0.01), 1.0)
		goal = _blend_shots(_from, goal, _blend)
	_shot = goal
	var xf: Transform3D = Transform3D(Basis.IDENTITY, goal.eye).looking_at(goal.look)
	xf.basis = xf.basis.rotated(xf.basis.z, goal.roll + shake.roll)
	xf.origin += xf.basis * shake.offset
	camera.global_transform = xf
	camera.fov = goal.fov


## The menu placement (plus a slow drift) for the runner at its current x.
func _menu_shot() -> Shot:
	var pivot: Vector3 = Vector3(target.position.x, 0.0, 0.0)
	var yaw: float = deg_to_rad(MENU_YAW_DEG + sin(_time * 0.21) * MENU_SWAY_YAW_DEG)
	var eye: Vector3 = pivot + Vector3(sin(yaw) * MENU_DISTANCE,
			MENU_EYE_HEIGHT + sin(_time * 0.33) * MENU_SWAY_HEIGHT, cos(yaw) * MENU_DISTANCE)
	_follow_x = Vector2(target.position.x, 0.0)
	_follow_y = Vector2.ZERO
	_tilt = Vector2.ZERO
	return Shot.new(eye, pivot + MENU_LOOK, MENU_FOV, 0.0)


func _run_shot(delta: float) -> Shot:
	var prev_x: float = _follow_x.x
	_follow_x = _smooth(_follow_x, target.position.x, _cfg.cam_lag_x, delta)
	_follow_y = _smooth(_follow_y, target.position.y, _cfg.cam_lag_y, delta)
	var fx: float = _follow_x.x
	var fy: float = _follow_y.x
	# Roll from the camera's own sideways speed: eases in and out with the lane move.
	var vx: float = (fx - prev_x) / maxf(delta, 0.0001)
	var tilt_goal: float = clampf(vx / TILT_REF_SPEED, -1.0, 1.0) * deg_to_rad(_cfg.cam_tilt_deg)
	_tilt = _smooth(_tilt, tilt_goal, 0.06, delta)
	var eye: Vector3 = Vector3(fx * 0.8, _cfg.cam_height + fy * 0.75, _cfg.cam_back)
	var look: Vector3 = Vector3(fx * 0.9, 1.3 + fy * 0.85, -_cfg.cam_look_ahead)
	var fov: float = _speed_fov.x + _punch.x + _boost.x
	return Shot.new(eye, look, fov, _tilt.x)


## Zoom in on the crash, then pull back for the results screen.
func _death_shot(delta: float) -> Shot:
	_death_time += delta
	var pull: float = smoothstep(0.9, 2.2, _death_time)
	var fx: float = _follow_x.x
	var eye: Vector3 = Vector3(fx * 0.8 + DEATH_SIDE, lerpf(2.6, 4.8, pull), lerpf(4.2, 8.0, pull))
	var look: Vector3 = target.position * Vector3(1.0, 0.0, 1.0) + Vector3(0.0, 1.0, 0.0)
	return Shot.new(eye, look, lerpf(52.0, 62.0, pull), 0.0)


## Blends two placements in orbit space around the runner (smootherstep eased): yaw takes the
## short way round, a big swing tightens and lifts in its middle, and the look point stays on
## the runner longer during a big swing so he never leaves the frame.
func _blend_shots(a: Shot, b: Shot, t: float) -> Shot:
	var e: float = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	var pivot: Vector3 = Vector3(target.position.x, 0.0, 0.0)
	var ra: Vector3 = a.eye - pivot
	var rb: Vector3 = b.eye - pivot
	var ya: float = atan2(ra.x, ra.z)
	var yb: float = atan2(rb.x, rb.z)
	var swing: float = absf(angle_difference(ya, yb)) / PI
	var yaw: float = lerp_angle(ya, yb, e)
	var bump: float = sin(PI * e) * swing
	var dist: float = lerpf(Vector2(ra.x, ra.z).length(), Vector2(rb.x, rb.z).length(), e) - SWING_TIGHTEN * bump
	var height: float = lerpf(ra.y, rb.y, e) + SWING_LIFT * bump
	var eye: Vector3 = pivot + Vector3(sin(yaw) * dist, height, cos(yaw) * dist)
	var look_t: float = pow(e, 1.0 + 2.2 * swing)
	return Shot.new(eye, a.look.lerp(b.look, look_t), lerpf(a.fov, b.fov, e), lerpf(a.roll, b.roll, e))


## Critically damped smoothing (value, velocity) toward a target; smooth_time ~ time to arrive.
static func _smooth(state: Vector2, target_value: float, smooth_time: float, dt: float) -> Vector2:
	var st: float = maxf(smooth_time, 0.0001)
	var omega: float = 2.0 / st
	var x: float = omega * dt
	var decay: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: float = state.x - target_value
	var temp: float = (state.y + omega * change) * dt
	var vel: float = (state.y - omega * temp) * decay
	var value: float = target_value + (change + temp) * decay
	return Vector2(value, vel)


## Damped spring (value, velocity) toward a target, sub-stepped for stability.
static func _spring(state: Vector2, target_value: float, omega: float, zeta: float, dt: float) -> Vector2:
	var steps: int = maxi(1, ceili(dt / 0.01))
	var h: float = dt / float(steps)
	var s: Vector2 = state
	for i in range(steps):
		var acc: float = (target_value - s.x) * omega * omega - s.y * 2.0 * zeta * omega
		s.y += acc * h
		s.x += s.y * h
	return s

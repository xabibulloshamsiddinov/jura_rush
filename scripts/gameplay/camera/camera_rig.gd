## Behind-the-back camera with manual follow. Lags the player's lane x (cam_lag_x) and height
## (cam_lag_y, so jumps feel airy), widens FOV with speed, punches FOV on near-misses / boosts,
## tilts on lane changes and shakes from trauma. Also runs the menu orbit and the death zoom.
class_name CameraRig
extends Node3D

enum Mode { MENU, RUN, DEATH }

## Menu framing: camera distance / eye height, aim height (below the chest = runner sits high
## on screen) and field of view.
const MENU_DISTANCE: float = 8.0
const MENU_EYE_HEIGHT: float = 2.3
const MENU_AIM_HEIGHT: float = 0.85
const MENU_FOV: float = 55.0

var mode: Mode = Mode.MENU
var camera: Camera3D = null
var shake: ScreenShake = null
var target: Node3D = null

var _cfg: GameConfig = GameConfig.current()
var _follow_x: float = 0.0
var _follow_y: float = 0.0
var _fov_punch: float = 0.0
var _boost_fov: float = 0.0
var _tilt: float = 0.0
var _orbit: float = 0.0
var _speed_fraction: float = 0.0
var _blend: float = 1.0
var _from: Transform3D = Transform3D.IDENTITY
var _from_fov: float = 65.0
var _death_time: float = 0.0


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
	GameEvents.speed_changed.connect(func(speed: float) -> void:
		_speed_fraction = _cfg.speed_fraction(speed))
	GameEvents.near_miss.connect(func(_lane: int) -> void: _fov_punch = _cfg.fov_punch_near)
	GameEvents.lane_changed.connect(func(from: int, to: int) -> void:
		_tilt = deg_to_rad(_cfg.cam_tilt_deg) * signf(float(to - from)))
	GameEvents.powerup_activated.connect(func(id: StringName, _d: float) -> void:
		if id == &"dash" or id == &"jetpack":
			_boost_fov = _cfg.fov_punch_boost)
	GameEvents.powerup_expired.connect(func(id: StringName) -> void:
		if id == &"dash" or id == &"jetpack":
			_boost_fov = 0.0)
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
	_from = camera.global_transform
	_from_fov = camera.fov
	_blend = 0.0 if blend_time > 0.0 else 1.0
	_blend_speed = 1.0 / maxf(blend_time, 0.01)
	_death_time = 0.0
	if mode != Mode.RUN:
		_boost_fov = 0.0


var _blend_speed: float = 1.25


## Updates the camera. Call once per physics step after the player moved.
func tick(delta: float) -> void:
	if target == null:
		return
	shake.tick(delta)
	_fov_punch = MathUtils.damp(_fov_punch, 0.0, 0.18, delta)
	_tilt = MathUtils.damp(_tilt, 0.0, 0.22, delta)
	var goal: Transform3D = Transform3D.IDENTITY
	var fov: float = _cfg.fov_min
	match mode:
		Mode.MENU:
			# Slow orbit showcasing the character, with a gentle idle sway.
			_orbit += delta * 0.25
			# The aim point sits BELOW the runner, so the runner is framed in the upper-middle of the
			# screen and the menu buttons in the lower third never cover it.
			var angle: float = 0.55 + sin(_orbit) * 0.5
			var eye: Vector3 = target.position + Vector3(sin(angle) * MENU_DISTANCE,
					MENU_EYE_HEIGHT + sin(_orbit * 0.7) * 0.15, -cos(angle) * MENU_DISTANCE)
			goal = Transform3D(Basis.IDENTITY, eye).looking_at(target.position + Vector3(0.0, MENU_AIM_HEIGHT, 0.0))
			fov = MENU_FOV
			_follow_x = target.position.x
			_follow_y = 0.0
		Mode.RUN:
			_follow_x = MathUtils.damp(_follow_x, target.position.x, _cfg.cam_lag_x, delta)
			_follow_y = MathUtils.damp(_follow_y, target.position.y, _cfg.cam_lag_y, delta)
			var eye: Vector3 = Vector3(_follow_x * 0.8, _cfg.cam_height + _follow_y * 0.75, _cfg.cam_back)
			var look: Vector3 = Vector3(_follow_x * 0.9, 1.3 + _follow_y * 0.85, -_cfg.cam_look_ahead)
			goal = Transform3D(Basis.IDENTITY, eye).looking_at(look)
			goal.basis = goal.basis.rotated(goal.basis.z, _tilt + shake.roll)
			fov = lerpf(_cfg.fov_min, _cfg.fov_max, _speed_fraction) + _fov_punch + _boost_fov
		Mode.DEATH:
			# Zoom in on the crash, then pull back for the results screen.
			_death_time += delta
			var pull: float = smoothstep(0.9, 2.2, _death_time)
			var eye: Vector3 = Vector3(_follow_x * 0.8 + 1.2, lerpf(2.6, 4.8, pull), lerpf(4.2, 8.0, pull))
			goal = Transform3D(Basis.IDENTITY, eye).looking_at(target.position * Vector3(1.0, 0.0, 1.0) + Vector3(0.0, 1.0, 0.0))
			fov = lerpf(52.0, 62.0, pull)
	if _blend < 1.0:
		_blend = minf(_blend + delta * _blend_speed, 1.0)
		var t: float = MathUtils.ease_out_cubic(_blend)
		goal = _from.interpolate_with(goal, t)
		fov = lerpf(_from_fov, fov, t)
	goal.origin += goal.basis * shake.offset
	camera.global_transform = goal
	camera.fov = MathUtils.damp(camera.fov, fov, 0.12, delta) if _blend >= 1.0 else fov

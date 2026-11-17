## The chaser: a Tyrannosaurus (TRex, scripts/gameplay/creatures). Hidden while the player runs
## clean, looms behind the runner after a stumble, lunges on the fatal hit. In the main menu it
## idles behind the runner (breathing, sniffing, roaring every few seconds); when a run starts it
## roars once more, turns to its left and stomps off sideways into the jungle, clear of the camera
## swinging round the runner's right side into the run view. Reads speed, player events and the
## flow state from the event bus only (plus GameState.current() to resolve hide_now() requests).
##
## States: Menu -> Retreat (run starts) -> Hidden
##         Hidden -> Chase (player_stumbled) -> Hidden (window elapsed)
##         Chase / Hidden -> Catch (player_crashed) -> Hidden (run reset / revive)
## GameWorld ticks it in every flow state, inside its per-frame sub-steps (menu idle, run-start
## retreat, the run, the crash), so it moves in lock-step with the runner and the camera. A paused
## tree freezes it; crash slow motion scales it like everything else.
class_name Chaser
extends Node3D

const HIDDEN: StringName = &"hidden"
const CHASE: StringName = &"chase"
const CATCH: StringName = &"catch"
const MENU: StringName = &"menu"
const RETREAT: StringName = &"retreat"
## Root positions (ground under the hips; the model faces -Z, toward the runner) and scales.
## CHASE: the head and shoulders loom low behind the runner at the bottom of the run camera.
const HIDDEN_Z: float = 14.0
const CHASE_Z: float = 5.75
const CHASE_SCALE: float = 0.62
## Sideways offset from the runner's lane and the yaw back toward him: the camera then sees the
## head in three-quarter profile (eye, teeth) instead of the back of the skull.
const CHASE_X: float = 1.1
const CHASE_YAW: float = 0.24
## CATCH: lunges in from behind-right, the side it chases on, so it never crosses the run camera's
## dive into the death camera (CameraRig.DEATH_SIDE, behind-LEFT, which still sees the runner).
## From hiding it does not sprint in under the camera: it enters from CATCH_ENTRY, off to the right.
const CATCH_Z: float = 4.4
const CATCH_X: float = 1.55
const CATCH_ENTRY: Vector3 = Vector3(3.0, 0.0, 6.8)
const CATCH_SCALE: float = 0.8
## MENU: idles behind the runner and a little to his left, head about 4.5 m up: in the menu camera
## it stands upper-middle, between the logo and the caveman.
const MENU_POS: Vector3 = Vector3(-1.6, 0.0, 9.0)
const MENU_SCALE: float = 1.0
## RETREAT: roars (mostly behind the GET READY curtain), turns RETREAT_YAW to face -X (away from the
## swing, which passes the runner's +X side and stops 2.5 m in front of the menu spot; the tail then
## trails past behind the run camera), strides off along -X and hides past RETREAT_X. Timed
## against the CameraRig.START_BLEND swing that starts with the countdown (Loading lasts 0.55 s):
## test_run_start_swing_clears_trex replays it and checks that the camera never gets within the
## creature near-dissolve distance and never sees the T-Rex once it is behind the runner.
const RETREAT_X: float = -10.0
const RETREAT_ROAR: float = 0.45
const RETREAT_TURN: float = 0.5
const RETREAT_YAW: float = PI * 0.5
const RETREAT_WALK_SPEED: float = 8.0

var machine: StateMachine = null
## X the chaser steers toward (the player's lane).
var target_x: float = 0.0
var world_speed: float = 0.0
## The creature (null when replacement art overrides the visual).
var rex: TRex = null

var _cfg: GameConfig = GameConfig.current()
var _visual: Node3D = null
var _chase_left: float = 0.0
var _goal_z: float = HIDDEN_Z
var _goal_scale: float = CHASE_SCALE
var _flow: StringName = &"boot"
var _state_time: float = 0.0
var _next_roar: float = 3.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"chaser")
	collision_setup()
	_visual = VisualProvider.build(&"chaser", _build_visual)
	add_child(_visual)
	_rng.seed = 2024
	machine = StateMachine.new()
	add_child(machine)
	machine.add_state(HIDDEN, ChaserState.new(HIDDEN_Z, false, CHASE_SCALE), self)
	machine.add_state(CHASE, ChaserState.new(CHASE_Z, true, CHASE_SCALE), self)
	machine.add_state(CATCH, ChaserState.new(CATCH_Z, true, CATCH_SCALE), self)
	machine.add_state(MENU, ChaserState.new(MENU_POS.z, true, MENU_SCALE), self)
	machine.add_state(RETREAT, ChaserState.new(MENU_POS.z, true, MENU_SCALE), self)
	machine.transitioned.connect(func(_from: StringName, to: StringName) -> void:
		_state_time = 0.0
		GameEvents.chaser_state_changed.emit(to))
	machine.start(HIDDEN)
	position = Vector3(0.0, 0.0, HIDDEN_Z)
	visible = false
	GameEvents.speed_changed.connect(func(speed: float) -> void: world_speed = speed)
	GameEvents.player_stumbled.connect(_on_player_stumbled)
	GameEvents.player_crashed.connect(_on_player_crashed)
	GameEvents.player_revived.connect(hide_now)
	GameEvents.lane_changed.connect(func(_from: int, to: int) -> void: target_x = _cfg.lane_x(to))
	GameEvents.state_changed.connect(_on_flow_changed)
	_flow = GameState.current()
	if _flow == &"boot" or _flow == &"menu":
		_enter_menu()


## Documented layer use only: the chaser lives on layer 5 and collides with nothing.
func collision_setup() -> void:
	pass


## Sends the chaser away immediately (new run, revive). In the menu it goes back to its idle
## spot; while a run is loading straight out of the menu it keeps its roar-and-retreat.
func hide_now() -> void:
	var flow: StringName = GameState.current()
	if flow == &"menu" or flow == &"boot":
		_enter_menu()
		return
	if flow == &"loading" and (machine.is_in(MENU) or machine.is_in(RETREAT)):
		if machine.is_in(MENU):
			_start_retreat()
		return
	_snap_hidden()


## Sets where the chaser wants to be (called by its states).
func set_goal(z: float, shown: bool, goal_scale: float) -> void:
	_goal_z = z
	_goal_scale = goal_scale
	if shown:
		visible = true


## Animates and moves the chaser.
func tick(delta: float) -> void:
	_state_time += delta
	var lag: float = 0.45
	var goal_x: float = target_x
	var yaw: float = 0.0
	match machine.current_id:
		CHASE:
			_chase_left -= delta
			if _chase_left <= 0.0:
				machine.transition_to(HIDDEN)
			goal_x = target_x + CHASE_X + sin(_state_time * 1.3) * 0.2
			yaw = CHASE_YAW
		CATCH:
			lag = 0.12
			goal_x = target_x + CATCH_X
			yaw = atan2(position.x - target_x, position.z)
		MENU:
			lag = 0.0
			goal_x = MENU_POS.x
			_next_roar -= delta
			if _next_roar <= 0.0 and rex != null and rex.roar():
				GameEvents.chaser_state_changed.emit(&"roar")
				_next_roar = _rng.randf_range(6.0, 9.0)
		RETREAT:
			lag = 0.0
			yaw = RETREAT_YAW * smoothstep(RETREAT_ROAR, RETREAT_ROAR + RETREAT_TURN, _state_time)
			# Strides off along -X (never toward the runner or the camera) as the turn gets under way.
			position.x -= _retreat_speed() * delta
			goal_x = position.x
			if position.x <= RETREAT_X:
				_snap_hidden()
				return
	if not machine.is_in(RETREAT):
		position.z = MathUtils.damp(position.z, _goal_z, lag, delta)
	position.x = MathUtils.damp(position.x, goal_x, 0.2 if lag > 0.0 else 0.0, delta)
	if machine.is_in(HIDDEN) and position.z > HIDDEN_Z - 0.5:
		visible = false
	if not visible or _visual == null:
		return
	_visual.rotation.y = MathUtils.damp(_visual.rotation.y, yaw, 0.15, delta) if not machine.is_in(RETREAT) else yaw
	var s: float = MathUtils.damp(_visual.scale.x, _goal_scale, 0.25, delta)
	_visual.scale = Vector3.ONE * s
	if rex == null:
		return
	_drive_rex(delta)


func _drive_rex(delta: float) -> void:
	rex.ground_drift = Vector3(0.0, 0.0, world_speed)
	rex.lunge = 0.0
	rex.hunt = 0.0
	rex.auto_snap = false
	rex.showcase = 0.0
	match machine.current_id:
		CHASE, HIDDEN:
			rex.ground_speed = world_speed
			rex.hunt = 1.0
			rex.auto_snap = machine.is_in(CHASE)
		CATCH:
			rex.ground_speed = 3.0 if _state_time < 0.8 else 0.0
			rex.hunt = 1.0
			rex.lunge = 1.0
		MENU:
			rex.ground_speed = world_speed
			rex.showcase = 1.0
		RETREAT:
			rex.ground_speed = _retreat_speed()
			rex.ground_drift = Vector3.ZERO
	rex.animate(delta)


func _retreat_speed() -> float:
	return RETREAT_WALK_SPEED * smoothstep(RETREAT_ROAR + RETREAT_TURN * 0.3, RETREAT_ROAR + RETREAT_TURN, _state_time)


func _enter_menu() -> void:
	machine.transition_to(MENU, true)
	position = MENU_POS
	target_x = MENU_POS.x
	_chase_left = 0.0
	_next_roar = _rng.randf_range(2.5, 4.0)
	visible = true
	if _visual != null:
		_visual.rotation.y = 0.0
		_visual.scale = Vector3.ONE * MENU_SCALE
	if rex != null:
		rex.reset_pose()


func _start_retreat() -> void:
	machine.transition_to(RETREAT, true)
	if rex != null and rex.roar():
		GameEvents.chaser_state_changed.emit(&"roar")


func _snap_hidden() -> void:
	machine.transition_to(HIDDEN, true)
	position = Vector3(0.0, 0.0, HIDDEN_Z)
	target_x = 0.0
	_chase_left = 0.0
	visible = false
	if _visual != null:
		_visual.rotation.y = 0.0
		_visual.scale = Vector3.ONE * CHASE_SCALE


func _on_flow_changed(_from: StringName, to: StringName) -> void:
	_flow = to
	match to:
		&"menu":
			_enter_menu()
		&"loading":
			if machine.is_in(MENU):
				_start_retreat()
		&"running":
			if machine.is_in(MENU) or machine.is_in(RETREAT):
				_snap_hidden()


func _on_player_stumbled(_kind: StringName) -> void:
	if machine.is_in(MENU) or machine.is_in(RETREAT):
		return
	_chase_left = _cfg.stumble_window
	machine.transition_to(CHASE, true)
	if position.z > HIDDEN_Z - 1.0:
		position.x = target_x


func _on_player_crashed(kind: StringName) -> void:
	if kind == &"gap" or machine.is_in(MENU):
		return
	if not visible or position.z > CATCH_ENTRY.z:
		# Out of sight behind the camera: come in from the right instead of running under the lens.
		position = Vector3(target_x + CATCH_ENTRY.x, 0.0, CATCH_ENTRY.z)
		if _visual != null:
			_visual.scale = Vector3.ONE * CATCH_SCALE
			_visual.rotation.y = atan2(CATCH_ENTRY.x, CATCH_ENTRY.z)
	machine.transition_to(CATCH, true)


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	rex = TRex.new()
	root.add_child(rex)
	return root


## One class serves every chaser state: each just declares where the chaser should be.
class ChaserState extends State:
	var _z: float = 0.0
	var _shown: bool = false
	var _scale: float = 1.0

	func _init(z: float, shown: bool, goal_scale: float) -> void:
		_z = z
		_shown = shown
		_scale = goal_scale

	func enter(_prev: StringName) -> void:
		(host as Chaser).set_goal(_z, _shown, _scale)

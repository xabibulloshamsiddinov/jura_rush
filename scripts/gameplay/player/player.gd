## The runner. Stays at world z = 0 (the world moves, see TrackManager) and only moves sideways
## between lanes and vertically. Behaviour lives in the state machine (player_states/*), input
## arrives as buffered Commands, and extra abilities are child components.
##
## State transitions
##   Run     -> Jump (jump) | Roll (roll) | Fall (ground gone) | Stumble (hit) | Jetpack | Dead
##   Jump    -> Fall (apex) | Roll (slam + land) | Run (land) | Stumble | Jetpack | Dead
##   Fall    -> Run (land) | Roll (slam + land) | Jump (coyote) | Stumble | Jetpack | Dead
##   Roll    -> Run (timer) | Jump (jump cancels roll) | Fall | Stumble | Jetpack | Dead
##   Stumble -> Run / Fall (timer) | Jump | Roll | Dead (second hit) | Jetpack
##   Jetpack -> Fall (power-up ends)
##   Dead    -> Run (revive / reset)
class_name Player
extends CharacterBody3D

const RUN: StringName = &"run"
const JUMP: StringName = &"jump"
const FALL: StringName = &"fall"
const ROLL: StringName = &"roll"
const STUMBLE: StringName = &"stumble"
const JETPACK: StringName = &"jetpack"
const DEAD: StringName = &"dead"
const PIT_DEATH_Y: float = -1.4

var track: TrackManager = null
## Target lane index (0 = left).
var lane: int = 1
var previous_lane: int = 1
## Height of the feet above the rails.
var feet_y: float = 0.0
var vertical_speed: float = 0.0
var on_ground: bool = true
var is_dead: bool = false
var rolling: bool = false
var dashing: bool = false
var flying: bool = false
## True after a mid-air roll input: land, then roll.
var slam_pending: bool = false
var coyote_left: float = 0.0
var machine: StateMachine = null
var health: PlayerComponents.Health = null
var shield: PlayerComponents.Shield = null
var magnet: PlayerComponents.Magnet = null
var powerups: PowerupController = null
var trail: TrailComponent = null
var visual: PlayerVisual = null
var sky_coins: SkyCoinTrail = null

var _cfg: GameConfig = GameConfig.current()
var _lane_from_x: float = 0.0
var _lane_t: float = 1.0
var _lane_duration: float = 0.12
var _lean: float = 0.0
var _invulnerable_left: float = 0.0
var _buffered: Command = null
var _capsule: CapsuleShape3D = null
var _collider: CollisionShape3D = null
var _shadow: MeshInstance3D = null


func _ready() -> void:
	collision_layer = 1 << 1
	collision_mask = 0
	_capsule = CapsuleShape3D.new()
	_capsule.radius = _cfg.player_half_width
	_collider = CollisionShape3D.new()
	_collider.shape = _capsule
	add_child(_collider)
	_set_collider_height(_cfg.player_height)
	visual = PlayerVisual.new()
	add_child(visual)
	health = PlayerComponents.Health.new()
	shield = PlayerComponents.Shield.new()
	magnet = PlayerComponents.Magnet.new()
	powerups = PowerupController.new()
	powerups.player = self
	trail = TrailComponent.new()
	for component: Node in [health, shield, magnet, powerups, trail]:
		add_child(component)
	_shadow = MeshLib.mi(MeshLib.plane(), Mats.blob_shadow(), Vector3.ZERO, Vector3(1.3, 1.0, 1.3))
	_shadow.top_level = true
	add_child(_shadow)
	machine = StateMachine.new()
	add_child(machine)
	machine.add_state(RUN, RunState.new(), self)
	machine.add_state(JUMP, JumpState.new(), self)
	machine.add_state(FALL, FallState.new(), self)
	machine.add_state(ROLL, RollState.new(), self)
	machine.add_state(STUMBLE, StumbleState.new(), self)
	machine.add_state(JETPACK, JetpackState.new(), self)
	machine.add_state(DEAD, DeadState.new(), self)
	machine.start(RUN)
	apply_loadout()


## Applies the equipped skin and trail from the save.
func apply_loadout() -> void:
	visual.apply_character(ContentDB.character(SaveSystem.equipped(&"character")))
	trail.apply_trail(ContentDB.trail(SaveSystem.equipped(&"trail")))


## Puts the runner back at the start line for a new run.
func reset() -> void:
	powerups.clear_all()
	is_dead = false
	lane = 1
	previous_lane = 1
	feet_y = 0.0
	vertical_speed = 0.0
	on_ground = true
	rolling = false
	slam_pending = false
	dashing = false
	flying = false
	_lane_t = 1.0
	_invulnerable_left = 0.0
	_buffered = null
	health.reset()
	visual.visible = true
	trail.clear_points()
	_set_collider_height(_cfg.player_height)
	position = Vector3(_cfg.lane_x(lane), 0.0, 0.0)
	machine.transition_to(RUN, true)


## Brings a dead runner back (revive): centre of the current lane, on the ground, protected.
func revive() -> void:
	is_dead = false
	feet_y = 0.0
	vertical_speed = 0.0
	on_ground = true
	slam_pending = false
	_lane_t = 1.0
	health.reset()
	position = Vector3(_cfg.lane_x(lane), 0.0, 0.0)
	grant_invulnerability(2.5)
	machine.transition_to(RUN, true)
	GameEvents.player_revived.emit()


## Queues a command. It runs now if the current state accepts it, otherwise it stays buffered
## for input_buffer_time and is retried every tick (jump / lane buffering).
func push_command(cmd: Command) -> void:
	if is_dead:
		return
	if machine.handle(cmd):
		_buffered = null
	else:
		_buffered = cmd


## One fixed step of player simulation. Called by GameWorld while the run is live.
func tick(delta: float) -> void:
	_retry_buffer()
	machine.physics_update(delta)
	_update_lane(delta)
	if not flying:
		_update_vertical(delta)
	health.tick(delta)
	shield.tick(delta)
	powerups.tick(delta)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	position.y = feet_y
	_update_visual(delta)


## Animation-only update for the menu showcase / countdown (no physics).
func idle_tick(delta: float, jogging: bool) -> void:
	visual.set_pose(PlayerVisual.Pose.RUN if jogging else PlayerVisual.Pose.IDLE)
	visual.animate(delta, 9.0, 0.0)
	_shadow.global_position = Vector3(position.x, 0.03, 0.0)
	trail.tick(delta, 0.0, position, false)


## Speed ramp fraction 0..1 at the current world speed.
func speed_fraction() -> float:
	return _cfg.speed_fraction(track.world_speed / maxf(track.speed_multiplier, 1.0))


## Current collision height (shorter while rolling).
func body_height() -> float:
	return _cfg.roll_height if rolling else _cfg.player_height


## True while nothing can hurt the runner.
func is_invulnerable() -> bool:
	return is_dead or flying or dashing or _invulnerable_left > 0.0


## True while obstacles should be smashed instead of hurting (dash).
func smashes_obstacles() -> bool:
	return dashing and not is_dead


## Makes the runner untouchable for a while (blinking).
func grant_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


## True while sliding between two lanes.
func is_changing_lane() -> bool:
	return _lane_t < 1.0


## Command target: change lane. Returns true when consumed.
func do_lane(direction: int) -> bool:
	var target: int = lane + direction
	if target < 0 or target >= _cfg.lane_count:
		return true
	previous_lane = lane
	lane = target
	_lane_from_x = position.x
	_lane_t = 0.0
	_lane_duration = _cfg.lane_time_at(speed_fraction())
	trail.burst()
	GameEvents.lane_changed.emit(previous_lane, lane)
	return true


## Command target: jump. Returns false (stay buffered) when not grounded and out of coyote time.
func do_jump() -> bool:
	if flying:
		return true
	if not on_ground and coyote_left <= 0.0:
		return false
	machine.transition_to(JUMP, true)
	return true


## Command target: roll on the ground, or slam down when airborne.
func do_roll() -> bool:
	if flying:
		return true
	if on_ground:
		machine.transition_to(ROLL, true)
	else:
		slam_pending = true
		vertical_speed = -_cfg.slam_speed
	return true


## Applies a hit from an obstacle. lethal = dies outright; otherwise it is a stumble (and the
## second stumble inside stumble_window kills). side = hit while changing lane (bump back).
func take_hit(lethal: bool, kind: StringName, obstacle: ObstacleBase, side: bool) -> void:
	if is_invulnerable():
		return
	if shield.absorb():
		obstacle.smash()
		grant_invulnerability(0.8)
		return
	if lethal or health.register_hit():
		die(kind)
		return
	grant_invulnerability(_cfg.i_frames)
	if side:
		_bump_back()
	machine.transition_to(STUMBLE, true)
	GameEvents.player_stumbled.emit(kind)


## Kills the runner. GameState reacts to player_crashed (hit-stop, revive offer...).
func die(kind: StringName) -> void:
	if is_dead:
		return
	is_dead = true
	powerups.clear_all()
	machine.transition_to(DEAD, true)
	GameEvents.player_crashed.emit(kind)


## Enters jetpack flight (called by the jetpack power-up strategy).
func start_jetpack() -> void:
	machine.transition_to(JETPACK, true)
	if sky_coins != null:
		sky_coins.spawn(track.world_speed, powerups.remaining(&"jetpack"), lane)


## Leaves jetpack flight: fall back down, protected until shortly after landing.
func stop_jetpack() -> void:
	if machine.is_in(JETPACK):
		grant_invulnerability(2.0)
		machine.transition_to(FALL, true)


## Resizes the collision capsule (roll shrinks it).
func set_rolling(value: bool) -> void:
	rolling = value
	_set_collider_height(body_height())


func _retry_buffer() -> void:
	if _buffered == null:
		return
	var age: float = float(Time.get_ticks_msec() - _buffered.created_msec) * 0.001 * Engine.time_scale
	if age > _cfg.input_buffer_time:
		_buffered = null
	elif machine.handle(_buffered):
		_buffered = null


func _update_lane(delta: float) -> void:
	var target_x: float = _cfg.lane_x(lane)
	if _lane_t < 1.0:
		_lane_t = minf(_lane_t + delta / maxf(_lane_duration, 0.01), 1.0)
		position.x = lerpf(_lane_from_x, target_x, MathUtils.ease_out_cubic(_lane_t))
		_lean = signf(target_x - _lane_from_x) * (1.0 - _lane_t) * 0.35
	else:
		position.x = target_x
		_lean = 0.0


func _update_vertical(delta: float) -> void:
	var ground: float = track.get_ground_height(_cfg.lane_at_x(position.x), 0.0)
	if dashing and ground < 0.0:
		ground = 0.0
	if on_ground:
		if ground < feet_y - 0.05:
			on_ground = false
			coyote_left = _cfg.coyote_time
			vertical_speed = 0.0
		elif ground > feet_y and ground - feet_y <= _cfg.step_height:
			feet_y = ground
	else:
		coyote_left -= delta
		var f: float = speed_fraction()
		var gravity: float = _cfg.jump_gravity(f)
		if vertical_speed <= 0.0:
			gravity *= _cfg.gravity_down_multiplier
		var before: float = feet_y
		vertical_speed -= gravity * delta
		feet_y += vertical_speed * delta
		# Land only on a surface that was below the feet (never snap up into a wall).
		if vertical_speed <= 0.0 and feet_y <= ground and before >= ground - 0.3:
			_land(ground)
		elif feet_y < PIT_DEATH_Y:
			if is_dead:
				feet_y = maxf(feet_y, -6.0)
				vertical_speed = 0.0
			else:
				die(&"gap")


func _land(ground: float) -> void:
	var impact: float = -vertical_speed
	feet_y = ground
	vertical_speed = 0.0
	on_ground = true
	if is_dead:
		return
	GameEvents.player_landed.emit(impact)
	if slam_pending:
		slam_pending = false
		machine.transition_to(ROLL, true)
	elif machine.is_in(JUMP) or machine.is_in(FALL):
		machine.transition_to(RUN)


func _bump_back() -> void:
	var back: int = previous_lane
	previous_lane = lane
	lane = back
	_lane_from_x = position.x
	_lane_t = 0.0
	_lane_duration = _cfg.lane_change_time
	GameEvents.lane_changed.emit(previous_lane, lane)


func _set_collider_height(height: float) -> void:
	_capsule.height = maxf(height, _capsule.radius * 2.0)
	_collider.position.y = height * 0.5


func _update_visual(delta: float) -> void:
	var blinking: bool = _invulnerable_left > 0.0 and not is_dead and not dashing
	visual.visible = not blinking or fmod(_invulnerable_left, 0.16) < 0.09
	visual.animate(delta, 9.0 + speed_fraction() * 5.0, _lean)
	var ground: float = maxf(track.get_ground_height(_cfg.lane_at_x(position.x), 0.0), 0.0)
	_shadow.global_position = Vector3(position.x, ground + 0.03, 0.0)
	var shrink: float = clampf(1.0 - (feet_y - ground) * 0.18, 0.4, 1.0)
	_shadow.scale = Vector3(1.3 * shrink, 1.0, 1.3 * shrink)
	trail.tick(delta, track.world_speed, position + Vector3(0.0, 0.9, 0.25), not is_dead)

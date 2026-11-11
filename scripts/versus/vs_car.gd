## One player's car in the versus mode: lane steering, relative speed (gas / brake / nitro),
## health, lives, three power-up slots, status timers and the police "bust" meter.
## Pure state + presentation; VsGame decides collisions and damage.
class_name VsCar
extends Node3D

## Per-tick controls (filled from the keyboard or by the test bot).
class Pad extends RefCounted:
	var left: bool = false
	var right: bool = false
	var gas: bool = false
	var brake: bool = false
	var fire: bool = false
	var cycle: bool = false

	func clear() -> void:
		left = false
		right = false
		gas = false
		brake = false
		fire = false
		cycle = false


var index: int = 0
var lane: int = 2
var prev_lane: int = 2
var rel_speed: float = 0.0
## Extra relative speed from hits (negative = shoved backward), decays to 0.
var impulse: float = 0.0
var health: float = VsDefs.MAX_HEALTH
var lives: int = VsDefs.LIVES
var slots: Array[StringName] = []
var shield_t: float = 0.0
var nitro_t: float = 0.0
var brake_jump_t: float = 0.0
var jam_t: float = 0.0
var ghost_t: float = 0.0
var respawn_t: float = 0.0
var bust: float = 0.0
var fans: int = 0
var stats: Dictionary = {}
var pad: Pad = Pad.new()
var model: VsModels.Vehicle = null
var trail_l: TrailComponent = null
var trail_r: TrailComponent = null

var _spin: float = 0.0
var _spin_v: float = 0.0
var _hop: float = 0.0
var _hop_v: float = 0.0
var _lean: float = 0.0
var _flash: float = 0.0


func _init(player_index: int) -> void:
	index = player_index


func _ready() -> void:
	model = VsModels.player_car(VsDefs.PLAYER_COLORS[index], VsDefs.PLAYER_GLOW[index])
	add_child(model)
	var trail_def: TrailDef = TrailDef.new()
	trail_def.color = Color(1.0, 0.1, 0.12)
	trail_def.width = 0.16
	trail_def.length = 14
	trail_l = TrailComponent.new()
	trail_r = TrailComponent.new()
	add_child(trail_l)
	add_child(trail_r)
	trail_l.apply_trail(trail_def)
	trail_r.apply_trail(trail_def)
	reset_for_match()


## Fresh state for a new match.
func reset_for_match() -> void:
	lives = VsDefs.LIVES
	fans = 0
	stats = {"hits": 0, "wrecks": 0, "busts": 0, "smashed": 0, "used": 0, "pickups": 0, "damage": 0}
	slots.clear()
	respawn(2 - 1 + index * 2)
	ghost_t = 0.0


## Puts the car back on the road (after a wreck / bust, or at the start).
func respawn(start_lane: int) -> void:
	lane = clampi(start_lane, 0, VsDefs.LANES - 1)
	prev_lane = lane
	position = Vector3(VsDefs.lane_x(lane), 0.0, VsDefs.SPAWN_Z)
	rel_speed = 0.0
	impulse = 0.0
	health = VsDefs.MAX_HEALTH
	shield_t = 0.0
	nitro_t = 0.0
	brake_jump_t = 0.0
	jam_t = 0.0
	bust = 0.0
	respawn_t = 0.0
	ghost_t = VsDefs.RESPAWN_GHOST
	_spin = 0.0
	_spin_v = 0.0
	_hop = 0.0
	_hop_v = 0.0
	visible = true
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	trail_l.clear_points()
	trail_r.clear_points()


## True while the car is on the road and can be hit.
func alive() -> bool:
	return respawn_t <= 0.0


## True when damage should be ignored.
func protected() -> bool:
	return shield_t > 0.0 or ghost_t > 0.0 or not alive()


## Steering + speed integration for one physics tick. Returns the lane change made (-1/0/1).
func drive(delta: float, police_z: float) -> int:
	var changed: int = 0
	if not alive():
		return 0
	if jam_t <= 0.0:
		if pad.left and lane > 0:
			prev_lane = lane
			lane -= 1
			changed = -1
		elif pad.right and lane < VsDefs.LANES - 1:
			prev_lane = lane
			lane += 1
			changed = 1
	var target: float = VsDefs.COAST_REL
	if pad.gas:
		target = VsDefs.GAS_REL
	elif pad.brake:
		target = VsDefs.BRAKE_REL
	if nitro_t > 0.0:
		target = VsDefs.NITRO_REL
	if brake_jump_t > 0.0:
		target = -VsDefs.NITRO_REL
	if jam_t > 0.0:
		target = minf(target, VsDefs.COAST_REL)
	var accel: float = VsDefs.REL_ACCEL * (3.0 if (nitro_t > 0.0 or brake_jump_t > 0.0) else 1.0)
	rel_speed = MathUtils.damp(rel_speed, target, 1.0 / accel, delta)
	impulse = MathUtils.damp(impulse, 0.0, 0.35, delta)
	position.z -= (rel_speed + impulse) * delta
	position.z = clampf(position.z, VsDefs.FRONT_Z, police_z - 1.2)
	var goal_x: float = VsDefs.lane_x(lane)
	if jam_t > 0.0:
		goal_x += sin(Time.get_ticks_msec() * 0.03) * 0.25
	var before: float = position.x
	position.x = MathUtils.damp(position.x, goal_x, VsDefs.LANE_TIME * 0.35, delta)
	_lean = MathUtils.damp(_lean, (position.x - before) / maxf(delta, 0.001) * 0.018, 0.08, delta)
	return changed


## Timers, visual pose, trails. road_speed = world scroll speed.
func tick_visual(delta: float, road_speed: float) -> void:
	shield_t = maxf(shield_t - delta, 0.0)
	nitro_t = maxf(nitro_t - delta, 0.0)
	brake_jump_t = maxf(brake_jump_t - delta, 0.0)
	jam_t = maxf(jam_t - delta, 0.0)
	ghost_t = maxf(ghost_t - delta, 0.0)
	_flash = maxf(_flash - delta * 4.0, 0.0)
	model.animate(delta, road_speed + rel_speed)
	model.flames.visible = nitro_t > 0.0
	if model.flames.visible:
		model.flames.scale = Vector3.ONE * (0.9 + randf() * 0.35)
	model.shield.visible = shield_t > 0.0
	if model.shield.visible:
		model.shield_material.set_shader_parameter(&"hit", _flash)
		model.shield_material.set_shader_parameter(&"strength", 0.5 if shield_t < 1.2 and fmod(shield_t, 0.25) < 0.12 else 1.0)
	# Hit spin / hop, lane lean, brake pitch.
	_spin += _spin_v * delta
	_spin_v = MathUtils.damp(_spin_v, 0.0, 0.25, delta)
	if absf(_spin_v) < 1.5:
		_spin = MathUtils.damp(wrapf(_spin, -PI, PI), 0.0, 0.14, delta)
	_hop_v -= 30.0 * delta
	_hop = maxf(_hop + _hop_v * delta, 0.0)
	if _hop <= 0.0:
		_hop_v = 0.0
	var pitch: float = clampf(-(rel_speed + impulse) * 0.004, -0.06, 0.06)
	model.body.rotation = Vector3(pitch, _spin, -_lean)
	model.body.position.y = _hop
	if ghost_t > 0.0 and alive():
		model.visible = fmod(ghost_t, 0.2) < 0.13
	else:
		model.visible = true
	model.underglow.scale = Vector3(3.0, 1.0, 5.6) * (1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.008))
	var emit: bool = alive() and road_speed > 1.0
	var tail_z: float = position.z + 2.3
	var y: float = 0.62 + _hop
	trail_l.tick(delta, road_speed, Vector3(position.x - 0.68, y, tail_z), emit)
	trail_r.tick(delta, road_speed, Vector3(position.x + 0.68, y, tail_z), emit)


## Visual reaction to a hit: spin and hop proportional to the strength.
func knock(strength: float) -> void:
	_spin_v += (1.0 if randf() < 0.5 else -1.0) * strength * 14.0
	_hop_v = maxf(_hop_v, strength * 7.0)
	_flash = 1.0


## Adds a power-up to the first free slot. Returns false when all slots are full.
func give(id: StringName) -> bool:
	if slots.size() >= VsDefs.SLOTS:
		return false
	slots.append(id)
	return true


## Removes and returns the active (first) power-up, or &"" when empty.
func take() -> StringName:
	if slots.is_empty():
		return &""
	return slots.pop_front() as StringName


## Rotates the slots so the next power-up becomes active.
func cycle() -> void:
	if slots.size() > 1:
		slots.append(slots.pop_front())


## Hides the car while it waits to respawn.
func wreck() -> void:
	respawn_t = VsDefs.RESPAWN_TIME
	visible = false
	slots.clear()
	trail_l.clear_points()
	trail_r.clear_points()

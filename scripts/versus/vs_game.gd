## The 2 Player versus match ("Neon Pursuit"). Two cars share a 5-lane night highway, dodge
## traffic, collect combat power-ups and try to wreck each other while a police cruiser closes
## in behind each of them. Three lives each: lose them all (wrecked or busted) and the other
## player wins; when the clock runs out, more lives (then more fans) wins.
##
## Step order while racing: speed -> road -> spawns -> cars -> police -> traffic -> weapons ->
## collisions -> respawns -> camera. Sounds and effects leave through the `fx` signal only.
class_name VsGame
extends Node3D

## Presentation hook: kind of event, where, tint, player involved (-1 = none).
signal fx(kind: StringName, pos: Vector3, color: Color, player: int)

const LANE_FRAC: Array[float] = [0.5, 0.57, 0.63, 0.57, 0.5]

## Testing hook (--versus-time=S): shorter matches. 0 = VsDefs.MATCH_TIME.
static var match_time_override: float = 0.0


class Traffic extends RefCounted:
	var node: VsModels.Vehicle = null
	var lane: int = 0
	var z: float = 0.0
	var x: float = 0.0
	var frac: float = 0.5
	var knocked: bool = false
	var vel: Vector3 = Vector3.ZERO
	var spin: Vector3 = Vector3.ZERO
	var life: float = 0.0
	var near_done: Array[bool] = [false, false]


class Orb extends RefCounted:
	var node: Node3D = null
	var id: StringName = &""
	var x: float = 0.0
	var z: float = 0.0
	var t: float = 0.0


class Shot extends RefCounted:
	var node: Node3D = null
	var kind: StringName = &""
	var owner: int = 0
	var dir: float = -1.0
	var x: float = 0.0
	var z: float = 0.0
	## &"car", &"police", &"traffic" or &"none".
	var target_kind: StringName = &"none"
	var target_index: int = -1
	var target_traffic: Traffic = null
	var life: float = 0.0
	var dead: bool = false


class Hazard extends RefCounted:
	var node: Node3D = null
	## &"mine" or &"dome".
	var kind: StringName = &""
	var owner: int = 0
	var x: float = 0.0
	var z: float = 0.0
	var arm: float = 0.0
	var t: float = 0.0
	var dead: bool = false


## &"countdown", &"race", &"over".
var phase: StringName = &"countdown"
var paused: bool = false
var time_left: float = VsDefs.MATCH_TIME
var match_time: float = VsDefs.MATCH_TIME
var speed: float = VsDefs.START_SPEED
var countdown: int = 3
var cars: Array[VsCar] = []
var police_z: Array[float] = [20.0, 20.0]
var police_x: Array[float] = [0.0, 0.0]
var police: Array[VsModels.Vehicle] = []
var camera: VsCamera = null
var road: VsRoad = null
## Test bots per player (null = keyboard).
var bots: Array[VsBot] = [null, null]
var result: Dictionary = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _traffic: Array[Traffic] = []
var _orbs: Array[Orb] = []
var _shots: Array[Shot] = []
var _hazards: Array[Hazard] = []
var _traffic_left: float = 20.0
var _orb_left: float = 30.0
var _count_left: float = 0.0
var _over_left: float = 0.0
var _elapsed: float = 0.0
var _bolt_queue: Array[int] = [0, 0]
var _bolt_dir: Array[float] = [-1.0, -1.0]
var _bolt_timer: Array[float] = [0.0, 0.0]
var _ram_cool: float = 0.0
var _env: Environment = null
var _sky: ProceduralSkyMaterial = null
var _bend_phase: float = 0.0
var _props: Node3D = null

const ACTIONS: Array[Array] = [
	[&"vs1_left", &"vs1_right", &"vs1_gas", &"vs1_brake", &"vs1_fire", &"vs1_cycle"],
	[&"vs2_left", &"vs2_right", &"vs2_gas", &"vs2_brake", &"vs2_fire", &"vs2_cycle"],
]


func _ready() -> void:
	VsInput.ensure()
	_build_environment()
	road = VsRoad.new()
	add_child(road)
	_props = Node3D.new()
	add_child(_props)
	for i in range(2):
		var car: VsCar = VsCar.new(i)
		add_child(car)
		cars.append(car)
		var cop: VsModels.Vehicle = VsModels.police()
		add_child(cop)
		police.append(cop)
	camera = VsCamera.new()
	add_child(camera)
	GameEvents.settings_changed.connect(_apply_palette)


## Starts (or restarts) a match from the countdown.
func start_match(match_seed: int = 0) -> void:
	_rng.seed = match_seed if match_seed != 0 else int(Time.get_ticks_usec())
	_clear_entities()
	road.reset()
	for car: VsCar in cars:
		car.reset_for_match()
	for i in range(2):
		police_z[i] = cars[i].position.z + VsDefs.POLICE_RESET_GAP + 6.0
		police_x[i] = cars[i].position.x
		_bolt_queue[i] = 0
	phase = &"countdown"
	paused = false
	countdown = 3
	_count_left = VsDefs.COUNTDOWN_STEP
	match_time = match_time_override if match_time_override > 0.0 else VsDefs.MATCH_TIME
	time_left = match_time
	_elapsed = 0.0
	speed = VsDefs.START_SPEED
	_traffic_left = 45.0
	_orb_left = 25.0
	result = {}
	_apply_palette()
	camera.activate()
	GameEvents.versus_countdown.emit(countdown)


func set_paused(value: bool) -> void:
	if phase == &"over":
		value = false
	paused = value


## Fraction 0..1 of the speed ramp.
func speed_fraction() -> float:
	return clampf((speed - VsDefs.START_SPEED) / (VsDefs.MAX_SPEED - VsDefs.START_SPEED), 0.0, 1.0)


## Read-only snapshot for the HUD (UI reads, never writes).
func snapshot() -> Dictionary:
	var players: Array[Dictionary] = []
	for i in range(2):
		var c: VsCar = cars[i]
		players.append({
			"health": c.health / VsDefs.MAX_HEALTH,
			"lives": c.lives,
			"slots": c.slots.duplicate(),
			"fans": c.fans,
			"bust": clampf(c.bust, 0.0, 1.0),
			"police_gap": police_z[i] - c.position.z,
			"shield": c.shield_t,
			"nitro": c.nitro_t,
			"jam": c.jam_t,
			"alive": c.alive(),
			"respawn": c.respawn_t,
			"ahead": c.position.z < cars[1 - i].position.z,
		})
	return {"phase": phase, "time": time_left, "players": players, "speed": speed, "paused": paused}


## Positions of things a driver should avoid (traffic, armed hazards). Used by the bot.
func blockers() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for t: Traffic in _traffic:
		if not t.knocked:
			out.append(Vector3(t.x, 0.0, t.z + t.node.length * 0.5))
	for h: Hazard in _hazards:
		out.append(Vector3(h.x, 0.0, h.z))
	return out


## Positions of power-up orbs on the road. Used by the bot.
func orb_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for o: Orb in _orbs:
		out.append(Vector3(o.x, 0.0, o.z))
	return out


func _physics_process(delta: float) -> void:
	if paused:
		return
	match phase:
		&"countdown":
			_count_left -= delta
			if _count_left <= 0.0:
				countdown -= 1
				_count_left = VsDefs.COUNTDOWN_STEP
				GameEvents.versus_countdown.emit(maxi(countdown, 0))
				if countdown <= 0:
					phase = &"race"
			_tick_world(delta, speed * 0.25, false)
		&"race":
			_elapsed += delta
			time_left = maxf(time_left - delta, 0.0)
			speed = lerpf(VsDefs.START_SPEED, VsDefs.MAX_SPEED, clampf(_elapsed / VsDefs.RAMP_TIME, 0.0, 1.0))
			_tick_world(delta, speed, true)
			if time_left <= 0.0:
				_finish(-2)
		&"over":
			_over_left -= delta
			_tick_world(delta, speed * 0.6, false)


func _tick_world(delta: float, road_speed: float, live: bool) -> void:
	var step: float = road_speed * delta
	road.advance(step)
	_bend_phase += delta * 0.07
	RenderingServer.global_shader_parameter_set(&"bend_x", sin(_bend_phase) * 0.0055)
	if live:
		_spawn(step)
	for i in range(2):
		var car: VsCar = cars[i]
		_read_pad(i)
		if live:
			var change: int = car.drive(delta, police_z[i])
			if change != 0:
				fx.emit(&"lane", car.position, Color.WHITE, i)
			if car.pad.cycle and car.slots.size() > 1:
				car.cycle()
				fx.emit(&"cycle", car.position, Color.WHITE, i)
			if car.pad.fire and car.alive():
				_fire(i)
			_tick_bolts(i, delta)
		car.tick_visual(delta, road_speed)
	_tick_police(delta, road_speed, live)
	_tick_traffic(delta, road_speed, live)
	_tick_orbs(delta, step)
	if live:
		_tick_shots(delta)
		_tick_hazards(delta, step)
		_collide(delta)
		_tick_respawns(delta)
	var xs: Array[float] = []
	var zs: Array[float] = []
	for car: VsCar in cars:
		if car.alive():
			xs.append(car.position.x)
			zs.append(car.position.z)
	camera.tick(delta, xs, zs)


func _read_pad(i: int) -> void:
	var pad: VsCar.Pad = cars[i].pad
	if bots[i] != null:
		bots[i].think(self, i, pad)
		return
	var a: Array = ACTIONS[i]
	pad.left = Input.is_action_just_pressed(a[0])
	pad.right = Input.is_action_just_pressed(a[1])
	pad.gas = Input.is_action_pressed(a[2])
	pad.brake = Input.is_action_pressed(a[3])
	pad.fire = Input.is_action_just_pressed(a[4])
	pad.cycle = Input.is_action_just_pressed(a[5])


# --- Spawning -------------------------------------------------------------------

func _spawn(step: float) -> void:
	_traffic_left -= step
	if _traffic_left <= 0.0:
		var gap: float = lerpf(VsDefs.TRAFFIC_GAP_START, VsDefs.TRAFFIC_GAP_END, clampf(_elapsed / 120.0, 0.0, 1.0))
		_traffic_left = gap * _rng.randf_range(0.8, 1.3)
		_spawn_traffic_row()
	_orb_left -= step
	if _orb_left <= 0.0:
		_orb_left = VsDefs.ORB_GAP * _rng.randf_range(0.8, 1.2)
		_spawn_orb_row()


func _lane_free(lane: int, z: float, margin: float) -> bool:
	for t: Traffic in _traffic:
		if not t.knocked and t.lane == lane and absf(t.z - z) < margin + t.node.length * 0.5:
			return false
	return true


func _spawn_traffic_row() -> void:
	var roll: float = _rng.randf()
	var count: int = 1 if roll < 0.35 else (2 if roll < 0.82 else 3)
	var lanes: Array[int] = [0, 1, 2, 3, 4]
	for i in range(lanes.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = lanes[i]
		lanes[i] = lanes[j]
		lanes[j] = tmp
	var z: float = VsDefs.SPAWN_Z_FAR
	for lane: int in lanes:
		if count <= 0:
			break
		if not _lane_free(lane, z, 14.0):
			continue
		var kind_roll: float = _rng.randf()
		var kind: int = 0 if kind_roll < 0.6 else (1 if kind_roll < 0.86 else 2)
		var t: Traffic = Traffic.new()
		t.node = VsModels.traffic(kind, _rng)
		t.lane = lane
		t.x = VsDefs.lane_x(lane)
		t.z = z
		t.frac = LANE_FRAC[lane] * (0.9 if kind == 2 else 1.0)
		t.node.position = Vector3(t.x, 0.0, t.z)
		_props.add_child(t.node)
		_traffic.append(t)
		count -= 1


func _spawn_orb_row() -> void:
	var count: int = 2 if _rng.randf() < 0.6 else 3
	var z: float = VsDefs.SPAWN_Z_FAR + 10.0
	var used: Array[int] = []
	var tries: int = 0
	while used.size() < count and tries < 20:
		tries += 1
		var lane: int = _rng.randi_range(0, VsDefs.LANES - 1)
		if used.has(lane) or not _lane_free(lane, z, 10.0):
			continue
		used.append(lane)
		var o: Orb = Orb.new()
		o.id = VsDefs.random_powerup(_rng)
		o.node = VsModels.orb(o.id)
		o.x = VsDefs.lane_x(lane)
		o.z = z
		o.t = _rng.randf() * TAU
		o.node.position = Vector3(o.x, 0.0, o.z)
		_props.add_child(o.node)
		_orbs.append(o)


# --- Police --------------------------------------------------------------------

func _tick_police(delta: float, road_speed: float, live: bool) -> void:
	var gap: float = lerpf(VsDefs.POLICE_GAP_START, VsDefs.POLICE_GAP_END,
			clampf(_elapsed / match_time, 0.0, 1.0))
	for i in range(2):
		var car: VsCar = cars[i]
		var goal: float = car.position.z + gap
		if not car.alive():
			goal = VsDefs.SPAWN_Z + VsDefs.POLICE_RESET_GAP
			police_z[i] = move_toward(police_z[i], goal, 12.0 * delta)
		elif goal < police_z[i]:
			police_z[i] = move_toward(police_z[i], goal, VsDefs.POLICE_FORWARD_RATE * delta)
		else:
			police_z[i] = move_toward(police_z[i], goal, VsDefs.POLICE_BACK_RATE * delta)
		police_x[i] = MathUtils.damp(police_x[i], car.position.x, 0.45, delta)
		var cop: VsModels.Vehicle = police[i]
		var other: float = police_x[1 - i]
		var x: float = police_x[i]
		# Keep the two cruisers from overlapping.
		if absf(x - other) < 2.3 and absf(police_z[i] - police_z[1 - i]) < 5.0:
			x += (1.0 if i == 1 else -1.0) * (2.3 - absf(x - other)) * 0.5
		cop.position = Vector3(x, 0.0, police_z[i])
		cop.rotation.y = clampf((car.position.x - x) * -0.05, -0.2, 0.2)
		cop.animate(delta, road_speed)
		if not live or not car.alive():
			car.bust = maxf(car.bust - delta, 0.0)
			continue
		if police_z[i] - car.position.z < VsDefs.BUST_RANGE and absf(car.position.x - x) < 2.6:
			car.bust += delta / VsDefs.BUST_TIME
			if car.bust >= 1.0:
				_busted(i)
		else:
			car.bust = maxf(car.bust - delta * 0.7, 0.0)


func _push_police(i: int, amount: float) -> void:
	police_z[i] = minf(police_z[i] + amount, cars[i].position.z + VsDefs.POLICE_RESET_GAP + 6.0)
	fx.emit(&"police_hit", police[i].position + Vector3(0.0, 1.0, 0.0), Color(0.3, 0.5, 1.0), i)


# --- Traffic -------------------------------------------------------------------

func _tick_traffic(delta: float, road_speed: float, live: bool) -> void:
	for k in range(_traffic.size() - 1, -1, -1):
		var t: Traffic = _traffic[k]
		if t.knocked:
			t.life -= delta
			t.vel.y -= 26.0 * delta
			t.node.position += (t.vel + Vector3(0.0, 0.0, road_speed)) * delta
			if t.node.position.y < 0.0:
				t.node.position.y = 0.0
				t.vel.y = absf(t.vel.y) * 0.3
				t.vel.x *= 0.7
			t.node.rotation += t.spin * delta
			t.z = t.node.position.z
			if t.life <= 0.0 or t.z > VsDefs.DESPAWN_Z:
				_remove_traffic(k)
			continue
		var prev: float = t.z
		t.z += road_speed * (1.0 - t.frac) * delta
		t.node.position = Vector3(t.x, 0.0, t.z)
		t.node.animate(delta, road_speed * t.frac)
		if live:
			for i in range(2):
				var car: VsCar = cars[i]
				if t.near_done[i] or not car.alive():
					continue
				if prev < car.position.z and t.z >= car.position.z:
					t.near_done[i] = true
					if absf(car.position.x - t.x) < 4.0:
						car.fans += VsDefs.FANS_NEAR
						fx.emit(&"near", Vector3((car.position.x + t.x) * 0.5, 1.0, car.position.z), Color(0.6, 0.9, 1.0), i)
			# Police cruisers barge through traffic.
			for i in range(2):
				var cop: Vector3 = police[i].position
				if absf(cop.x - t.x) < 2.0 and absf(cop.z - t.z) < (t.node.length * 0.5 + 2.4):
					_knock_traffic(t, cop, 0.7)
					break
		if t.z > VsDefs.DESPAWN_Z + t.node.length:
			_remove_traffic(k)


func _knock_traffic(t: Traffic, from: Vector3, strength: float) -> void:
	if t.knocked:
		return
	t.knocked = true
	t.life = 1.6
	var side: float = signf(t.x - from.x)
	if side == 0.0:
		side = 1.0 if _rng.randf() < 0.5 else -1.0
	t.vel = Vector3(side * _rng.randf_range(5.0, 10.0) * strength, _rng.randf_range(5.0, 9.0) * strength,
			-_rng.randf_range(4.0, 12.0) * strength)
	t.spin = Vector3(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-5.0, 5.0), _rng.randf_range(-4.0, 4.0)) * strength
	fx.emit(&"smash", t.node.position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.7, 0.3), -1)


func _remove_traffic(k: int) -> void:
	_traffic[k].node.queue_free()
	_traffic.remove_at(k)


# --- Orbs ----------------------------------------------------------------------

func _tick_orbs(delta: float, step: float) -> void:
	for k in range(_orbs.size() - 1, -1, -1):
		var o: Orb = _orbs[k]
		o.z += step
		o.t += delta
		o.node.position = Vector3(o.x, sin(o.t * 3.0) * 0.18, o.z)
		o.node.rotation.y = o.t * 1.6
		var ring: Node3D = o.node.get_node(^"Ring") as Node3D
		ring.rotation = Vector3(o.t * 2.3, 0.0, o.t * 1.1)
		if o.z > VsDefs.DESPAWN_Z:
			o.node.queue_free()
			_orbs.remove_at(k)


# --- Weapons -------------------------------------------------------------------

func _fire(i: int) -> void:
	var car: VsCar = cars[i]
	var other: VsCar = cars[1 - i]
	if car.slots.is_empty():
		fx.emit(&"empty", car.position, Color.WHITE, i)
		return
	var id: StringName = car.take()
	var back: bool = car.pad.brake and VsDefs.REVERSIBLE.has(id)
	car.stats["used"] = int(car.stats["used"]) + 1
	var c: Color = VsDefs.color(id)
	var pos: Vector3 = car.position
	match id:
		&"seeker":
			var s: Shot = _new_shot(&"seeker", i, 1.0 if back else -1.0)
			if not back:
				if other.alive() and other.position.z < pos.z - 1.0:
					s.target_kind = &"car"
					s.target_index = 1 - i
				else:
					var best: Traffic = null
					for t: Traffic in _traffic:
						if not t.knocked and t.z < pos.z - 3.0 and t.z > pos.z - 110.0:
							if best == null or absf(t.z - pos.z) + absf(t.x - pos.x) * 4.0 < absf(best.z - pos.z) + absf(best.x - pos.x) * 4.0:
								best = t
					if best != null:
						s.target_kind = &"traffic"
						s.target_traffic = best
			else:
				if other.alive() and other.position.z > pos.z + 1.0:
					s.target_kind = &"car"
					s.target_index = 1 - i
				else:
					s.target_kind = &"police"
					s.target_index = i
			if s.target_kind == &"car":
				fx.emit(&"lock", other.position, c, 1 - i)
				GameEvents.versus_callout.emit(1 - i, Tr.t(&"vs.call.incoming"), c)
			fx.emit(&"fire_seeker", pos, c, i)
		&"bolt":
			_bolt_queue[i] = 3
			_bolt_dir[i] = 1.0 if back else -1.0
			_bolt_timer[i] = 0.0
		&"pulse":
			_pulse(i)
		&"emp":
			_emp(i)
		&"mine":
			var h: Hazard = Hazard.new()
			h.kind = &"mine"
			h.owner = i
			h.x = pos.x
			h.z = pos.z + 3.2
			h.arm = 0.2
			h.node = VsModels.mine()
			h.node.position = Vector3(h.x, 0.0, h.z)
			_props.add_child(h.node)
			_hazards.append(h)
			fx.emit(&"mine_drop", pos, c, i)
		&"nitro":
			if back:
				car.brake_jump_t = VsDefs.BRAKE_JUMP_TIME
				car.nitro_t = 0.0
				fx.emit(&"brake_jump", pos, c, i)
			else:
				car.nitro_t = VsDefs.NITRO_TIME
				car.brake_jump_t = 0.0
				camera.punch(9.0)
				fx.emit(&"nitro", pos, c, i)
		&"shield":
			car.shield_t = VsDefs.SHIELD_TIME
			fx.emit(&"shield", pos, c, i)
		&"repair":
			car.health = minf(car.health + VsDefs.REPAIR_AMOUNT, VsDefs.MAX_HEALTH)
			car.jam_t = 0.0
			fx.emit(&"repair", pos, c, i)
	GameEvents.versus_event.emit(id, i)


func _new_shot(kind: StringName, owner: int, dir: float) -> Shot:
	var s: Shot = Shot.new()
	s.kind = kind
	s.owner = owner
	s.dir = dir
	var pos: Vector3 = cars[owner].position
	s.x = pos.x
	s.z = pos.z + dir * 2.8
	s.life = 3.5 if kind == &"seeker" else 1.2
	s.node = VsModels.projectile(kind)
	s.node.position = Vector3(s.x, 0.0, s.z)
	if dir > 0.0:
		s.node.rotation.y = PI
	_props.add_child(s.node)
	_shots.append(s)
	return s


func _tick_bolts(i: int, delta: float) -> void:
	if _bolt_queue[i] <= 0:
		return
	_bolt_timer[i] -= delta
	if _bolt_timer[i] > 0.0:
		return
	if not cars[i].alive():
		_bolt_queue[i] = 0
		return
	_bolt_timer[i] = 0.13
	_bolt_queue[i] -= 1
	_new_shot(&"bolt", i, _bolt_dir[i])
	fx.emit(&"fire_bolt", cars[i].position, VsDefs.color(&"bolt"), i)


func _pulse(i: int) -> void:
	var car: VsCar = cars[i]
	var other: VsCar = cars[1 - i]
	var pos: Vector3 = car.position
	fx.emit(&"pulse", pos, VsDefs.color(&"pulse"), i)
	var r: float = VsDefs.PULSE_RADIUS
	if other.alive() and Vector2(other.position.x - pos.x, other.position.z - pos.z).length() < r:
		var side: int = 1 if other.position.x >= pos.x else -1
		if absf(other.position.x - pos.x) < 0.3:
			side = 1 if other.lane < 2 else -1
		if _damage(1 - i, VsDefs.DMG_PULSE, i, &"pulse", -8.0, 0.9):
			var to: int = other.lane + side
			if to < 0 or to >= VsDefs.LANES:
				# Slammed into the barrier.
				_damage(1 - i, 8.0, i, &"wall", -4.0, 0.3)
			else:
				other.prev_lane = other.lane
				other.lane = to
	for t: Traffic in _traffic:
		if not t.knocked and Vector2(t.x - pos.x, t.z - pos.z).length() < r + 1.5:
			_knock_traffic(t, pos, 1.3)
			car.fans += VsDefs.FANS_SMASH
	for s: Shot in _shots:
		if s.owner != i and Vector2(s.x - pos.x, s.z - pos.z).length() < r:
			_kill_shot(s, true)
			car.fans += VsDefs.FANS_BLOCK
	for h: Hazard in _hazards:
		if Vector2(h.x - pos.x, h.z - pos.z).length() < r:
			_kill_hazard(h, true)
	for k in range(2):
		if police_z[k] - pos.z < r and absf(police[k].position.x - pos.x) < r:
			_push_police(k, 7.0)


func _emp(i: int) -> void:
	var other: VsCar = cars[1 - i]
	var target_lane: int = other.lane if other.alive() else _rng.randi_range(0, VsDefs.LANES - 1)
	var base_z: float = (other.position.z if other.alive() else VsDefs.SPAWN_Z) - 46.0
	var lanes: Array[int] = [target_lane]
	while lanes.size() < 3:
		var l: int = _rng.randi_range(0, VsDefs.LANES - 1)
		if not lanes.has(l):
			lanes.append(l)
	for l: int in lanes:
		var h: Hazard = Hazard.new()
		h.kind = &"dome"
		h.owner = i
		h.x = VsDefs.lane_x(l)
		h.z = base_z - _rng.randf_range(0.0, 6.0)
		h.arm = 0.8
		h.node = VsModels.dome()
		h.node.position = Vector3(h.x, 12.0, h.z)
		_props.add_child(h.node)
		_hazards.append(h)
	fx.emit(&"emp", cars[i].position, VsDefs.color(&"emp"), i)
	if other.alive():
		GameEvents.versus_callout.emit(1 - i, Tr.t(&"vs.call.emp_warn"), VsDefs.color(&"emp"))


func _tick_shots(delta: float) -> void:
	for s: Shot in _shots:
		if s.dead:
			continue
		s.life -= delta
		if s.kind == &"seeker":
			var tx: float = s.x
			var tz: float = s.z + s.dir * 40.0
			var valid: bool = true
			match s.target_kind:
				&"car":
					var tc: VsCar = cars[s.target_index]
					valid = tc.alive()
					tx = tc.position.x
					tz = tc.position.z
				&"police":
					tx = police[s.target_index].position.x
					tz = police_z[s.target_index]
				&"traffic":
					valid = s.target_traffic != null and not s.target_traffic.knocked
					if valid:
						tx = s.target_traffic.x
						tz = s.target_traffic.z
			if not valid:
				s.target_kind = &"none"
			var spd: float = 31.0
			s.x = MathUtils.damp(s.x, tx, 0.16, delta)
			if s.target_kind == &"none":
				s.z += s.dir * spd * delta
			else:
				s.z = move_toward(s.z, tz, (spd + absf(tz - s.z) * 0.2) * delta)
				if absf(s.z - tz) < 2.4 and absf(s.x - tx) < 1.5:
					_seeker_hit(s)
		else:
			s.z += s.dir * 85.0 * delta
			_bolt_contacts(s)
		if s.node != null:
			s.node.position = Vector3(s.x, 0.0, s.z)
			if s.kind == &"seeker":
				s.node.rotation.z += delta * 8.0
		if s.life <= 0.0 or s.z < -220.0 or s.z > 60.0:
			_kill_shot(s, false)
	for k in range(_shots.size() - 1, -1, -1):
		if _shots[k].dead:
			if _shots[k].node != null:
				_shots[k].node.queue_free()
			_shots.remove_at(k)


func _seeker_hit(s: Shot) -> void:
	var pos: Vector3 = Vector3(s.x, 1.0, s.z)
	match s.target_kind:
		&"car":
			_damage(s.target_index, VsDefs.DMG_SEEKER, s.owner, &"seeker", -14.0, 1.4)
		&"police":
			_push_police(s.target_index, 9.0)
			cars[s.owner].fans += VsDefs.FANS_HIT
		&"traffic":
			_knock_traffic(s.target_traffic, pos, 1.4)
			cars[s.owner].fans += VsDefs.FANS_SMASH
	fx.emit(&"explode", pos, VsDefs.color(&"seeker"), s.owner)
	s.dead = true


func _bolt_contacts(s: Shot) -> void:
	for i in range(2):
		if i == s.owner:
			continue
		var c: VsCar = cars[i]
		if c.alive() and absf(c.position.x - s.x) < 1.35 and absf(c.position.z - s.z) < 2.8:
			_damage(i, VsDefs.DMG_BOLT, s.owner, &"bolt", -6.0, 0.45)
			fx.emit(&"zap", Vector3(s.x, 1.0, s.z), VsDefs.color(&"bolt"), s.owner)
			s.dead = true
			return
	for t: Traffic in _traffic:
		if not t.knocked and absf(t.x - s.x) < t.node.half_width + 0.3 and absf(t.z - s.z) < t.node.length * 0.5 + 1.0:
			_knock_traffic(t, Vector3(s.x, 0.0, s.z + s.dir * -3.0), 0.9)
			cars[s.owner].fans += VsDefs.FANS_SMASH
			s.dead = true
			return
	for o: Shot in _shots:
		if o != s and not o.dead and o.owner != s.owner and absf(o.x - s.x) < 1.4 and absf(o.z - s.z) < 3.0:
			_kill_shot(o, true)
			cars[s.owner].fans += VsDefs.FANS_BLOCK
			s.dead = true
			return
	for h: Hazard in _hazards:
		if not h.dead and absf(h.x - s.x) < 1.4 and absf(h.z - s.z) < 2.5:
			_kill_hazard(h, true)
			s.dead = true
			return
	if s.dir > 0.0:
		for k in range(2):
			if absf(police[k].position.x - s.x) < 1.5 and absf(police_z[k] - s.z) < 3.0:
				_push_police(k, 3.0)
				s.dead = true
				return


func _kill_shot(s: Shot, explode: bool) -> void:
	if s.dead:
		return
	s.dead = true
	if explode:
		fx.emit(&"explode_small", Vector3(s.x, 1.0, s.z), VsDefs.color(s.kind), s.owner)


func _tick_hazards(delta: float, step: float) -> void:
	for h: Hazard in _hazards:
		if h.dead:
			continue
		h.t += delta
		h.arm = maxf(h.arm - delta, 0.0)
		h.z += step
		var y: float = 0.0
		if h.kind == &"dome":
			y = 12.0 * MathUtils.ease_in_quad(h.arm / 0.8)
			var shell: Node3D = h.node.get_node(^"Shell") as Node3D
			shell.scale = Vector3(1.7, 1.5, 1.7) * (1.0 + 0.06 * sin(h.t * 20.0))
		else:
			(h.node.get_node(^"Blink") as Node3D).visible = fmod(h.t, 0.4) < 0.2
		h.node.position = Vector3(h.x, y, h.z)
		if h.z > VsDefs.DESPAWN_Z + 5.0:
			h.dead = true
			continue
		if h.arm > 0.0:
			continue
		var reach_x: float = 1.5 if h.kind == &"mine" else 1.9
		for i in range(2):
			var c: VsCar = cars[i]
			if c.alive() and absf(c.position.x - h.x) < reach_x and absf(c.position.z - h.z) < 2.5:
				if h.kind == &"mine":
					_damage(i, VsDefs.DMG_MINE, h.owner, &"mine", -12.0, 1.2)
				else:
					if not c.protected():
						c.jam_t = VsDefs.EMP_JAM
					_damage(i, VsDefs.DMG_EMP, h.owner, &"emp", -9.0, 0.6)
					fx.emit(&"emp_hit", c.position, VsDefs.color(&"emp"), i)
				_kill_hazard(h, true)
				break
		if h.dead:
			continue
		for k in range(2):
			if absf(police[k].position.x - h.x) < reach_x and absf(police_z[k] - h.z) < 2.8:
				_push_police(k, 8.0)
				cars[h.owner].fans += VsDefs.FANS_HIT
				_kill_hazard(h, true)
				break
		if h.dead:
			continue
		for s: Shot in _shots:
			if not s.dead and s.owner != h.owner and absf(s.x - h.x) < 1.5 and absf(s.z - h.z) < 2.5:
				_kill_shot(s, false)
				cars[h.owner].fans += VsDefs.FANS_BLOCK
				_kill_hazard(h, true)
				break
	for k in range(_hazards.size() - 1, -1, -1):
		if _hazards[k].dead:
			_hazards[k].node.queue_free()
			_hazards.remove_at(k)


func _kill_hazard(h: Hazard, explode: bool) -> void:
	if h.dead:
		return
	h.dead = true
	if explode:
		fx.emit(&"explode", Vector3(h.x, 0.8, h.z), VsDefs.color(h.kind if h.kind == &"mine" else &"emp"), h.owner)


# --- Collisions and damage -----------------------------------------------------

func _collide(delta: float) -> void:
	_ram_cool = maxf(_ram_cool - delta, 0.0)
	for i in range(2):
		var c: VsCar = cars[i]
		if not c.alive():
			continue
		var cx: float = c.position.x
		var cz: float = c.position.z
		for t: Traffic in _traffic:
			if t.knocked:
				continue
			if absf(cx - t.x) < VsDefs.CAR_HALF_W + t.node.half_width - 0.2 \
					and absf(cz - t.z) < VsDefs.CAR_HALF_L + t.node.length * 0.5 - 0.2:
				_knock_traffic(t, c.position, 1.0 if c.nitro_t > 0.0 else 0.75)
				if c.nitro_t > 0.0 or c.shield_t > 0.0 or c.ghost_t > 0.0:
					c.fans += VsDefs.FANS_SMASH
					c.stats["smashed"] = int(c.stats["smashed"]) + 1
					if c.shield_t > 0.0:
						fx.emit(&"shield_block", c.position, VsDefs.color(&"shield"), i)
				else:
					_damage(i, VsDefs.DMG_TRAFFIC, -1, &"traffic", -17.0, 0.7)
		for o: Orb in _orbs:
			if o.node != null and absf(cx - o.x) < 1.8 and absf(cz - o.z) < 2.8:
				if c.give(o.id):
					c.fans += VsDefs.FANS_PICKUP
					c.stats["pickups"] = int(c.stats["pickups"]) + 1
					fx.emit(&"pickup", Vector3(o.x, 1.1, o.z), VsDefs.color(o.id), i)
					o.node.queue_free()
					o.node = null
				elif o.t >= 0.0:
					o.t = -100.0
					fx.emit(&"full", c.position, Color.WHITE, i)
	for k in range(_orbs.size() - 1, -1, -1):
		if _orbs[k].node == null:
			_orbs.remove_at(k)
	_car_vs_car()


func _car_vs_car() -> void:
	var a: VsCar = cars[0]
	var b: VsCar = cars[1]
	if not a.alive() or not b.alive():
		return
	var dx: float = b.position.x - a.position.x
	var dz: float = b.position.z - a.position.z
	var ox: float = VsDefs.CAR_HALF_W * 2.0 + 0.1 - absf(dx)
	var oz: float = VsDefs.CAR_HALF_L * 2.0 - absf(dz)
	if ox <= 0.0 or oz <= 0.0:
		return
	var mid: Vector3 = (a.position + b.position) * 0.5 + Vector3(0.0, 0.7, 0.0)
	if ox < oz * 0.7:
		# Side swipe: whoever is between lanes is bounced back where they came from.
		for car: VsCar in [a, b]:
			if absf(car.position.x - VsDefs.lane_x(car.lane)) > 0.25:
				var back_lane: int = car.prev_lane
				car.prev_lane = car.lane
				car.lane = back_lane
		var push: float = ox * 0.5 * signf(dx if dx != 0.0 else 1.0)
		a.position.x -= push
		b.position.x += push
	else:
		var front: VsCar = a if a.position.z < b.position.z else b
		var rear: VsCar = b if front == a else a
		rear.position.z = front.position.z + VsDefs.CAR_HALF_L * 2.0
		rear.impulse -= 5.0
		front.impulse += 4.0
	if _ram_cool <= 0.0:
		_ram_cool = 0.45
		_damage(0, VsDefs.DMG_RAM, 1, &"ram", 0.0, 0.25)
		_damage(1, VsDefs.DMG_RAM, 0, &"ram", 0.0, 0.25)
		fx.emit(&"ram", mid, Color(1.0, 0.8, 0.4), -1)


## Applies damage to player `victim`. Returns true if it landed (not blocked).
func _damage(victim: int, amount: float, attacker: int, kind: StringName, shove: float,
		knock: float) -> bool:
	var c: VsCar = cars[victim]
	if not c.alive():
		return false
	if c.protected():
		if c.shield_t > 0.0 and kind != &"ram":
			c.fans += VsDefs.FANS_BLOCK
			fx.emit(&"shield_block", c.position, VsDefs.color(&"shield"), victim)
			c.knock(0.1)
		return false
	c.health -= amount
	c.impulse += shove
	c.knock(knock)
	c.stats["damage"] = int(c.stats["damage"]) + int(amount)
	if attacker >= 0 and attacker != victim and kind != &"ram":
		var a: VsCar = cars[attacker]
		a.fans += VsDefs.FANS_HIT + int(amount) * 3
		a.stats["hits"] = int(a.stats["hits"]) + 1
		GameEvents.versus_callout.emit(attacker, Tr.t(StringName("vs.hit." + String(kind))), VsDefs.color(kind)
				if VsDefs.COLORS.has(kind) else Color.WHITE)
	if kind != &"ram":
		fx.emit(&"hit", c.position + Vector3(0.0, 0.8, 0.0), Color(1.0, 0.6, 0.3), victim)
		camera.shake.add_trauma(clampf(knock * 0.45, 0.15, 0.7))
	if c.health <= 0.0:
		c.health = 0.0
		_wreck(victim, attacker)
	return true


func _wreck(victim: int, attacker: int) -> void:
	var c: VsCar = cars[victim]
	fx.emit(&"wreck", c.position + Vector3(0.0, 0.8, 0.0), VsDefs.PLAYER_COLORS[victim], victim)
	camera.shake.add_trauma(0.9)
	camera.punch(6.0)
	c.lives -= 1
	c.wreck()
	_bolt_queue[victim] = 0
	GameEvents.versus_callout.emit(victim, Tr.t(&"vs.call.wrecked"), Color(1.0, 0.3, 0.25))
	if attacker >= 0 and attacker != victim:
		cars[attacker].fans += VsDefs.FANS_WRECK
		cars[attacker].stats["wrecks"] = int(cars[attacker].stats["wrecks"]) + 1
		GameEvents.versus_callout.emit(attacker, Tr.t(&"vs.call.takedown"), Color(1.0, 0.85, 0.2))
	if c.lives <= 0:
		_finish(1 - victim)


func _busted(i: int) -> void:
	var c: VsCar = cars[i]
	fx.emit(&"busted", c.position + Vector3(0.0, 0.8, 0.0), Color(0.3, 0.4, 1.0), i)
	camera.shake.add_trauma(0.6)
	c.lives -= 1
	c.stats["busts"] = int(c.stats["busts"]) + 1
	c.wreck()
	_bolt_queue[i] = 0
	GameEvents.versus_callout.emit(i, Tr.t(&"vs.call.busted"), Color(0.35, 0.55, 1.0))
	cars[1 - i].fans += VsDefs.FANS_WRECK / 2
	if c.lives <= 0:
		_finish(1 - i)


func _tick_respawns(delta: float) -> void:
	for i in range(2):
		var c: VsCar = cars[i]
		if c.alive() or c.lives <= 0:
			continue
		c.respawn_t -= delta
		if c.respawn_t <= 0.0:
			var other: VsCar = cars[1 - i]
			var best: int = 2
			var best_score: float = -1e9
			for lane in range(VsDefs.LANES):
				var score: float = -absf(float(lane) - 2.0)
				if other.alive() and other.lane == lane:
					score -= 5.0
				if not _lane_free(lane, VsDefs.SPAWN_Z, 12.0):
					score -= 20.0
				if score > best_score:
					best_score = score
					best = lane
			c.respawn(best)
			police_z[i] = maxf(police_z[i], c.position.z + VsDefs.POLICE_RESET_GAP)
			fx.emit(&"respawn", c.position, VsDefs.PLAYER_COLORS[i], i)


## winner: 0 / 1, -1 draw, -2 decide on time (lives, then fans).
func _finish(winner: int) -> void:
	if phase == &"over":
		return
	if winner == -2:
		var a: VsCar = cars[0]
		var b: VsCar = cars[1]
		if a.lives != b.lives:
			winner = 0 if a.lives > b.lives else 1
		elif a.fans != b.fans:
			winner = 0 if a.fans > b.fans else 1
		else:
			winner = -1
	phase = &"over"
	_over_left = 1.5
	var players: Array[Dictionary] = []
	for c: VsCar in cars:
		var row: Dictionary = c.stats.duplicate()
		row["fans"] = c.fans
		row["lives"] = c.lives
		players.append(row)
	result = {"winner": winner, "players": players, "time": match_time - time_left}
	fx.emit(&"finish", Vector3.ZERO, Color.WHITE, winner)
	GameEvents.versus_finished.emit(result)


func _clear_entities() -> void:
	for t: Traffic in _traffic:
		t.node.queue_free()
	_traffic.clear()
	for o: Orb in _orbs:
		if o.node != null:
			o.node.queue_free()
	_orbs.clear()
	for s: Shot in _shots:
		if s.node != null:
			s.node.queue_free()
	_shots.clear()
	for h: Hazard in _hazards:
		h.node.queue_free()
	_hazards.clear()


# --- Look ------------------------------------------------------------------------

func _build_environment() -> void:
	_sky = ProceduralSkyMaterial.new()
	_sky.sun_angle_max = 0.0
	_sky.sky_curve = 0.18
	var sky: Sky = Sky.new()
	sky.sky_material = _sky
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.4, 0.4, 0.6)
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 4.0
	_env.glow_intensity = 1.0
	_env.glow_bloom = 0.12
	_env.glow_hdr_threshold = 0.9
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.1
	_env.adjustment_saturation = 1.22
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


## Night-city palette through the shared global shader parameters (restored by VersusMode).
func _apply_palette() -> void:
	var fog: Color = Color(0.07, 0.035, 0.13)
	var accent: Color = Color(0.15, 0.85, 1.0)
	var lamp: Color = Color(1.0, 0.5, 0.18)
	if SettingsManager.get_bool("colorblind"):
		accent = Color(0.25, 0.6, 1.0)
		lamp = Color(1.0, 0.85, 0.1)
	RenderingServer.global_shader_parameter_set(&"fog_color", fog)
	RenderingServer.global_shader_parameter_set(&"biome_accent", accent)
	RenderingServer.global_shader_parameter_set(&"biome_accent2", lamp)
	RenderingServer.global_shader_parameter_set(&"fog_start", 45.0)
	RenderingServer.global_shader_parameter_set(&"fog_end", 185.0)
	RenderingServer.global_shader_parameter_set(&"bend_y", 0.0095)
	_sky.sky_top_color = Color(0.02, 0.02, 0.07)
	_sky.sky_horizon_color = Color(0.3, 0.08, 0.32).lerp(fog, 0.35)
	_sky.ground_horizon_color = fog
	_sky.ground_bottom_color = fog
	_env.glow_enabled = SettingsManager.quality() > 0
	_env.adjustment_enabled = true
	# The Compatibility renderer (web builds) renders this unshaded palette noticeably darker.
	var compat: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_env.adjustment_brightness = 1.45 if compat else 1.0
	_env.adjustment_contrast = 1.0 if compat else 1.1

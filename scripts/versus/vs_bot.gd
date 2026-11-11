## Simple driver used for automated soak runs and screenshots (--versus-bots): keeps away from
## the police, dodges traffic and hazards in its lane, and fires whatever it holds now and then.
class_name VsBot
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _think: float = 0.0
var _fire_wait: float = 1.0


func _init(bot_seed: int) -> void:
	_rng.seed = bot_seed


## Fills `pad` for this physics tick.
func think(game: VsGame, i: int, pad: VsCar.Pad) -> void:
	var car: VsCar = game.cars[i]
	var delta: float = 1.0 / float(Engine.physics_ticks_per_second)
	pad.clear()
	pad.gas = car.position.z > VsDefs.SPAWN_Z - 6.0 or game.police_z[i] - car.position.z < 9.0
	pad.brake = not pad.gas and _rng.randf() < 0.02
	_fire_wait -= delta
	if _fire_wait <= 0.0 and not car.slots.is_empty():
		_fire_wait = _rng.randf_range(2.0, 5.0)
		pad.fire = true
		pad.brake = _rng.randf() < 0.25
	elif _rng.randf() < 0.004:
		pad.cycle = true
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.12
	var best: int = car.lane
	var best_score: float = _lane_score(game, car, car.lane)
	for l: int in [car.lane - 1, car.lane + 1]:
		if l < 0 or l >= VsDefs.LANES:
			continue
		var s: float = _lane_score(game, car, l) - 0.5
		if s > best_score:
			best_score = s
			best = l
	pad.left = best < car.lane
	pad.right = best > car.lane


## Higher = safer: distance to the nearest blocker ahead in that lane, plus orbs.
func _lane_score(game: VsGame, car: VsCar, lane: int) -> float:
	var x: float = VsDefs.lane_x(lane)
	var nearest: float = 80.0
	var snap: Array[Vector3] = game.blockers()
	for p: Vector3 in snap:
		if absf(p.x - x) < 2.2 and p.z < car.position.z + 3.0:
			nearest = minf(nearest, car.position.z - p.z)
	var score: float = nearest
	for p: Vector3 in game.orb_positions():
		if absf(p.x - x) < 1.0 and p.z < car.position.z and p.z > car.position.z - 40.0:
			score += 10.0
	return score

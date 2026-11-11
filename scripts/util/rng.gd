## Deterministic random source. One Rng per run, seeded from the RunSeed, makes any run reproducible.
class_name Rng
extends RefCounted

var seed_value: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	reseed(p_seed)


## Restarts the sequence from a seed.
func reseed(p_seed: int) -> void:
	seed_value = p_seed
	_rng.seed = p_seed
	_rng.state = p_seed * 2 + 1


## Float in [0, 1).
func randf() -> float:
	return _rng.randf()


## Float in [a, b].
func range_f(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


## Integer in [a, b] inclusive.
func range_i(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


## True with probability p.
func chance(p: float) -> bool:
	return _rng.randf() < p


## Picks an index using non-negative weights. Returns -1 when all weights are zero.
func pick_weighted(weights: PackedFloat32Array) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return -1
	var roll: float = _rng.randf() * total
	for i in range(weights.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


## Seed for the daily challenge: the calendar date as YYYYMMDD.
static func daily_seed() -> int:
	var d: Dictionary = Time.get_date_dict_from_system()
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


## Today's date as "YYYY-MM-DD".
static func today_text() -> String:
	return Time.get_date_string_from_system()


## A fresh seed for a normal run.
static func random_seed() -> int:
	return int(Time.get_unix_time_from_system()) ^ (Time.get_ticks_usec() << 8) & 0x7fffffff

## Pure score maths (unit-tested).
##   points(base)  = base * combo * powerup_multiplier * account_multiplier
##   run total     = distance * score_per_meter + coins * score_per_coin
##                   + near_misses * near_miss_points   (each scaled by the multipliers active
##                   at the moment it was earned)
class_name ScoreCalculator
extends RefCounted


## Points awarded for an event worth `base`, with the multipliers active right now.
static func points(base: float, combo: int, powerup_multiplier: int, account_multiplier: int) -> float:
	return base * float(maxi(combo, 1)) * float(maxi(powerup_multiplier, 1)) \
			* float(maxi(account_multiplier, 1))


## Score of a whole run under constant multipliers (reference formula for tests / balancing).
static func run_total(distance: float, coins: int, near_misses: int, cfg: GameConfig,
		multiplier: int) -> int:
	var base: float = distance * cfg.score_per_meter + float(coins * cfg.score_per_coin) \
			+ float(near_misses * cfg.near_miss_points)
	return int(base * float(maxi(multiplier, 1)))


## Combo level for a chain: every near miss counts 1, every 10 coins count 1; capped.
static func combo_level(near_chain: int, coin_chain: int, cap: int) -> int:
	@warning_ignore("integer_division")
	return clampi(1 + near_chain + coin_chain / 10, 1, cap)

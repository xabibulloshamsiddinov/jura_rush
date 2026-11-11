## Data definition of a power-up: duration per upgrade level, stacking rule and shop costs.
class_name PowerupDef
extends Resource

enum Stacking { REFRESH, EXTEND, IGNORE }

@export var id: StringName = &""
@export var name_key: StringName = &""
## Short glyph drawn inside the HUD timer and the pickup (no texture needed).
@export var icon: String = "?"
@export var color: Color = Color(0.0, 0.9, 1.0)
## Base duration in seconds at level 1.
@export var duration: float = 10.0
## Extra seconds per upgrade level above 1.
@export var duration_per_level: float = 1.5
@export var stacking: Stacking = Stacking.REFRESH
## Coin cost of levels 2..5 (index 0 = level 2).
@export var upgrade_costs: PackedInt32Array = PackedInt32Array([500, 1200, 2500, 5000])
## Relative chance when a power-up slot is filled.
@export var weight: float = 1.0


## Highest purchasable level.
func max_level() -> int:
	return upgrade_costs.size() + 1


## Duration in seconds at an upgrade level (1-based).
func duration_for_level(level: int) -> float:
	return duration + duration_per_level * float(clampi(level, 1, max_level()) - 1)


## Cost to go from `level` to `level + 1`, or -1 when maxed.
func cost_for_next(level: int) -> int:
	if level < 1 or level >= max_level():
		return -1
	return upgrade_costs[level - 1]

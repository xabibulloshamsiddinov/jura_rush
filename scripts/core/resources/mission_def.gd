## A mission or an achievement: "reach `target` of `metric`", per run or lifetime.
class_name MissionDef
extends Resource

enum Scope { RUN, TOTAL }
enum Kind { MISSION, ACHIEVEMENT }

@export var id: StringName = &""
## Stat name: coins, jumps, rolls, distance, near_misses, shield_used, powerups, boxes, score, runs, stumbles.
@export var metric: StringName = &"coins"
@export var target: int = 100
@export var scope: Scope = Scope.RUN
@export var kind: Kind = Kind.MISSION
@export var reward_coins: int = 100


## Localisation key of the description, e.g. "mission.coins.run".
func text_key() -> StringName:
	return StringName("mission.%s.%s" % [metric, "run" if scope == Scope.RUN else "total"])

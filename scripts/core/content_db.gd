## Central registry of content resources. Preloaded lists keep exports reliable (no directory
## scanning) and give every system one place to look definitions up by id.
class_name ContentDB
extends RefCounted

const OBSTACLES: Array[ObstacleDef] = [
	preload("res://config/obstacle_defs/train_long.tres"),
	preload("res://config/obstacle_defs/train_short.tres"),
	preload("res://config/obstacle_defs/train_moving.tres"),
	preload("res://config/obstacle_defs/barrier_low.tres"),
	preload("res://config/obstacle_defs/barrier_high.tres"),
	preload("res://config/obstacle_defs/barrier_full.tres"),
	preload("res://config/obstacle_defs/ramp.tres"),
	preload("res://config/obstacle_defs/gap.tres"),
	preload("res://config/obstacle_defs/hazard_light.tres"),
]

const POWERUPS: Array[PowerupDef] = [
	preload("res://config/powerup_defs/magnet.tres"),
	preload("res://config/powerup_defs/shield.tres"),
	preload("res://config/powerup_defs/jetpack.tres"),
	preload("res://config/powerup_defs/multiplier.tres"),
	preload("res://config/powerup_defs/dash.tres"),
]

const CHARACTERS: Array[CharacterDef] = [
	preload("res://config/character_defs/volt.tres"),
	preload("res://config/character_defs/ember.tres"),
	preload("res://config/character_defs/moss.tres"),
	preload("res://config/character_defs/pixel.tres"),
	preload("res://config/character_defs/nova.tres"),
	preload("res://config/character_defs/onyx.tres"),
]

const TRAILS: Array[TrailDef] = [
	preload("res://config/trail_defs/cyan.tres"),
	preload("res://config/trail_defs/magenta.tres"),
	preload("res://config/trail_defs/solar.tres"),
	preload("res://config/trail_defs/ghost.tres"),
]

const BIOMES: Array[BiomeDef] = [
	preload("res://config/biome_defs/neon_yard.tres"),
	preload("res://config/biome_defs/sunset_docks.tres"),
	preload("res://config/biome_defs/toxic_works.tres"),
	preload("res://config/biome_defs/ice_grid.tres"),
]

const MISSIONS: Array[MissionDef] = [
	preload("res://config/mission_defs/m_coins_1.tres"),
	preload("res://config/mission_defs/m_jumps_1.tres"),
	preload("res://config/mission_defs/m_distance_1.tres"),
	preload("res://config/mission_defs/m_rolls_1.tres"),
	preload("res://config/mission_defs/m_near_1.tres"),
	preload("res://config/mission_defs/m_powerups_1.tres"),
	preload("res://config/mission_defs/m_coins_2.tres"),
	preload("res://config/mission_defs/m_shield_1.tres"),
	preload("res://config/mission_defs/m_distance_2.tres"),
	preload("res://config/mission_defs/m_score_1.tres"),
	preload("res://config/mission_defs/m_boxes_1.tres"),
	preload("res://config/mission_defs/m_jumps_2.tres"),
	preload("res://config/mission_defs/m_near_2.tres"),
	preload("res://config/mission_defs/m_coins_3.tres"),
	preload("res://config/mission_defs/m_distance_3.tres"),
	preload("res://config/mission_defs/a_first_run.tres"),
	preload("res://config/mission_defs/a_coins_1k.tres"),
	preload("res://config/mission_defs/a_coins_10k.tres"),
	preload("res://config/mission_defs/a_dist_10k.tres"),
	preload("res://config/mission_defs/a_dist_100k.tres"),
	preload("res://config/mission_defs/a_near_100.tres"),
	preload("res://config/mission_defs/a_jumps_500.tres"),
	preload("res://config/mission_defs/a_rolls_500.tres"),
	preload("res://config/mission_defs/a_powerups_50.tres"),
	preload("res://config/mission_defs/a_boxes_20.tres"),
	preload("res://config/mission_defs/a_score_50k.tres"),
	preload("res://config/mission_defs/a_runs_100.tres"),
]


## Obstacle definition by id (null when unknown).
static func obstacle(id: StringName) -> ObstacleDef:
	for d in OBSTACLES:
		if d.id == id:
			return d
	return null


## Power-up definition by id (null when unknown).
static func powerup(id: StringName) -> PowerupDef:
	for d in POWERUPS:
		if d.id == id:
			return d
	return null


## Character definition by id (falls back to the default skin).
static func character(id: StringName) -> CharacterDef:
	for d in CHARACTERS:
		if d.id == id:
			return d
	return CHARACTERS[0]


## Trail definition by id (falls back to the default trail).
static func trail(id: StringName) -> TrailDef:
	for d in TRAILS:
		if d.id == id:
			return d
	return TRAILS[0]


## Mission or achievement definition by id (null when unknown).
static func mission(id: StringName) -> MissionDef:
	for d in MISSIONS:
		if d.id == id:
			return d
	return null


## All definitions of one kind (missions or achievements).
static func missions_of(kind: MissionDef.Kind) -> Array[MissionDef]:
	var out: Array[MissionDef] = []
	for d in MISSIONS:
		if d.kind == kind:
			out.append(d)
	return out

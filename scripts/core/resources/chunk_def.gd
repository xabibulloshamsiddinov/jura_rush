## One hand-authored chunk pattern: rows_per_chunk rows of three lane cells written in the
## pattern DSL (see pattern_data.gd for the character legend). Row 0 is reached first.
class_name ChunkDef
extends Resource

@export var id: StringName = &""
## Authored difficulty 1..10 (drives the tension budget).
@export var difficulty: int = 1
@export var min_difficulty: int = 1
@export var max_difficulty: int = 10
@export var weight: float = 1.0
## Empty = allowed in every biome.
@export var biome_tags: Array[StringName] = []
## Free-form tags: rest, jump, roll, lanes, roof, gap, moving, panic.
@export var tags: Array[StringName] = []
## Exactly rows_per_chunk strings of lane_count characters.
@export var rows: PackedStringArray = PackedStringArray()

## Filled by PatternLibrary.analyse(): actions the pattern can demand.
var required_actions: Array[StringName] = []
## Filled by PatternLibrary.analyse(): lanes with no blocking cell at all.
var safe_lanes: Array[int] = []


## True for coin-only breather patterns.
func is_rest() -> bool:
	return tags.has(&"rest")


## True when the pattern counts as "hard" for pacing.
func is_hard(threshold: int) -> bool:
	return difficulty >= threshold

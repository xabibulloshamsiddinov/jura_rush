## Single source of truth for every tunable number. Edit config/game_config.tres, not scripts.
class_name GameConfig
extends Resource

const PATH: String = "res://config/game_config.tres"
## The one place the game title lives.
const GAME_TITLE: String = "JURA RUSH"

@export_group("Speed")
@export var start_speed: float = 14.0
@export var max_speed: float = 34.0
@export var speed_ramp_time: float = 180.0
@export var speed_smoothing: float = 1.5
## World scroll speed behind the menu (0 = the caveman stands still in front of the camera).
@export var menu_scroll_speed: float = 0.0
@export var difficulty_curve: Curve
@export var difficulty_strategy: StringName = &"adaptive"
@export var spawn_strategy: StringName = &"pattern"
@export var adaptive_range: float = 1.5

@export_group("Track")
@export var lane_width: float = 2.0
@export var lane_count: int = 3
@export var chunk_length: float = 30.0
@export var rows_per_chunk: int = 10
@export var active_chunks: int = 9
@export var recycle_threshold: float = 30.0
@export var fog_start: float = 60.0
@export var fog_end: float = 190.0
@export var bend_strength_y: float = 0.022
@export var bend_strength_x: float = 0.012
@export var biome_length: float = 1500.0
@export var train_height: float = 3.0
@export var moving_train_activation: float = 45.0
@export var moving_train_speed_factor: float = 0.5

@export_group("Player")
## Lane change duration at start speed (shortened toward max speed by speed_scale_lane).
@export var lane_change_time: float = 0.16
## Lane-change speed curve v(u) = (1 - exp(-u / ramp)) * (1 - u)^settle (see Player.lane_ease):
## ramp = share of the move spent speeding up, settle = softness of the arrival.
@export var lane_ease_ramp: float = 0.05
@export var lane_ease_settle: float = 4.0
## Height of the small hop while changing lanes on the ground (metres).
@export var lane_hop_height: float = 0.06
## Peak body lean while changing lanes (radians); the visual springs toward it.
@export var lane_lean: float = 0.26
@export var jump_height: float = 2.2
@export var jump_time: float = 0.62
@export var roll_time: float = 0.55
@export var gravity_down_multiplier: float = 1.6
@export var coyote_time: float = 0.08
@export var input_buffer_time: float = 0.12
@export var stumble_window: float = 2.5
@export var i_frames: float = 1.2
@export var slam_speed: float = 30.0
@export var step_height: float = 0.6
@export var player_half_width: float = 0.35
@export var player_height: float = 1.7
@export var roll_height: float = 0.8
@export var speed_scale_lane: float = 0.8125
@export var speed_scale_jump: float = 0.82
@export var speed_scale_roll: float = 0.85
@export var hit_stop_time: float = 0.08

@export_group("Camera")
@export var cam_back: float = 6.5
@export var cam_height: float = 4.2
@export var cam_look_ahead: float = 7.0
@export var cam_lag_x: float = 0.18
@export var cam_lag_y: float = 0.3
@export var fov_min: float = 65.0
@export var fov_max: float = 78.0
@export var fov_punch_near: float = 4.0
@export var fov_punch_boost: float = 8.0
@export var cam_tilt_deg: float = 2.0

@export_group("Scoring")
@export var coin_value: int = 1
@export var score_per_meter: float = 1.0
@export var score_per_coin: int = 10
@export var near_miss_margin: float = 0.35
@export var near_miss_points: int = 50
@export var combo_window: float = 1.5
@export var combo_max: int = 5
@export var account_multiplier_cap: int = 30

@export_group("Power-ups")
@export var magnet_radius: float = 7.0
@export var powerup_min_gap: float = 400.0
@export var powerup_chance: float = 0.35
@export var jetpack_height: float = 5.5
@export var dash_speed_multiplier: float = 1.6

@export_group("Economy")
@export var revive_cost_keys: int = 1
@export var revive_timer: float = 5.0
@export var max_revives: int = 3
@export var daily_reward_base: int = 100

@export_group("Generation")
@export var min_reaction_time: float = 0.45
@export var max_validation_tries: int = 5
@export var hard_pattern_threshold: int = 6
@export var tension_limit: float = 14.0
@export var tension_rest_relief: float = 6.0
@export var extra_chunk_defs: Array[ChunkDef] = []

@export_group("Input")
@export var swipe_min_distance: float = 60.0
@export var swipe_max_time: float = 0.3
@export var swipe_axis_ratio: float = 1.25

static var _instance: GameConfig = null


## Returns the shared config (loaded once; falls back to defaults if the file is missing).
static func current() -> GameConfig:
	if _instance == null:
		if ResourceLoader.exists(PATH):
			_instance = ResourceLoader.load(PATH) as GameConfig
		if _instance == null:
			_instance = GameConfig.new()
		_instance._ensure_curve()
	return _instance


## Drops the cached instance so the next current() re-reads the file (debug cheat).
static func reload() -> void:
	_instance = null
	if ResourceLoader.exists(PATH):
		_instance = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameConfig
	if _instance == null:
		_instance = GameConfig.new()
	_instance._ensure_curve()


func _ensure_curve() -> void:
	if difficulty_curve == null:
		difficulty_curve = Curve.new()
		difficulty_curve.add_point(Vector2(0.0, 0.0), 0.0, 1.4)
		difficulty_curve.add_point(Vector2(1.0, 1.0), 0.3, 0.0)


## Row length in metres (chunk_length / rows_per_chunk).
func row_length() -> float:
	return chunk_length / float(rows_per_chunk)


## X coordinate of a lane centre. Lane 0 is the left-most lane.
func lane_x(lane: int) -> float:
	return (float(lane) - float(lane_count - 1) * 0.5) * lane_width


## Lane index nearest to a world x coordinate.
func lane_at_x(x: float) -> int:
	return clampi(roundi(x / lane_width + float(lane_count - 1) * 0.5), 0, lane_count - 1)


## Speed fraction (0 at start_speed, 1 at max_speed) for a world speed.
func speed_fraction(speed: float) -> float:
	return clampf((speed - start_speed) / maxf(max_speed - start_speed, 0.001), 0.0, 1.0)


## Lane change duration at a speed fraction: t = lane_change_time * lerp(1, speed_scale_lane, f).
func lane_time_at(f: float) -> float:
	return lane_change_time * lerpf(1.0, speed_scale_lane, f)


## Total jump air time at a speed fraction: T = jump_time * lerp(1, speed_scale_jump, f).
func jump_time_at(f: float) -> float:
	return jump_time * lerpf(1.0, speed_scale_jump, f)


## Roll duration at a speed fraction: t = roll_time * lerp(1, speed_scale_roll, f).
func roll_time_at(f: float) -> float:
	return roll_time * lerpf(1.0, speed_scale_roll, f)


## Time spent rising in a jump. With heavier fall gravity (m): t_up = T / (1 + 1/sqrt(m)).
func jump_up_time(f: float) -> float:
	return jump_time_at(f) / (1.0 + 1.0 / sqrt(gravity_down_multiplier))


## Upward gravity so the apex equals jump_height: g = 2h / t_up^2.
func jump_gravity(f: float) -> float:
	var tu: float = jump_up_time(f)
	return 2.0 * jump_height / (tu * tu)


## Launch velocity: v0 = g * t_up.
func jump_velocity(f: float) -> float:
	return jump_gravity(f) * jump_up_time(f)


## Height of the jump arc `t` seconds after take-off (0 once landed).
func jump_height_at_time(t: float, f: float) -> float:
	var tu: float = jump_up_time(f)
	var g: float = jump_gravity(f)
	if t <= tu:
		return maxf(jump_velocity(f) * t - 0.5 * g * t * t, 0.0)
	var td: float = t - tu
	return maxf(jump_height - 0.5 * g * gravity_down_multiplier * td * td, 0.0)


## Distance from the camera at which a recycled chunk appears.
func spawn_distance(chunk_count: int) -> float:
	return float(chunk_count - 1) * chunk_length - recycle_threshold + cam_back


## Fog end actually used: never further than the spawn distance (hides pop-in).
func effective_fog_end(chunk_count: int) -> float:
	return minf(fog_end, spawn_distance(chunk_count) - 8.0)

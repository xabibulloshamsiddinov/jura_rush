## Event Bus (Observer). Signals only: gameplay emits, UI / audio / VFX / missions subscribe.
## Nothing in scripts/gameplay may reference scripts/ui; this bus is the only bridge.
extends Node

# --- Flow -----------------------------------------------------------------
signal state_changed(from: StringName, to: StringName)
signal run_started
signal run_ended(result: Dictionary)
signal countdown_tick(remaining: int)
signal tutorial_step_done(action: StringName)
signal tutorial_finished

# --- Flow requests (screens ask, only GameState decides) -------------------
signal request_play(daily: bool)
signal request_pause
signal request_resume
signal request_restart
signal request_menu
signal request_revive(method: StringName)
signal request_decline_revive

# --- Player ----------------------------------------------------------------
signal lane_changed(from: int, to: int)
signal player_jumped
signal player_landed(fall_speed: float)
signal player_rolled
signal player_stumbled(kind: StringName)
signal player_crashed(kind: StringName)
signal player_revived
signal near_miss(lane: int)

# --- World -----------------------------------------------------------------
signal speed_changed(speed: float)
signal biome_changed(id: StringName, title: String)
signal moving_train_warning(lane: int)
signal obstacle_smashed(world_pos: Vector3)
signal validator_failed(pattern_id: StringName)
signal chaser_state_changed(state: StringName)

# --- Pickups / power-ups ---------------------------------------------------
signal coin_collected(value: int, world_pos: Vector3)
signal powerup_activated(id: StringName, duration: float)
signal powerup_expiring(id: StringName)
signal powerup_expired(id: StringName)
signal shield_hit
signal shield_broken
signal mystery_box_opened(reward: StringName, amount: int)

# --- Score / progression ---------------------------------------------------
signal score_changed(score: int)
signal coins_changed(run_coins: int)
signal distance_changed(metres: int)
signal combo_changed(combo: int)
signal multiplier_changed(multiplier: int)
signal floating_text(text: String, world_pos: Vector3, color: Color)
signal mission_progress(id: StringName, value: int, target: int)
signal mission_completed(id: StringName)
signal mission_set_completed(new_multiplier: int)
signal achievement_unlocked(id: StringName)
signal wallet_changed(coins: int, keys: int)
signal item_purchased(id: StringName)

# --- Meta ------------------------------------------------------------------
signal settings_changed
signal ui_feedback(kind: StringName)
signal camera_trauma(amount: float)

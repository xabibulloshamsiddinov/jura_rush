# Balancing sheet

Every value is a field of `config/game_config.tres` unless noted. "Tune" says which way to move
it and what to watch.

## Speed and track

| Value | Start | Reasoning | Tune |
|---|---|---|---|
| start_speed | 14 m/s | Slow enough to read the first obstacles; a 3 m row passes in 0.21 s | Lower for younger players; below 10 jumps cover under 2 rows and patterns feel cramped |
| max_speed | 34 m/s | A row passes in 0.09 s: close to the limit for reading three lanes | Above 36 the reaction budget exceeds half a chunk |
| speed_ramp_time | 180 s | Top speed arrives around the 3-minute mark, a long run for most players | Shorter = harder sooner; also shortens average session |
| difficulty_curve | fast start, soft end | Early speed gain is felt most; easing off near the top avoids a wall | Edit `config/difficulty_curve.tres` |
| lane_width | 2.0 m | 1.7 m trains leave a 0.3 m visual gap; adjacent trains do not trigger near-miss spam | Wider lanes need a longer lane_change_time |
| chunk_length | 30 m | 10 rows of 3 m: enough for two actions at top speed | Keep a multiple of the row length |
| active_chunks | 9 | Spec asked for 8, but with recycle_threshold 30 that spawns at 186 m, inside fog_end 190; 9 spawns at 216 m | Low quality uses 8 with a shorter fog |
| recycle_threshold | 30 m | A whole chunk behind the camera before recycling: nothing visible ever pops | Lower to 10 to save one chunk of draw calls |
| fog_start / fog_end | 60 / 190 m | Obstacles are fully readable for 60 m (4.3 s at start, 1.8 s at max) | fog_end is clamped below the spawn distance automatically |
| biome_length | 1500 m | A new look roughly every 60-100 s | Shorter for more variety |
| bend_strength_y / x | 0.022 / 0.012 | 19 m drop at 200 m hides the horizon; gentle side drift | Too much y makes far obstacles sink out of view |

## Player

| Value | Start | Reasoning | Tune |
|---|---|---|---|
| lane_change_time | 0.12 s | Feels instant but still shows the slide; x0.8 at top speed | Above 0.18 dodges feel late |
| jump_height | 2.2 m | Clears 1.0 m barriers generously, cannot reach a 3.0 m train roof | Must stay below train_height - step_height |
| jump_time | 0.62 s | 8.7 m (3 rows) at start, 17 m (6 rows) at max after the x0.82 scale | Longer = floatier and longer forced commitment |
| gravity_down_multiplier | 1.6 | Snappy fall, airy rise | 1.0 = symmetric arc |
| roll_time | 0.55 s | Covers 2 rows at start, 5 at max | Must cover at least 1 row at start_speed |
| coyote_time | 0.08 s | Forgives late jumps off roof edges | Above 0.15 looks like air-jumping |
| input_buffer_time | 0.12 s | A swipe slightly before landing still counts | Above 0.2 causes unintended actions |
| stumble_window | 2.5 s | Time the chaser stays close after a stumble | Shorter = more forgiving |
| i_frames | 1.2 s | Enough to get clear after a stumble | Below 0.8 double hits feel unfair |
| slam_speed | 30 m/s | Mid-air swipe down lands almost instantly | |
| hit_stop_time | 0.08 s | Sells the impact without feeling like a freeze | 0.07-0.10 |

## Generation and fairness

| Value | Start | Reasoning | Tune |
|---|---|---|---|
| min_reaction_time | 0.45 s | Minimum time between two required inputs; 2 rows at start, 5 at max | Raise to 0.55 for a casual audience (fewer patterns stay valid at speed) |
| max_validation_tries | 5 | Rejection rate measured at about 1 % of proposals | |
| hard_pattern_threshold | 6 | Patterns of difficulty 6+ are followed by rest chunks | |
| tension_limit / tension_rest_relief | 14 / 6 | Two or three demanding chunks, then a breather | Lower limit = more coins-only stretches |
| powerup_min_gap | 400 m | At most one power-up per 12-28 s | |
| powerup_chance | 0.35 | Chance a ready rest chunk gets a power-up | |
| moving_train_activation / speed_factor | 45 m / 0.5 | The train closes 15 m (5 rows) early at any speed, so its threat zone is speed-independent | Keep activation * f / (1 + f) under half a chunk |

## Scoring and economy

| Value | Start | Reasoning | Tune |
|---|---|---|---|
| score_per_meter | 1 | Distance is the backbone of the score | |
| score_per_coin | 10 | A coin line is worth about 5 m of running | |
| near_miss_points / margin | 50 / 0.35 m | Rewards late dodges; the margin excludes simply running beside a train | Larger margin = more frequent bonus |
| combo_window / combo_max | 1.5 s / x5 | Coins every 1.5 m keep a chain alive along any coin line | |
| coin_value | 1 | | |
| account_multiplier_cap | 30 | One step per completed mission set | |
| revive_cost_keys | 1 (+1 per revive in the run) | First revive is cheap, chaining them is not | |
| revive_timer | 5 s | | |
| max_revives | 3 | | |
| daily_reward_base | 100 coins x streak (max x7) | | |

## Power-ups (`config/powerup_defs/*.tres`)

| Power-up | Duration L1 | Per level | Stacking | Upgrade costs |
|---|---|---|---|---|
| Magnet (radius 7 m) | 10 s | +1.5 s | refresh | 500 / 1200 / 2500 / 5000 |
| Shield (1 hit) | 12 s | +2 s | refresh | 500 / 1200 / 2500 / 5000 |
| Jetpack (5.5 m high) | 8 s | +1 s | ignore | 800 / 1800 / 3500 / 7000 |
| Score x2 | 10 s | +1.5 s | extend (max 2x) | 500 / 1200 / 2500 / 5000 |
| Dash (speed x1.6) | 4 s | +0.5 s | ignore | 600 / 1500 / 3000 / 6000 |

Shop prices: runners 0 / 500 / 1000 / 2000 / 3500 / 6000; trails 0 / 400 / 900 / 1500;
head start 300; score booster 400. A typical 60-90 s run earns 60-150 coins plus mission rewards
(100-500), so the first runner unlocks after a handful of runs.

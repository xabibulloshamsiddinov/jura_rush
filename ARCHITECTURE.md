# NEON RAILS — Architecture

Godot 4.3+ (developed and tested on 4.6.3), GDScript with static typing everywhere
(`untyped_declaration` is an error in Project Settings). Almost every node tree is built in code;
the `.tscn` files are a root node plus a script.

## 1. Layers and dependency rules

```
                    +----------------------------------------------+
                    |  scripts/ui   (screens, UIKit, router users) |
                    +----------------------+-----------------------+
                                           | reads / requests only through
                                           v
+-------------+   signals   +-----------------------------+   signals   +----------------+
| scripts/    | ----------> |  GameEvents (event bus)     | <---------- | scripts/audio  |
| gameplay    | <---------- |  autoload, signals only     | ----------> | scripts/vfx    |
+------+------+   requests  +-----------------------------+             +----------------+
       |                                   ^
       v                                   |
+-------------+                 +----------+----------+
| scripts/    |                 | autoload services   |  GameState, SaveSystem, SettingsManager,
| core, util  | <-------------- | (Service Locator)   |  PoolManager, AudioManager, VFXManager,
+-------------+                 +---------------------+  SceneRouter, Haptics, Tr, stubs
```

Rules (enforced by convention, checked in review):

* `scripts/gameplay` never references `scripts/ui`. Gameplay only emits `GameEvents` signals.
* UI may read services (`SaveSystem`, `Services.locate(&"missions")`) and emit `request_*`
  signals. It never calls gameplay nodes.
* Gameplay never plays a sound or an effect. `AudioEventRouter` and `VFXManager` subscribe to
  the bus and decide what an event sounds / looks like.
* Only `GameState` changes the flow state, pauses the tree or touches `Engine.time_scale`.
* `scripts/core` and `scripts/util` depend on nothing but the engine.

## 2. Design patterns and where they are used

| Pattern | Where | Why it earns its place |
|---|---|---|
| State | `core/state.gd`, `core/state_machine.gd`; player (`player_states/*`), game flow (`autoload/game_flow_states.gd`), chaser (`chaser.gd`) | Each behaviour is isolated; transitions are whitelisted for the flow |
| Observer (Event Bus) | `autoload/game_events.gd` | Decouples gameplay from UI / audio / VFX / missions / analytics |
| Object Pool | `core/object_pool.gd`, `autoload/pool_manager.gd` | Zero `instantiate()` during a run; verified by the soak tests |
| Singleton | The autoloads listed in `project.godot` | Only for genuinely global services |
| Service Locator | `core/service_locator.gd` (`Services.provide / locate`) | Swappable services; tests inject fakes (`FakeSave` in `test_core.gd`) |
| Command | `core/command.gd`, `player/input_commands.gd`, `core/purchase_command.gd` | Buffered / replayable input; purchases with rollback |
| Factory | `track/factories.gd` (`Obstacles`, `Pickups`, `Chunks`) | The only place definitions become nodes, always through pools |
| Strategy | `score/difficulty_strategy.gd`, `track/spawn_strategy.gd`, `pickups/powerup_strategy.gd` | Selectable difficulty / spawning; one small class per power-up |
| Data-driven | `core/resources/*.gd` + `config/**/*.tres`, `core/content_db.gd` | All content and numbers live in resources |
| Component | `player/components.gd` (Health, Shield, Magnet), `PowerupController`, `TrailComponent` | Abilities are child nodes, not player subclasses |
| Builder | `track/chunk_builder.gd` | `begin().add_obstacles().add_coins().add_pickups().add_decor().build()` |
| Template Method | `ObstacleBase.on_player_hit()`, `PickupBase.collect()` | Shared bookkeeping, overridable hooks |

Note: the locator method is `Services.locate()`, not `get()`, because GDScript cannot override the
native `Object.get()`.

## 3. The endless world

**Treadmill + chunk recycling** (`track/track_manager.gd`).

* The player never moves forward: it stays at world z = 0. Forward is -Z; chunks slide toward +Z.
* `active_chunks` chunks of `chunk_length` metres stay alive. Each physics step the head chunk is
  moved by `world_speed * delta` and every other chunk is re-snapped to
  `head.z - i * chunk_length`, so drift and gaps cannot accumulate (measured max gap: 0.00001 m).
* When the head chunk's far edge passes `recycle_threshold` behind the player it is cleared
  (contents go back to their pools), refilled by the generator and builder, and placed at
  `last.z - chunk_length`. An `assert` checks the new chunk is beyond the fog end.
* Coordinates never grow, so there are no float precision problems and shaders stay stable.

**Horizon hiding** (`assets/shaders/world_common.gdshaderinc`): every world material bends in view
space (`y -= (d * bend_y)^2`, `x += sign(bend_x) * (d * bend_x)^2`) and fades to the fog colour
between `fog_start` and `fog_end`. Both are global shader parameters. Fog end is clamped to the
spawn distance: `min(fog_end, (chunks - 1) * chunk_length - recycle_threshold + cam_back - 8)`.

**Biomes** (`track/biome_director.gd`): every `biome_length` metres the fog, sky, light and accent
colours lerp to the next `BiomeDef` over 3.5 s, and newly recycled chunks get that biome's decor
set. Chunks already on screen are never altered.

**Speed model**: `world_speed` eases toward `director.target_speed() * speed_multiplier`
(exponential smoothing). Fairness scaling with speed fraction `f` (0 at start speed, 1 at max):

```
lane_change_time(f) = lane_change_time * lerp(1, 0.80, f)
jump_time(f)        = jump_time        * lerp(1, 0.82, f)     (height stays jump_height)
roll_time(f)        = roll_time        * lerp(1, 0.85, f)
t_up = jump_time(f) / (1 + 1/sqrt(gravity_down_multiplier));  g = 2h / t_up^2;  v0 = g * t_up
```

## 4. Chunk generation

`ChunkGenerator.next_plan()`:

1. `SpawnStrategy.propose()` picks a pattern (53 hand-authored ones in `track/pattern_data.gd`,
   randomly mirrored) inside the difficulty window, or a rest pattern when pacing asks for one.
2. `SolvabilityValidator` checks the window *previous chunk + candidate*. Up to
   `max_validation_tries` proposals; then the empty fallback (always valid).
3. Pacing: `tension += pattern.difficulty`; rest patterns subtract `tension_rest_relief`; rest is
   forced when `tension >= tension_limit`; a hard pattern (>= `hard_pattern_threshold`) queues
   `max(1, round(difficulty / 4))` rest chunks.
4. Power-ups: a slot is filled only if `powerup_min_gap` metres have passed since the last one.

**Validator model.** State = (row, lane, level in {ground, roof}, wait). `wait` is the number of
rows before another input is allowed: `round(speed * min_reaction_time / row_length)`. Edges: run
on, change lane (target cell and the next must be open), jump (clears low barriers / gaps while
high enough, by the real jump curve), roll (covers `roll_time * speed`), ramp up, drop off a roof.
All edges go forward, so it is one ascending sweep plus one descending sweep that keeps only
states that can reach the end. Moving trains block the rows they sweep. The model is conservative
(no mid-air lane change, no slam), so "solvable" always corresponds to a real path. The same
search plans the test bot.

## 5. Player

`CharacterBody3D` with a capsule that shrinks while rolling. Movement is kinematic and explicit.

```
Run     -> Jump | Roll | Fall (ground gone) | Stumble | Jetpack | Dead
Jump    -> Fall (apex) | Roll (slam, on landing) | Run (land) | Stumble | Jetpack | Dead
Fall    -> Run (land) | Roll (slam) | Jump (coyote) | Stumble | Jetpack | Dead
Roll    -> Run (timer) | Jump (cancels roll) | Fall | Stumble | Jetpack | Dead
Stumble -> Run / Fall (0.4 s) | Jump | Roll | Dead (second hit in stumble_window)
Jetpack -> Fall (power-up ends, protected until after landing)
Dead    -> Run (revive / new run)
```

Input: `InputHandler` turns swipes / keys / gamepad into `InputCommand`s. A command the current
state rejects is kept for `input_buffer_time` and retried every tick.

**Collision** is a deterministic swept box test in `obstacles/collision_system.gd`, not physics
overlap: at 34 m/s a 0.3 m barrier moves 0.57 m per tick and would tunnel through an `Area3D`.
Near miss = the obstacle overlapped the player's box grown by `near_miss_margin`, never hit, and
has fully passed.

| Layer | Name | Used by |
|---|---|---|
| 1 | World | reserved for imported level art |
| 2 | Player | player capsule |
| 3 | Obstacle | reserved (obstacles use the box test) |
| 4 | Pickup | reserved (pickups use the distance sweep) |
| 5 | Chaser | reserved |
| 6 | Trigger | reserved |

## 6. Game flow

```
Boot -> Menu -> Loading -> Countdown -> Running <-> Paused
                               ^            |
                               |            v
                          (revive ok)    Revive ----> GameOver -> Loading (again) | Menu
Paused -> Countdown (resume, tree stays frozen) | Loading (restart) | Menu
```

Crash sequence (in `GameState`): time scale 0.05 for `hit_stop_time`, 0.3 for 0.65 s, back to 1,
then Revive (if revives remain) or GameOver.

## 7. Difficulty Director

```
speed      = lerp(start_speed, max_speed, strategy.speed_fraction(run_time))
skill      = clamp(time_since_hit / 30 + 0.1 * near_recent - 0.6 * hits_recent, -1, 1)
difficulty = clamp(1 + 9 * speed_fraction + skill * adaptive_range, 1, 10)
```

`near_recent` / `hits_recent` decay with a 20 s half-life. Strategies: Linear, CurveBased
(`config/difficulty_curve.tres`), Adaptive (curve + the skill bias above).

## 8. Save data

`user://save.json` = `{checksum, payload}` where checksum is SHA-256 of the payload. Writes go to
`.tmp`, the previous good file is copied to `.bak`, then the temp file is renamed. Load order:
main -> backup -> defaults. `SaveCodec.migrate()` upgrades old schemas (v1 -> v2) and fills
missing keys.

## 9. Performance budget

| Item | Budget | Notes |
|---|---|---|
| Frame rate | 60 FPS, physics 60 Hz | `Engine.max_fps = 60`, vsync on |
| Draw calls | <= 150 | chunk = 4 (track mesh x2 surfaces, decor MultiMesh, coin MultiMesh); obstacles 2-5 each |
| Instantiation during a run | 0 | pools pre-warmed; soak tests show 0 pool growth after warm-up |
| Lights / shadows | 1 directional, no real-time shadows | world shader bakes a fake sun; blob shadow under the runner |
| Particles | CPU, <= 28 per burst | scaled by quality preset and "reduce effects" |
| Quality presets | Low / Medium / High | render scale 0.75 / 0.9 / 1.0, MSAA off / 2x / 2x, glow off on Low, one chunk fewer on Low, decor density 3 / 5 / 7 per side |

Profiling notes: generation costs one validator solve (~20 rows) per recycled chunk, about once
every 1-2 s; coins are one MultiMesh per chunk spun in the vertex shader; collision scans only
the chunks within 24 m.

## 9b. Look tuning, theme and texts (1.2)

* `scripts/vfx/visual_tuning.gd` holds every hand-tuned look value and the FEATURE_* flags
  (player rim, lane warnings, night sky, window flicker, rail sparks, tunnels / bridges).
* The night sky is an unshaded dome that follows the camera (BiomeDirector); the environment
  background is a plain colour, so there is no sky radiance work.
* `UITheme.godot_theme()` builds the one Godot Theme set on the UI root (SceneRouter). Buttons use
  theme type variations `NeonPrimary / NeonSecondary / NeonAccent / NeonSuccess / NeonDanger /
  NeonGhost` (UIKit.button picks them).
* Texts: `localization/strings.csv` (keys, en, uz, ru) is imported by Godot into
  `strings.<lang>.translation`; `Tr.t()` goes through TranslationServer.

## 10. Tests and tools

| What | How to run |
|---|---|
| Unit + integration tests (154 checks) | `godot --headless --path . res://tests/test_runner.tscn` |
| Treadmill soak (10 simulated minutes) | `godot --headless --path . res://tests/track_soak_test.tscn` |
| Bot soak | `godot --headless --path . -- --bot-soak=600` |
| Pattern preview | run `scenes/obstacles/pattern_preview.tscn` |
| VFX lab / audio lab | run `scenes/vfx/vfx_lab.tscn`, `scenes/vfx/audio_lab.tscn` |
| Debug overlay and cheats | F3 in a debug build (see `util/debug_overlay.gd`) |
| UI screenshots of every screen | `godot --path . --resolution 540x960 -- --ui-shots=<dir>` |
| Gameplay burst screenshots | `godot --path . -- --shot=<dir>/x.png --shot-burst=12` |
| Performance log (FPS, CPU / GPU ms, draw calls) | add `--perf-log`, or Settings > Show FPS |

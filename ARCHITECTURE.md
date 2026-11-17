# JURA RUSH — Architecture

Godot 4.3+ (developed and tested on 4.6.3), GDScript with static typing everywhere
(`untyped_declaration` is an error in Project Settings). Almost every node tree is built in code;
the `.tscn` files are a root node plus a script. Jura Rush is the Mesozoic re-theme of the former
"Neon Rails": the gameplay rules, numbers and content ids are unchanged, only what they look and
sound like changed (see README, "Assets and obstacles"). The 2 Player versus mode was removed.

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
| Flyweight | `OrganicMesh` / `CavemanMesh` / `NatureMesh` meshes, `CreatureMats`, `CavemanModel` | Every creature, caveman part and plant mesh is built once and shared by all instances |

Note: the locator method is `Services.locate()`, not `get()`, because GDScript cannot override the
native `Object.get()`.

## 3. The endless world

**Treadmill + chunk recycling** (`track/track_manager.gd`).

* The player never moves forward: it stays at world z = 0. Forward is -Z; chunks slide toward +Z.
* `active_chunks` chunks of `chunk_length` metres stay alive. Each simulation step the head chunk
  is moved by `world_speed * delta` and every other chunk is re-snapped to
  `head.z - i * chunk_length`, so drift and gaps cannot accumulate (measured max gap: 0.00001 m).
* When the head chunk's far edge passes `recycle_threshold` behind the player it is cleared
  (contents go back to their pools), refilled by the generator and builder, and placed at
  `last.z - chunk_length`. An `assert` checks the new chunk is beyond the fog end.
* Coordinates never grow, so there are no float precision problems and shaders stay stable.
* Passed obstacles are hidden once their far VISUAL edge (box far edge plus
  `ObstacleBase.far_overhang`, e.g. a sauropod's neck or tail) is
  `VisualTuning.HIDE_PASSED_OBSTACLES_Z` (1 m) behind the runner, so nothing passed stands between
  the camera and the runner, and no herd vanishes while its tail is still on screen.

**Frame pacing** (`game_world.gd`). Everything that moves on screen (treadmill, runner, chaser,
pickups, creatures, camera) advances once per RENDERED frame in `_process`, split into equal
sub-steps of at most 1/60 s (the step the gameplay was tuned for); the camera ticks once per frame
after the sub-steps. Nothing visible moves on the physics tick, so there is no physics-vs-render
beat on 60 / 90 / 120 Hz displays. GameWorld also steps the chaser in every flow state (menu idle,
run-start retreat, run, crash), so it has no clock of its own. A paused tree stops all of it;
hit-stop and crash slow motion scale `Engine.time_scale`, which shrinks the frame delta for every
system at once. Only shader-`TIME` idle motion (creature neck / tail sway and blinks, the caveman's
hair flutter, foliage wind, egg spin) keeps going through a pause, by design.

**Curved world and fog** (`assets/shaders/world_common.gdshaderinc`): every world material bends
in view space (`y -= (d * bend_y)^2`, `x += sign(bend_x) * (d * bend_x)^2`) and fades to the fog
colour between `fog_start` and `fog_end`. All of these are global shader parameters. Fog end is
clamped to the spawn distance: `min(fog_end, (chunks - 1) * chunk_length - recycle_threshold +
cam_back - 8)`. Shadow casters bend with `CURVE_WORLD()`, which in the orthographic shadow pass
applies the same drop in world space by the distance from the run camera; that pivot is the global
`run_cam_z`, pushed from `GameConfig.cam_back` by TrackManager (one source of truth with the run
camera). The bend puts the visual horizon of the ground about `2 * bend_y * sqrt(camera height)`
below eye level, so the day sky dome (`sky_dome.gdshader`) sits its hills, haze and ground on that
line rather than on the eye-level horizon.

**Daylight and shadows** (`track/biome_director.gd`, `world_light.gdshaderinc`). One
DirectionalLight3D sun (direction `SUN_DIR`, the same constant the baked unshaded materials use)
with real shadows on Medium / High (2 splits, 42 / 60 m), a sky-tinted ambient colour and Filmic
tonemapping. Every LIT world material (track ground, flora, rocks, caves, bridges, creatures, the
caveman) shares one light model: `wrap_diffuse()` (soft wrapped Lambert, receives the shadow
through `ATTENUATION`) plus the WorldEnvironment ambient with `hemi_ao()` hemisphere occlusion.
Shaders that need extra terms define `WORLD_LIGHT_CUSTOM` and write their own `light()` around
`wrap_diffuse()`. Caves darken whatever is inside them through the real sun shadow (Low quality has
no shadows, so nothing darkens there). Look values live in `vfx/visual_tuning.gd`.

**Biomes** (`track/biome_director.gd`, `biome_style.gd`, `flora_library.gd`): Fern Valley, Red
Canyon, Misty Swamp and Volcano Ridge. Every `biome_length` metres the fog, sky, sun colour,
ambient and foliage / rock tints lerp to the next `BiomeDef` over 3.5 s, and newly recycled
chunks get that biome's decor style (four MultiMesh slots per chunk) and ground. Chunks already on
screen are never altered. Track features (`track/track_features.gd`): rock caves with torches and
log bridges over a river come round now and then.

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

**Herd orientation** (`ChunkBuilder.ramp_leads_train`): a static "train" run with a ramp in
front of it in its lane becomes a TAIL-FIRST Brachiosaurus herd (the nearest animal's tail is the
ramp, necks curl to the side so the backs are free to run on); without a ramp it is HEAD-FIRST, an
unclimbable wall of sauropods facing the runner. The visuals are checked against the collision
(walkable backs at exactly the roof height, ramp tail on the ramp incline) in `test_creatures.gd`.

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
state rejects is kept for `input_buffer_time` and retried every tick. Lane changes follow an eased
lateral profile (`Player.lane_ease`), so the start and the arrival are smooth.

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

**The caveman** (`player/player_visual.gd`, `caveman_model.gd`, `caveman_mesh.gd`). Organic
procedural body parts built once with the `CavemanMesh` kit (ellipsoids, lathes, swept tubes,
sheets; smooth normals; vertex colours carry palette slot, baked occlusion, fur-pattern mask and
gloss) and cached by `CavemanModel`, hung on a small bone hierarchy animated with transforms only.
Every pose (idle with idle actions, ready crouch, run, jump, fall, roll, stumble, fly, dead) writes
joint channels; pose changes cross-fade from a snapshot of what was on screen, and spring layers add
lane lean, landing squash, take-off stretch, stumble wobble, the menu facing turn and secondary
motion of hair, beard, skirt hem and feathers. Footsteps kick up dirt. Skins are `CharacterDef`
resources (colours, fur pattern, hair style, beard, bulk, height, accessory): six of them, none
rebuilds geometry. The material is `character_toon.gdshader`, LIT with the world's light model (the
biome's sun direction, colour and shadows, sky ambient, hemisphere occlusion) eased toward toon
bands, plus readability terms: a camera-side fill and a sunlit rim (both shadowed like the sun)
and a faint constant sky rim, so he stays the clearest thing on screen yet darkens in caves like
the creatures. He casts no real shadow: the blob contact shadow under him reads jump height better
and exists at every quality. The jetpack is a pterosaur ride (`pterosaur_ride.gd`, same kit and
shader). `runner_lab.tscn` is the dev turntable / screenshot lab.

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

**Camera** (`camera/camera_rig.gd`). RUN: behind and above the runner (`cam_back`, `cam_height`),
lane x and height followed by critically damped springs, roll from the camera's own sideways
speed, FOV from speed plus punches, trauma shake. MENU: a front three-quarter view, low and
looking up, so the caveman stands between the menu's UI bands and the idle T-Rex behind him fills
the upper middle under the logo. DEATH: zoom on the crash from behind-left (`DEATH_SIDE`), then
pull back for the results. Mode changes blend in orbit space around the runner (smootherstep), so
PLAY swings the camera round the runner's right side into the run view in `START_BLEND` (1.1 s).

**The T-Rex chaser** (`chaser/chaser.gd`, `creatures/trex.gd`). Menu: idles behind the runner,
roaring now and then. PLAY: one roar behind the GET READY curtain, then it turns and strides off to
the left, away from the camera swing (`test_run_start_swing_clears_trex` replays the real timing
and checks the camera never comes within the creature near-dissolve distance). Run: hidden;
after a stumble its head and shoulders loom at the bottom-right of the run view; on the fatal hit
it lunges in from behind-right, on the opposite side of the death camera
(`test_catch_keeps_clear_of_death_camera`).

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
missing keys. Content ids (skins, trails, power-ups, obstacle ids) kept their old names so saves
from before the re-theme load unchanged.

## 9. Performance budget

| Item | Budget | Notes |
|---|---|---|
| Frame rate | 60 FPS | `Engine.max_fps = 60`, vsync on; simulation sub-stepped per rendered frame (section 3) |
| Draw calls | <= 150 | chunk = track ground + decor MultiMesh slots + egg MultiMesh; creatures one skinned mesh each; the caveman ~20 small meshes |
| Instantiation during a run | 0 | pools pre-warmed; soak tests show 0 pool growth after warm-up |
| Lights / shadows | 1 directional sun | real shadows on Medium / High only (atlas 1024 / 2048, 42 / 60 m); creatures and eggs cast, the caveman uses a blob |
| Triangles | T-Rex <= 8k, Brachiosaurus <= 6k, Triceratops <= 5k | measured 5.8k / 4.6k / 3.8k (`test_triangle_budgets`); caveman ~3.6k body + hair + accessory, pterosaur 1.7k |
| Particles | CPU, <= 28 per burst | scaled by quality preset and "reduce effects"; creature dust is one MultiMesh per creature |
| Quality presets | Low / Medium / High | render scale 0.75 / 0.9 / 1.0, shadows off / on / on, glow off on Low, one chunk fewer on Low, decor density 3 / 5 / 7 per side |

Profiling notes: generation costs one validator solve (~20 rows) per recycled chunk, about once
every 1-2 s; eggs are one MultiMesh per chunk spun in the vertex shader; collision scans only
the chunks within 24 m; creature idle motion is vertex-shader work on `TIME`.

## 9b. Look, theme and texts

* `scripts/vfx/visual_tuning.gd` holds every hand-tuned look value and the FEATURE_* flags (sun
  shadows, sky dome, lane warnings, player rim, egg shadows, wind sway).
* Creatures: the `OrganicMesh` kit (`vfx/organic_mesh.gd`: lofted tubes along Catmull-Rom spines,
  lathes, ellipsoids, horns / teeth / claws, smooth normals, skin weights) builds the T-Rex, the
  Brachiosaurus herds and the Triceratops once; `creature.gdshader` (via `CreatureMats`) lights them
  like the landscape, sways necks / tails on `TIME`, blinks, and dissolves surfaces with an ordered
  dither near the camera instead of clipping the lens. `NatureMesh` builds rocks, plants, caves and
  bridges. `creature_lab.tscn` is the creature turntable / gameplay-framing lab.
* UI ("Chunky" theme): `UITheme.godot_theme()` builds the one Godot Theme set on the UI root
  (SceneRouter). Boxes are `ChunkyStyle` (thick dark-brown outline, coloured ring, 3D lip, soft
  shine); buttons use the theme type variations `ChunkyPrimary / ChunkySecondary / ChunkyAccent /
  ChunkySuccess / ChunkyDanger / ChunkyGhost` (UIKit.button picks them). Icons are vector
  (`UIIcon`: egg, amber, power-up symbols ...), the logo is drawn in code (`GameLogo`), the loading
  backdrop is a painted sunset (`JuraBackdrop`), shop thumbnails are caveman stickers
  (`ItemThumb`). Fonts: Rubik (Latin and Cyrillic) with Exo 2 as the fallback for
  rare glyphs, both SIL OFL (`assets/fonts`).
* Texts: `localization/strings.csv` (keys, en, uz, ru) is imported by Godot into
  `strings.<lang>.translation`; `Tr.t()` goes through TranslationServer. Re-import after editing.

## 10. Tests and tools

| What | How to run |
|---|---|
| Unit + integration tests (230 checks) | `godot --headless --path . res://tests/test_runner.tscn` (add `-- --only=<text>` to filter) |
| Treadmill soak (10 simulated minutes) | `godot --headless --path . res://tests/track_soak_test.tscn` |
| Bot soak | `godot --headless --path . -- --bot-soak=600` |
| Pattern preview | run `scenes/obstacles/pattern_preview.tscn` |
| VFX lab / audio lab | run `scenes/vfx/vfx_lab.tscn`, `scenes/vfx/audio_lab.tscn` |
| Creature lab | `scenes/vfx/creature_lab.tscn` (`-- --lab-shot=<dir>` / `--lab-views=<dir>`) |
| Runner lab (caveman, skins, poses, pterosaur) | `scenes/vfx/runner_lab.tscn` (`-- --lab-shots=<dir>`) |
| Environment lab | `godot --path . -- --env-lab=<dir>` |
| Debug overlay and cheats | F3 in a debug build (see `util/debug_overlay.gd`) |
| UI screenshots of every screen | `godot --path . --resolution 540x960 -- --ui-shots=<dir>` |
| Gameplay screenshots | `godot --path . -- --shot=<dir>/x.png` plus the flags in README |
| Performance log (FPS, CPU / GPU ms, draw calls) | add `--perf-log`, or Settings > Show FPS |

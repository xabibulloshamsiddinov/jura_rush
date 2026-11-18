# JURA RUSH

A Mesozoic endless lane runner for Android / iOS (portrait) that also runs on desktop: a caveman in
animal skins sprints through dinosaur country, dodging stones and herds, grabbing eggs and
outrunning a T-Rex. Everything is generated in code: visuals from primitives and shaders, sound and
music from a small synthesiser. Built with Godot 4 (GDScript, statically typed). Formerly the
cyberpunk "Neon Rails"; the gameplay is unchanged. On desktop, up to three players race on one
split screen with their phones as controllers (see "Multiplayer").

## Features

* Three-lane endless runner on a treadmill world that never drifts: 53 hand-made chunk patterns,
  every one checked by a solvability validator, adaptive difficulty, power-up pacing.
* Four daylight biomes (Fern Valley, Red Canyon, Misty Swamp, Volcano Ridge) that cross-fade every
  500 m, with a real sun and shadows, a painted sky dome, rock caves with torches and log bridges.
* Dinosaurs instead of trains: Brachiosaurus herds you climb tail-first and run along, head-first
  herd walls you must dodge, charging Triceratops, and a T-Rex that idles behind you in the menu,
  hunts you after a stumble and catches you on the fatal hit.
* A procedural caveman with six skins (fur colour and pattern, hair, beard, build, accessory),
  springy secondary motion, idle actions and a pterosaur ride for the jetpack power-up.
* Five power-ups (Magnet, Shell Shield, Ptero Ride, Score x2, Dash), eggs and amber as currencies,
  missions, a daily run, revives, a shop with a 3D preview, settings with colour-blind and large-text
  modes, English / Uzbek / Russian.
* Multiplayer (desktop): 1-3 players on a vertical split screen, each controlling a runner from
  their own phone's browser (QR code, no app) or the keyboard; lobby with runner choice and READY,
  3-2-1, lives, a round clock, results with medals and PLAY AGAIN.

## Multiplayer

Main menu > Multiplayer (desktop builds only). The window is maximized to fill the screen
(F11 = full screen) and goes back to its size and place when you leave.
Started from the Godot editor, the game runs embedded in the editor's Game tab and its window
cannot grow (the lobby says so): turn off "Embed Game on Next Play" in the Game tab, or run the
exported build.

1. Phones join over the same Wi-Fi: scan the QR code in the lobby, or type the address shown
   under it (`http://<this computer>:8080`) into the phone browser. No app, no internet needed.
2. On the phone: enter a name, pick a runner (no two players share one), press READY. The round
   starts by itself when everybody is ready (or press START on the computer).
3. In the round the phone is a swipe pad (plus four arrow buttons): left / right change lane, up
   jumps, down rolls. Every player runs the same track in their own strip; three lives each
   (a crash costs one, the runner comes back after a short count), three minutes on the clock.
   The phone shows score, lives, place and the time, and vibrates on hits (Android).
4. Results: places with gold / silver / bronze, distance, eggs, score. PLAY AGAIN on the computer
   or on every phone restarts with the same players; CHANGE PLAYERS goes back to the lobby.

* A phone that loses Wi-Fi or reloads the page gets its slot back (it keeps a phone id); during a
  round its runner waits frozen until the phone is back.
* Keyboard players need no phone: K adds one (first W A S D + Space, then the arrow keys), L
  removes it. B / N add / remove a computer player. Esc pauses (RESUME, RESTART, CHANGE PLAYERS,
  MAIN MENU).
* HOW TO CONNECT (F1) lists every address of the computer, counts page loads and connected
  controllers and says what is wrong. Windows asks once to allow the game through the firewall:
  allow private networks. The server (ports 8080-8090, plain HTTP and WebSocket, LAN only) runs
  only while the multiplayer mode is open.
* Multiplayer rounds never touch the save: all runners are free to pick, power-ups have their
  base durations and no eggs are banked.

## Run it

1. Open the folder in Godot 4.3 or newer (developed on 4.6.3) and press F5.
2. Or from a terminal: `godot --path .`

Controls: touch = swipe left / right (change lane), up (jump), down (roll; in the air: slam
down). Desktop: A / D or arrows change lane, W / Up / Space jump, S / Down roll, Esc pause; mouse
drags act as swipes. Gamepad works too (see `scripts/gameplay/player/input_map_setup.gd`).

Debug builds: F3 overlay, F4 bot, F5 invincible, F6 eggs and amber, F7 next biome, F8 power-up,
F9 slow motion, F10 reload config, F11 speed up, F12 force next pattern.

Web build: `godot --headless --path . --export-release "Web" build/web/index.html`, then serve
`build/web/` with any static server (single-threaded build, no special headers needed).

Windows build (the multiplayer host): `godot --headless --path . --export-release "Windows Desktop"
build/windows/JuraRush.exe` (export templates installed; the pack is embedded in the .exe).

## Test it

```
godot --headless --path . res://tests/test_runner.tscn       # unit + integration tests
godot --headless --path . res://tests/track_soak_test.tscn   # 10 simulated minutes of track
godot --headless --path . -- --bot-soak=600                  # bot plays for 10 simulated minutes
```

Each exits with code 0 on success. Add `-- --only=<text>` to the test runner to run only the test
methods whose name contains `<text>`.

## Dev flags

All go after `--` on the command line (`godot --path . -- <flags>`); none is used by the game.

| Flag | What it does |
|---|---|
| `--bot` | start with the test bot playing |
| `--party` | open the multiplayer lobby at boot |
| `--party-bots=N` | N computer players (1-3) start a multiplayer round at boot |
| `--party-keys=N` | N keyboard players (1-2) join the lobby at boot |
| `--party-help` | open the HOW TO CONNECT window at boot |
| `--party-time=S` | multiplayer round length in seconds |
| `--party-shot=<path>.png` | screenshot after `--party-shot-at=S` seconds (default 9), then quit |
| `--party-close-at=S` | leave the multiplayer mode after S seconds (window restore check), then quit |
| `--bot-soak=N` | headless bot soak for N simulated seconds, exit code 0 / 1 |
| `--ui-shots=<dir>` | screenshot every menu screen (menu in en / uz / ru, every shop skin, flow screens), then quit |
| `--shot=<path>.png` | automated run: `_menu`, `_run1`, `_run2`, `_pause` screenshots, then quit |
| `--shot-interval=S` | seconds between the frames of every burst below (defaults: shot 1.5, menu 0.9, start 0.25) |
| `--shot-burst=N` | N more gameplay frames after `_run2` |
| `--menu-burst=N` | N more menu frames before PLAY |
| `--start-burst=N` | N frames right after PLAY (camera swing, T-Rex retreat) |
| `--force-powerup=ID` | activate a power-up (jetpack, dash, magnet, shield, multiplier) 6 s after PLAY |
| `--action-shots` | lane change, jump and roll on the empty runway, frames mid-move |
| `--shot-scenario=menu` | menu idle / roar frames, then the run start |
| `--shot-scenario=chase` | forced stumble (T-Rex chase frames), then a crash (catch frames) |
| `--shot-pattern=a,b,...` | force these chunk patterns, round robin (each must validate after the previous chunk; an `empty` in between helps) |
| `--biome=N` | runs start in biome N (0 Fern Valley, 1 Red Canyon, 2 Misty Swamp, 3 Volcano Ridge) |
| `--feature=tunnel` / `--feature=bridge` | that track feature (cave / bridge) comes round again and again |
| `--quality=N` | quality preset for automated runs (0 Low .. 2 High) |
| `--no-shadows` | sun shadows off at every quality (performance comparison) |
| `--env-lab=<dir>` | deterministic environment dioramas from the run camera, then quit; with `--lab-only=a,b`, `--lab-style=N`, `--lab-colorblind`, `--lab-perf` |
| `--perf-log` | print FPS, CPU / GPU frame time and draw calls every 2 s |

Labs (run the scene; without flags they are interactive turntables):

| Scene | Flags |
|---|---|
| `res://scenes/vfx/creature_lab.tscn` | `--lab-shot=<dir>` (every creature and pose), `--lab-views=<dir>` (gameplay framings), `--lab-only=a,b` |
| `res://scenes/vfx/runner_lab.tscn` | `--lab-shots=<dir>` (skins, faces, poses, idle actions, pterosaur ride, triangle counts) |

Use a portrait resolution for screenshots, e.g. `godot --path . --resolution 540x960 -- --shot=...`.

## Project layout

```
config/      all tunable data (.tres): game_config, difficulty curve, obstacle / power-up /
             character / trail / biome / mission definitions, ui_theme
scripts/     autoload/ core/ gameplay/ party/ net/ ui/ vfx/ audio/ util/
scenes/      main.tscn plus thin scene files (root node + script)
assets/      shaders, generated icon; drop replacement meshes / audio / fonts here
tests/       test runner, suites, soak test
tools/       icon generator, version sync
docs/        balancing sheet, QA checklist, release checklist
```

See ARCHITECTURE.md for patterns, diagrams and formulas.

## Tuning

Open `config/game_config.tres` in the Inspector. Every number in docs/BALANCING.md is a field
there. Patterns are text rows in `scripts/gameplay/track/pattern_data.gd`; extra `ChunkDef`
resources can be listed in `game_config.tres > extra_chunk_defs`. To rename the game change
`GameConfig.GAME_TITLE` (one constant) and `application/config/name` in Project Settings.

## Replacing the procedural assets

| What | How |
|---|---|
| Meshes | Put `assets/meshes/<id>.glb` (or `.tscn`). Ids: `player`, `chaser`, and every obstacle id in the table below. `VisualProvider` uses the file automatically. |
| Sounds | Put `assets/audio/<id>.ogg` (ids in `scripts/audio/sfx_library.gd`), or fill `config/audio_config.tres` (an `AudioConfig` resource). |
| Music | Set `music_menu`, `music_drums`, `music_bass`, `music_lead` in an `AudioConfig` saved as `config/audio_config.tres`. Layers must be loops of equal length. |
| Font / UI colours | Edit `config/ui_theme.tres`. |

Conventions for meshes: 1 unit = 1 m, +Y up, forward = -Z, pivot at ground centre. Budgets of
the procedural art (keep replacements in the same range): caveman ~4k triangles with hair and
accessory, T-Rex <= 8k, Brachiosaurus <= 6k per animal, Triceratops <= 5k, stone obstacles <= 800,
decor <= 1.5k. Collision sizes come from the `ObstacleDef`, not the mesh. Replacement meshes do not
get the curved-world bend unless their materials use `assets/shaders/world_lit.gdshader`.

## Assets and obstacles

Content ids kept their original (Neon Rails) names so saves, patterns and configs stay compatible;
only the visuals changed. The `train_*` ids are dinosaurs:

| Id | Gameplay | Jura Rush visual |
|---|---|---|
| `train_long`, `train_short` | static train: crash head-on, stumble on the side, walkable roof at 3 m | Brachiosaurus herd. Tail-first when a ramp leads in (the nearest tail IS the ramp, you run along the backs); otherwise head-first, a wall of sauropods facing you |
| `train_moving` | oncoming train with a telegraph | Triceratops stampede: paws, snorts and shakes its head (telegraph), then gallops at you |
| `ramp` | ramp up to a roof | the Brachiosaurus tail when paired with a herd, else a mossy rock slope |
| `barrier_low` | jump over | knee-high pile of boulders |
| `barrier_high` | roll under | stone dolmen (capstone on two standing stones) |
| `barrier_full` | change lane, lethal | wall of menhirs with ochre warning bands |
| `gap` | jump, falling in is a crash | ravine with rock strata, lava glow in Volcano Ridge |
| `hazard_light` | harmless telegraph | flickering torch between the lanes |
| coins / keys | currencies | eggs / amber |
| `jetpack` power-up | flight above the obstacles | Ptero Ride: a pterosaur carries the caveman |
| `player`, `chaser` | runner, chaser | the caveman (six skins), the T-Rex |

## Build for Android

1. Editor > Manage Export Templates: install templates for your Godot version.
2. Editor Settings > Export > Android: set the Android SDK path and Java SDK path (JDK 17).
3. Project > Export: the `Android` (APK) and `Android AAB` presets are in `export_presets.cfg`.
   Package `com.example.jurarush` (placeholder), min SDK 24, arm64-v8a, permission VIBRATE only.
   Change the package name and set a release keystore before publishing.
4. The AAB preset needs Project > Install Android Build Template.

Project settings already applied: Mobile renderer, portrait orientation, 1080x1920 base with
`canvas_items` stretch and `expand` aspect, ETC2/ASTC texture import, MSAA 2x, 60 Hz physics.

iOS: add an iOS preset on a Mac with Xcode, set the bundle identifier and team id, export the
Xcode project, and enable "Requires full screen" with portrait only.

Version: edit `version.cfg`, then run
`godot --headless --path . --script res://tools/apply_version.gd`.
Icon and splash: `godot --path . --script res://tools/generate_icon.gd` (draws with the real
renderer, so no `--headless`; a window opens for a second).

## Known limitations

* No real-money code: `monetization_stub.gd` simulates rewarded ads, `analytics_stub.gd` only logs.
* The frame rate is capped at 60 FPS (`Engine.max_fps`); the simulation is sub-stepped per rendered
  frame (at most 1/60 s per step), so lifting the cap needs no interpolation.
* Collision uses a deterministic box test instead of physics areas (see ARCHITECTURE.md, section 5).
* Consumables (head start, score booster) are used automatically at the start of the next run.
* Not yet run on a physical phone: performance numbers are budgets, not device measurements.

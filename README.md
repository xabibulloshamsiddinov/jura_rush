# NEON RAILS

An original 3D endless lane runner for Android / iOS (portrait) that also runs on desktop.
Everything is generated in code: visuals from primitives and shaders, sound and music from a small
synthesiser. Built with Godot 4 (GDScript, statically typed).

## Run it

1. Open the folder in Godot 4.3 or newer (developed on 4.6.3) and press F5.
2. Or from a terminal: `godot --path .`

Desktop controls: A / D or arrows change lane, W / Up / Space jump, S / Down roll, Esc pause.
Mouse drags act as swipes. Touch: swipe left / right / up / down.

Debug builds: F3 overlay, F4 bot, F5 invincible, F6 coins and keys, F7 next biome, F8 power-up,
F9 slow motion, F10 reload config, F11 speed up, F12 force next pattern.

## 2 Player mode ("Neon Pursuit")

Main menu > **2 PLAYERS**. Shared-screen car duel on a 5-lane night highway, a police cruiser
tailing each car, combat power-ups (seeker rocket, bolt, pulse, EMP domes, mine, nitro, shield,
repair). Code lives in `scripts/versus/` plus `scripts/ui/versus_intro.gd`, `versus_hud.gd`,
`vs_icon.gd`; the single-player game is untouched (its world is detached while a match runs).

| | Player 1 | Player 2 |
|---|---|---|
| Gas / brake | W / S | Up / Down |
| Change lane | A / D | Left / Right |
| Use power-up | Space (F) | Enter (Numpad 0, Right Ctrl) |
| Switch power-up | Q (Left Shift) | Right Shift (Numpad ., /) |

Hold brake while firing to shoot backwards (seeker, bolt, nitro = hard brake). Esc / P pauses.
Testing: `-- --versus-bots`, `-- --versus-shot=out.png`, `-- --versus-soak=60 --versus-time=25`.

Web build: `godot --headless --path . --export-release "Web" build/web/index.html`, then serve
`build/web/` with any static server (single-threaded build, no special headers needed).

## Test it

```
godot --headless --path . res://tests/test_runner.tscn       # unit + integration tests
godot --headless --path . res://tests/track_soak_test.tscn   # 10 simulated minutes of track
godot --headless --path . -- --bot-soak=600                  # bot plays for 10 simulated minutes
```

Each exits with code 0 on success.

## Project layout

```
config/      all tunable data (.tres): game_config, difficulty curve, obstacle / power-up /
             character / trail / biome / mission definitions, ui_theme
scripts/     autoload/ core/ gameplay/ ui/ vfx/ audio/ util/
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
| Meshes | Put `assets/meshes/<id>.glb` (or `.tscn`). Ids: `player`, `chaser`, and every obstacle id (`train_long`, `train_short`, `train_moving`, `barrier_low`, `barrier_high`, `barrier_full`, `ramp`, `gap`, `hazard_light`). `VisualProvider` uses the file automatically. |
| Sounds | Put `assets/audio/<id>.ogg` (ids in `scripts/audio/sfx_library.gd`), or fill `config/audio_config.tres` (an `AudioConfig` resource). |
| Music | Set `music_menu`, `music_drums`, `music_bass`, `music_lead` in an `AudioConfig` saved as `config/audio_config.tres`. Layers must be loops of equal length. |
| Font / UI colours | Edit `config/ui_theme.tres`. |

Conventions for meshes: 1 unit = 1 m, +Y up, forward = -Z, pivot at ground centre. Budgets:
player and chaser <= 3,000 triangles, obstacles <= 800, decor <= 300. Collision sizes come from
the `ObstacleDef`, not the mesh. Replacement meshes do not get the curved-world bend unless their
materials use `assets/shaders/world_lit.gdshader`.

## Build for Android

1. Editor > Manage Export Templates: install templates for your Godot version.
2. Editor Settings > Export > Android: set the Android SDK path and Java SDK path (JDK 17).
3. Project > Export: the `Android` (APK) and `Android AAB` presets are in `export_presets.cfg`.
   Package `com.example.neonrails`, min SDK 24, arm64-v8a, permission VIBRATE only.
   Change the package name and set a release keystore before publishing.
4. The AAB preset needs Project > Install Android Build Template.

Project settings already applied: Mobile renderer, portrait orientation, 1080x1920 base with
`canvas_items` stretch and `expand` aspect, ETC2/ASTC texture import, MSAA 2x, 60 Hz physics.

iOS: add an iOS preset on a Mac with Xcode, set the bundle identifier and team id, export the
Xcode project, and enable "Requires full screen" with portrait only.

Version: edit `version.cfg`, then run
`godot --headless --path . --script res://tools/apply_version.gd`.
Icon and splash: `godot --headless --path . --script res://tools/generate_icon.gd`.

## Known limitations

* No real-money code: `monetization_stub.gd` simulates rewarded ads, `analytics_stub.gd` only logs.
* Gameplay steps at 60 Hz; on 120 Hz screens motion is not interpolated.
* Collision uses a deterministic box test instead of physics areas (see ARCHITECTURE.md, section 5).
* Consumables (head start, score booster) are used automatically at the start of the next run.
* Not yet run on a physical phone: performance numbers are budgets, not device measurements.

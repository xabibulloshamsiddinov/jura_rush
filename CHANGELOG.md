# Changelog

## 1.2.0 (in progress) - UI, visuals and robustness pass

### Look and readability
- One tuning script for every look value: `scripts/vfx/visual_tuning.gd` (glow, coins, player rim,
  obstacle warnings, shadow, atmosphere) with FEATURE_* flags to switch effects off per device.
- Coins 60 % size, shrink near the camera, removed once behind the runner, colour capped below
  the glow threshold; glow without bloom, SCREEN blend (no white blow-out).
- Player rim light; passed obstacles hidden; barrier warning glow pulses and shows through fog;
  chevron lane marker in front of barriers; fog starts at 85 m; contact shadow follows the track.
- Night sky dome (stars, moon, skyline), flickering windows, rail sparks, tunnels and bridges,
  colour theme every 500 m.
- Key-art pass (matches the new icon): neon rail tops in the biome accent, magenta lane dashes
  and edges on a violet bed; smaller two-colour building windows; stronger, wider glow.
- Trains: cabin window rows, neon side stripe, magenta roof edges and destination sign, dark
  windscreen. Gaps now cover the rails, so the rails visibly end at the pit.
- Runner rebuilt: block torso, bending elbows and knees, hands, hair, eyes, sneakers with white
  soles; new cap. Volt (starter) wears the key-art look (orange top, cap with glowing brim);
  Ember is now red with an orange visor.
- Player trail is a faint flat streak on the ground (the upright ribbon read as a laser line);
  particles use a soft round sprite (dust no longer shows as grey squares).

### UI
- Logo drawn in code (`scripts/ui/game_logo.gd`): stacked slanted NEON / RAILS with a neon halo
  and swoosh, on the main menu and loading screen. One font size, two outline sizes (the first
  version cost about 35 MB of glyph atlases).
- Fonts: Orbitron (headings), Rajdhani (body), Exo 2 Cyrillic fallback (SIL OFL, assets/fonts).
- One shared Godot Theme (UITheme.godot_theme) with neon button variations; vector coin / key icons.
- Main menu: runner framed above the buttons, pulsing PLAY, merged Shop, labelled keys,
  Daily Run shows the next reward.
- Shop: 3D SubViewport preview, kinetic list, clear button states, purchase confirmation.
- Settings: Music / SFX on-off, Show FPS (FPS, CPU / GPU frame time, draw calls).

### Tech
- All texts in one translation file `localization/strings.csv` (en / uz / ru) through
  TranslationServer; strings_table.gd removed.
- Optional single music file `assets/audio/music.ogg` replaces the synth layers.
- Dev tools: `-- --ui-shots=<dir>`, `-- --shot-burst=N`, `-- --perf-log`.

## 1.1.0

### 2 Player versus mode
- "Neon Pursuit": two cars, 5-lane highway, civilian traffic, police cruisers that catch you
  when you fall back (hits and braking let them close in), 3 lives, 3-minute clock, fans score.
- Combat power-ups: seeker (homing), bolt, pulse, EMP domes, mine, nitro / hard brake, shield,
  repair; 3 slots per player; backwards fire.
- Intro screen with per-player keys and ready-up, HUD with health / lives / slots / police
  meter, callouts, pause and results; English / Uzbek / Russian strings.
- Procedural cars, police, night city road and synthesised sounds; Web export preset
  (Compatibility renderer).

## 1.0.0

### Phase 1 - Foundation
- Project settings (mobile renderer, portrait 1080x1920, typed-GDScript errors), folder tree.
- Event bus, state machine, object pool, command, service locator, config resources, logging.

### Phase 2 - Endless track
- Treadmill world with chunk recycling and per-frame re-snapping; curved-world + fog shaders.
- Merged track mesh, MultiMesh decor with procedural lit windows, speed model.

### Phase 3 - Player and camera
- Player state machine (run, jump, fall, roll, stumble, jetpack, dead), lane change, jump with
  heavier fall gravity, coyote time, slam-roll, buffered commands, swipe + keyboard + gamepad.
- Camera rig: lagged follow, speed FOV, punches, tilt, trauma shake, menu orbit, death zoom.

### Phase 4 - Obstacles, patterns, validator
- Trains (static, roofed, moving), low / high / full barriers, ramps, gaps, hazard lights.
- 53 patterns in a text DSL, solvability validator, tension-budget pacing, coin layouts,
  swept-box collision, stumble / death rules, near-miss detection.

### Phase 5 - Power-ups, chaser, score, missions, difficulty
- Magnet, shield, jetpack (with sky coin trail), score x2, dash; mystery boxes.
- Chaser robot + drone, score / combo, 15 missions, 12 achievements, adaptive difficulty.

### Phase 6 - VFX and audio
- Pooled particle effects, rings and streaks, speed lines, vignette, flashes, chromatic pulse.
- Synthesised sound effects, 4-layer adaptive music, buses, ducking, pause low-pass, haptics.
- VFX lab and audio lab scenes.

### Phase 7 - UI
- Splash / loading, main menu, HUD, pause, revive, results, shop, missions, settings, tutorial.
- Router with back stack, Android back / Esc, safe area; English / Uzbek / Russian.

### Phase 8 - Save, economy, polish
- Checksummed save with atomic write, backup and v1 -> v2 migration; revive flow with rising
  key cost; daily challenge with streak; biome cross-fades; consumables.

### Phase 9 - Optimisation and QA
- Quality presets, fixed-size effect pools, pool sizes tuned from soak runs.
- 154 automated checks, treadmill soak, validator-driven bot soak, manual QA checklist.

### Phase 10 - Release
- Android export presets, generated icon and splash, version sync tool, documentation.

### Fixed during QA
- `panic_lanes` pattern was unsolvable at its own minimum difficulty; respaced.
- Moving trains arrived half a row earlier than the validator assumed; sweep widened by a row.
- Validator assumed the runner could act immediately after a jump or roof drop even when it
  touched down past the centre of the landing row; it now waits one row in that case.
- Bot soak used `Engine.time_scale` alone, which enlarges the physics step; it now raises the
  tick rate instead so the simulation keeps exact 1/60 s steps.

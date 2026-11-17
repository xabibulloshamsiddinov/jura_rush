# Changelog

## Unreleased - Jura Rush re-theme

The cyberpunk "Neon Rails" becomes the Mesozoic "Jura Rush". Gameplay rules, numbers, patterns and
content ids are unchanged (saves stay compatible); everything the player sees and hears is new.

### World
- Daylight instead of night: a painted sky dome (clouds, sun, distant pterosaurs and hills sat on
  the bent world's visual horizon), a real sun with shadows on Medium / High, sky-tinted ambient
  and one shared soft light model (`world_light.gdshaderinc`) for the ground, flora, rocks, caves,
  bridges, creatures and the caveman. Shadow casters bend correctly in the shadow pass around the
  run camera (`run_cam_z` global, set from `GameConfig.cam_back`).
- Four biomes: Fern Valley, Red Canyon, Misty Swamp, Volcano Ridge, each with its own procedural
  flora, terrain, path stone and sky; rock caves with torches and log bridges over a river replace
  tunnels and viaducts.
- Obstacles in stone: boulder piles (jump), dolmens (roll), menhir walls with ochre bands (dodge),
  ravines with lava glow, torches as harmless telegraphs; eggs instead of coins, amber instead of
  keys, clay-pot mystery boxes, stone-totem power-ups.

### Creatures (OrganicMesh kit)
- Brachiosaurus herds are the static trains: tail-first when a ramp leads in (the tail is the ramp,
  you run along the backs), otherwise a head-first wall. Triceratops stampedes are the moving
  trains (pawing / snorting telegraph, gallop). Visuals match the collision exactly (tested).
- The chaser is a T-Rex: it idles and roars behind the caveman in the menu, roars on PLAY and
  strides off to the left, clear of the camera swing; after a stumble its head looms at the bottom
  right; on the fatal hit it lunges in from behind-right while the death camera looks from
  behind-left, so the camera never dives through it (both choreographies are regression-tested).
- Creatures are lit by the real sun, cast shadows, sway / blink on the GPU and dissolve near the
  lens instead of clipping it.

### Runner
- A procedural caveman (CavemanMesh kit) with smoother lane changes, cross-faded poses, spring
  secondary motion (hair, beard, skirt, feathers), idle actions, a ready crouch, footstep dirt kicks
  and a pterosaur ride for the jetpack. Six skins with fur patterns, hair styles and accessories:
  Bone top-knot, Raptor skull, Feather band, Stone club, Tooth necklace (Blaze wears none).
- His material uses the world's light model (sun direction and colour per biome, shadows, darker in
  caves) plus a camera-side fill and rims that keep him the most readable thing on screen; the blob
  contact shadow stays.
- Shop thumbnails are caveman stickers that show each skin's fur, hair, beard, build and accessory.

### Camera and frame pacing
- New camera rig: front three-quarter menu view with the T-Rex framed under the logo, a 1.1 s
  orbit swing round the runner into the run view on PLAY, critically damped follow, speed roll.
- The world is simulated per rendered frame in sub-steps of at most 1/60 s (no physics-vs-render
  stutter); the chaser is stepped by the world in every state.

### UI and texts
- "Chunky" cartoon UI (ChunkyStyle boxes, vector icons, code-drawn Jura Rush logo, painted sunset
  loading screen), Rubik font; all texts re-written in en / uz / ru.
- Removed: the 2 Player versus mode (code, screens, strings, sounds and test flags).
- Shell Shield bubble in the power-up's jade colour; colour-blind palette for chevrons, menhir
  paint and ravine edges.

### Tools
- Screenshot flags merged: `--shot-interval` shared by `--shot-burst`, `--menu-burst` and
  `--start-burst`; `--force-powerup`, `--action-shots`, `--shot-scenario=menu|chase`,
  `--shot-pattern`. Labs: `creature_lab.tscn`, `runner_lab.tscn`, `--env-lab`. `--ui-shots` covers
  the menu in every language and every shop skin. Test runner filter `-- --only=<text>`.

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

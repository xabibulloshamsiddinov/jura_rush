# Audio

All sounds are synthesised at boot (`scripts/audio/sfx_library.gd`, `music_sequencer.gd`), so this
folder is empty by default.

To replace a sound, drop a file here named after its id, for example `coin.ogg`, `crash.ogg`,
`ui_click.ogg`. `.ogg`, `.wav` and `.mp3` are picked up automatically; no code changes.

Sound ids: coin, jump, land, roll, swipe, stumble, crash, powerup_start, powerup_end,
powerup_warning, shield_hit, shield_break, near_miss, combo_break, box_open, smash, train_horn,
biome, ui_click, ui_hover, ui_back, ui_confirm, ui_error, purchase, mission_complete, count_beep,
count_go, count_up, and the loops train_rumble, jetpack_loop, wind_loop (enable looping in the
import settings for those three).

To replace the music, create an `AudioConfig` resource, save it as `config/audio_config.tres`
and assign `music_menu`, `music_drums`, `music_bass`, `music_lead`. The four tracks play together
and are mixed by speed, so they must be loops of identical length and tempo.

## One music file instead of the synth layers

Drop a single looping synthwave track here as `music.ogg` (or `music.mp3` / `music.wav`).
AudioManager finds it at boot, loops it (menu and runs, slightly louder at high speed) and skips
the four synthesised layers. Use a CC0 / royalty-free track and note its licence next to it.
Music and sound effects each have a volume slider and an ON/OFF toggle in Settings (saved).

## Recipes for every procedural sound effect. Each entry describes mixing rules (bus, volume,
## voice limit, priority); build() renders the placeholder waveform with AudioSynth.
## A real file at assets/audio/<id>.ogg (or an AudioConfig override) replaces any of them.
class_name SfxLibrary
extends RefCounted

const S: int = AudioSynth.Wave.SINE
const Q: int = AudioSynth.Wave.SQUARE
const W: int = AudioSynth.Wave.SAW
const T: int = AudioSynth.Wave.TRIANGLE

## id -> [bus, volume_db, max_voices, priority, loop]
const DEFS: Dictionary = {
	&"coin": [&"SFX", -8.0, 4, 1, false],
	&"jump": [&"SFX", -8.0, 2, 3, false],
	&"land": [&"SFX", -9.0, 2, 2, false],
	&"roll": [&"SFX", -9.0, 2, 3, false],
	&"swipe": [&"SFX", -14.0, 3, 1, false],
	&"stumble": [&"SFX", -4.0, 1, 8, false],
	&"crash": [&"SFX", -1.0, 1, 10, false],
	&"powerup_start": [&"SFX", -5.0, 2, 7, false],
	&"powerup_end": [&"SFX", -8.0, 2, 5, false],
	&"powerup_warning": [&"SFX", -12.0, 1, 4, false],
	&"shield_hit": [&"SFX", -5.0, 1, 8, false],
	&"shield_break": [&"SFX", -4.0, 1, 9, false],
	&"near_miss": [&"SFX", -7.0, 2, 5, false],
	&"combo_break": [&"SFX", -14.0, 1, 2, false],
	&"box_open": [&"SFX", -6.0, 1, 6, false],
	&"smash": [&"SFX", -4.0, 2, 7, false],
	&"train_horn": [&"SFX", -6.0, 1, 6, false],
	&"biome": [&"SFX", -8.0, 1, 6, false],
	&"ui_click": [&"UI", -8.0, 3, 5, false],
	&"ui_hover": [&"UI", -18.0, 2, 1, false],
	&"ui_back": [&"UI", -9.0, 2, 5, false],
	&"ui_confirm": [&"UI", -7.0, 2, 6, false],
	&"ui_error": [&"UI", -8.0, 1, 6, false],
	&"purchase": [&"UI", -5.0, 1, 8, false],
	&"mission_complete": [&"UI", -5.0, 1, 9, false],
	&"count_beep": [&"UI", -7.0, 1, 8, false],
	&"count_go": [&"UI", -5.0, 1, 8, false],
	&"count_up": [&"UI", -14.0, 2, 2, false],
	&"train_rumble": [&"Ambience", -8.0, 1, 4, true],
	&"jetpack_loop": [&"Ambience", -9.0, 1, 4, true],
	&"wind_loop": [&"Ambience", -12.0, 1, 4, true],
}


## Renders the waveform for a sound id.
static func build(id: StringName) -> AudioStreamWAV:
	var b: PackedFloat32Array = PackedFloat32Array()
	var loop: bool = false
	match id:
		&"coin":
			b = AudioSynth.tone(S, 1320.0, 1340.0, 0.05, 0.5, 0.002, 0.02)
			AudioSynth.mix(b, AudioSynth.tone(S, 1980.0, 2020.0, 0.11, 0.45, 0.002, 0.09), 900)
		&"jump":
			b = AudioSynth.tone(T, 280.0, 640.0, 0.17, 0.6, 0.005, 0.08)
		&"land":
			b = AudioSynth.noise(0.12, 0.7, 0.002, 0.1, 0.25, 0.05)
			AudioSynth.mix(b, AudioSynth.tone(S, 110.0, 55.0, 0.12, 0.6, 0.002, 0.09))
		&"roll":
			b = AudioSynth.noise(0.32, 0.6, 0.05, 0.2, 0.05, 0.45)
		&"swipe":
			b = AudioSynth.noise(0.13, 0.5, 0.02, 0.09, 0.5, 0.12)
		&"stumble":
			b = AudioSynth.tone(S, 150.0, 55.0, 0.28, 0.8, 0.002, 0.2)
			AudioSynth.mix(b, AudioSynth.noise(0.2, 0.5, 0.002, 0.17, 0.4, 0.08))
		&"crash":
			b = AudioSynth.noise(0.8, 0.9, 0.002, 0.7, 0.7, 0.03)
			AudioSynth.mix(b, AudioSynth.tone(S, 70.0, 28.0, 0.7, 0.9, 0.002, 0.6))
			AudioSynth.mix(b, AudioSynth.tone(Q, 220.0, 60.0, 0.25, 0.3, 0.002, 0.2))
		&"powerup_start":
			b = _arpeggio([523.0, 659.0, 784.0, 1047.0], 0.07, T, 0.5)
		&"powerup_end":
			b = _arpeggio([784.0, 587.0, 392.0], 0.09, T, 0.45)
		&"powerup_warning":
			b = AudioSynth.tone(Q, 990.0, 990.0, 0.07, 0.35, 0.002, 0.03)
		&"shield_hit":
			b = AudioSynth.tone(Q, 950.0, 420.0, 0.16, 0.45, 0.002, 0.12)
			AudioSynth.mix(b, AudioSynth.tone(S, 1900.0, 900.0, 0.16, 0.3, 0.002, 0.12))
		&"shield_break":
			b = AudioSynth.noise(0.4, 0.7, 0.002, 0.35, 0.9, 0.2)
			AudioSynth.mix(b, AudioSynth.tone(S, 1400.0, 180.0, 0.4, 0.5, 0.002, 0.3))
		&"near_miss":
			b = AudioSynth.noise(0.26, 0.7, 0.08, 0.14, 0.08, 0.7)
		&"combo_break":
			b = AudioSynth.tone(S, 420.0, 210.0, 0.2, 0.4, 0.01, 0.15)
		&"box_open":
			b = _arpeggio([1047.0, 1319.0, 1568.0, 2093.0, 2637.0], 0.05, S, 0.4)
		&"smash":
			b = AudioSynth.noise(0.35, 0.9, 0.002, 0.3, 0.8, 0.1)
			AudioSynth.mix(b, AudioSynth.tone(S, 120.0, 45.0, 0.3, 0.7, 0.002, 0.25))
		&"train_horn":
			# Triceratops stampede telegraph (the id is the old train horn): a snort, then a low,
			# falling bellow.
			b = AudioSynth.noise(0.22, 0.6, 0.01, 0.12, 0.5, 0.15, AudioSynth.RATE, 7)
			AudioSynth.mix(b, AudioSynth.tone(W, 150.0, 92.0, 0.85, 0.42, 0.06, 0.35), 4400)
			AudioSynth.mix(b, AudioSynth.tone(W, 226.0, 140.0, 0.85, 0.18, 0.06, 0.35), 4400)
			AudioSynth.mix(b, AudioSynth.noise(0.85, 0.22, 0.08, 0.4, 0.12, 0.05, AudioSynth.RATE, 9), 4400)
		&"biome":
			b = AudioSynth.tone(S, 330.0, 660.0, 0.6, 0.35, 0.2, 0.3)
			AudioSynth.mix(b, AudioSynth.noise(0.6, 0.25, 0.25, 0.3, 0.05, 0.5))
		&"ui_click":
			b = AudioSynth.tone(T, 880.0, 660.0, 0.05, 0.5, 0.002, 0.03)
		&"ui_hover":
			b = AudioSynth.tone(S, 1200.0, 1200.0, 0.025, 0.3, 0.002, 0.02)
		&"ui_back":
			b = AudioSynth.tone(T, 620.0, 380.0, 0.09, 0.5, 0.002, 0.06)
		&"ui_confirm":
			b = _arpeggio([660.0, 990.0], 0.06, T, 0.5)
		&"ui_error":
			b = _arpeggio([220.0, 180.0], 0.09, Q, 0.4)
		&"purchase":
			b = _arpeggio([1319.0, 1760.0, 2637.0], 0.07, S, 0.5)
			AudioSynth.mix(b, AudioSynth.noise(0.08, 0.2, 0.002, 0.07, 0.9, 0.6))
		&"mission_complete":
			b = _arpeggio([523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0], 0.085, T, 0.5)
		&"count_beep":
			b = AudioSynth.tone(S, 880.0, 880.0, 0.12, 0.5, 0.004, 0.06)
		&"count_go":
			b = AudioSynth.tone(S, 1320.0, 1320.0, 0.35, 0.5, 0.004, 0.25)
			AudioSynth.mix(b, AudioSynth.tone(S, 1760.0, 1760.0, 0.35, 0.3, 0.004, 0.25))
		&"count_up":
			b = AudioSynth.tone(S, 1500.0, 1700.0, 0.03, 0.35, 0.002, 0.02)
		&"train_rumble":
			b = AudioSynth.make_seamless(AudioSynth.noise(1.3, 0.9, 0.01, 0.01, 0.06, 0.06, AudioSynth.RATE, 5), 0.25)
			loop = true
		&"jetpack_loop":
			b = AudioSynth.noise(1.2, 0.6, 0.01, 0.01, 0.3, 0.3, AudioSynth.RATE, 9)
			AudioSynth.mix(b, AudioSynth.tone(W, 82.0, 82.0, 1.2, 0.3, 0.01, 0.01))
			b = AudioSynth.make_seamless(b, 0.2)
			loop = true
		&"wind_loop":
			b = AudioSynth.make_seamless(AudioSynth.noise(1.6, 0.8, 0.01, 0.01, 0.12, 0.12, AudioSynth.RATE, 3), 0.3)
			loop = true
	return AudioSynth.to_stream(b, loop)


static func _arpeggio(freqs: Array[float], step: float, wave: int, volume: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for i in range(freqs.size()):
		var last: bool = i == freqs.size() - 1
		var note: PackedFloat32Array = AudioSynth.tone(wave as AudioSynth.Wave, freqs[i], freqs[i],
				step * (3.0 if last else 1.4), volume, 0.003, step * (2.4 if last else 0.9))
		AudioSynth.mix(out, note, int(float(i) * step * float(AudioSynth.RATE)))
	return out

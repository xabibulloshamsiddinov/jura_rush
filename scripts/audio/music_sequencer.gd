## Procedural music: a 4-bar step sequencer in A minor pentatonic rendered once into four
## perfectly synchronised loops (drums, bass, lead, pad). AudioManager fades the layers in and
## out with speed / difficulty (adaptive music); the menu uses the calm pad-led mix.
class_name MusicSequencer
extends RefCounted

const RATE: int = 16000
const BARS: int = 4
const STEPS_PER_BAR: int = 16
## A minor pentatonic across two octaves (Hz).
const SCALE: Array[float] = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99]
## Bass root per bar (scale indices, played two octaves down).
const BASS_ROOTS: Array[int] = [0, 0, 2, 3]
## Lead melody: one scale index per 8th note (-1 = rest), 8 per bar.
const LEAD: Array[int] = [
	5, -1, 7, 5, 8, -1, 7, 5,
	4, -1, 5, 7, 5, -1, 4, 2,
	7, -1, 8, 9, 8, -1, 7, 5,
	8, 7, 5, 4, 5, -1, -1, -1,
]

var bpm: float = 128.0


func _init(p_bpm: float = 128.0) -> void:
	bpm = p_bpm


## Samples in one 16th-note step.
func step_samples() -> int:
	return int(60.0 / bpm / 4.0 * float(RATE))


## Total samples in the loop.
func loop_samples() -> int:
	return step_samples() * STEPS_PER_BAR * BARS


## Kick on every beat, snare on 2 and 4, hats on the off-beat 8ths.
func build_drums() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _empty()
	var kick: PackedFloat32Array = AudioSynth.tone(AudioSynth.Wave.SINE, 130.0, 42.0, 0.16, 0.9, 0.002, 0.1, RATE)
	var snare: PackedFloat32Array = AudioSynth.noise(0.12, 0.5, 0.002, 0.1, 0.8, 0.3, RATE, 11)
	var hat: PackedFloat32Array = AudioSynth.noise(0.04, 0.22, 0.001, 0.035, 1.0, 1.0, RATE, 17)
	for step in range(STEPS_PER_BAR * BARS):
		var offset: int = step * step_samples()
		var in_bar: int = step % STEPS_PER_BAR
		if in_bar % 4 == 0:
			AudioSynth.mix_wrapped(buf, kick, offset)
		if in_bar == 4 or in_bar == 12:
			AudioSynth.mix_wrapped(buf, snare, offset)
		if in_bar % 4 == 2:
			AudioSynth.mix_wrapped(buf, hat, offset)
	return AudioSynth.to_stream(buf, true, RATE)


## Driving 8th-note bass on the bar's root.
func build_bass() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _empty()
	var eighth: float = 60.0 / bpm / 2.0
	for bar in range(BARS):
		var freq: float = SCALE[BASS_ROOTS[bar]] / 4.0
		var note: PackedFloat32Array = AudioSynth.tone(AudioSynth.Wave.TRIANGLE, freq, freq,
				eighth * 0.85, 0.55, 0.004, 0.04, RATE)
		var octave: PackedFloat32Array = AudioSynth.tone(AudioSynth.Wave.TRIANGLE, freq * 2.0,
				freq * 2.0, eighth * 0.6, 0.4, 0.004, 0.04, RATE)
		for i in range(8):
			var offset: int = (bar * STEPS_PER_BAR + i * 2) * step_samples()
			AudioSynth.mix_wrapped(buf, octave if i % 4 == 3 else note, offset)
	return AudioSynth.to_stream(buf, true, RATE)


## Pentatonic lead line.
func build_lead() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _empty()
	var eighth: float = 60.0 / bpm / 2.0
	for i in range(LEAD.size()):
		if LEAD[i] < 0:
			continue
		var freq: float = SCALE[LEAD[i]]
		var note: PackedFloat32Array = AudioSynth.tone(AudioSynth.Wave.SQUARE, freq, freq,
				eighth * 1.2, 0.2, 0.006, eighth * 0.7, RATE)
		AudioSynth.mix_wrapped(buf, note, i * 2 * step_samples())
	return AudioSynth.to_stream(buf, true, RATE)


## Soft sustained chords (root + fifth + octave), one per bar.
func build_pad() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _empty()
	var bar_seconds: float = 60.0 / bpm * 4.0
	for bar in range(BARS):
		var root: float = SCALE[BASS_ROOTS[bar]] / 2.0
		for ratio: float in [1.0, 1.5, 2.0]:
			var note: PackedFloat32Array = AudioSynth.tone(AudioSynth.Wave.SINE, root * ratio,
					root * ratio, bar_seconds * 1.05, 0.16, bar_seconds * 0.2, bar_seconds * 0.25, RATE)
			AudioSynth.mix_wrapped(buf, note, bar * STEPS_PER_BAR * step_samples())
	return AudioSynth.to_stream(buf, true, RATE)


func _empty() -> PackedFloat32Array:
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(loop_samples())
	return buf

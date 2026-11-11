## Tiny software synthesiser. Builds AudioStreamWAV placeholders at boot from oscillators, noise,
## envelopes, pitch sweeps and a one-pole low-pass, so the game ships without audio files.
class_name AudioSynth
extends RefCounted

enum Wave { SINE, SQUARE, SAW, TRIANGLE }

const RATE: int = 22050


## Oscillator note with a linear pitch sweep and an attack / release envelope.
static func tone(wave: Wave, freq_from: float, freq_to: float, duration: float, volume: float,
		attack: float = 0.005, release: float = 0.05, rate: int = RATE) -> PackedFloat32Array:
	var n: int = int(duration * float(rate))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var attack_n: float = maxf(attack * float(rate), 1.0)
	var release_n: float = maxf(release * float(rate), 1.0)
	for i in range(n):
		var t: float = float(i) / float(n)
		phase += lerpf(freq_from, freq_to, t) / float(rate)
		phase -= floorf(phase)
		var s: float = 0.0
		match wave:
			Wave.SINE:
				s = sin(phase * TAU)
			Wave.SQUARE:
				s = 0.6 if phase < 0.5 else -0.6
			Wave.SAW:
				s = (phase * 2.0 - 1.0) * 0.7
			Wave.TRIANGLE:
				s = 1.0 - 4.0 * absf(phase - 0.5)
		var env: float = minf(minf(float(i) / attack_n, float(n - i) / release_n), 1.0)
		out[i] = s * env * volume
	return out


## Filtered white noise. The low-pass cutoff factor sweeps from cut_from to cut_to (0..1).
static func noise(duration: float, volume: float, attack: float, release: float,
		cut_from: float = 1.0, cut_to: float = 1.0, rate: int = RATE, noise_seed: int = 1) -> PackedFloat32Array:
	var n: int = int(duration * float(rate))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = noise_seed
	var attack_n: float = maxf(attack * float(rate), 1.0)
	var release_n: float = maxf(release * float(rate), 1.0)
	var y: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		y += lerpf(cut_from, cut_to, t) * (rng.randf_range(-1.0, 1.0) - y)
		var env: float = minf(minf(float(i) / attack_n, float(n - i) / release_n), 1.0)
		out[i] = y * env * volume
	return out


## Adds `src` into `dst` starting at `offset` samples (dst grows if needed). Returns dst.
static func mix(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int = 0) -> PackedFloat32Array:
	if dst.size() < offset + src.size():
		dst.resize(offset + src.size())
	for i in range(src.size()):
		dst[offset + i] += src[i]
	return dst


## Like mix() but wraps around the end of dst (for seamless loops).
static func mix_wrapped(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int) -> void:
	var n: int = dst.size()
	for i in range(src.size()):
		dst[(offset + i) % n] += src[i]


## Cross-fades the tail of a buffer into its head so it loops without a click.
static func make_seamless(samples: PackedFloat32Array, fade_seconds: float, rate: int = RATE) -> PackedFloat32Array:
	var fade: int = mini(int(fade_seconds * float(rate)), samples.size() / 2)
	var n: int = samples.size() - fade
	var out: PackedFloat32Array = samples.slice(0, n)
	for i in range(fade):
		var t: float = float(i) / float(fade)
		out[i] = out[i] * t + samples[n + i] * (1.0 - t)
	return out


## Converts float samples (-1..1) to a 16-bit mono AudioStreamWAV.
static func to_stream(samples: PackedFloat32Array, loop: bool = false, rate: int = RATE) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream

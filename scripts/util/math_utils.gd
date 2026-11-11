## Small math helpers shared across gameplay, camera and UI.
class_name MathUtils
extends RefCounted


## Ease-out cubic: fast start, soft landing. t in 0..1.
static func ease_out_cubic(t: float) -> float:
	var u: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


## Ease-in quad. t in 0..1.
static func ease_in_quad(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c


## Frame-rate independent smoothing toward a target. `lag` is roughly the time to close 63%.
static func damp(current: float, target: float, lag: float, delta: float) -> float:
	if lag <= 0.0001:
		return target
	return lerpf(target, current, exp(-delta / lag))


## Pitch ratio for a number of semitones.
static func semitones(n: float) -> float:
	return pow(2.0, n / 12.0)


## Formats seconds as m:ss.
static func time_text(seconds: float) -> String:
	var s: int = int(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d" % [s / 60, s % 60]


## Formats an integer with thin thousands separators (12 345).
static func group_digits(value: int) -> String:
	var s: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return ("-" + out) if value < 0 else out

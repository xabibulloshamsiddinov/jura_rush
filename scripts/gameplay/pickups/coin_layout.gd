## Coin placement helpers: lines, jump arcs, diagonals (zig-zags) and spirals.
## All positions are local to the CoinField they are added to.
class_name CoinLayout
extends RefCounted


## Evenly spaced coins along z at a fixed x / y.
static func line(field: CoinField, x: float, y: float, z_from: float, z_to: float, count: int) -> void:
	for i in range(count):
		var t: float = (float(i) + 0.5) / float(count)
		field.add(Vector3(x, y, lerpf(z_from, z_to, t)))


## A parabola matching a jump: `span` metres long, peaking `peak` above base_y at z_center.
static func arc(field: CoinField, x: float, base_y: float, z_center: float, span: float,
		peak: float, count: int) -> void:
	for i in range(count):
		var u: float = (float(i) + 0.5) / float(count)
		var z: float = z_center + span * (0.5 - u)
		field.add(Vector3(x, base_y + peak * 4.0 * u * (1.0 - u), z))


## Coins sliding from x_from to x_to while advancing along z (one leg of a zig-zag).
static func diagonal(field: CoinField, x_from: float, x_to: float, y: float, z_from: float,
		z_to: float, count: int) -> void:
	for i in range(count):
		var t: float = (float(i) + 0.5) / float(count)
		field.add(Vector3(lerpf(x_from, x_to, t), y, lerpf(z_from, z_to, t)))


## A corkscrew of coins around a centre line (used for the jetpack sky trail).
static func spiral(field: CoinField, x_center: float, y_center: float, radius: float,
		z_from: float, z_to: float, count: int, turns: float) -> void:
	for i in range(count):
		var t: float = (float(i) + 0.5) / float(count)
		var a: float = t * turns * TAU
		field.add(Vector3(x_center + cos(a) * radius, y_center + sin(a) * radius * 0.5,
				lerpf(z_from, z_to, t)))

## A warm prehistoric sunset painted in code: sky gradient, a big sun, a smoking volcano, rolling
## hills, a Brachiosaurus silhouette and palms. The backdrop of the loading screen and of the
## generated splash image (tools/generate_icon.gd), so both always match.
class_name JuraBackdrop
extends Control

const SKY_TOP: Color = Color(0.20, 0.09, 0.10)
const SKY_MID: Color = Color(0.80, 0.34, 0.14)
const SKY_LOW: Color = Color(1.0, 0.80, 0.38)
const FAR: Color = Color(0.36, 0.16, 0.10)
const MID: Color = Color(0.24, 0.12, 0.07)
const NEAR: Color = Color(0.13, 0.07, 0.04)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	paint(self, size)


## Paints the scene into `area` (origin at the top-left of the item).
static func paint(ci: CanvasItem, area: Vector2) -> void:
	var w: float = area.x
	var h: float = area.y
	# Sky: two vertical gradient bands meeting at the glowing horizon.
	_band(ci, 0.0, h * 0.52, w, SKY_TOP, SKY_MID)
	_band(ci, h * 0.52, h * 0.74, w, SKY_MID, SKY_LOW)
	_band(ci, h * 0.74, h * 0.84, w, SKY_LOW, SKY_LOW)
	# Sun with soft halos.
	var sun: Vector2 = Vector2(w * 0.5, h * 0.66)
	for i in range(7):
		var k: float = float(i) / 6.0
		ci.draw_circle(sun, w * (0.46 - 0.30 * k), Color(1.0, 0.86, 0.45, 0.05 + 0.03 * k), true, -1.0, true)
	ci.draw_circle(sun, w * 0.17, Color(1.0, 0.95, 0.72), true, -1.0, true)
	# Volcano on the right with a lava-lit crater and smoke.
	var volcano: PackedVector2Array = PackedVector2Array([
		Vector2(w * 0.40, h * 0.75), Vector2(w * 0.60, h * 0.62), Vector2(w * 0.71, h * 0.53),
		Vector2(w * 0.745, h * 0.515), Vector2(w * 0.775, h * 0.525), Vector2(w * 0.805, h * 0.512),
		Vector2(w * 0.84, h * 0.535), Vector2(w * 0.95, h * 0.62), Vector2(w * 1.1, h * 0.75)])
	ci.draw_colored_polygon(volcano, FAR)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.745, h * 0.516), Vector2(w * 0.775, h * 0.526),
			Vector2(w * 0.805, h * 0.513), Vector2(w * 0.79, h * 0.54), Vector2(w * 0.76, h * 0.54)]),
			Color(1.0, 0.55, 0.12))
	for i in range(4):
		var puff: Vector2 = Vector2(w * (0.77 + 0.025 * float(i)), h * (0.49 - 0.04 * float(i)))
		ci.draw_circle(puff, w * (0.03 + 0.012 * float(i)), Color(0.28, 0.13, 0.09, 0.55 - 0.1 * float(i)), true, -1.0, true)
	# Far and near hills.
	ci.draw_colored_polygon(_hills(w, h, 0.735, 0.018, 7.0, 0.8), MID)
	_brachiosaurus(ci, Vector2(w * 0.27, h * 0.745), w * 0.30, NEAR)
	ci.draw_colored_polygon(_hills(w, h, 0.79, 0.014, 5.0, 2.2), NEAR)
	_palm(ci, Vector2(w * 0.07, h * 0.82), h * 0.17, 0.5, NEAR)
	_palm(ci, Vector2(w * 0.93, h * 0.83), h * 0.15, -0.5, NEAR)
	_palm(ci, Vector2(w * 0.17, h * 0.86), h * 0.10, 0.35, NEAR)
	ci.draw_rect(Rect2(0.0, h * 0.86, w, h * 0.14), NEAR)


static func _band(ci: CanvasItem, y0: float, y1: float, w: float, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(0.0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0.0, y1)]),
			PackedColorArray([top, top, bottom, bottom]))


## Rolling hill outline filled down to the bottom edge.
static func _hills(w: float, h: float, base: float, amplitude: float, waves: float, phase: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 36
	for i in range(steps + 1):
		var x: float = w * float(i) / float(steps)
		pts.append(Vector2(x, h * (base + amplitude * sin(x / w * waves + phase))))
	pts.append(Vector2(w, h))
	pts.append(Vector2(0.0, h))
	return pts


## A long-necked Brachiosaurus walking along the horizon (silhouette).
static func _brachiosaurus(ci: CanvasItem, ground: Vector2, length: float, color: Color) -> void:
	var u: float = length / 10.0
	var body: Vector2 = ground + Vector2(0.0, -u * 1.6)
	for leg: float in [-3.0, -1.6, 1.4, 2.8]:
		ci.draw_rect(Rect2(body.x + leg * u - u * 0.35, body.y, u * 0.7, u * 1.6), color)
	ci.draw_colored_polygon(_oval(body, u * 4.0, u * 1.5, 0.0), color)
	var neck: PackedVector2Array = PackedVector2Array([body + Vector2(u * 3.0, -u * 0.6),
			body + Vector2(u * 4.2, -u * 2.6), body + Vector2(u * 4.6, -u * 5.0), body + Vector2(u * 5.4, -u * 6.4)])
	ci.draw_polyline(neck, color, u * 1.0, true)
	ci.draw_colored_polygon(_oval(body + Vector2(u * 5.9, -u * 6.5), u * 0.9, u * 0.5, -0.25), color)
	var tail: PackedVector2Array = PackedVector2Array([body + Vector2(-u * 3.6, -u * 0.2),
			body + Vector2(-u * 5.5, u * 0.5), body + Vector2(-u * 7.0, u * 1.4)])
	ci.draw_polyline(tail, color, u * 0.7, true)


## A palm: curved trunk with a fan of fronds (silhouette).
static func _palm(ci: CanvasItem, base: Vector2, height: float, lean: float, color: Color) -> void:
	var trunk: PackedVector2Array = PackedVector2Array()
	for i in range(9):
		var t: float = float(i) / 8.0
		trunk.append(base + Vector2(lean * height * 0.35 * t * t, -height * t))
	ci.draw_polyline(trunk, color, height * 0.07, true)
	var top: Vector2 = trunk[8]
	for i in range(7):
		var a: float = deg_to_rad(-170.0 + 160.0 * float(i) / 6.0)
		var tip: Vector2 = top + Vector2(cos(a), sin(a) * 0.7) * height * 0.5
		var mid: Vector2 = top + Vector2(cos(a), sin(a) * 0.7 - 0.25) * height * 0.28
		var side: Vector2 = Vector2(-sin(a), cos(a)) * height * 0.045
		ci.draw_colored_polygon(PackedVector2Array([top, mid + side, tip, mid - side]), color)


static func _oval(center: Vector2, rx: float, ry: float, rot: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in range(24):
		var a: float = TAU * float(i) / 24.0
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out

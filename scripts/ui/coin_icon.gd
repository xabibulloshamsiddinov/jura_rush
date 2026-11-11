## Vector coin icon drawn with the 2D canvas (no texture, scales cleanly to any size): dark gold
## rim, bright face, inner ring, a vertical slot emblem and a small shine. Used wherever a coin
## amount is shown instead of the old placeholder "o".
class_name CoinIcon
extends Control

const RIM: Color = Color(0.72, 0.45, 0.02)
const FACE: Color = Color(1.0, 0.8, 0.12)
const INNER: Color = Color(1.0, 0.9, 0.38)
const EMBLEM: Color = Color(0.8, 0.52, 0.04)
const SHINE: Color = Color(1.0, 1.0, 0.92, 0.85)

## Diameter in UI pixels.
@export var diameter: float = 48.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(value, value)
		queue_redraw()
## Draws the coin greyed out (for unaffordable / disabled states).
@export var dimmed: bool = false:
	set(value):
		dimmed = value
		queue_redraw()


func _init(p_diameter: float = 48.0) -> void:
	diameter = p_diameter
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	var k: float = 0.45 if dimmed else 1.0
	draw_circle(c, r, _tone(RIM, k), true, -1.0, true)
	draw_circle(c, r * 0.84, _tone(FACE, k), true, -1.0, true)
	draw_arc(c, r * 0.64, 0.0, TAU, 32, _tone(INNER, k), maxf(r * 0.1, 1.0), true)
	var slot: Vector2 = Vector2(r * 0.2, r * 0.72)
	draw_rect(Rect2(c - slot * 0.5, slot), _tone(EMBLEM, k), true)
	draw_arc(c, r * 0.84, deg_to_rad(200.0), deg_to_rad(250.0), 10, SHINE * Color(1, 1, 1, k),
			maxf(r * 0.12, 1.0), true)


func _tone(color: Color, k: float) -> Color:
	if k >= 1.0:
		return color
	var grey: float = color.get_luminance() * 0.75
	return Color(grey, grey, grey).lerp(color, 0.2)

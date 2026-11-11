## Vector key icon (revive keys), drawn like CoinIcon so it scales cleanly.
class_name KeyIcon
extends Control

const BODY: Color = Color(0.0, 0.9, 1.0)
const DARK: Color = Color(0.0, 0.35, 0.45)

@export var diameter: float = 48.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(value, value)
		queue_redraw()


func _init(p_diameter: float = 48.0) -> void:
	diameter = p_diameter
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	var ring_c: Vector2 = o + Vector2(s * 0.3, s * 0.5)
	var w: float = maxf(s * 0.12, 1.5)
	draw_arc(ring_c, s * 0.2, 0.0, TAU, 24, BODY, w, true)
	draw_circle(ring_c, s * 0.07, DARK, true, -1.0, true)
	var shaft_from: Vector2 = ring_c + Vector2(s * 0.2, 0.0)
	var shaft_to: Vector2 = o + Vector2(s * 0.95, s * 0.5)
	draw_line(shaft_from, shaft_to, BODY, w, true)
	draw_line(o + Vector2(s * 0.78, s * 0.5), o + Vector2(s * 0.78, s * 0.7), BODY, w, true)
	draw_line(o + Vector2(s * 0.92, s * 0.5), o + Vector2(s * 0.92, s * 0.66), BODY, w, true)

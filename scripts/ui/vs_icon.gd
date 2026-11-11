## Power-up badge for the versus UI: a glowing coloured disc with a vector glyph drawn in code
## (rocket, bolt, shockwave, dome, mine, flame, shield, wrench), so no icon art is needed.
class_name VsIcon
extends Control

var id: StringName = &"":
	set(value):
		id = value
		queue_redraw()
## Dimmed when the slot is not the active one.
var active: bool = true:
	set(value):
		active = value
		queue_redraw()


func _init(power_id: StringName = &"", side: float = 96.0) -> void:
	id = power_id
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	if id == &"":
		draw_circle(c, r * 0.92, Color(1.0, 1.0, 1.0, 0.06))
		draw_arc(c, r * 0.92, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.22), maxf(r * 0.06, 2.0), true)
		return
	var col: Color = VsDefs.color(id)
	var alpha: float = 1.0 if active else 0.55
	draw_circle(c, r, Color(col, 0.22 * alpha))
	draw_circle(c, r * 0.84, Color(col.darkened(0.55), 0.95 * alpha))
	draw_arc(c, r * 0.84, 0.0, TAU, 48, Color(col.lightened(0.2), alpha), maxf(r * 0.09, 2.0), true)
	var ink: Color = Color(1.0, 1.0, 1.0, alpha)
	var w: float = maxf(r * 0.1, 2.0)
	var s: float = r * 0.5
	match id:
		&"seeker":
			var body: PackedVector2Array = PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 0.42, -s * 0.3),
					c + Vector2(s * 0.42, s * 0.55), c + Vector2(-s * 0.42, s * 0.55), c + Vector2(-s * 0.42, -s * 0.3)])
			draw_colored_polygon(body, ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, s * 0.1), c + Vector2(-s * 0.8, s * 0.75),
					c + Vector2(-s * 0.42, s * 0.55)]), ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.42, s * 0.1), c + Vector2(s * 0.8, s * 0.75),
					c + Vector2(s * 0.42, s * 0.55)]), ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.25, s * 0.6), c + Vector2(s * 0.25, s * 0.6),
					c + Vector2(0, s * 1.15)]), Color(col.lightened(0.5), alpha))
		&"bolt":
			for k in range(3):
				var y: float = -s * 0.75 + float(k) * s * 0.75
				draw_line(c + Vector2(-s * 0.9, y), c + Vector2(s * 0.5, y), ink, w * 1.2, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.5, y - s * 0.22), c + Vector2(s * 1.0, y),
						c + Vector2(s * 0.5, y + s * 0.22)]), ink)
		&"pulse":
			draw_circle(c, s * 0.3, ink)
			draw_arc(c, s * 0.65, 0.0, TAU, 32, ink, w, true)
			draw_arc(c, s * 1.0, 0.0, TAU, 40, Color(ink, alpha * 0.6), w * 0.8, true)
		&"emp":
			draw_arc(c + Vector2(0, s * 0.45), s * 0.95, PI, TAU, 32, ink, w, true)
			draw_line(c + Vector2(-s * 1.05, s * 0.45), c + Vector2(s * 1.05, s * 0.45), ink, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(s * 0.1, -s * 0.5), c + Vector2(-s * 0.25, s * 0.05),
					c + Vector2(s * 0.15, s * 0.05), c + Vector2(-s * 0.15, s * 0.45)]), ink, w * 0.8, true)
		&"mine":
			for k in range(8):
				var a: float = float(k) * TAU / 8.0
				draw_line(c, c + Vector2(cos(a), sin(a)) * s * 0.95, ink, w, true)
			draw_circle(c, s * 0.6, ink)
			draw_circle(c, s * 0.24, Color(col, alpha))
		&"nitro":
			for k in range(2):
				var x: float = -s * 0.55 + float(k) * s * 0.6
				draw_polyline(PackedVector2Array([c + Vector2(x, -s * 0.7), c + Vector2(x + s * 0.55, 0),
						c + Vector2(x, s * 0.7)]), ink, w * 1.3, true)
		&"shield":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.85, -s * 0.6),
					c + Vector2(s * 0.7, s * 0.3), c + Vector2(0, s * 1.05), c + Vector2(-s * 0.7, s * 0.3),
					c + Vector2(-s * 0.85, -s * 0.6)]), ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.62), c + Vector2(s * 0.5, -s * 0.38),
					c + Vector2(s * 0.4, s * 0.2), c + Vector2(0, s * 0.62)]), Color(col, alpha))
		&"repair":
			draw_rect(Rect2(c - Vector2(s * 0.25, s * 0.85), Vector2(s * 0.5, s * 1.7)), ink)
			draw_rect(Rect2(c - Vector2(s * 0.85, s * 0.25), Vector2(s * 1.7, s * 0.5)), ink)

## Small coloured preview drawn for a shop row: a mini runner silhouette in the skin colours, a
## trail ribbon, or a glowing power-up badge with its icon letter.
class_name ItemThumb
extends Control

enum Kind { RUNNER, TRAIL, BADGE }

var kind: Kind = Kind.BADGE
var body: Color = Color.WHITE
var limbs: Color = Color(0.15, 0.15, 0.25)
var head: Color = Color(0.95, 0.8, 0.65)
var glow: Color = Color(0.0, 0.9, 1.0)
var badge_text: String = ""


func _init(p_kind: Kind, size_px: float = 104.0) -> void:
	kind = p_kind
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


static func runner(def: CharacterDef) -> ItemThumb:
	var t: ItemThumb = ItemThumb.new(Kind.RUNNER)
	t.body = def.body_color
	t.limbs = def.limb_color
	t.head = def.head_color
	t.glow = def.glow_color
	return t


static func trail(color: Color) -> ItemThumb:
	var t: ItemThumb = ItemThumb.new(Kind.TRAIL)
	t.glow = color
	return t


static func badge(color: Color, text: String) -> ItemThumb:
	var t: ItemThumb = ItemThumb.new(Kind.BADGE)
	t.glow = color
	t.badge_text = text
	return t


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	draw_rect(Rect2(o, Vector2(s, s)), Color(0.02, 0.03, 0.08, 0.9))
	draw_rect(Rect2(o, Vector2(s, s)), Color(glow, 0.8), false, 2.0)
	match kind:
		Kind.RUNNER:
			var cx: float = o.x + s * 0.5
			draw_rect(Rect2(cx - s * 0.13, o.y + s * 0.6, s * 0.1, s * 0.3), limbs)    # legs
			draw_rect(Rect2(cx + s * 0.03, o.y + s * 0.6, s * 0.1, s * 0.3), limbs)
			draw_rect(Rect2(cx - s * 0.25, o.y + s * 0.36, s * 0.08, s * 0.26), limbs) # arms
			draw_rect(Rect2(cx + s * 0.17, o.y + s * 0.36, s * 0.08, s * 0.26), limbs)
			draw_rect(Rect2(cx - s * 0.16, o.y + s * 0.33, s * 0.32, s * 0.32), body)  # torso
			draw_rect(Rect2(cx - s * 0.16, o.y + s * 0.46, s * 0.32, s * 0.04), glow)
			draw_circle(Vector2(cx, o.y + s * 0.22), s * 0.12, head, true, -1.0, true)
		Kind.TRAIL:
			var points: PackedVector2Array = PackedVector2Array()
			for i in range(9):
				var t: float = float(i) / 8.0
				points.append(o + Vector2(s * (0.12 + t * 0.76), s * (0.5 + sin(t * TAU) * 0.18)))
			draw_polyline(points, Color(glow, 0.35), s * 0.18, true)
			draw_polyline(points, glow, s * 0.07, true)
		Kind.BADGE:
			draw_circle(o + Vector2(s, s) * 0.5, s * 0.32, Color(glow, 0.3), true, -1.0, true)
			draw_arc(o + Vector2(s, s) * 0.5, s * 0.32, 0.0, TAU, 32, glow, 3.0, true)
			if not badge_text.is_empty():
				var font: Font = UIKit.font()
				var fs: int = int(s * 0.36)
				var w: float = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, o + Vector2((s - w) * 0.5, s * 0.5 + fs * 0.35), badge_text,
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

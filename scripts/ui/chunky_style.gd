## Cartoon "stone and leather" box style shared by buttons, panels and badges: a thick dark
## outline, an optional coloured ring, a darker lip along the bottom edge (the 3D side of a
## button) and a soft highlight on the face. A pressed button drops its face onto the lip.
## Drawn from StyleBoxFlats, so the corners are anti-aliased at any radius.
class_name ChunkyStyle
extends StyleBox

var face: Color = Color(0.42, 0.74, 0.2)
var outline: Color = Color(0.11, 0.065, 0.035)
var outline_width: float = 6.0
## Optional coloured ring between the outline and the face (alpha 0 = none).
var ring: Color = Color(0.0, 0.0, 0.0, 0.0)
var ring_width: float = 4.0
## Height of the 3D lip in pixels (0 = flat, used by panels).
var lip: float = 10.0
## Colour of the lip (alpha 0 = a darker shade of the face).
var lip_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var radius: int = 30
## Pressed: the face sinks onto the lip, so the button loses its lip height from the top.
var pressed: bool = false
## Alpha of the soft highlight over the top of the face (0 = none).
var shine: float = 0.2

var _box: StyleBoxFlat = StyleBoxFlat.new()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var body: Rect2 = rect
	var drop: float = lip
	if pressed:
		body = Rect2(rect.position + Vector2(0.0, lip), rect.size - Vector2(0.0, lip))
		drop = 0.0
	var edge: float = outline_width + (ring_width if ring.a > 0.0 else 0.0)
	if body.size.x <= edge * 2.0 + 2.0 or body.size.y <= edge * 2.0 + 2.0:
		return
	var inner: Rect2 = body.grow(-outline_width)
	var inner_radius: int = maxi(radius - int(outline_width), 0)
	var face_area: Rect2 = inner
	var face_radius: int = inner_radius
	if ring.a > 0.0:
		face_area = inner.grow(-ring_width)
		face_radius = maxi(inner_radius - int(ring_width), 0)
	# Fills reach 1 px under the strokes so no hairline seam shows between them.
	var under: Rect2 = face_area.grow(1.0)
	if drop > 0.0 and under.size.y > drop:
		_fill(to_canvas_item, under, lip_color if lip_color.a > 0.0 else face.darkened(0.4), face_radius + 1)
		under.size.y -= drop
	_fill(to_canvas_item, under, face, face_radius + 1)
	if shine > 0.0 and under.size.y > 24.0:
		var gloss: Rect2 = Rect2(under.position + Vector2(7.0, 6.0),
				Vector2(maxf(under.size.x - 14.0, 1.0), under.size.y * 0.4))
		_fill(to_canvas_item, gloss, Color(1.0, 1.0, 1.0, shine), int(float(face_radius) * 0.8))
	if ring.a > 0.0:
		_stroke(to_canvas_item, inner, ring, ring_width, inner_radius)
	_stroke(to_canvas_item, body, outline, outline_width, radius)


func _fill(to_canvas_item: RID, area: Rect2, color: Color, corner: int) -> void:
	_box.draw_center = true
	_box.set_border_width_all(0)
	_box.bg_color = color
	_box.set_corner_radius_all(corner)
	_box.draw(to_canvas_item, area)


func _stroke(to_canvas_item: RID, area: Rect2, color: Color, width: float, corner: int) -> void:
	_box.draw_center = false
	_box.set_border_width_all(int(width))
	_box.border_color = color
	_box.set_corner_radius_all(corner)
	_box.draw(to_canvas_item, area)

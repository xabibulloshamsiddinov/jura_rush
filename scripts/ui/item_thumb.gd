## Small preview drawn for a shop row on a dark-brown outlined tile: a caveman sticker that hints at
## the skin (fur colour and pattern, skin tone, hair colour and style, beard, build, accessory), a
## trail streak, or a power-up badge with its icon.
class_name ItemThumb
extends Control

enum Kind { RUNNER, TRAIL, BADGE }

const BONE: Color = Color(0.94, 0.89, 0.76)
const STONE: Color = Color(0.56, 0.55, 0.52)
const EYE: Color = Color(0.10, 0.07, 0.05)

var kind: Kind = Kind.BADGE
## Runner skin (RUNNER only).
var character: CharacterDef = null
var glow: Color = Color(1.0, 0.64, 0.12)
var badge_text: String = ""
## UIIcon.Kind drawn inside the badge instead of the text (-1 = none).
var badge_icon: int = -1

var _tile: ChunkyStyle = null
# Caveman drawing state: tile origin and size (px), outline width (px), outline colour.
var _o: Vector2 = Vector2.ZERO
var _s: float = 1.0
var _edge: float = 2.0
var _ink: Color = Color.BLACK


func _init(p_kind: Kind, size_px: float = 104.0) -> void:
	kind = p_kind
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


static func runner(def: CharacterDef) -> ItemThumb:
	var t: ItemThumb = ItemThumb.new(Kind.RUNNER)
	t.character = def
	t.glow = def.glow_color
	return t


static func trail(color: Color) -> ItemThumb:
	var t: ItemThumb = ItemThumb.new(Kind.TRAIL)
	t.glow = color
	return t


static func badge(color: Color, text: String, icon_kind: int = -1) -> ItemThumb:
	var t: ItemThumb = ItemThumb.new(Kind.BADGE)
	t.glow = color
	t.badge_text = text
	t.badge_icon = icon_kind
	return t


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	var ui: UITheme = UITheme.current()
	if _tile == null:
		_tile = UITheme.panel_style(false, Color(glow, 0.95), int(s * 0.2))
		_tile.face = Color(0.15, 0.095, 0.06)
		_tile.outline_width = 4.0
		_tile.ring_width = 3.0
	draw_style_box(_tile, Rect2(o, Vector2(s, s)))
	match kind:
		Kind.RUNNER:
			if character != null:
				_draw_caveman(o, s, ui.outline)
		Kind.TRAIL:
			var points: PackedVector2Array = PackedVector2Array()
			for i in range(9):
				var t: float = float(i) / 8.0
				points.append(o + Vector2(s * (0.14 + t * 0.72), s * (0.5 + sin(t * TAU) * 0.16)))
			draw_polyline(points, ui.outline, s * 0.2, true)
			draw_polyline(points, glow, s * 0.11, true)
			draw_polyline(points, glow.lightened(0.5), s * 0.04, true)
		Kind.BADGE:
			var c: Vector2 = o + Vector2(s, s) * 0.5
			draw_circle(c, s * 0.33, ui.outline, true, -1.0, true)
			if badge_icon >= 0:
				# A symbol needs a neutral disc: a dark face with a ring in the power-up colour.
				draw_circle(c, s * 0.29, Color(0.24, 0.16, 0.11), true, -1.0, true)
				draw_arc(c, s * 0.265, 0.0, TAU, 40, glow, s * 0.045, true)
				UIIcon.paint(self, badge_icon as UIIcon.Kind, Rect2(c - Vector2(s, s) * 0.2, Vector2(s, s) * 0.4))
				return
			draw_circle(c, s * 0.29, Color(glow, 0.9), true, -1.0, true)
			draw_arc(c, s * 0.2, deg_to_rad(200.0), deg_to_rad(290.0), 10, Color(1.0, 1.0, 1.0, 0.45), s * 0.04, true)
			if not badge_text.is_empty():
				var font: Font = UIKit.heading_font()
				var fs: int = int(s * 0.34)
				var w: float = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var at: Vector2 = o + Vector2((s - w) * 0.5, s * 0.5 + fs * 0.34)
				draw_string_outline(font, at, badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, ui.outline)
				draw_string(font, at, badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ui.text)


# --- caveman sticker -----------------------------------------------------------------------------
# Front view in tile units (0..1, y down): hair top ~0.1, feet ~0.92. Every shape gets the UI's dark
# outline first, then its fill, so overlapping parts read like a chunky sticker at 100 px.

func _draw_caveman(o: Vector2, s: float, ink: Color) -> void:
	_o = o
	_s = s
	_edge = maxf(s * 0.022, 1.5)
	_ink = ink
	var d: CharacterDef = character
	var fur: Color = d.body_color
	var skin: Color = d.head_color
	var hair: Color = d.hair_color
	var leather: Color = d.leather_color
	var bulk: float = clampf(d.bulk, 0.8, 1.25)
	var cx: float = 0.5
	var head_c: Vector2 = Vector2(cx, 0.34)
	var head_r: float = 0.13
	var sh: float = 0.15 * bulk
	# Behind the body: long hair down the back, the stone club over the right shoulder.
	if d.hair_style == &"long":
		_blob(_rounded_rect(cx - 0.165, 0.25, 0.33, 0.27, 0.08), hair)
	if d.accessory == &"backpack":
		_capsule(Vector2(cx + 0.05, 0.66), Vector2(cx + 0.25, 0.3), 0.028, leather.darkened(0.1))
		_blob(_lumpy(Vector2(cx + 0.27, 0.24), 0.08, 0.14, 9, 1.3), STONE)
	# Legs with fur foot wraps.
	for side: float in [-1.0, 1.0]:
		var x: float = cx + side * 0.068 * lerpf(1.0, bulk, 0.6)
		_capsule(Vector2(x, 0.72), Vector2(x, 0.86), 0.04, skin.darkened(0.08))
		_blob(_ellipse(Vector2(x + side * 0.012, 0.885), Vector2(0.058, 0.034), 12), fur.darkened(0.18))
	# Arms hanging at the sides, fists.
	for side: float in [-1.0, 1.0]:
		var top: Vector2 = Vector2(cx + side * (sh - 0.02), 0.5)
		var hand: Vector2 = Vector2(cx + side * (sh + 0.04), 0.68)
		_capsule(top, hand, 0.038, skin)
		_blob(_ellipse(hand + Vector2(0.0, 0.01), Vector2(0.04, 0.038), 10), skin)
	# Fur tunic: strap over the right shoulder, ragged hem, the skin's markings.
	var tunic: PackedVector2Array = _tunic(cx, sh)
	_blob(tunic, fur)
	_pattern(tunic, d.fur_pattern, d.limb_color, fur)
	_line([Vector2(cx - sh * 0.95, 0.655), Vector2(cx + sh * 0.95, 0.655)], 0.02, leather)
	if d.accessory == &"backpack":
		# The club's strap across the chest.
		_line([Vector2(cx - sh * 0.9, 0.64), Vector2(cx + sh * 0.85, 0.47)], 0.024, leather)
	if d.accessory == &"scarf":
		# Fur shawl round the shoulders and a tooth necklace.
		_blob(_ragged_band(cx, 0.47, sh + 0.02, 0.05), fur.lightened(0.08))
		_teeth_necklace(cx, 0.525, 0.09, leather)
	# Head and ears.
	for side: float in [-1.0, 1.0]:
		_blob(_ellipse(head_c + Vector2(side * head_r * 0.98, 0.02), Vector2(0.03, 0.04), 8), skin.darkened(0.05))
	_blob(_ellipse(head_c, Vector2(head_r, head_r * 1.05), 20), skin)
	if d.beard_size > 0.05:
		_blob(_beard(head_c, head_r, clampf(d.beard_size, 0.0, 1.0)), hair)
	# Face: brows, eyes with a glint, nose.
	for side: float in [-1.0, 1.0]:
		var eye: Vector2 = head_c + Vector2(side * 0.05, -0.005)
		_line([eye + Vector2(-0.03, -0.035 - side * 0.004), eye + Vector2(0.03, -0.035 + side * 0.004)], 0.02,
				hair.darkened(0.1), false)
		draw_circle(_p(eye), 0.019 * _s, EYE, true, -1.0, true)
		draw_circle(_p(eye + Vector2(0.006, -0.007)), 0.006 * _s, Color(1.0, 1.0, 1.0, 0.9), true, -1.0, true)
	draw_circle(_p(head_c + Vector2(0.0, 0.035)), 0.022 * _s, skin.darkened(0.15), true, -1.0, true)
	if d.accessory != &"visor":
		_hair(d.hair_style, head_c, head_r, hair)
	match d.accessory:
		&"cap":
			# A bone pushed through a hair top-knot.
			var knot: Vector2 = head_c + Vector2(0.0, -head_r - 0.075)
			_blob(_ellipse(knot, Vector2(0.058, 0.05), 14), hair)
			_bone(knot + Vector2(-0.125, 0.005), knot + Vector2(0.125, -0.005), 0.02)
		&"visor":
			_raptor_skull(head_c, head_r)
		&"antenna":
			# Leather headband with feathers in the accent colour.
			_line([head_c + Vector2(-head_r * 0.98, -0.065), head_c + Vector2(head_r * 0.98, -0.075)], 0.032, leather)
			for f: Array in [[0.075, 0.3, 0.2], [0.04, 0.05, 0.17], [0.1, 0.6, 0.12]]:
				_feather(head_c + Vector2(f[0], -0.1), f[1], f[2], d.glow_color)


func _p(u: Vector2) -> Vector2:
	return _o + u * _s


func _to_px(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in points:
		out.append(_p(q))
	return out


## Outlined filled polygon (tile units).
func _blob(points: PackedVector2Array, fill: Color) -> void:
	if points.size() < 3:
		return
	var px: PackedVector2Array = _to_px(points)
	var loop: PackedVector2Array = px.duplicate()
	loop.append(px[0])
	draw_polyline(loop, _ink, _edge * 2.0, true)
	draw_colored_polygon(px, fill)


## Thick polyline (tile units; width in tile units), outlined unless told otherwise.
func _line(points: Array, width: float, color: Color, outlined: bool = true) -> void:
	var px: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in points:
		px.append(_p(q))
	if outlined:
		draw_polyline(px, _ink, width * _s + _edge * 2.0, true)
	draw_polyline(px, color, width * _s, true)


func _capsule(a: Vector2, b: Vector2, r: float, color: Color) -> void:
	var dir: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(-dir.y, dir.x)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(9):
		var t: float = PI * float(i) / 8.0
		pts.append(b + (n * cos(t) + dir * sin(t)) * r)
	for i in range(9):
		var t: float = PI + PI * float(i) / 8.0
		pts.append(a + (n * cos(t) + dir * sin(t)) * r)
	_blob(pts, color)


func _ellipse(c: Vector2, r: Vector2, n: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(n):
		var t: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(t) * r.x, sin(t) * r.y))
	return pts


func _rounded_rect(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r),
			Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	for k in range(4):
		for i in range(5):
			var t: float = -PI * 0.5 + PI * 0.5 * (float(k) + float(i) / 4.0)
			pts.append(corners[k] + Vector2(cos(t), sin(t)) * r)
	return pts


## Irregular round lump (club stone, fur spots). `wobble` = share of radius variation.
func _lumpy(c: Vector2, r: float, wobble: float, n: int, seed_phase: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(n * 2):
		var t: float = TAU * float(i) / float(n * 2)
		var k: float = 1.0 + wobble * sin(t * 3.0 + seed_phase) * cos(t * 2.0 + seed_phase * 1.7)
		pts.append(c + Vector2(cos(t), sin(t)) * r * k)
	return pts


## Fur tunic: left shoulder bare, strap over the right shoulder, zigzag hem.
func _tunic(cx: float, sh: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var hem_y: float = 0.75
	var hem_w: float = sh * 1.12
	pts.append(Vector2(cx + sh * 0.2, 0.47))
	pts.append(Vector2(cx + sh * 0.95, 0.47))
	pts.append(Vector2(cx + sh * 1.02, 0.55))
	pts.append(Vector2(cx + hem_w, hem_y - 0.03))
	var teeth: int = 6
	for i in range(teeth * 2 + 1):
		var t: float = float(i) / float(teeth * 2)
		pts.append(Vector2(cx + hem_w - t * hem_w * 2.0, hem_y + (0.035 if i % 2 == 1 else 0.0)))
	pts.append(Vector2(cx - hem_w, hem_y - 0.03))
	pts.append(Vector2(cx - sh * 1.0, 0.56))
	pts.append(Vector2(cx - sh * 0.75, 0.53))
	pts.append(Vector2(cx - sh * 0.25, 0.545))
	return pts


func _ragged_band(cx: float, y: float, half: float, h: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2(cx - half * 0.7, y - h * 0.6))
	pts.append(Vector2(cx + half * 0.7, y - h * 0.6))
	pts.append(Vector2(cx + half, y))
	var n: int = 7
	for i in range(n * 2 + 1):
		var t: float = float(i) / float(n * 2)
		pts.append(Vector2(cx + half - t * half * 2.0, y + h * (0.9 if i % 2 == 1 else 0.45)))
	pts.append(Vector2(cx - half, y))
	return pts


## The skin's fur markings (CharacterDef.fur_pattern), clipped to the tunic.
func _pattern(tunic: PackedVector2Array, pattern: StringName, marks: Color, fur: Color) -> void:
	var clip: PackedVector2Array = _to_px(tunic)
	var shapes: Array[PackedVector2Array] = []
	match pattern:
		&"spots":
			for c: Vector2 in [Vector2(0.45, 0.52), Vector2(0.57, 0.55), Vector2(0.41, 0.62), Vector2(0.53, 0.64),
					Vector2(0.62, 0.68), Vector2(0.46, 0.71), Vector2(0.6, 0.5)]:
				shapes.append(_to_px(_lumpy(c, 0.022, 0.25, 5, c.x * 9.0)))
		&"stripes":
			for i in range(5):
				var y: float = 0.5 + float(i) * 0.058
				shapes.append(_to_px(PackedVector2Array([Vector2(0.25, y), Vector2(0.5, y + 0.025),
						Vector2(0.75, y - 0.01), Vector2(0.75, y + 0.016), Vector2(0.5, y + 0.047),
						Vector2(0.25, y + 0.022)])))
		&"leaves":
			for row in range(3):
				for k in range(4):
					var c: Vector2 = Vector2(0.37 + float(k) * 0.08 + float(row % 2) * 0.04, 0.53 + float(row) * 0.075)
					shapes.append(_to_px(_ellipse(c, Vector2(0.028, 0.04), 8)))
		&"patches":
			for c: Vector2 in [Vector2(0.44, 0.56), Vector2(0.6, 0.66), Vector2(0.4, 0.72)]:
				shapes.append(_to_px(_lumpy(c, 0.05, 0.3, 6, c.y * 13.0)))
	for shape: PackedVector2Array in shapes:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, clip):
			if pattern == &"leaves":
				# Overlapping leaves: a lighter leaf with a dark edge.
				draw_colored_polygon(piece, fur.lerp(marks, 0.4))
				var loop: PackedVector2Array = piece.duplicate()
				loop.append(piece[0])
				draw_polyline(loop, marks, maxf(_edge * 0.6, 1.0), true)
			else:
				draw_colored_polygon(piece, marks)


func _beard(head_c: Vector2, head_r: float, amount: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var top: float = head_c.y + 0.035
	var drop: float = lerpf(0.03, 0.08, amount)
	for i in range(11):
		var t: float = float(i) / 10.0
		var x: float = head_c.x + (t * 2.0 - 1.0) * head_r * 0.9
		pts.append(Vector2(x, top + sin(t * PI) * (head_r * 0.7 + drop) + (0.012 if i % 2 == 1 else 0.0)))
	# Mouth opening under the moustache.
	pts.append(Vector2(head_c.x + 0.035, top + 0.04))
	pts.append(Vector2(head_c.x - 0.035, top + 0.04))
	return pts


## Hair styles: mop (shaggy dome, scalloped fringe; also the crown of long hair), flame (spiky
## crest), short (close crop).
func _hair(style: StringName, head_c: Vector2, head_r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	match style:
		&"flame":
			for q: Vector2 in [Vector2(-1.05, 0.2), Vector2(-0.95, -0.55), Vector2(-0.6, -0.3), Vector2(-0.55, -1.45),
					Vector2(-0.2, -0.75), Vector2(0.05, -1.75), Vector2(0.3, -0.8), Vector2(0.6, -1.4),
					Vector2(0.7, -0.4), Vector2(1.0, -0.65), Vector2(1.05, 0.2), Vector2(0.6, -0.28), Vector2(-0.6, -0.28)]:
				pts.append(head_c + q * head_r)
			_blob(pts, color)
			var inner: PackedVector2Array = PackedVector2Array()
			for q: Vector2 in [Vector2(-0.45, -0.38), Vector2(-0.4, -0.95), Vector2(-0.1, -0.6), Vector2(0.05, -1.25),
					Vector2(0.25, -0.65), Vector2(0.45, -0.95), Vector2(0.5, -0.38)]:
				inner.append(_p(head_c + q * head_r))
			draw_colored_polygon(inner, color.lightened(0.35))
			return
		&"short":
			for i in range(13):
				var t: float = PI + PI * float(i) / 12.0
				pts.append(head_c + Vector2(cos(t) * head_r * 1.04, sin(t) * head_r * 1.08 - 0.008))
			for i in range(7):
				var x: float = 1.0 - float(i) / 6.0 * 2.0
				pts.append(head_c + Vector2(x * head_r * 0.9, -head_r * (0.42 if i % 2 == 0 else 0.3)))
		_:
			var n: int = 16
			for i in range(n + 1):
				var t: float = PI * 0.95 + PI * 1.1 * float(i) / float(n)
				var r: float = head_r * (1.14 + (0.06 if i % 2 == 0 else 0.0))
				pts.append(head_c + Vector2(cos(t) * r, sin(t) * r * 1.05 - 0.01))
			var fringe: int = 9
			for i in range(fringe + 1):
				var x: float = 1.0 - float(i) / float(fringe) * 2.0
				pts.append(head_c + Vector2(x * head_r * 1.02, -head_r * (0.25 if i % 2 == 1 else 0.45)))
	_blob(pts, color)
	# A soft highlight so dark hair still shows its shape on the dark tile.
	draw_arc(_p(head_c + Vector2(-0.02, -head_r * 0.62)), head_r * 0.55 * _s, deg_to_rad(205.0), deg_to_rad(265.0),
			8, Color(1.0, 1.0, 1.0, 0.25), maxf(_s * 0.018, 1.0), true)


func _bone(a: Vector2, b: Vector2, r: float) -> void:
	for end: Vector2 in [a, b]:
		for k: float in [-1.0, 1.0]:
			_blob(_ellipse(end + Vector2(0.0, k * r * 1.1), Vector2(r * 1.3, r * 1.3), 10), BONE)
	_capsule(a, b, r, BONE)


## Raptor skull helmet: bone dome over the head, teeth over the brow, eye sockets, nose horn.
func _raptor_skull(head_c: Vector2, head_r: float) -> void:
	var dome: PackedVector2Array = PackedVector2Array()
	for i in range(15):
		var t: float = PI + PI * float(i) / 14.0
		dome.append(head_c + Vector2(cos(t) * head_r * 1.22, sin(t) * head_r * 1.25 - 0.03))
	var n: int = 7
	for i in range(n * 2 + 1):
		var t: float = float(i) / float(n * 2)
		var x: float = head_c.x + head_r * 1.22 - t * head_r * 2.44
		dome.append(Vector2(x, head_c.y - 0.03 + (0.04 if i % 2 == 1 else 0.0) * (1.0 - absf(t * 2.0 - 1.0) * 0.5)))
	_blob(dome, BONE)
	_capsule(head_c + Vector2(0.0, -head_r * 0.6), head_c + Vector2(0.0, -head_r * 1.4), 0.024, BONE.darkened(0.08))
	_blob(PackedVector2Array([head_c + Vector2(-0.02, -head_r * 1.45), head_c + Vector2(0.0, -head_r * 1.9),
			head_c + Vector2(0.02, -head_r * 1.45)]), BONE)
	for side: float in [-1.0, 1.0]:
		var hole: PackedVector2Array = _ellipse(head_c + Vector2(side * head_r * 0.6, -head_r * 0.55), Vector2(0.032, 0.024), 10)
		draw_colored_polygon(_to_px(hole), Color(0.2, 0.13, 0.09))


func _teeth_necklace(cx: float, y: float, half: float, cord: Color) -> void:
	var arc: Array = []
	for i in range(9):
		var t: float = float(i) / 8.0 * 2.0 - 1.0
		arc.append(Vector2(cx + t * half, y - 0.03 + (1.0 - t * t) * 0.03))
	_line(arc, 0.012, cord, false)
	for i in range(5):
		var t: float = (float(i) - 2.0) / 2.0
		var base: Vector2 = Vector2(cx + t * half * 0.75, y - 0.03 + (1.0 - t * t * 0.56) * 0.03)
		_blob(PackedVector2Array([base + Vector2(-0.013, 0.0), base + Vector2(0.013, 0.0),
				base + Vector2(0.0, 0.045 - absf(t) * 0.01)]), BONE)


func _feather(base: Vector2, tilt: float, length: float, color: Color) -> void:
	var dir: Vector2 = Vector2(sin(tilt), -cos(tilt))
	var n: Vector2 = Vector2(-dir.y, dir.x)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(7):
		var t: float = float(i) / 6.0
		pts.append(base + dir * t * length + n * sin(t * PI) * 0.028)
	for i in range(5, 0, -1):
		var t: float = float(i) / 6.0
		pts.append(base + dir * t * length - n * sin(t * PI) * 0.028)
	_blob(pts, color)
	_line([base + dir * length * 0.15, base + dir * length * 0.95], 0.008, color.darkened(0.35), false)
	draw_circle(_p(base + dir * length * 0.9), 0.014 * _s, color.darkened(0.5), true, -1.0, true)

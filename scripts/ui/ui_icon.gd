## Vector icons drawn with the 2D canvas (no textures, so they scale cleanly to any size): speckled
## egg, amber gem, gear, scroll, gift, pouch, caveman head, footprints, play triangle, trophy and
## the power-up symbols (magnet, shell shield, wing, dash chevrons).
## Every shape has a dark-brown outline like the rest of the chunky UI. CoinIcon (egg) and KeyIcon
## (amber) draw through the same functions, so the HUD, the shop and the menu always agree.
##
## Use `UIIcon.new(kind, diameter)` as a control, or `UIIcon.paint(canvas_item, kind, rect)` from
## any `_draw()`.
class_name UIIcon
extends Control

enum Kind { EGG, AMBER, GEAR, SCROLL, GIFT, BAG, HEAD, FOOTPRINTS, PLAY, TROPHY, MAGNET, SHELL, WING, DASH, PLAYERS }

## Power-up id -> its symbol (the multiplier keeps its "x2" text).
const POWERUP_KINDS: Dictionary = {
	&"magnet": Kind.MAGNET,
	&"shield": Kind.SHELL,
	&"jetpack": Kind.WING,
	&"dash": Kind.DASH,
}

@export var kind: Kind = Kind.EGG:
	set(value):
		kind = value
		queue_redraw()
## Diameter in UI pixels.
@export var diameter: float = 64.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(value, value)
		queue_redraw()
## Draws the icon greyed out (for unaffordable / disabled states).
@export var dimmed: bool = false:
	set(value):
		dimmed = value
		queue_redraw()


func _init(p_kind: Kind = Kind.EGG, p_diameter: float = 64.0) -> void:
	kind = p_kind
	diameter = p_diameter
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	paint(self, kind, Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s)), 0.0 if dimmed else 1.0)


## Draws an icon into the square `area` of any CanvasItem. `tone` 1 = full colour, 0 = greyed out.
static func paint(ci: CanvasItem, icon: Kind, area: Rect2, tone: float = 1.0) -> void:
	var s: float = minf(area.size.x, area.size.y)
	var c: Vector2 = area.get_center()
	match icon:
		Kind.EGG:
			_egg(ci, c, s, tone)
		Kind.AMBER:
			_amber(ci, c, s, tone)
		Kind.GEAR:
			_gear(ci, c, s, tone)
		Kind.SCROLL:
			_scroll(ci, c, s, tone)
		Kind.GIFT:
			_gift(ci, c, s, tone)
		Kind.BAG:
			_bag(ci, c, s, tone)
		Kind.HEAD:
			_head(ci, c, s, tone)
		Kind.FOOTPRINTS:
			_footprints(ci, c, s, tone)
		Kind.PLAY:
			_play(ci, c, s, tone)
		Kind.TROPHY:
			_trophy(ci, c, s, tone)
		Kind.MAGNET:
			_magnet(ci, c, s, tone)
		Kind.SHELL:
			_shell(ci, c, s, tone)
		Kind.WING:
			_wing(ci, c, s, tone)
		Kind.DASH:
			_dash(ci, c, s, tone)
		Kind.PLAYERS:
			_players(ci, c, s, tone)


## Symbol of a power-up as a Kind value, or -1 when it has none (it is drawn as text instead).
static func for_powerup(id: StringName) -> int:
	return int(POWERUP_KINDS.get(id, -1))


# --- shapes ---------------------------------------------------------------------------------

## Speckled cream egg: soft shade on the lower right, brown speckles, small highlight.
static func _egg(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s)
	var body: PackedVector2Array = _egg_outline(c, s)
	ci.draw_colored_polygon(body, _tone(Color(0.93, 0.78, 0.52), t))
	var lit: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in body:
		lit.append(c + (p - c) * 0.9 + Vector2(-0.02, -0.025) * s)
	ci.draw_colored_polygon(lit, _tone(Color(1.0, 0.96, 0.82), t))
	var speckles: Array[Vector3] = [Vector3(0.10, 0.12, 0.045), Vector3(-0.13, 0.20, 0.036),
			Vector3(0.17, -0.06, 0.03), Vector3(-0.05, -0.10, 0.028), Vector3(0.02, 0.31, 0.03),
			Vector3(-0.17, 0.02, 0.024)]
	for dot: Vector3 in speckles:
		ci.draw_circle(c + Vector2(dot.x, dot.y) * s, dot.z * s, _tone(Color(0.52, 0.36, 0.2, 0.85), t), true, -1.0, true)
	ci.draw_colored_polygon(_ellipse(c + Vector2(-0.12, -0.2) * s, 0.055 * s, 0.1 * s, 0.5), Color(1.0, 1.0, 1.0, 0.75 * t))
	ci.draw_polyline(body, _tone(_outline(), t), line, true)


## Faceted amber gem with a glint.
static func _amber(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s)
	var a: Vector2 = c + Vector2(-0.46, -0.10) * s
	var b: Vector2 = c + Vector2(-0.27, -0.40) * s
	var cc: Vector2 = c + Vector2(0.27, -0.40) * s
	var d: Vector2 = c + Vector2(0.46, -0.10) * s
	var e: Vector2 = c + Vector2(0.0, 0.46) * s
	var g1: Vector2 = c + Vector2(-0.16, -0.10) * s
	var g2: Vector2 = c + Vector2(0.16, -0.10) * s
	var facets: Array = [
		[PackedVector2Array([a, b, g1]), Color(1.0, 0.78, 0.28)],
		[PackedVector2Array([b, cc, g2, g1]), Color(1.0, 0.88, 0.46)],
		[PackedVector2Array([cc, d, g2]), Color(1.0, 0.70, 0.18)],
		[PackedVector2Array([a, g1, e]), Color(0.98, 0.58, 0.08)],
		[PackedVector2Array([g1, g2, e]), Color(0.92, 0.46, 0.05)],
		[PackedVector2Array([g2, d, e]), Color(0.78, 0.36, 0.04)],
	]
	for facet: Array in facets:
		ci.draw_colored_polygon(facet[0] as PackedVector2Array, _tone(facet[1] as Color, t))
	var seam: Color = _tone(Color(0.62, 0.27, 0.03, 0.75), t)
	var thin: float = maxf(s * 0.02, 1.0)
	ci.draw_line(b, g1, seam, thin, true)
	ci.draw_line(cc, g2, seam, thin, true)
	ci.draw_line(a, d, seam, thin, true)
	ci.draw_line(g1, e, seam, thin, true)
	ci.draw_line(g2, e, seam, thin, true)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.19, -0.35) * s, c + Vector2(-0.05, -0.35) * s,
			c + Vector2(-0.12, -0.17) * s]), Color(1.0, 1.0, 1.0, 0.7 * t))
	_joined(ci, PackedVector2Array([a, b, cc, d, e]), _tone(_outline(), t), line)


## Stone-coloured cog with a dark hub.
static func _gear(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var profile: Array[Vector2] = [Vector2(-0.30, 0.31), Vector2(-0.17, 0.45), Vector2(0.17, 0.45), Vector2(0.30, 0.31)]
	var pts: PackedVector2Array = PackedVector2Array()
	for k in range(8):
		var base: float = TAU * float(k) / 8.0
		for p: Vector2 in profile:
			var angle: float = base + p.x
			pts.append(c + Vector2(cos(angle), sin(angle)) * p.y * s)
	_shape(ci, pts, _tone(Color(0.90, 0.86, 0.78), t), _tone(_outline(), t), _line(s))
	ci.draw_arc(c, 0.25 * s, deg_to_rad(-170.0), deg_to_rad(-100.0), 10, Color(1.0, 1.0, 1.0, 0.6 * t), maxf(s * 0.035, 1.0), true)
	ci.draw_circle(c, 0.15 * s, _tone(_outline(), t), true, -1.0, true)
	ci.draw_circle(c, 0.09 * s, _tone(Color(0.62, 0.56, 0.48), t), true, -1.0, true)


## Parchment scroll with two rolled ends and lines of writing.
static func _scroll(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s)
	_shape(ci, _rect_pts(c, s, -0.29, -0.34, 0.58, 0.68), _tone(Color(1.0, 0.94, 0.78), t), _tone(_outline(), t), line)
	var ink: Color = _tone(Color(0.52, 0.36, 0.2), t)
	var y: float = -0.17
	for width: float in [0.36, 0.36, 0.20]:
		ci.draw_line(c + Vector2(-0.18, y) * s, c + Vector2(-0.18 + width, y) * s, ink, maxf(s * 0.05, 1.5), true)
		y += 0.14
	for edge: float in [-0.43, 0.29]:
		_shape(ci, _round_rect(c, s, -0.38, edge, 0.76, 0.14, 0.07), _tone(Color(0.86, 0.62, 0.34), t), _tone(_outline(), t), line)
		ci.draw_line(c + Vector2(-0.30, edge + 0.04) * s, c + Vector2(0.30, edge + 0.04) * s, Color(1.0, 1.0, 1.0, 0.35 * t), maxf(s * 0.03, 1.0), true)


## Gift box with a cream ribbon and bow.
static func _gift(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s)
	var out: Color = _tone(_outline(), t)
	_shape(ci, _rect_pts(c, s, -0.33, -0.06, 0.66, 0.46), _tone(Color(0.90, 0.30, 0.20), t), out, line)
	_shape(ci, _rect_pts(c, s, -0.39, -0.22, 0.78, 0.18), _tone(Color(0.98, 0.40, 0.26), t), out, line)
	_shape(ci, _rect_pts(c, s, -0.075, -0.22, 0.15, 0.62), _tone(Color(1.0, 0.92, 0.66), t), out, line * 0.8)
	for side: float in [-1.0, 1.0]:
		_shape(ci, _ellipse(c + Vector2(0.15 * side, -0.31) * s, 0.14 * s, 0.085 * s, 0.45 * side),
				_tone(Color(1.0, 0.92, 0.66), t), out, line * 0.8)
	ci.draw_circle(c + Vector2(0.0, -0.27) * s, 0.065 * s, _tone(Color(1.0, 0.86, 0.5), t), true, -1.0, true)
	ci.draw_arc(c + Vector2(0.0, -0.27) * s, 0.065 * s, 0.0, TAU, 16, out, line * 0.7, true)


## Leather pouch tied with a cord, a small egg stitched on.
static func _bag(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s)
	var out: Color = _tone(_outline(), t)
	var leather: Color = _tone(Color(0.78, 0.52, 0.26), t)
	_shape(ci, PackedVector2Array([c + Vector2(-0.22, -0.42) * s, c + Vector2(0.22, -0.42) * s,
			c + Vector2(0.15, -0.26) * s, c + Vector2(-0.15, -0.26) * s]), _tone(Color(0.88, 0.62, 0.32), t), out, line)
	_shape(ci, PackedVector2Array([c + Vector2(-0.17, -0.12) * s, c + Vector2(0.17, -0.12) * s,
			c + Vector2(0.13, -0.28) * s, c + Vector2(-0.13, -0.28) * s]), leather, out, line)
	_shape(ci, _ellipse(c + Vector2(0.0, 0.14) * s, 0.38 * s, 0.33 * s, 0.0), leather, out, line)
	ci.draw_polyline(_arc_pts(c + Vector2(0.0, 0.14) * s, 0.30 * s, 0.30 * s, deg_to_rad(20.0), deg_to_rad(75.0)),
			_tone(Color(0.55, 0.33, 0.14, 0.6), t), maxf(s * 0.05, 1.5), true)
	_shape(ci, _rect_pts(c, s, -0.16, -0.22, 0.32, 0.09), _tone(Color(1.0, 0.92, 0.66), t), out, line * 0.8)
	_egg(ci, c + Vector2(0.0, 0.17) * s, s * 0.36, t)


## Caveman head: messy hair, heavy brow, bone in the hair.
static func _head(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s)
	var out: Color = _tone(_outline(), t)
	var face_c: Vector2 = c + Vector2(0.0, 0.07) * s
	_shape(ci, _ellipse(face_c, 0.32 * s, 0.34 * s, 0.0), _tone(Color(0.97, 0.77, 0.56), t), out, line)
	ci.draw_polyline(_arc_pts(face_c, 0.25 * s, 0.27 * s, deg_to_rad(10.0), deg_to_rad(70.0)),
			_tone(Color(0.80, 0.55, 0.38, 0.55), t), maxf(s * 0.05, 1.5), true)
	var hair: Array[Vector2] = [Vector2(-0.35, 0.02), Vector2(-0.40, -0.14), Vector2(-0.31, -0.22),
			Vector2(-0.31, -0.36), Vector2(-0.18, -0.30), Vector2(-0.12, -0.46), Vector2(0.0, -0.36),
			Vector2(0.12, -0.48), Vector2(0.20, -0.32), Vector2(0.33, -0.36), Vector2(0.31, -0.20),
			Vector2(0.40, -0.12), Vector2(0.35, 0.02), Vector2(0.22, -0.10), Vector2(0.0, -0.15),
			Vector2(-0.22, -0.10)]
	_shape(ci, _pts(c, s, hair), _tone(Color(0.40, 0.22, 0.10), t), out, line)
	for side: float in [-1.0, 1.0]:
		var eye: Vector2 = face_c + Vector2(0.125 * side, 0.02) * s
		ci.draw_circle(eye, 0.07 * s, _tone(Color.WHITE, t), true, -1.0, true)
		ci.draw_circle(eye + Vector2(0.012 * side, 0.01) * s, 0.034 * s, out, true, -1.0, true)
		ci.draw_line(face_c + Vector2(0.24 * side, -0.07) * s, face_c + Vector2(0.05 * side, -0.085) * s, out, maxf(s * 0.075, 2.0), true)
	ci.draw_circle(face_c + Vector2(0.0, 0.14) * s, 0.04 * s, _tone(Color(0.85, 0.58, 0.40), t), true, -1.0, true)
	ci.draw_polyline(_arc_pts(face_c + Vector2(0.0, 0.14) * s, 0.12 * s, 0.09 * s, deg_to_rad(25.0), deg_to_rad(155.0)),
			out, maxf(s * 0.04, 1.5), true)
	_bone(ci, c + Vector2(0.22, -0.40) * s, s * 0.46, deg_to_rad(-25.0), t)


## Multiplayer: two caveman heads side by side with a phone between them.
static func _players(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	_head(ci, c + Vector2(-0.2, 0.06) * s, s * 0.62, t)
	_head(ci, c + Vector2(0.2, 0.06) * s, s * 0.62, t)
	var line: float = _line(s)
	var out: Color = _tone(_outline(), t)
	var phone: PackedVector2Array = _round_rect(c, s, -0.11, 0.06, 0.22, 0.36, 0.05)
	_shape(ci, phone, _tone(Color(0.32, 0.30, 0.34), t), out, line)
	_shape(ci, _round_rect(c, s, -0.07, 0.11, 0.14, 0.22, 0.02), _tone(Color(0.55, 0.85, 1.0), t), out, maxf(line * 0.5, 1.0))


## Two three-toed footprints walking up the icon.
static func _footprints(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	_print(ci, c + Vector2(-0.17, 0.2) * s, s * 0.62, deg_to_rad(-12.0), t)
	_print(ci, c + Vector2(0.17, -0.16) * s, s * 0.62, deg_to_rad(12.0), t)


## Right-pointing triangle with rounded corners.
static func _play(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var tri: PackedVector2Array = PackedVector2Array([c + Vector2(-0.2, -0.3) * s, c + Vector2(-0.2, 0.3) * s,
			c + Vector2(0.28, 0.0) * s])
	var rounded: Array[PackedVector2Array] = Geometry2D.offset_polygon(tri, 0.06 * s, Geometry2D.JOIN_ROUND)
	if not rounded.is_empty():
		_shape(ci, rounded[0], _tone(Color(1.0, 0.97, 0.9), t), _tone(_outline(), t), _line(s))


## Golden cup with two handles and a star.
static func _trophy(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s)
	var out: Color = _tone(_outline(), t)
	var gold: Color = _tone(Color(1.0, 0.80, 0.22), t)
	for side: float in [-1.0, 1.0]:
		var from: float = deg_to_rad(-90.0) if side > 0.0 else deg_to_rad(90.0)
		var handle: PackedVector2Array = _arc_pts(c + Vector2(0.29 * side, -0.2) * s, 0.14 * s, 0.14 * s,
				from, from + PI)
		ci.draw_polyline(handle, out, line * 2.6, true)
		ci.draw_polyline(handle, _tone(Color(0.90, 0.62, 0.10), t), line * 1.1, true)
	_shape(ci, _rect_pts(c, s, -0.07, 0.04, 0.14, 0.2), _tone(Color(0.90, 0.62, 0.10), t), out, line)
	_shape(ci, _round_rect(c, s, -0.22, 0.22, 0.44, 0.15, 0.04), _tone(Color(0.90, 0.62, 0.10), t), out, line)
	var cup: PackedVector2Array = PackedVector2Array([c + Vector2(-0.29, -0.40) * s, c + Vector2(0.29, -0.40) * s,
			c + Vector2(0.27, -0.14) * s, c + Vector2(0.15, 0.04) * s, c + Vector2(0.0, 0.12) * s,
			c + Vector2(-0.15, 0.04) * s, c + Vector2(-0.27, -0.14) * s])
	_shape(ci, cup, gold, out, line)
	ci.draw_line(c + Vector2(-0.19, -0.33) * s, c + Vector2(-0.16, -0.10) * s, Color(1.0, 1.0, 1.0, 0.65 * t), maxf(s * 0.05, 1.5), true)
	ci.draw_colored_polygon(_star(c + Vector2(0.03, -0.19) * s, 0.09 * s, 0.04 * s), _tone(Color(1.0, 0.97, 0.9), t))


## Horseshoe magnet: red body, silver tips.
static func _magnet(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s)
	var out: Color = _tone(_outline(), t)
	var path: PackedVector2Array = PackedVector2Array([c + Vector2(-0.24, -0.3) * s])
	path.append_array(_arc_pts(c + Vector2(0.0, -0.02) * s, 0.24 * s, 0.3 * s, PI, 0.0, 16))
	path.append(c + Vector2(0.24, -0.3) * s)
	ci.draw_polyline(path, out, 0.28 * s + line, true)
	ci.draw_polyline(path, _tone(Color(0.92, 0.25, 0.28), t), 0.2 * s, true)
	ci.draw_polyline(_arc_pts(c + Vector2(0.0, -0.02) * s, 0.24 * s, 0.3 * s, deg_to_rad(120.0), deg_to_rad(165.0), 6),
			Color(1.0, 1.0, 1.0, 0.45 * t), 0.05 * s, true)
	for side: float in [-1.0, 1.0]:
		_shape(ci, _rect_pts(c, s, 0.24 * side - 0.12, -0.38, 0.24, 0.17), _tone(Color(0.93, 0.94, 0.97), t), out, line * 0.9)
		ci.draw_line(c + Vector2(0.24 * side, -0.215) * s, c + Vector2(0.24 * side, -0.37) * s,
				_tone(Color(0.62, 0.66, 0.74), t), 0.03 * s, true)


## Shield made from turtle-shell plates.
static func _shell(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s)
	var out: Color = _tone(_outline(), t)
	var outline_pts: Array[Vector2] = [Vector2(-0.31, -0.35), Vector2(0.31, -0.35), Vector2(0.34, 0.04),
			Vector2(0.22, 0.28), Vector2(0.0, 0.44), Vector2(-0.22, 0.28), Vector2(-0.34, 0.04)]
	_shape(ci, _pts(c, s, outline_pts), _tone(Color(0.32, 0.70, 0.98), t), out, line)
	var plate: Color = _tone(Color(0.78, 0.92, 1.0, 0.85), t)
	var hex: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var a: float = deg_to_rad(30.0 + 60.0 * float(i))
		hex.append(c + (Vector2(0.0, -0.06) + Vector2(cos(a), sin(a)) * 0.16) * s)
	ci.draw_polyline(_closed(hex), plate, maxf(s * 0.035, 1.2), true)
	for i in range(0, 6, 2):
		var a: float = deg_to_rad(30.0 + 60.0 * float(i))
		var from: Vector2 = c + (Vector2(0.0, -0.06) + Vector2(cos(a), sin(a)) * 0.16) * s
		ci.draw_line(from, c + (Vector2(0.0, -0.06) + Vector2(cos(a), sin(a)) * 0.36) * s, plate, maxf(s * 0.035, 1.2), true)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-0.24, -0.28) * s, c + Vector2(-0.27, -0.02) * s]),
			Color(1.0, 1.0, 1.0, 0.55 * t), maxf(s * 0.04, 1.2), true)


## Pterosaur wing: three feather-like fingers fanning out.
static func _wing(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var line: float = _line(s) * 0.9
	var out: Color = _tone(_outline(), t)
	var base: Vector2 = c + Vector2(-0.28, 0.28) * s
	var fingers: Array[Vector3] = [Vector3(-12.0, 0.66, 0.22), Vector3(-38.0, 0.74, 0.24), Vector3(-64.0, 0.62, 0.22)]
	var colors: Array[Color] = [Color(1.0, 0.82, 0.30), Color(1.0, 0.64, 0.14), Color(0.94, 0.44, 0.08)]
	for i in range(fingers.size()):
		var f: Vector3 = fingers[i]
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(f.x))
		var side: Vector2 = dir.orthogonal()
		var left: PackedVector2Array = PackedVector2Array()
		var right: PackedVector2Array = PackedVector2Array()
		for k in range(11):
			var u: float = float(k) / 10.0
			var w: float = pow(sin(u * PI), 0.7) * f.z * s * 0.5
			left.append(base + dir * f.y * s * u + side * w)
			right.append(base + dir * f.y * s * u - side * w)
		right.reverse()
		_shape(ci, left + right, _tone(colors[i], t), out, line)


## Two bold chevrons (dash).
static func _dash(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var out: Color = _tone(_outline(), t)
	var green: Color = _tone(Color(0.46, 0.88, 0.34), t)
	for shift: float in [-0.2, 0.12]:
		var pts: PackedVector2Array = PackedVector2Array([c + Vector2(shift - 0.12, -0.3) * s,
				c + Vector2(shift + 0.14, 0.0) * s, c + Vector2(shift - 0.12, 0.3) * s])
		ci.draw_polyline(pts, out, 0.25 * s, true)
		for p: Vector2 in pts:
			ci.draw_circle(p, 0.125 * s, out, true, -1.0, true)
		ci.draw_polyline(pts, green, 0.13 * s, true)
		for p: Vector2 in pts:
			ci.draw_circle(p, 0.065 * s, green, true, -1.0, true)


## A bone lying at an angle (hair ornament).
static func _bone(ci: CanvasItem, c: Vector2, length: float, angle: float, t: float) -> void:
	var line: float = maxf(length * 0.07, 1.5)
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var normal: Vector2 = dir.orthogonal()
	var half: float = length * 0.5
	var thick: float = length * 0.1
	var cream: Color = _tone(Color(1.0, 0.95, 0.8), t)
	var out: Color = _tone(_outline(), t)
	for end: float in [-1.0, 1.0]:
		for knob: float in [-1.0, 1.0]:
			ci.draw_circle(c + dir * half * end + normal * thick * 1.15 * knob, thick * 1.35, out, true, -1.0, true)
	ci.draw_line(c - dir * half, c + dir * half, out, thick * 2.0 + line * 2.0, true)
	for end: float in [-1.0, 1.0]:
		for knob: float in [-1.0, 1.0]:
			ci.draw_circle(c + dir * half * end + normal * thick * 1.15 * knob, thick * 1.35 - line * 0.7, cream, true, -1.0, true)
	ci.draw_line(c - dir * half, c + dir * half, cream, thick * 2.0, true)


## One three-toed dinosaur footprint (pad and three toes with claws).
static func _print(ci: CanvasItem, c: Vector2, s: float, rot: float, t: float) -> void:
	var line: float = _line(s) * 0.9
	var out: Color = _tone(_outline(), t)
	var cream: Color = _tone(Color(1.0, 0.95, 0.8), t)
	for toe: float in [-0.9, 0.0, 0.9]:
		var base: Vector2 = Vector2(sin(toe) * 0.27, -0.12 - cos(toe) * 0.2).rotated(rot)
		var angle: float = rot + toe * 0.9
		var shape: PackedVector2Array = _ellipse(c + base * s, 0.085 * s, 0.14 * s, angle)
		_shape(ci, shape, cream, out, line)
	_shape(ci, _ellipse(c + Vector2(0.0, 0.18).rotated(rot) * s, 0.16 * s, 0.2 * s, rot), cream, out, line)


# --- helpers --------------------------------------------------------------------------------

static func _outline() -> Color:
	return UITheme.current().outline


static func _line(s: float) -> float:
	return maxf(s * 0.07, 1.5)


## Greys a colour out when tone < 1 (unaffordable / disabled).
static func _tone(color: Color, tone: float) -> Color:
	if tone >= 1.0:
		return color
	var grey: float = color.get_luminance() * 0.75
	return Color(grey, grey, grey, color.a).lerp(color, 0.2)


static func _pts(c: Vector2, s: float, points: Array[Vector2]) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		out.append(c + p * s)
	return out


static func _rect_pts(c: Vector2, s: float, x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(x, y) * s, c + Vector2(x + w, y) * s, c + Vector2(x + w, y + h) * s,
			c + Vector2(x, y + h) * s])


static func _round_rect(c: Vector2, s: float, x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r), Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	for k in range(4):
		for i in range(7):
			var a: float = deg_to_rad(-90.0 + 90.0 * float(k) + 15.0 * float(i))
			out.append(c + (corners[k] + Vector2(cos(a), sin(a)) * r) * s)
	return out


static func _ellipse(center: Vector2, rx: float, ry: float, rot: float, steps: int = 28) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in range(steps):
		var a: float = TAU * float(i) / float(steps)
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


static func _arc_pts(center: Vector2, rx: float, ry: float, from: float, to: float, steps: int = 16) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var a: float = lerpf(from, to, float(i) / float(steps))
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func _egg_outline(c: Vector2, s: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in range(41):
		var a: float = TAU * float(i) / 40.0
		out.append(c + Vector2(sin(a) * 0.35 * (1.0 - 0.16 * cos(a)), -cos(a) * 0.45 + 0.02) * s)
	return out


static func _star(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var a: float = -PI * 0.5 + TAU * float(i) / 10.0
		var r: float = outer if i % 2 == 0 else inner
		out.append(center + Vector2(cos(a), sin(a)) * r)
	return out


## Filled polygon with a dark outline of constant width and round joins (the outline grows
## outward from the shape's edge by half its width and inward by the other half).
static func _shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line_color: Color, width: float) -> void:
	var outer: Array[PackedVector2Array] = Geometry2D.offset_polygon(pts, width * 0.5, Geometry2D.JOIN_ROUND)
	for poly: PackedVector2Array in outer:
		ci.draw_colored_polygon(poly, line_color)
		ci.draw_polyline(_closed(poly), line_color, 1.5, true)
	var inner: Array[PackedVector2Array] = Geometry2D.offset_polygon(pts, -width * 0.5, Geometry2D.JOIN_ROUND)
	for poly: PackedVector2Array in inner:
		ci.draw_colored_polygon(poly, fill)


## Outline stroke for polygons whose fill was drawn facet by facet: round joints at the corners.
static func _joined(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	ci.draw_polyline(_closed(pts), color, width, true)
	for p: Vector2 in pts:
		ci.draw_circle(p, width * 0.5, color, true, -1.0, true)


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	if not pts.is_empty():
		out.append(pts[0])
	return out

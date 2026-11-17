## The game logo drawn in code: the words of the title stacked ("JURA" over "RUSH") in chunky,
## stone-carved cartoon letters. Each letter has a thick dark-brown outline and a deep extruded
## side, an amber-to-orange gradient face (a tiny canvas shader recolours white glyphs by height),
## a pale rim light along its top edge, and a slightly different tilt and height so the word looks
## hand-cut. A bone sticks out behind the last word and two leaves sprout from the first.
## The whole logo is tilted and breathes by scaling a hair, both done with node properties, so
## the glyphs are drawn once (not every frame). Used by the main menu and the loading screen.
##
## Memory: Godot keeps one glyph atlas per (font size, outline size) pair, and big outlines make
## big atlases. The logo therefore uses ONE font size and ONE outline size.
class_name GameLogo
extends Control

## Tilt of the whole logo (radians) and how far the breathing sways around it.
const TILT: float = -0.07
const SWAY: float = 0.012
const BREATH: float = 0.018
## Metrics as a share of the font size.
const CAP_HEIGHT: float = 0.70
const OUTLINE: float = 0.12
const DEPTH: float = 0.075
const TRACKING: float = -0.025
const LINE_GAP: float = 0.21
## Extra room above the first line for the leaves.
const LEAF_ROOM: float = 0.14

const OUTLINE_COLOR: Color = Color(0.11, 0.06, 0.03)
const WALL_COLOR: Color = Color(0.62, 0.25, 0.04)
const RIM_COLOR: Color = Color(1.0, 0.97, 0.82, 0.9)

const FACE_SHADER: String = """
shader_type canvas_item;
uniform vec4 top_a = vec4(1.0, 0.93, 0.45, 1.0);
uniform vec4 bottom_a = vec4(1.0, 0.68, 0.12, 1.0);
uniform vec4 top_b = vec4(1.0, 0.75, 0.20, 1.0);
uniform vec4 bottom_b = vec4(0.96, 0.40, 0.07, 1.0);
uniform float y0 = 0.0;
uniform float y_split = 100.0;
uniform float y1 = 200.0;
varying float v_y;
void vertex() {
	v_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}
void fragment() {
	vec4 c;
	if (v_y < y_split) {
		c = mix(top_a, bottom_a, clamp((v_y - y0) / max(y_split - y0, 1.0), 0.0, 1.0));
	} else {
		c = mix(top_b, bottom_b, clamp((v_y - y_split) / max(y1 - y_split, 1.0), 0.0, 1.0));
	}
	COLOR = vec4(c.rgb, COLOR.a * c.a);
}
"""

static var _shader: Shader = null

var _words: PackedStringArray = PackedStringArray()
var _size: int = 150
var _font: Font = null
var _letters: Array[Dictionary] = []
var _face: Control = null
var _material: ShaderMaterial = null
var _grad: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _bone_at: Vector2 = Vector2.ZERO
var _bone_length: float = 0.0
var _leaf_at: Vector2 = Vector2.ZERO


## The size every logo uses, so the menu and the loading screen share their glyph atlases.
static func default_size() -> int:
	return UIKit.scaled(int(float(UITheme.current().size_title) * 1.45))


func _init(title: String, font_size: int = -1) -> void:
	_words = title.split(" ", false)
	if _words.is_empty():
		_words = PackedStringArray([title])
	_size = font_size if font_size > 0 else default_size()
	_font = UITheme.logo_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()
	_face = Control.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fill(_face)
	_face.material = _make_material()
	_face.draw.connect(_draw_face)
	add_child(_face)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	scale = Vector2.ONE * (1.0 + BREATH * sin(_time * 1.7))
	rotation = TILT + SWAY * sin(_time * 0.9)
	_update_gradient()


## The shader works in canvas space (glyph quads carry their position in MODEL_MATRIX), so the
## gradient heights are re-projected from logo space whenever the logo moves.
func _update_gradient() -> void:
	if _material == null or _face == null or not _face.is_inside_tree():
		return
	var xf: Transform2D = _face.get_global_transform()
	_material.set_shader_parameter(&"y0", (xf * Vector2(0.0, _grad.x)).y)
	_material.set_shader_parameter(&"y_split", (xf * Vector2(0.0, _grad.y)).y)
	_material.set_shader_parameter(&"y1", (xf * Vector2(0.0, _grad.z)).y)


## Places every letter (baseline-left corner, tilt) and measures the logo.
func _layout() -> void:
	var s: float = float(_size)
	var cap: float = s * CAP_HEIGHT
	var pad_x: float = s * (OUTLINE + 0.16)
	var pad_top: float = s * (OUTLINE + 0.04 + LEAF_ROOM)
	var pitch: float = cap + s * LINE_GAP
	var widths: Array[float] = []
	var widest: float = 0.0
	for word: String in _words:
		var w: float = 0.0
		for i in range(word.length()):
			w += _font.get_char_size(word.unicode_at(i), _size).x + (TRACKING * s if i > 0 else 0.0)
		widths.append(w)
		widest = maxf(widest, w)
	var total_w: float = widest + pad_x * 2.0
	_letters.clear()
	for wi in range(_words.size()):
		var word: String = _words[wi]
		var x: float = (total_w - widths[wi]) * 0.5
		var base_y: float = pad_top + cap + pitch * float(wi)
		for i in range(word.length()):
			var ch: String = word.substr(i, 1)
			var swing: float = sin(float(i) * 2.1 + float(wi) * 1.3)
			_letters.append({"ch": ch, "pos": Vector2(x, base_y + swing * s * 0.02), "rot": swing * 0.05, "word": wi})
			x += _font.get_char_size(word.unicode_at(i), _size).x + TRACKING * s
	var last: int = _words.size() - 1
	var bottom: float = pad_top + cap + pitch * float(last)
	_bone_length = widths[last] * 1.16
	_bone_at = Vector2(total_w * 0.5, bottom - cap * 0.18)
	_leaf_at = Vector2((total_w - widths[0]) * 0.5 + widths[0] * 0.86, pad_top + s * 0.02)
	custom_minimum_size = Vector2(total_w, bottom + s * (DEPTH + OUTLINE + 0.08))
	pivot_offset = custom_minimum_size * 0.5


func _make_material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FACE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	var s: float = float(_size)
	var cap: float = s * CAP_HEIGHT
	var pad_top: float = s * (OUTLINE + 0.04 + LEAF_ROOM)
	var pitch: float = cap + s * LINE_GAP
	# Gradient heights in logo space: top of the first line, the gap between lines, last baseline.
	_grad = Vector3(pad_top - s * 0.02, pad_top + cap + s * LINE_GAP * 0.5,
			pad_top + cap + pitch * float(maxi(_words.size() - 1, 0)) + s * 0.02)
	return _material


func _draw() -> void:
	var s: float = float(_size)
	var outline_px: int = int(s * OUTLINE)
	var depth: float = s * DEPTH
	_draw_accents(s)
	# Dark body: the outline stamped down the whole extrusion depth.
	for d: float in [0.0, 0.34, 0.67, 1.0]:
		_stamp_outline(outline_px, Vector2(0.0, depth * d), OUTLINE_COLOR)
	# Side walls: the glyph copied down the depth in burnt orange (the lit face covers the top).
	for d: float in [1.0, 0.85, 0.7, 0.55, 0.4, 0.25, 0.12]:
		_stamp_fill(Vector2(0.0, depth * d), WALL_COLOR)
	# Rim light along the top edge of the face.
	_stamp_fill(Vector2(0.0, -s * 0.028), RIM_COLOR)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_face() -> void:
	for letter: Dictionary in _letters:
		_face.draw_set_transform(letter["pos"] as Vector2, float(letter["rot"]), Vector2.ONE)
		_face.draw_string(_font, Vector2.ZERO, letter["ch"] as String, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _size, Color.WHITE)
	_face.draw_set_transform_matrix(Transform2D.IDENTITY)


func _stamp_outline(outline_px: int, shift: Vector2, color: Color) -> void:
	for letter: Dictionary in _letters:
		draw_set_transform((letter["pos"] as Vector2) + shift, float(letter["rot"]), Vector2.ONE)
		draw_string_outline(_font, Vector2.ZERO, letter["ch"] as String, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				_size, outline_px, color)


func _stamp_fill(shift: Vector2, color: Color) -> void:
	for letter: Dictionary in _letters:
		draw_set_transform((letter["pos"] as Vector2) + shift, float(letter["rot"]), Vector2.ONE)
		draw_string(_font, Vector2.ZERO, letter["ch"] as String, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _size, color)


## A bone lying behind the last word (its knobs stick out under the letters) and two leaves.
func _draw_accents(s: float) -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var half: float = _bone_length * 0.5
	var thick: float = s * 0.065
	var line: float = s * 0.03
	var cream: Color = Color(1.0, 0.94, 0.78)
	var wing: Vector2 = Vector2(half, 0.0)
	for end: float in [-1.0, 1.0]:
		for knob: float in [-1.0, 1.0]:
			draw_circle(_bone_at + wing * end + Vector2(0.0, thick * 1.1 * knob), thick * 1.3 + line, OUTLINE_COLOR, true, -1.0, true)
	draw_line(_bone_at - wing, _bone_at + wing, OUTLINE_COLOR, thick * 2.0 + line * 2.0, true)
	for end: float in [-1.0, 1.0]:
		for knob: float in [-1.0, 1.0]:
			draw_circle(_bone_at + wing * end + Vector2(0.0, thick * 1.1 * knob), thick * 1.3, cream, true, -1.0, true)
	draw_line(_bone_at - wing, _bone_at + wing, cream, thick * 2.0, true)
	_draw_leaf(_leaf_at, deg_to_rad(-64.0), s * 0.33, s * 0.14)
	_draw_leaf(_leaf_at + Vector2(s * 0.02, s * 0.01), deg_to_rad(-20.0), s * 0.27, s * 0.115)


## A pointed leaf growing from `base` in direction `angle`.
func _draw_leaf(base: Vector2, angle: float, length: float, width: float) -> void:
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var side: Vector2 = dir.orthogonal()
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i in range(13):
		var t: float = float(i) / 12.0
		var w: float = pow(sin(t * PI), 0.75) * width * 0.5
		left.append(base + dir * length * t + side * w)
		right.append(base + dir * length * t - side * w)
	right.reverse()
	var outline: PackedVector2Array = left + right
	var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(outline, float(_size) * 0.03, Geometry2D.JOIN_ROUND)
	for poly: PackedVector2Array in grown:
		draw_colored_polygon(poly, OUTLINE_COLOR)
	draw_colored_polygon(outline, Color(0.45, 0.78, 0.22))
	var half_shade: PackedVector2Array = PackedVector2Array()
	for i in range(13):
		half_shade.append(left[i])
	for i in range(12, -1, -1):
		half_shade.append(base + dir * length * (float(i) / 12.0))
	draw_colored_polygon(half_shade, Color(0.58, 0.88, 0.30))
	draw_line(base, base + dir * length * 0.9, Color(0.28, 0.55, 0.12), float(_size) * 0.015, true)

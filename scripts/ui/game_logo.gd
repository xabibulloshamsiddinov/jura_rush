## The game logo drawn in code, styled after the key art: two stacked words ("NEON" cyan,
## "RAILS" magenta), slanted forward, a thick dark outline, a soft neon halo that breathes
## slowly, and a magenta swoosh under the second word. Used by the main menu and loading screen.
##
## Memory: Godot keeps one glyph atlas per (font size, outline size) pair, and big outlines make
## big atlases. The logo therefore uses ONE font size (the second word is enlarged with the draw
## transform, not a bigger size) and only two outline sizes. With 2 sizes x 6 outlines the logo
## alone cost about 35 MB.
class_name GameLogo
extends Control

## Forward slant of the letters (x shift per pixel of height) and the tilt of the whole logo.
const SKEW: float = -0.2
const TILT: float = -0.06
const LINE_GAP: float = -0.22
## The second word is drawn this much larger (by transform).
const SECOND_SCALE: float = 1.12
## Outline widths as a share of the font size: soft halo and the dark rim.
const HALO_OUTLINE: float = 0.3
const DARK_OUTLINE: float = 0.18

var _words: PackedStringArray = PackedStringArray()
var _size: int = 104
var _font: Font = null
var _colors: Array[Color] = []
var _time: float = 0.0


## The size every logo uses, so the menu and the loading screen share their glyph atlases.
static func default_size() -> int:
	return UIKit.scaled(int(float(UITheme.current().size_title) * 1.3))


func _init(title: String, font_size: int = -1) -> void:
	var ui: UITheme = UITheme.current()
	_words = title.split(" ", false)
	if _words.is_empty():
		_words = PackedStringArray([title])
	_size = font_size if font_size > 0 else default_size()
	_font = UIKit.heading_font()
	_colors = [ui.cyan, ui.magenta]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var height: float = 0.0
	var width: float = 0.0
	for i in range(_words.size()):
		var k: float = _word_scale(i)
		height += _font.get_height(_size) * k * (1.0 + (LINE_GAP if i > 0 else 0.0))
		width = maxf(width, _font.get_string_size(_words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x * k)
	custom_minimum_size = Vector2(width + _size * 0.6, height + _size * 0.35)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _word_scale(index: int) -> float:
	return SECOND_SCALE if index > 0 else 1.0


func _draw() -> void:
	var logo_xf: Transform2D = Transform2D(TILT, Vector2.ONE, SKEW, size * 0.5)
	var line_h: float = _font.get_height(_size)
	var total: float = 0.0
	for i in range(_words.size()):
		total += line_h * _word_scale(i) * (1.0 + (LINE_GAP if i > 0 else 0.0))
	var y: float = -total * 0.5
	var breath: float = 0.75 + 0.25 * sin(_time * 1.6)
	var outline_dark: Color = Color(0.02, 0.01, 0.08, 0.95)
	var halo_px: int = int(_size * HALO_OUTLINE)
	var dark_px: int = int(_size * DARK_OUTLINE)
	var last_bottom: float = 0.0
	var last_width: float = 0.0
	for i in range(_words.size()):
		var k: float = _word_scale(i)
		var word: String = _words[i]
		var col: Color = _colors[mini(i, _colors.size() - 1)]
		var w: float = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x
		if i > 0:
			y += line_h * k * LINE_GAP
		# Each word is drawn at the shared size around its own origin, scaled by k.
		var origin: Vector2 = Vector2(0.0, y + _font.get_ascent(_size) * k)
		draw_set_transform_matrix(logo_xf * Transform2D(0.0, Vector2(k, k), 0.0, origin))
		var base: Vector2 = Vector2(-w * 0.5, 0.0)
		draw_string_outline(_font, base, word, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, halo_px,
				Color(col, 0.16 * breath))
		draw_string_outline(_font, base, word, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, dark_px, outline_dark)
		draw_string(_font, base, word, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, col.lightened(0.2))
		# Highlight on the upper edge of the letters (glossy look of the key art).
		draw_string(_font, base + Vector2(0.0, -_size * 0.035), word, HORIZONTAL_ALIGNMENT_LEFT, -1, _size,
				Color(1.0, 1.0, 1.0, 0.16))
		y += line_h * k
		last_bottom = origin.y
		last_width = w * k
	draw_set_transform_matrix(logo_xf)
	_draw_swoosh(Vector2(0.0, last_bottom + _size * 0.22), last_width * 1.15, breath)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A brush stroke under the last word: thick in the middle, thin at both ends.
func _draw_swoosh(at: Vector2, width: float, breath: float) -> void:
	var col: Color = _colors[_colors.size() - 1]
	var steps: int = 24
	var top: PackedVector2Array = PackedVector2Array()
	var bottom: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: float = at.x - width * 0.5 + width * t
		var curve: float = -sin(t * PI) * _size * 0.12 + (t - 0.5) * _size * -0.18
		var thick: float = sin(t * PI) * _size * 0.07 + 1.0
		top.append(Vector2(x, at.y + curve - thick * 0.5))
		bottom.append(Vector2(x, at.y + curve + thick * 0.5))
	draw_polyline(top, Color(col, 0.18 * breath), _size * 0.16, true)
	bottom.reverse()
	draw_colored_polygon(top + bottom, col.lightened(0.15))

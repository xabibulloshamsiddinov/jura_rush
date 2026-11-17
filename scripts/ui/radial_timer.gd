## Circular countdown: a ring that empties as time runs out, with a glyph in the middle.
## Used for HUD power-up timers and the revive popup.
class_name RadialTimer
extends Control

signal finished

var total: float = 1.0
var left: float = 1.0
var color: Color = Color(0.42, 0.74, 0.20)
var glyph: String = ""
## UIIcon.Kind of a vector symbol drawn instead of the glyph text (-1 = none).
var icon_kind: int = -1
var running: bool = true
## Blink when less than this many seconds remain.
var warn_below: float = 2.0

var _done: bool = false


func _init(diameter: float = 110.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pauses with the game (the router itself keeps processing while paused).
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Starts (or restarts) the countdown.
func start(seconds: float) -> void:
	total = maxf(seconds, 0.01)
	left = total
	_done = false
	running = true
	queue_redraw()


func _process(delta: float) -> void:
	if not running or _done:
		return
	left = maxf(left - delta, 0.0)
	queue_redraw()
	if left <= 0.0:
		_done = true
		finished.emit()


func _draw() -> void:
	var ui: UITheme = UITheme.current()
	var center: Vector2 = size * 0.5
	var outer: float = minf(size.x, size.y) * 0.5 - 2.0
	var ring: float = outer - 11.0
	var blink: bool = left < warn_below and fmod(left, 0.3) < 0.15
	# Dark rim, brown dial, pale groove, then the coloured arc that shrinks with the time left.
	draw_circle(center, outer, ui.outline, true, -1.0, true)
	draw_circle(center, outer - 4.0, Color(ui.panel, 0.9), true, -1.0, true)
	draw_arc(center, ring, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.13), 11.0, true)
	var sweep: float = TAU * clampf(left / total, 0.0, 1.0)
	if sweep > 0.01:
		draw_arc(center, ring, -PI * 0.5, -PI * 0.5 + sweep, 48, ui.text if blink else color, 11.0, true)
	if icon_kind >= 0:
		var half: float = ring * 0.88
		UIIcon.paint(self, icon_kind as UIIcon.Kind, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0))
	elif not glyph.is_empty():
		var font: Font = UIKit.font()
		var font_size: int = int(ring * 0.9)
		var text_size: Vector2 = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var at: Vector2 = center + Vector2(-text_size.x * 0.5, text_size.y * 0.3)
		draw_string_outline(font, at, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, ui.outline)
		draw_string(font, at, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ui.text)

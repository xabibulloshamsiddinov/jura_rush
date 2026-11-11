## Circular countdown: a ring that empties as time runs out, with a glyph in the middle.
## Used for HUD power-up timers and the revive popup.
class_name RadialTimer
extends Control

signal finished

var total: float = 1.0
var left: float = 1.0
var color: Color = Color(0.0, 0.9, 1.0)
var glyph: String = ""
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
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 6.0
	var blink: bool = left < warn_below and fmod(left, 0.3) < 0.15
	draw_circle(center, radius, Color(0.0, 0.0, 0.05, 0.6))
	draw_arc(center, radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.15), 8.0, true)
	var sweep: float = TAU * clampf(left / total, 0.0, 1.0)
	if sweep > 0.01:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + sweep, 40,
				Color.WHITE if blink else color, 8.0, true)
	if not glyph.is_empty():
		var font: Font = UIKit.font()
		var font_size: int = int(radius * 0.8)
		var text_size: Vector2 = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, text_size.y * 0.3), glyph,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

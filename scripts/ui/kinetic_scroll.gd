## ScrollContainer with touch-friendly kinetic (inertial) scrolling: the built-in drag moves the
## list while the finger is down; on release the list keeps gliding with the release velocity
## and slows down smoothly. Also pads the content so the first / last rows are never clipped.
class_name KineticScroll
extends ScrollContainer

## Velocity decay per second (higher = stops sooner).
const FRICTION: float = 4.5
## Minimum release speed (px/s) that starts a glide.
const MIN_FLING: float = 120.0

var _velocity: float = 0.0
var _last_scroll: float = 0.0
var _was_down: bool = false
var _gliding: bool = false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_deadzone = 12
	follow_focus = false


func _process(delta: float) -> void:
	if not is_visible_in_tree() or delta <= 0.0:
		return
	var down: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and get_global_rect().has_point(get_global_mouse_position())
	var current: float = float(scroll_vertical)
	if down:
		_gliding = false
		var instant: float = (current - _last_scroll) / delta
		_velocity = lerpf(_velocity, instant, 0.5)
	elif _was_down:
		_gliding = absf(_velocity) > MIN_FLING
	elif _gliding:
		_velocity *= exp(-FRICTION * delta)
		var before: int = scroll_vertical
		scroll_vertical = int(round(current + _velocity * delta))
		if absf(_velocity) < 20.0 or scroll_vertical == before:
			_gliding = false
	if not down and not _gliding:
		_velocity = 0.0
	_was_down = down
	_last_scroll = float(scroll_vertical)

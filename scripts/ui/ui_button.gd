## Custom button: press / hover scale, ink ripple, click sound and haptic (through the event
## bus). Created with UIKit.button().
class_name UIButton
extends Button

var ripple_color: Color = Color.WHITE
## Feedback kind emitted on press: &"click", &"confirm" or &"back".
var feedback: StringName = &"click"

var _ripple_t: float = 1.0
var _ripple_pos: Vector2 = Vector2.ZERO
var _scale_tween: Tween = null


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_on_down)
	button_up.connect(func() -> void: _scale_to(1.0))
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(func() -> void: _scale_to(1.0))
	pressed.connect(func() -> void: GameEvents.ui_feedback.emit(feedback))
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	set_process(false)


func _process(delta: float) -> void:
	_ripple_t += delta * 2.6
	queue_redraw()
	if _ripple_t >= 1.0:
		set_process(false)


func _draw() -> void:
	if _ripple_t < 1.0:
		var radius: float = maxf(size.x, size.y) * _ripple_t
		draw_circle(_ripple_pos, radius, Color(ripple_color, 0.35 * (1.0 - _ripple_t)))


func _on_down() -> void:
	if disabled:
		return
	_ripple_pos = get_local_mouse_position()
	_ripple_t = 0.0
	set_process(true)
	_scale_to(0.95)


func _on_hover() -> void:
	if disabled or DisplayServer.is_touchscreen_available():
		return
	_scale_to(1.04)
	GameEvents.ui_feedback.emit(&"hover")


func _scale_to(value: float) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	pivot_offset = size * 0.5
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(value, value), 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Chunky button. The look comes from the shared theme (ChunkyStyle): a pressed button drops its
## face onto the lip, so there is no scale squash. This class adds the desktop hover scale, the
## click sound and haptic (through the event bus), and lets child content follow the face down.
## Created with UIKit.button() / UIKit.round_button().
class_name UIButton
extends Button

## Feedback kind emitted on press: &"click", &"confirm" or &"back".
var feedback: StringName = &"click"
## Scale on mouse hover (desktop only). Buttons that pulse set 1.0 so the tweens never fight.
var hover_scale: float = 1.04
## Wrapper made by attach_content(); moves down by the lip height while the button is held.
var face_content: MarginContainer = null

var _scale_tween: Tween = null
var _content_top: int = 0
var _content_bottom: int = 0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(func() -> void: _scale_to(1.0))
	pressed.connect(func() -> void: GameEvents.ui_feedback.emit(feedback))
	resized.connect(func() -> void: pivot_offset = size * 0.5)


## Puts a control (icon, label, rows of them) on the button face. It sits above the lip and drops
## with the face when the button is pressed. Everything inside ignores the mouse.
func attach_content(child: Control, pad_x: int = 14, pad_y: int = 4) -> void:
	var ui: UITheme = UITheme.current()
	_content_top = ui.button_border + pad_y
	_content_bottom = ui.button_border + pad_y + ui.button_lip
	var wrap: MarginContainer = MarginContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fill(wrap)
	wrap.add_theme_constant_override(&"margin_left", ui.button_border + pad_x)
	wrap.add_theme_constant_override(&"margin_right", ui.button_border + pad_x)
	wrap.add_theme_constant_override(&"margin_top", _content_top)
	wrap.add_theme_constant_override(&"margin_bottom", _content_bottom)
	wrap.add_child(child)
	add_child(wrap)
	_ignore_mouse(wrap)
	face_content = wrap


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _on_down() -> void:
	if disabled or face_content == null:
		return
	var lip: int = UITheme.current().button_lip
	face_content.add_theme_constant_override(&"margin_top", _content_top + lip)
	face_content.add_theme_constant_override(&"margin_bottom", _content_bottom - lip)


func _on_up() -> void:
	if face_content == null:
		return
	face_content.add_theme_constant_override(&"margin_top", _content_top)
	face_content.add_theme_constant_override(&"margin_bottom", _content_bottom)


func _on_hover() -> void:
	if disabled or hover_scale == 1.0 or DisplayServer.is_touchscreen_available():
		return
	_scale_to(hover_scale)
	GameEvents.ui_feedback.emit(&"hover")


func _scale_to(value: float) -> void:
	if hover_scale == 1.0:
		return
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	pivot_offset = size * 0.5
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2(value, value), 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

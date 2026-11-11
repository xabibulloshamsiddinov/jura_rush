## First-run tutorial overlay. Teaches the four gestures one at a time with an animated "finger";
## each gesture must actually be performed (detected through the event bus) to move on. The
## track stays empty meanwhile. Skippable; completion is stored in the save.
extends UIScreen

const STEPS: Array[StringName] = [&"left", &"right", &"up", &"down"]
const DIRECTIONS: Dictionary = {
	&"left": Vector2(-1.0, 0.0), &"right": Vector2(1.0, 0.0),
	&"up": Vector2(0.0, -1.0), &"down": Vector2(0.0, 1.0),
}

var _step: int = 0
var _text: Label = null
var _finger: Panel = null
var _time: float = 0.0
var _active: bool = false


func build() -> void:
	is_popup = true
	var ui: UITheme = UITheme.current()
	var column: VBoxContainer = UIKit.vbox(20)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrap: MarginContainer = UIKit.margin(column, 60, 300)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fill(wrap)
	add_child(wrap)
	var card: PanelContainer = UIKit.panel(false, ui.yellow)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = UIKit.label("", ui.size_h2, ui.text)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(_text)
	column.add_child(card)
	column.add_child(UIKit.spacer())
	var skip: UIButton = UIKit.button(tr_key(&"tutorial.skip"), &"ghost", 360.0)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(_finish)
	column.add_child(skip)
	_finger = Panel.new()
	_finger.size = Vector2(120.0, 120.0)
	_finger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finger.add_theme_stylebox_override(&"panel", UIKit.box(Color(1.0, 1.0, 1.0, 0.85), 60, ui.yellow, 8))
	add_child(_finger)


func connect_events() -> void:
	GameEvents.lane_changed.connect(func(from: int, to: int) -> void:
		_on_action(&"left" if to < from else &"right"))
	GameEvents.player_jumped.connect(func() -> void: _on_action(&"up"))
	GameEvents.player_rolled.connect(func() -> void: _on_action(&"down"))
	GameEvents.state_changed.connect(func(_from: StringName, to: StringName) -> void:
		if _active and (to == &"menu" or to == &"game_over" or to == &"loading"):
			_active = false)


func on_enter(_args: Dictionary) -> void:
	_step = 0
	_active = true
	_show_step()


func handle_back() -> bool:
	GameEvents.request_pause.emit()
	return true


func _process(delta: float) -> void:
	if not visible or not _active or _step >= STEPS.size():
		return
	# The "finger" repeats the swipe: slide along the direction, fade out, start again.
	_time = fmod(_time + delta, 1.1)
	var t: float = clampf(_time / 0.7, 0.0, 1.0)
	var direction: Vector2 = DIRECTIONS[STEPS[_step]]
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.68) - _finger.size * 0.5
	_finger.position = center + direction * lerpf(-170.0, 170.0, MathUtils.ease_out_cubic(t))
	_finger.modulate.a = 1.0 - smoothstep(0.7, 1.0, _time / 1.1 * 1.4)


func _show_step() -> void:
	_time = 0.0
	_text.text = tr_key(StringName("tutorial." + String(STEPS[_step])))
	UITween.bump(_text, 1.1)


func _on_action(action: StringName) -> void:
	if not _active or not visible or _step >= STEPS.size() or STEPS[_step] != action:
		return
	GameEvents.tutorial_step_done.emit(action)
	GameEvents.ui_feedback.emit(&"confirm")
	_step += 1
	if _step < STEPS.size():
		_show_step()
		return
	_text.text = tr_key(&"tutorial.done")
	_finger.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(_finish)


func _finish() -> void:
	if not _active:
		return
	_active = false
	GameEvents.tutorial_finished.emit()
	SceneRouter.close(&"tutorial")

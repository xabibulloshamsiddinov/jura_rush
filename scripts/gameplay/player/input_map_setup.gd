## Creates the input actions in code so the project needs no hand-edited Input Map.
##   move_left  : A, Left,  D-pad left,  left stick left
##   move_right : D, Right, D-pad right, left stick right
##   jump       : W, Up, Space, D-pad up, gamepad A
##   roll       : S, Down, D-pad down, gamepad B
##   debug_overlay : F3
class_name InputMapSetup
extends RefCounted


## Adds every action once (safe to call repeatedly).
static func ensure() -> void:
	if InputMap.has_action(&"move_left"):
		return
	_add(&"move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add(&"move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add(&"jump", [KEY_W, KEY_UP, KEY_SPACE], [JOY_BUTTON_DPAD_UP, JOY_BUTTON_A], JOY_AXIS_LEFT_Y, -1.0)
	_add(&"roll", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_B], JOY_AXIS_LEFT_Y, 1.0)
	_add(&"debug_overlay", [KEY_F3], [], -1, 0.0)


static func _add(action: StringName, keys: Array[Key], buttons: Array[JoyButton], axis: int,
		axis_value: float) -> void:
	InputMap.add_action(action, 0.5)
	for key in keys:
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for button in buttons:
		var jb: InputEventJoypadButton = InputEventJoypadButton.new()
		jb.button_index = button
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = axis as JoyAxis
		motion.axis_value = axis_value
		InputMap.action_add_event(action, motion)

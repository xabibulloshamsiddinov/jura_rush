## Keyboard actions for the two versus players (created in code, like InputMapSetup).
##   Player 1: W gas, S brake, A / D lanes, Space fire (also F), Q switch power-up (also Left Shift)
##   Player 2: arrows, Enter fire (also Numpad 0 / Right Ctrl), Right Shift switch (also Numpad . and /)
##   P pauses (Esc too, through the UI router).
## Gamepads: pad 0 -> player 1, pad 1 -> player 2 (D-pad / stick, A fire, B brake, X switch, RT gas).
class_name VsInput
extends RefCounted

const KEYS: Dictionary = {
	&"vs1_left": [KEY_A], &"vs1_right": [KEY_D], &"vs1_gas": [KEY_W], &"vs1_brake": [KEY_S],
	&"vs1_fire": [KEY_SPACE, KEY_F], &"vs1_cycle": [KEY_Q, KEY_SHIFT],
	&"vs2_left": [KEY_LEFT], &"vs2_right": [KEY_RIGHT], &"vs2_gas": [KEY_UP], &"vs2_brake": [KEY_DOWN],
	&"vs2_fire": [KEY_ENTER, KEY_KP_ENTER, KEY_KP_0, KEY_CTRL], &"vs2_cycle": [KEY_SHIFT, KEY_KP_PERIOD, KEY_SLASH],
	&"vs_pause_key": [KEY_P],
}
## Left / right modifier keys are told apart by location.
const RIGHT_SIDE: Dictionary = {&"vs1_cycle": false, &"vs2_fire": true, &"vs2_cycle": true}


## Adds every action once (safe to call repeatedly).
static func ensure() -> void:
	if InputMap.has_action(&"vs1_left"):
		return
	for action: StringName in KEYS.keys():
		InputMap.add_action(action, 0.5)
		for key: Key in KEYS[action]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = key
			if key == KEY_SHIFT or key == KEY_CTRL:
				ev.location = KEY_LOCATION_RIGHT if bool(RIGHT_SIDE.get(action, false)) else KEY_LOCATION_LEFT
			InputMap.action_add_event(action, ev)
	for device in range(2):
		var p: String = "vs%d_" % (device + 1)
		_pad_button(StringName(p + "left"), device, JOY_BUTTON_DPAD_LEFT)
		_pad_button(StringName(p + "right"), device, JOY_BUTTON_DPAD_RIGHT)
		_pad_button(StringName(p + "gas"), device, JOY_BUTTON_DPAD_UP)
		_pad_button(StringName(p + "brake"), device, JOY_BUTTON_DPAD_DOWN)
		_pad_button(StringName(p + "brake"), device, JOY_BUTTON_B)
		_pad_button(StringName(p + "fire"), device, JOY_BUTTON_A)
		_pad_button(StringName(p + "cycle"), device, JOY_BUTTON_X)
		_pad_axis(StringName(p + "left"), device, JOY_AXIS_LEFT_X, -1.0)
		_pad_axis(StringName(p + "right"), device, JOY_AXIS_LEFT_X, 1.0)
		_pad_axis(StringName(p + "gas"), device, JOY_AXIS_TRIGGER_RIGHT, 1.0)


static func _pad_button(action: StringName, device: int, button: JoyButton) -> void:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action, ev)


static func _pad_axis(action: StringName, device: int, axis: JoyAxis, value: float) -> void:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

## Translates raw input (touch swipes, keyboard, gamepad) into InputCommands for the player.
## Swipes fire as soon as the threshold is crossed (not on release) for minimum latency, and the
## gesture re-arms immediately so several swipes can be chained without lifting the finger.
class_name InputHandler
extends Node

## Receives the commands.
var player: Player = null
## Only produces commands while true (set by GameWorld from the flow state).
var enabled: bool = false

var _cfg: GameConfig = GameConfig.current()
var _touching: bool = false
var _touch_index: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _start_msec: int = 0
var _fired: bool = false


func _ready() -> void:
	InputMapSetup.ensure()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or player == null:
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event.is_action_pressed(&"move_left"):
		player.push_command(InputCommand.Lane.new(-1))
	elif event.is_action_pressed(&"move_right"):
		player.push_command(InputCommand.Lane.new(1))
	elif event.is_action_pressed(&"jump"):
		player.push_command(InputCommand.Jump.new())
	elif event.is_action_pressed(&"roll"):
		player.push_command(InputCommand.Roll.new())


## Swipe threshold in base-resolution pixels (1080 wide). Because the UI stretch mode scales
## input with the screen, this is a constant fraction of the display on every device / DPI.
func swipe_threshold() -> float:
	return _cfg.swipe_min_distance / clampf(SettingsManager.get_float("sensitivity"), 0.5, 2.0)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and not _touching:
		_touching = true
		_touch_index = event.index
		_start_pos = event.position
		_start_msec = Time.get_ticks_msec()
		_fired = false
	elif not event.pressed and event.index == _touch_index:
		_touching = false
		_touch_index = -1


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touching or event.index != _touch_index:
		return
	var now: int = Time.get_ticks_msec()
	# Too slow to be a swipe: slide the window so a later flick still counts.
	if float(now - _start_msec) > _cfg.swipe_max_time * 1000.0:
		_start_pos = event.position
		_start_msec = now
		return
	var d: Vector2 = event.position - _start_pos
	var ax: float = absf(d.x)
	var ay: float = absf(d.y)
	var threshold: float = swipe_threshold()
	var cmd: Command = null
	# Dominant axis with a dead zone: diagonal drags inside the ratio band are ignored.
	if ax >= threshold and ax > ay * _cfg.swipe_axis_ratio:
		cmd = InputCommand.Lane.new(1 if d.x > 0.0 else -1)
	elif ay >= threshold and ay > ax * _cfg.swipe_axis_ratio:
		cmd = InputCommand.Jump.new() if d.y < 0.0 else InputCommand.Roll.new()
	if cmd != null:
		player.push_command(cmd)
		_start_pos = event.position
		_start_msec = now
		_fired = true

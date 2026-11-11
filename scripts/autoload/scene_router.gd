## UI navigation: a stack of screens on one CanvasLayer with fade / slide / pop transitions,
## safe-area margins and back handling (Android back button and Esc).
## The base screen follows the game-flow state; shop / settings / missions are pushed on top.
extends Node

const SCREEN_DIR: String = "res://scenes/ui/"
const SCREEN_IDS: Array[StringName] = [&"loading_overlay", &"main_menu", &"hud", &"pause_menu",
		&"revive_popup", &"game_over", &"shop", &"settings", &"missions", &"tutorial", &"versus_intro",
		&"versus_hud"]

var _layer: CanvasLayer = null
var _root: Control = null
var _screens: Dictionary = {}
var _stack: Array[StringName] = []
var _language: String = ""
var _large_text: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The one shared Godot Theme: every screen below inherits fonts and neon button styles.
	_root.theme = UITheme.godot_theme()
	# FPS / draw-call readout above every screen (Settings > Show FPS).
	var perf: PerfOverlay = PerfOverlay.new()
	_layer.add_child(perf)
	_layer.add_child(_root)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_language = Tr.language()
	_large_text = SettingsManager.get_bool("large_text")
	GameEvents.state_changed.connect(_on_state_changed)
	GameEvents.settings_changed.connect(_on_settings_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


## Replaces the whole stack with one screen.
func show_screen(id: StringName, args: Dictionary = {}) -> void:
	if _stack.size() == 1 and _stack[0] == id:
		_screen(id).args = args
		_screen(id).on_enter(args)
		return
	for old: StringName in _stack:
		_hide(old)
	_stack.clear()
	_stack.append(id)
	_show(id, args, false)


## Pushes a screen on top of the current one.
func push(id: StringName, args: Dictionary = {}) -> void:
	if _stack.has(id):
		return
	var incoming: UIScreen = _screen(id)
	if not incoming.is_popup and not _stack.is_empty():
		_screen(_stack[_stack.size() - 1]).visible = false
	_stack.append(id)
	_show(id, args, true)


## Pops the top screen and reveals the one below.
func back() -> void:
	if _stack.size() <= 1:
		return
	var top: StringName = _stack.pop_back() as StringName
	_hide(top)
	var below: UIScreen = _screen(_stack[_stack.size() - 1])
	if not below.visible:
		below.visible = true
		below.modulate.a = 1.0
		below.on_enter(below.args)
	GameEvents.ui_feedback.emit(&"back")


## Removes a specific screen wherever it is in the stack.
func close(id: StringName) -> void:
	if not _stack.has(id):
		return
	if _stack[_stack.size() - 1] == id and _stack.size() > 1:
		_stack.pop_back()
		_hide(id)
		var below: UIScreen = _screen(_stack[_stack.size() - 1])
		below.visible = true
	else:
		_stack.erase(id)
		_hide(id)


## Id of the top-most screen.
func current() -> StringName:
	return _stack[_stack.size() - 1] if not _stack.is_empty() else &""


## The instance of a screen (created on first use).
func get_screen(id: StringName) -> UIScreen:
	return _screen(id)


func _screen(id: StringName) -> UIScreen:
	if _screens.has(id):
		return _screens[id] as UIScreen
	var scene: PackedScene = ResourceLoader.load(SCREEN_DIR + String(id) + ".tscn") as PackedScene
	var screen: UIScreen = scene.instantiate() as UIScreen
	screen.visible = false
	_root.add_child(screen)
	_screens[id] = screen
	return screen


func _show(id: StringName, args: Dictionary, pushed: bool) -> void:
	var screen: UIScreen = _screen(id)
	screen.args = args
	screen.visible = true
	_root.move_child(screen, -1)
	screen.on_enter(args)
	if screen.is_popup:
		UITween.fade(screen, 1.0, 0.15)
	elif pushed:
		UITween.slide_in(screen, Vector2(_root.size.x * 0.25, 0.0))
	else:
		screen.position = Vector2.ZERO
		screen.modulate.a = 0.0
		UITween.fade(screen, 1.0, 0.25)


func _hide(id: StringName) -> void:
	if not _screens.has(id):
		return
	var screen: UIScreen = _screens[id]
	if screen.visible:
		screen.on_exit()
	screen.visible = false


func _on_back() -> void:
	if _stack.is_empty():
		return
	var top: UIScreen = _screen(_stack[_stack.size() - 1])
	if top.handle_back():
		return
	if _stack.size() > 1:
		back()


func _on_state_changed(from: StringName, to: StringName) -> void:
	match to:
		&"menu":
			show_screen(&"main_menu")
		&"loading":
			show_screen(&"loading_overlay", {"mode": "run"})
		&"countdown":
			if from == &"paused" or from == &"revive":
				close(&"pause_menu")
				close(&"revive_popup")
			else:
				show_screen(&"hud")
		&"running":
			if not _stack.has(&"hud"):
				show_screen(&"hud")
		&"paused":
			push(&"pause_menu")
		&"revive":
			push(&"revive_popup")
		&"game_over":
			show_screen(&"game_over")


## Language or text size changed: rebuild every screen so all strings refresh.
func _on_settings_changed() -> void:
	var large: bool = SettingsManager.get_bool("large_text")
	if Tr.language() == _language and large == _large_text:
		return
	_language = Tr.language()
	_large_text = large
	for screen: UIScreen in _screens.values():
		screen.rebuild.call_deferred()


## Keeps the UI inside the display safe area (notches, rounded corners, gesture bars).
func _apply_safe_area() -> void:
	UIKit.fill(_root)
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var base_size: Vector2 = get_viewport().get_visible_rect().size
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	var screen_size: Vector2 = Vector2(DisplayServer.screen_get_size())
	if not OS.has_feature("mobile") or safe.size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var scale: Vector2 = base_size / screen_size
	_root.offset_left = safe.position.x * scale.x
	_root.offset_top = safe.position.y * scale.y
	_root.offset_right = -(screen_size.x - safe.end.x) * scale.x
	_root.offset_bottom = -(screen_size.y - safe.end.y) * scale.y

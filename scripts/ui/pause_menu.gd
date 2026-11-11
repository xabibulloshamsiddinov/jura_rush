## Pause popup. The game tree is frozen by GameState; resuming goes through a 3 s countdown.
extends UIScreen

var _panel: PanelContainer = null


func build() -> void:
	is_popup = true
	var ui: UITheme = UITheme.current()
	add_child(UIKit.dimmer(0.55))
	var center: CenterContainer = CenterContainer.new()
	UIKit.fill(center)
	add_child(center)
	_panel = UIKit.panel(false, ui.cyan)
	_panel.custom_minimum_size = Vector2(720.0, 0.0)
	center.add_child(_panel)
	var column: VBoxContainer = UIKit.vbox(26)
	_panel.add_child(UIKit.margin(column, 40, 40))
	column.add_child(UIKit.label(tr_key(&"pause.title"), ui.size_h1, ui.cyan))
	_add(column, &"pause.resume", &"primary", func() -> void: GameEvents.request_resume.emit())
	_add(column, &"pause.restart", &"accent", func() -> void: GameEvents.request_restart.emit())
	_add(column, &"pause.settings", &"ghost", func() -> void: SceneRouter.push(&"settings"))
	_add(column, &"pause.menu", &"danger", func() -> void: GameEvents.request_menu.emit())


func on_enter(_args: Dictionary) -> void:
	UITween.pop(_panel, 0.0, 0.85)


func handle_back() -> bool:
	GameEvents.request_resume.emit()
	return true


func _add(parent: Control, key: StringName, style: StringName, action: Callable) -> void:
	var b: UIButton = UIKit.button(tr_key(key), style)
	b.pressed.connect(action)
	parent.add_child(b)

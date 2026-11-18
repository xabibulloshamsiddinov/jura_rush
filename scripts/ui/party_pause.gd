## Multiplayer pause popup (the tree is frozen by PartyMode; the phones show PAUSED).
## RESUME, RESTART (same players), CHANGE PLAYERS (back to the lobby), MAIN MENU.
extends UIScreen

var _panel: PanelContainer = null


func build() -> void:
	is_popup = true
	var ui: UITheme = UITheme.current()
	add_child(UIKit.dimmer(0.6))
	var center: CenterContainer = CenterContainer.new()
	UIKit.fill(center)
	add_child(center)
	_panel = UIKit.panel(false, ui.accent)
	_panel.custom_minimum_size = Vector2(720.0, 0.0)
	center.add_child(_panel)
	var column: VBoxContainer = UIKit.vbox(24)
	_panel.add_child(UIKit.margin(column, 40, 36))
	column.add_child(UIKit.label(tr_key(&"pause.title"), ui.size_h1, ui.accent))
	_add(column, &"pause.resume", &"primary", func() -> void: _party_call(&"set_paused", [false]))
	_add(column, &"pause.restart", &"accent", func() -> void: _party_call(&"restart", []))
	_add(column, &"party.change_players", &"secondary", func() -> void: _party_call(&"to_lobby", []))
	_add(column, &"pause.menu", &"danger", func() -> void: _party_call(&"close", []))


func on_enter(_args: Dictionary) -> void:
	UITween.pop(_panel, 0.0, 0.85)


func handle_back() -> bool:
	_party_call(&"set_paused", [false])
	return true


func _party_call(method: StringName, arguments: Array) -> void:
	var party: PartyMode = Services.locate(&"party") as PartyMode
	if party != null:
		party.callv(method, arguments)


func _add(parent: Control, key: StringName, style: StringName, action: Callable) -> void:
	var b: UIButton = UIKit.button(tr_key(key), style)
	b.pressed.connect(action)
	parent.add_child(b)

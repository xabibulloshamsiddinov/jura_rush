## Multiplayer results: gold / silver / bronze rows (place, name, runner, score, distance, eggs),
## PLAY AGAIN (Enter, or every phone's own button), CHANGE PLAYERS (L), MAIN MENU (Esc), and the
## seconds left before the room goes back to the lobby by itself.
extends UIScreen

const MEDALS: Array[Color] = [Color(1.0, 0.8, 0.2), Color(0.82, 0.86, 0.9), Color(0.85, 0.53, 0.28)]

var _party: PartyMode = null
var _rows: VBoxContainer = null
var _timer: Label = null
var _phones: Label = null
var _title: Label = null


func build() -> void:
	var ui: UITheme = UITheme.current()
	add_child(UIKit.dimmer(0.72))
	var center: CenterContainer = CenterContainer.new()
	UIKit.fill(center)
	add_child(center)
	var panel: PanelContainer = UIKit.panel(false, ui.accent)
	panel.custom_minimum_size = Vector2(1240.0, 0.0)
	center.add_child(panel)
	var column: VBoxContainer = UIKit.vbox(22)
	panel.add_child(UIKit.margin(column, 48, 36))
	_title = UIKit.label(tr_key(&"party.results.title"), ui.size_title, ui.accent)
	_title.add_theme_font_override(&"font", UIKit.heading_font())
	column.add_child(_title)
	_rows = UIKit.vbox(14)
	column.add_child(_rows)
	_phones = UIKit.label(tr_key(&"party.results.phones"), ui.size_small, ui.text_dim)
	column.add_child(_phones)
	var buttons: HBoxContainer = UIKit.hbox(24)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var again: UIButton = UIKit.button(tr_key(&"over.again"), &"primary", 360.0)
	again.feedback = &"confirm"
	again.pressed.connect(func() -> void:
		if _party != null:
			_party.restart())
	buttons.add_child(again)
	var lobby: UIButton = UIKit.button(tr_key(&"party.change_players"), &"secondary", 380.0)
	lobby.pressed.connect(func() -> void:
		if _party != null:
			_party.to_lobby())
	buttons.add_child(lobby)
	var menu: UIButton = UIKit.button(tr_key(&"pause.menu"), &"danger", 320.0)
	menu.pressed.connect(func() -> void:
		if _party != null:
			_party.close())
	buttons.add_child(menu)
	_timer = UIKit.label("", ui.size_small, ui.text_dim)
	column.add_child(_timer)


func on_enter(_args: Dictionary) -> void:
	_party = Services.locate(&"party") as PartyMode
	_fill()
	VFXManager.play_ui(&"confetti", Vector2(960.0, 420.0))


func handle_back() -> bool:
	if _party != null:
		_party.close()
	return true


func _process(_delta: float) -> void:
	if visible and _party != null and _timer != null:
		_timer.text = Tr.f(&"party.results.lobby_in", {"n": ceili(maxf(_party.results_left, 0.0))})


func _fill() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _party == null:
		return
	var ui: UITheme = UITheme.current()
	_rows.add_child(_header(ui))
	var any_phone: bool = false
	for m: PartyRoster.Member in _party.roster.list():
		any_phone = any_phone or m.kind == PartyRoster.Kind.PHONE
	_phones.visible = any_phone
	for entry: Dictionary in _party.results:
		var place: int = int(entry["place"])
		var row: PanelContainer = PanelContainer.new()
		var tint: Color = MEDALS[place - 1] if place <= 3 else ui.secondary
		row.add_theme_stylebox_override(&"panel", UITheme.panel_style(true, tint))
		var line: HBoxContainer = UIKit.hbox(24)
		row.add_child(UIKit.margin(line, 26, 10))
		var medal: Label = UIKit.label(tr_key([&"party.place1", &"party.place2", &"party.place3"][clampi(place - 1, 0, 2)]),
				ui.size_h2, tint)
		medal.add_theme_font_override(&"font", UIKit.heading_font())
		medal.custom_minimum_size = Vector2(170.0, 0.0)
		line.add_child(medal)
		var swatch: ColorRect = ColorRect.new()
		swatch.color = entry["color"] as Color
		swatch.custom_minimum_size = Vector2(26.0, 64.0)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(swatch)
		var who: VBoxContainer = UIKit.vbox(-4)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_child(UIKit.label(str(entry["name"]), ui.size_h2, ui.text, HORIZONTAL_ALIGNMENT_LEFT))
		var def: CharacterDef = ContentDB.character(StringName(str(entry["character"])))
		var sub: String = Tr.t(def.name_key) if def != null else ""
		if not bool(entry.get("survived", false)):
			sub += "  -  " + tr_key(&"party.results.out")
		who.add_child(UIKit.label(sub, ui.size_small, ui.text_dim, HORIZONTAL_ALIGNMENT_LEFT))
		line.add_child(who)
		line.add_child(_cell(MathUtils.group_digits(int(entry["distance"])) + " m", 200.0, ui.text))
		line.add_child(_cell(MathUtils.group_digits(int(entry["eggs"])), 140.0, ui.accent))
		var score: Label = _cell(MathUtils.group_digits(int(entry["score"])), 240.0, ui.text)
		score.add_theme_font_override(&"font", UIKit.heading_font())
		score.add_theme_font_size_override(&"font_size", UIKit.scaled(ui.size_h2))
		line.add_child(score)
		_rows.add_child(row)
		UITween.pop(row, 0.12 * float(place), 0.7)


## Column titles, padded exactly like the rows below so the columns line up.
func _header(ui: UITheme) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	var row_style: StyleBox = UITheme.panel_style(true, ui.secondary)
	var pad: StyleBoxEmpty = StyleBoxEmpty.new()
	pad.content_margin_left = row_style.content_margin_left
	pad.content_margin_right = row_style.content_margin_right
	frame.add_theme_stylebox_override(&"panel", pad)
	var line: HBoxContainer = UIKit.hbox(24)
	frame.add_child(UIKit.margin(line, 26, 0))
	line.add_child(UIKit.spacer())
	line.add_child(_cell(tr_key(&"over.distance"), 200.0, ui.text_dim))
	line.add_child(_cell(tr_key(&"over.coins"), 140.0, ui.text_dim))
	line.add_child(_cell(tr_key(&"over.score"), 240.0, ui.text_dim))
	return frame


func _cell(text: String, width: float, color: Color) -> Label:
	var label: Label = UIKit.label(text, UITheme.current().size_body, color, HORIZONTAL_ALIGNMENT_RIGHT)
	label.custom_minimum_size = Vector2(width, 0.0)
	return label

## "How to connect your phone" (F1 in the lobby): the steps, every address the computer has with
## the port, live counters ("page opened N times", "controllers connected M, now K") and what
## they mean, and the usual fixes (same Wi-Fi, firewall, mobile data, the /ping test, a hotspot).
extends UIScreen

var _panel: PanelContainer = null
var _addresses: Label = null
var _counters: Label = null
var _verdict: Label = null
var _left: float = 0.0


func build() -> void:
	is_popup = true
	var ui: UITheme = UITheme.current()
	add_child(UIKit.dimmer(0.75))
	var center: CenterContainer = CenterContainer.new()
	UIKit.fill(center)
	add_child(center)
	_panel = UIKit.panel(false, ui.accent)
	_panel.custom_minimum_size = Vector2(1500.0, 0.0)
	center.add_child(_panel)
	var column: VBoxContainer = UIKit.vbox(16)
	_panel.add_child(UIKit.margin(column, 44, 32))
	column.add_child(UIKit.label(tr_key(&"party.help.title"), ui.size_h1, ui.accent))
	var body: HBoxContainer = UIKit.hbox(40)
	column.add_child(body)
	var left: VBoxContainer = UIKit.vbox(12)
	left.custom_minimum_size = Vector2(700.0, 0.0)
	body.add_child(left)
	left.add_child(UIKit.label(tr_key(&"party.help.addresses"), ui.size_body, ui.accent, HORIZONTAL_ALIGNMENT_LEFT))
	_addresses = _text("", ui.text)
	left.add_child(_addresses)
	left.add_child(UIKit.label(tr_key(&"party.help.diagnostics"), ui.size_body, ui.accent, HORIZONTAL_ALIGNMENT_LEFT))
	_counters = _text("", ui.text)
	left.add_child(_counters)
	_verdict = _text("", ui.success)
	left.add_child(_verdict)
	var right: VBoxContainer = UIKit.vbox(12)
	right.custom_minimum_size = Vector2(660.0, 0.0)
	body.add_child(right)
	right.add_child(UIKit.label(tr_key(&"party.help.tips"), ui.size_body, ui.accent, HORIZONTAL_ALIGNMENT_LEFT))
	for key: StringName in [&"party.help.tip_wifi", &"party.help.tip_firewall", &"party.help.tip_data",
			&"party.help.tip_ping", &"party.help.tip_screen", &"party.help.tip_hotspot"]:
		right.add_child(_text("-  " + tr_key(key), ui.text))
	var close: UIButton = UIKit.button(tr_key(&"party.help.close"), &"primary", 360.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: SceneRouter.close(&"party_help"))
	column.add_child(close)


func on_enter(_args: Dictionary) -> void:
	UITween.pop(_panel, 0.0, 0.9)
	_left = 0.0
	_update()


func handle_back() -> bool:
	SceneRouter.close(&"party_help")
	return true


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		_left = 0.5
		_update()


func _update() -> void:
	var party: PartyMode = Services.locate(&"party") as PartyMode
	if party == null:
		return
	var info: Dictionary = party.connection_info()
	var ui: UITheme = UITheme.current()
	if not bool(info["listening"]):
		_addresses.text = tr_key(&"party.server_error")
		_counters.text = ""
		_verdict.text = ""
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append(Tr.f(&"party.help.port", {"port": info["port"]}))
	var addresses: Array = info["addresses"]
	if addresses.is_empty():
		lines.append(tr_key(&"party.help.no_network"))
	for a: Dictionary in addresses:
		var line: String = "http://%s:%d" % [a["ip"], info["port"]]
		if bool(a["virtual"]):
			line += "   (" + tr_key(&"party.help.virtual") + ")"
		elif str(a["name"]) != "":
			line += "   (" + str(a["name"]) + ")"
		lines.append(line)
	_addresses.text = "\n".join(lines)
	_counters.text = Tr.f(&"party.help.counters", {"pages": info["page_hits"], "total": info["ws_total"],
			"now": info["ws_now"]})
	var verdict: StringName = &"party.help.verdict_none"
	var color: Color = ui.danger
	if int(info["ws_now"]) > 0:
		verdict = &"party.help.verdict_ok"
		color = ui.success
	elif int(info["page_hits"]) > 0:
		verdict = &"party.help.verdict_page"
		color = ui.accent
	_verdict.text = tr_key(verdict)
	_verdict.add_theme_color_override(&"font_color", color)


func _text(text: String, color: Color) -> Label:
	var label: Label = UIKit.label(text, 26, color, HORIZONTAL_ALIGNMENT_LEFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(640.0, 0.0)
	return label

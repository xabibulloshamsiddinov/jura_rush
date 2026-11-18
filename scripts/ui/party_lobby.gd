## Multiplayer lobby (landscape, 1920 x 1080 canvas). Left: how to join with a phone, the QR code
## of the controller page and its address. Right: three player cards (name, 3D runner on its
## pedestal, status; keyboard and bot cards get runner / READY / remove buttons). Bottom: the room
## status ("starting in 2..."), + KEYBOARD, + BOT and START. Everything lives in PartyMode; this
## screen only shows it and forwards the buttons.
extends UIScreen

const CARD_SIZE: Vector2 = Vector2(330.0, 600.0)
const QR_SIZE: float = 320.0

var _party: PartyMode = null
var _qr: TextureRect = null
var _qr_url: String = ""
var _url_label: Label = null
var _server_error: Label = null
var _status: Label = null
var _start: UIButton = null
var _add_keys: UIButton = null
var _add_bot: UIButton = null
var _cards: Array[Dictionary] = []
var _refresh_left: float = 0.0
## The whole layout; scaled down uniformly when it needs more room than the screen has.
var _content: MarginContainer = null
var _embedded_note: Label = null


func build() -> void:
	var ui: UITheme = UITheme.current()
	add_child(UIKit.backdrop())
	_content = UIKit.margin(UIKit.vbox(18), 56, 36)
	add_child(_content)
	resized.connect(_fit)
	_content.minimum_size_changed.connect(_fit.call_deferred)
	var column: VBoxContainer = _content.get_child(0) as VBoxContainer
	column.add_child(_top_bar(ui))
	var body: HBoxContainer = UIKit.hbox(40)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_join_panel(ui))
	var cards: HBoxContainer = UIKit.hbox(24)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(cards)
	_cards.clear()
	for slot in range(PartyRoster.MAX_PLAYERS):
		cards.add_child(_card(ui, slot))
	column.add_child(_bottom_bar(ui))
	var help: Label = UIKit.label(tr_key(&"party.lobby.keys_hint"), 24, ui.text_dim)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(400.0, 0.0)
	column.add_child(help)


func on_enter(_args: Dictionary) -> void:
	_party = Services.locate(&"party") as PartyMode
	if _party != null and _embedded_note != null:
		_embedded_note.visible = _party.embedded
	if _party != null and not _party.changed.is_connected(_refresh):
		_party.changed.connect(_refresh)
	_qr_url = ""
	_refresh()


## Lays the content out at the screen size, or larger and scaled down when its minimum size does
## not fit (narrow or short windows, long translations).
func _fit() -> void:
	if _content == null:
		return
	var need: Vector2 = _content.get_combined_minimum_size()
	var k: float = minf(1.0, minf(size.x / maxf(need.x, 1.0), size.y / maxf(need.y, 1.0)))
	_content.scale = Vector2(k, k)
	_content.position = Vector2.ZERO
	_content.size = size / k


func on_exit() -> void:
	if _party != null and _party.changed.is_connected(_refresh):
		_party.changed.disconnect(_refresh)


func handle_back() -> bool:
	if _party != null:
		_party.close()
	return true


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if visible and key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F1:
		SceneRouter.push(&"party_help")
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or _party == null:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.25
		_update_status()
		_update_qr()


# --- building --------------------------------------------------------------------------------

func _top_bar(ui: UITheme) -> Control:
	var bar: HBoxContainer = UIKit.hbox(24)
	var back: UIButton = UIKit.back_button()
	back.pressed.connect(func() -> void: handle_back())
	bar.add_child(back)
	var titles: VBoxContainer = UIKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.label(tr_key(&"party.title"), ui.size_h1, ui.accent))
	titles.add_child(UIKit.label(tr_key(&"party.subtitle"), ui.size_small, ui.text_dim))
	_embedded_note = UIKit.label(tr_key(&"party.embedded_hint"), 24, ui.danger)
	_embedded_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_embedded_note.custom_minimum_size = Vector2(600.0, 0.0)
	_embedded_note.visible = false
	titles.add_child(_embedded_note)
	bar.add_child(titles)
	var help: UIButton = UIKit.button(tr_key(&"party.help.button"), &"secondary", 300.0)
	help.pressed.connect(func() -> void: SceneRouter.push(&"party_help"))
	bar.add_child(help)
	return bar


func _join_panel(ui: UITheme) -> Control:
	var panel: PanelContainer = UIKit.panel(false, ui.accent)
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	var box: VBoxContainer = UIKit.vbox(14)
	panel.add_child(UIKit.margin(box, 30, 24))
	box.add_child(UIKit.label(tr_key(&"party.join.title"), ui.size_h2, ui.accent))
	for key: StringName in [&"party.join.step1", &"party.join.step2", &"party.join.step3"]:
		var step: Label = UIKit.label(tr_key(key), 26, ui.text, HORIZONTAL_ALIGNMENT_LEFT)
		step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step.custom_minimum_size = Vector2(450.0, 0.0)
		box.add_child(step)
	var holder: CenterContainer = CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(holder)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override(&"panel", UIKit.box(Color.WHITE, 18, ui.outline, 6, 10.0))
	holder.add_child(frame)
	var stack: VBoxContainer = UIKit.vbox(0)
	frame.add_child(stack)
	_qr = TextureRect.new()
	_qr.custom_minimum_size = Vector2(QR_SIZE, QR_SIZE)
	_qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stack.add_child(_qr)
	_server_error = UIKit.label(tr_key(&"party.server_error"), 26, ui.danger)
	_server_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_server_error.custom_minimum_size = Vector2(QR_SIZE, 0.0)
	_server_error.visible = false
	stack.add_child(_server_error)
	box.add_child(UIKit.label(tr_key(&"party.join.scan"), 24, ui.text_dim))
	_url_label = UIKit.label("", 40, ui.accent)
	_url_label.add_theme_font_override(&"font", UIKit.heading_font())
	box.add_child(_url_label)
	return panel


## A player card: colour band, name, 3D runner, runner name, status, and (keyboard / bot) controls.
func _card(ui: UITheme, slot: int) -> Control:
	var color: Color = PartyRoster.SLOT_COLORS[slot]
	var panel: PanelContainer = UIKit.panel(false, color)
	panel.custom_minimum_size = CARD_SIZE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = UIKit.vbox(8)
	panel.add_child(UIKit.margin(box, 18, 18))
	var badge: Label = UIKit.label("P%d" % (slot + 1), ui.size_body, color)
	box.add_child(badge)
	var name_label: Label = UIKit.label("", ui.size_h2, ui.text)
	box.add_child(name_label)
	var kind_label: Label = UIKit.label("", 24, ui.text_dim)
	box.add_child(kind_label)
	var preview: RunnerPreview = RunnerPreview.new()
	preview.custom_minimum_size = Vector2(0.0, 300.0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(preview)
	var empty: Label = UIKit.label(tr_key(&"party.card.empty"), 30, ui.text_dim)
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty.custom_minimum_size = Vector2(CARD_SIZE.x - 50.0, 0.0)
	box.add_child(empty)
	var runner_row: HBoxContainer = UIKit.hbox(10)
	runner_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev: UIButton = UIKit.button("<", &"ghost", 80.0)
	prev.custom_minimum_size = Vector2(80.0, 80.0)
	prev.pressed.connect(func() -> void: _cycle(slot, -1))
	runner_row.add_child(prev)
	var runner_label: Label = UIKit.label("", 30, ui.accent)
	runner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	runner_row.add_child(runner_label)
	var next: UIButton = UIKit.button(">", &"ghost", 80.0)
	next.custom_minimum_size = Vector2(80.0, 80.0)
	next.pressed.connect(func() -> void: _cycle(slot, 1))
	runner_row.add_child(next)
	box.add_child(runner_row)
	var status: Label = UIKit.label("", 30, ui.text)
	box.add_child(status)
	var actions: HBoxContainer = UIKit.hbox(10)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var ready: UIButton = UIKit.button(tr_key(&"party.card.ready"), &"accent", 180.0)
	ready.pressed.connect(func() -> void:
		var m: PartyRoster.Member = _party.roster.at(slot) if _party != null else null
		if m != null:
			_party.roster.set_ready(slot, not m.ready))
	actions.add_child(ready)
	var remove: UIButton = UIKit.button("X", &"danger", 96.0)
	remove.tooltip_text = tr_key(&"party.card.remove")
	remove.pressed.connect(func() -> void:
		if _party != null:
			_party.remove_member(slot))
	actions.add_child(remove)
	box.add_child(actions)
	_cards.append({"panel": panel, "name": name_label, "kind": kind_label, "preview": preview,
			"empty": empty, "runner_row": runner_row, "runner": runner_label, "prev": prev, "next": next,
			"status": status, "ready": ready, "remove": remove, "character": &""})
	return panel


func _bottom_bar(ui: UITheme) -> Control:
	var bar: HBoxContainer = UIKit.hbox(24)
	_status = UIKit.label("", ui.size_body, ui.text, HORIZONTAL_ALIGNMENT_LEFT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_status)
	_add_keys = UIKit.button(tr_key(&"party.add_keyboard"), &"secondary", 330.0)
	_add_keys.pressed.connect(func() -> void:
		if _party != null:
			_party.add_keyboard_player())
	bar.add_child(_add_keys)
	_add_bot = UIKit.button(tr_key(&"party.add_bot"), &"secondary", 260.0)
	_add_bot.pressed.connect(func() -> void:
		if _party != null:
			_party.add_bot())
	bar.add_child(_add_bot)
	_start = UIKit.button(tr_key(&"party.start"), &"primary", 340.0)
	_start.feedback = &"confirm"
	_start.pressed.connect(func() -> void:
		if _party != null:
			_party.start_round())
	bar.add_child(_start)
	return bar


# --- refresh ---------------------------------------------------------------------------------

func _cycle(slot: int, direction: int) -> void:
	if _party != null:
		_party.roster.cycle_character(slot, direction)


func _refresh() -> void:
	if _party == null or _cards.is_empty():
		return
	var ui: UITheme = UITheme.current()
	for slot in range(_cards.size()):
		var card: Dictionary = _cards[slot]
		var m: PartyRoster.Member = _party.roster.at(slot)
		var has: bool = m != null
		(card["panel"] as Control).modulate.a = 1.0 if has else 0.6
		(card["preview"] as Control).visible = has
		(card["empty"] as Control).visible = not has
		(card["runner_row"] as Control).visible = has
		(card["status"] as Control).visible = has
		(card["kind"] as Control).visible = has
		var name_label: Label = card["name"] as Label
		name_label.text = m.name if has else "---"
		UIKit.fit_label(name_label, CARD_SIZE.x - 50.0)
		if not has:
			(card["ready"] as Control).visible = false
			(card["remove"] as Control).visible = false
			continue
		var local: bool = m.kind != PartyRoster.Kind.PHONE
		(card["prev"] as Control).visible = local
		(card["next"] as Control).visible = local
		(card["ready"] as Control).visible = m.kind == PartyRoster.Kind.KEYBOARD
		(card["remove"] as Control).visible = true
		var kind_text: String = tr_key(&"party.kind.phone")
		if m.kind == PartyRoster.Kind.KEYBOARD:
			kind_text = tr_key(&"party.kind.wasd" if m.keys == 0 else &"party.kind.arrows")
		elif m.kind == PartyRoster.Kind.BOT:
			kind_text = tr_key(&"party.kind.bot")
		(card["kind"] as Label).text = kind_text
		var def: CharacterDef = ContentDB.character(m.character)
		if def != null:
			(card["runner"] as Label).text = Tr.t(def.name_key)
			if card["character"] != m.character:
				card["character"] = m.character
				(card["preview"] as RunnerPreview).show_character(def)
		var status: Label = card["status"] as Label
		if not m.connected():
			status.text = tr_key(&"party.card.lost")
			status.add_theme_color_override(&"font_color", ui.danger)
		elif m.ready:
			status.text = tr_key(&"party.card.is_ready")
			status.add_theme_color_override(&"font_color", ui.success)
		else:
			status.text = tr_key(&"party.card.not_ready")
			status.add_theme_color_override(&"font_color", ui.text_dim)
		var ready: UIButton = card["ready"] as UIButton
		ready.text = tr_key(&"party.card.unready" if m.ready else &"party.card.ready")
	var count: int = _party.roster.count()
	_start.disabled = count == 0
	_add_keys.disabled = _party.roster.is_full() or (_party.roster.by_keys(0) != null and _party.roster.by_keys(1) != null)
	_add_bot.disabled = _party.roster.is_full()
	_update_status()
	_update_qr()


func _update_status() -> void:
	if _party == null or _status == null:
		return
	var count: int = _party.roster.count()
	var ready: int = 0
	for m: PartyRoster.Member in _party.roster.list():
		if m.ready and m.connected():
			ready += 1
	if count == 0:
		_status.text = tr_key(&"party.status.waiting")
	elif _party.auto_start_left > 0.0:
		_status.text = Tr.f(&"party.status.starting", {"n": ceili(_party.auto_start_left)})
	else:
		_status.text = Tr.f(&"party.status.ready_count", {"ready": ready, "total": count})


func _update_qr() -> void:
	if _party == null or _qr == null:
		return
	var ok: bool = _party.hub.server.is_listening()
	_qr.visible = ok
	_server_error.visible = not ok
	if not ok:
		_url_label.text = ""
		return
	var url: String = _party.main_url()
	if url == _qr_url:
		return
	_qr_url = url
	_url_label.text = url.trim_prefix("http://")
	var code: QrCode = QrCode.encode(url)
	if code != null:
		_qr.texture = ImageTexture.create_from_image(code.to_image(8, 3))

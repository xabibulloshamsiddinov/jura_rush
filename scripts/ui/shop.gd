## Shop: runners, trails, power-up upgrades and consumables.
## Layout: top bar (back, title, coins) / 3D preview (~35 %, RunnerPreview SubViewport) / tabs /
## kinetic-scrolling list filling the rest. Tapping a row previews it; buying asks for
## confirmation first. Purchases go through PurchaseCommand (validation + rollback on a failed
## save) and every change is saved immediately.
##
## Button states: equipped = green badge with a check (not pressable); owned = cyan EQUIP;
## affordable = yellow coin price, gently pulsing; not affordable = dimmed with a red price
## (tapping it explains why).
extends UIScreen

const TABS: Array[StringName] = [&"shop.tab.characters", &"shop.tab.trails", &"shop.tab.upgrades", &"shop.tab.items"]
const ACTION_WIDTH: float = 300.0
const PREVIEW_RATIO: float = 1.0
const LIST_RATIO: float = 1.85
const ITEM_BADGES: Dictionary = {&"headstart": ">>", &"booster": "+5"}

var _tab: int = 0
var _tab_buttons: Array[UIButton] = []
var _list: VBoxContainer = null
var _scroll: KineticScroll = null
var _coins: CoinCounter = null
var _preview: RunnerPreview = null
var _preview_name: Label = null
var _preview_info: Label = null
var _toast: Label = null
var _confirm: Control = null
var _confirm_text: Label = null
var _confirm_buy: UIButton = null
var _pending: Dictionary = {}
var _selected: Dictionary = {}   # tab index -> selected id


func build() -> void:
	var ui: UITheme = UITheme.current()
	# Opaque backdrop: the shop owns the screen (the preview has its own 3D view).
	var back_fill: ColorRect = ColorRect.new()
	back_fill.color = Color(ui.background, 0.97)
	back_fill.mouse_filter = Control.MOUSE_FILTER_STOP
	UIKit.fill(back_fill)
	add_child(back_fill)
	var column: VBoxContainer = UIKit.vbox(16)
	var wrap: MarginContainer = UIKit.margin(column, 36, 50)
	UIKit.fill(wrap)
	add_child(wrap)

	var top: HBoxContainer = UIKit.hbox(20)
	column.add_child(top)
	var back: UIButton = UIKit.button("<", &"ghost", 120.0)
	back.feedback = &"back"
	back.pressed.connect(func() -> void: SceneRouter.back())
	top.add_child(back)
	var title: Label = UIKit.label(tr_key(&"shop.title"), ui.size_h1, ui.magenta)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_coins = CoinCounter.new(ui.size_h2, ui.yellow, HORIZONTAL_ALIGNMENT_RIGHT)
	_coins.custom_minimum_size = Vector2(220.0, 0.0)
	top.add_child(_coins)

	# Preview area (~35 % of the height).
	var stage: PanelContainer = UIKit.panel(false, Color(ui.cyan, 0.35))
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = PREVIEW_RATIO
	column.add_child(stage)
	var stage_box: VBoxContainer = UIKit.vbox(0)
	stage.add_child(stage_box)
	_preview = RunnerPreview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_box.add_child(_preview)
	_preview_name = UIKit.label("", ui.size_h2, ui.text)
	stage_box.add_child(_preview_name)
	_preview_info = UIKit.label("", ui.size_small, ui.text_dim)
	stage_box.add_child(_preview_info)

	var tabs: HBoxContainer = UIKit.hbox(10)
	column.add_child(tabs)
	_tab_buttons.clear()
	for i in range(TABS.size()):
		var b: UIButton = UIKit.button(tr_key(TABS[i]), &"ghost")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", UIKit.scaled(ui.size_small))
		b.pressed.connect(_select_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)

	var panel: PanelContainer = UIKit.panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = LIST_RATIO
	column.add_child(panel)
	_scroll = KineticScroll.new()
	panel.add_child(_scroll)
	# Inner padding: the first and last rows (and their borders) are never clipped.
	var pad: MarginContainer = UIKit.margin(UIKit.vbox(0), 6, 14)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pad)
	_list = pad.get_child(0) as VBoxContainer
	_list.add_theme_constant_override(&"separation", 14)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_toast = UIKit.label("", ui.size_h2, ui.success)
	_toast.add_theme_constant_override(&"outline_size", 12)
	_toast.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 420.0
	_toast.modulate.a = 0.0
	add_child(_toast)
	_build_confirm()


func connect_events() -> void:
	GameEvents.wallet_changed.connect(func(_c: int, _k: int) -> void:
		if visible:
			_refresh_wallet())


func on_enter(p_args: Dictionary) -> void:
	_tab = clampi(int(p_args.get("tab", _tab)), 0, TABS.size() - 1)
	_confirm.visible = false
	_refresh()


func handle_back() -> bool:
	if _confirm.visible:
		_close_confirm()
		return true
	return false


func _select_tab(index: int) -> void:
	_tab = index
	_scroll.scroll_vertical = 0
	_refresh()


func _refresh_wallet() -> void:
	_coins.set_amount(SaveSystem.coins())


func _refresh() -> void:
	_refresh_wallet()
	for i in range(_tab_buttons.size()):
		var active: bool = i == _tab
		_tab_buttons[i].theme_type_variation = UITheme.button_variation(&"primary" if active else &"ghost")
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _tab:
		0:
			for def in ContentDB.CHARACTERS:
				_runner_row(def)
		1:
			for def in ContentDB.TRAILS:
				_trail_row(def)
		2:
			for def in ContentDB.POWERUPS:
				_upgrade_row(def)
		3:
			for entry in ShopCatalog.CONSUMABLES:
				_item_row(entry)
	_update_preview()


# --- rows ---------------------------------------------------------------------------------------

func _runner_row(def: CharacterDef) -> void:
	var stats: String = Tr.f(&"shop.char.stats", {"a": tr_key(StringName("shop.acc." + String(def.accessory))),
			"b": tr_key(_build_key(def.bulk))})
	var action: Control = _item_action(&"character", def.id, tr_key(def.name_key), def.price)
	_row(def.id, ItemThumb.runner(def), tr_key(def.name_key), stats, def.glow_color, action)


func _trail_row(def: TrailDef) -> void:
	var stats: String = Tr.f(&"shop.trail.stats", {"w": "%.1f" % def.width, "l": def.length})
	var action: Control = _item_action(&"trail", def.id, tr_key(def.name_key), def.price)
	_row(def.id, ItemThumb.trail(def.color), tr_key(def.name_key), stats, def.color, action)


func _upgrade_row(def: PowerupDef) -> void:
	var level: int = SaveSystem.upgrade_level(def.id)
	var subtitle: String = Tr.f(&"shop.level", {"n": level, "s": "%.1f" % def.duration_for_level(level)})
	var cost: int = def.cost_for_next(level)
	var action: Control = _badge(tr_key(&"shop.max"), UITheme.current().text_dim, false) if cost < 0 \
			else _price_action(&"upgrade", def.id, tr_key(def.name_key), cost)
	_row(def.id, ItemThumb.badge(def.color, def.icon), tr_key(def.name_key), subtitle, def.color, action)


func _item_row(entry: Dictionary) -> void:
	var id: StringName = entry["id"]
	var subtitle: String = "%s\n%s" % [tr_key(entry["desc_key"]),
			Tr.f(&"shop.owned", {"n": SaveSystem.consumable_count(id)})]
	var ui: UITheme = UITheme.current()
	_row(id, ItemThumb.badge(ui.yellow, str(ITEM_BADGES.get(id, "+"))), tr_key(entry["name_key"]), subtitle,
			ui.yellow, _price_action(&"consumable", id, tr_key(entry["name_key"]), int(entry["price"])))


## Equipped badge / Equip button / price button for a runner or trail.
func _item_action(slot: StringName, id: StringName, title: String, price: int) -> Control:
	if SaveSystem.equipped(slot) == id:
		return _badge(tr_key(&"shop.equipped"), UITheme.current().success, true)
	if SaveSystem.owns(id):
		var equip: UIButton = UIKit.button(tr_key(&"shop.equip"), &"primary", ACTION_WIDTH)
		equip.mouse_filter = Control.MOUSE_FILTER_PASS
		equip.pressed.connect(func() -> void:
			_selected[_tab] = id
			SaveSystem.equip(slot, id)
			SaveSystem.save_game()
			GameEvents.item_purchased.emit(id)
			_refresh())
		return equip
	return _price_action(&"item", id, title, price)


## Yellow pulsing price (affordable) or dimmed red price (not affordable).
func _price_action(kind: StringName, id: StringName, title: String, price: int) -> Control:
	var ui: UITheme = UITheme.current()
	var affordable: bool = SaveSystem.coins() >= price
	var b: UIButton = UIKit.button("", &"accent" if affordable else &"ghost", ACTION_WIDTH)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var content: HBoxContainer = UIKit.hbox(10)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fill(content)
	var icon: CoinIcon = CoinIcon.new(float(UIKit.scaled(ui.size_body)))
	icon.dimmed = not affordable
	content.add_child(icon)
	content.add_child(UIKit.label(MathUtils.group_digits(price), ui.size_body,
			Color.WHITE if affordable else ui.danger, HORIZONTAL_ALIGNMENT_LEFT))
	b.add_child(content)
	if affordable:
		b.ready.connect(func() -> void: UITween.pulse(b, 1.04, 1.6), CONNECT_ONE_SHOT)
		b.pressed.connect(func() -> void:
			_selected[_tab] = id
			_update_preview()
			_ask_confirm(kind, id, title, price))
	else:
		b.modulate = Color(1, 1, 1, 0.75)
		b.pressed.connect(func() -> void:
			_selected[_tab] = id
			_update_preview()
			GameEvents.ui_feedback.emit(&"error")
			_show_toast(Tr.f(&"shop.funds", {"n": MathUtils.group_digits(price - SaveSystem.coins())}),
					ui.danger))
	return b


## Non-pressable state badge (equipped with a check mark, or MAX).
func _badge(text: String, color: Color, check: bool) -> Control:
	var ui: UITheme = UITheme.current()
	var badge: PanelContainer = PanelContainer.new()
	badge.custom_minimum_size = Vector2(ACTION_WIDTH, float(ui.button_height))
	var style: StyleBoxFlat = UIKit.box(Color(color, 0.12), -1, color, 3)
	badge.add_theme_stylebox_override(&"panel", style)
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = UIKit.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_child(row)
	if check:
		var mark: Control = Control.new()
		mark.custom_minimum_size = Vector2(36.0, 36.0)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.draw.connect(func() -> void:
			var s: Vector2 = mark.size
			mark.draw_polyline(PackedVector2Array([Vector2(s.x * 0.12, s.y * 0.55), Vector2(s.x * 0.42, s.y * 0.85),
					Vector2(s.x * 0.9, s.y * 0.18)]), color, 5.0, true))
		row.add_child(mark)
	row.add_child(UIKit.label(text, ui.size_body, color, HORIZONTAL_ALIGNMENT_LEFT))
	return badge


func _row(id: StringName, thumb: Control, title: String, subtitle: String, color: Color, action: Control) -> void:
	var ui: UITheme = UITheme.current()
	var selected: bool = _selected_id() == id
	var card: PanelContainer = UIKit.panel(true, Color(color, 0.95 if selected else 0.45))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	# Tap a row to preview it (a drag that scrolled the list is not a tap).
	card.gui_input.connect(func(event: InputEvent) -> void:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			card.set_meta(&"press_scroll", float(_scroll.scroll_vertical))
		elif absf(float(_scroll.scroll_vertical) - float(card.get_meta(&"press_scroll", 0.0))) < 8.0:
			_selected[_tab] = id
			_refresh())
	var row: HBoxContainer = UIKit.hbox(18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(thumb)
	var texts: VBoxContainer = UIKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(UIKit.label(title, ui.size_body, ui.text, HORIZONTAL_ALIGNMENT_LEFT))
	if not subtitle.is_empty():
		var sub: Label = UIKit.label(subtitle, ui.size_small, ui.text_dim, HORIZONTAL_ALIGNMENT_LEFT)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(sub)
	row.add_child(texts)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	card.set_meta(&"id", id)
	_list.add_child(card)


# --- preview ------------------------------------------------------------------------------------

func _selected_id() -> StringName:
	if _selected.has(_tab):
		return _selected[_tab]
	match _tab:
		0:
			return SaveSystem.equipped(&"character")
		1:
			return SaveSystem.equipped(&"trail")
		2:
			return ContentDB.POWERUPS[0].id if not ContentDB.POWERUPS.is_empty() else &""
		_:
			return ShopCatalog.CONSUMABLES[0]["id"]


func _update_preview() -> void:
	var id: StringName = _selected_id()
	match _tab:
		0:
			var c: CharacterDef = ContentDB.character(id)
			_preview.show_character(c)
			_preview_name.text = tr_key(c.name_key) if c != null else ""
			_preview_info.text = ""
		1:
			var t: TrailDef = ContentDB.trail(id)
			_preview.show_trail(t)
			_preview_name.text = tr_key(t.name_key) if t != null else ""
			_preview_info.text = ""
		2:
			var p: PowerupDef = ContentDB.powerup(id)
			if p != null:
				_preview.show_orb(p.color)
				_preview_name.text = tr_key(p.name_key)
				_preview_info.text = tr_key(StringName("shop.desc." + String(p.id)))
		3:
			for entry in ShopCatalog.CONSUMABLES:
				if entry["id"] == id:
					_preview.show_orb(UITheme.current().yellow)
					_preview_name.text = tr_key(entry["name_key"])
					_preview_info.text = tr_key(entry["desc_key"])


# --- confirm popup ------------------------------------------------------------------------------

func _build_confirm() -> void:
	var ui: UITheme = UITheme.current()
	_confirm = Control.new()
	UIKit.fill(_confirm)
	_confirm.visible = false
	add_child(_confirm)
	var dim: ColorRect = UIKit.dimmer(0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	UIKit.fill(center)
	_confirm.add_child(center)
	var panel: PanelContainer = UIKit.panel(true, ui.yellow)
	panel.custom_minimum_size = Vector2(820.0, 0.0)
	center.add_child(panel)
	var box: VBoxContainer = UIKit.vbox(30)
	panel.add_child(UIKit.margin(box, 30, 30))
	_confirm_text = UIKit.label("", ui.size_h2, ui.text)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirm_text)
	var buttons: HBoxContainer = UIKit.hbox(24)
	box.add_child(buttons)
	var cancel: UIButton = UIKit.button(tr_key(&"shop.cancel"), &"ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.feedback = &"back"
	cancel.pressed.connect(_close_confirm)
	buttons.add_child(cancel)
	_confirm_buy = UIKit.button(tr_key(&"shop.buy"), &"accent")
	_confirm_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_buy.feedback = &"confirm"
	_confirm_buy.pressed.connect(_buy_pending)
	buttons.add_child(_confirm_buy)


func _ask_confirm(kind: StringName, id: StringName, title: String, price: int) -> void:
	_pending = {"kind": kind, "id": id, "title": title}
	_confirm_text.text = Tr.f(&"shop.confirm", {"name": title, "n": MathUtils.group_digits(price)})
	_confirm.visible = true
	_confirm.modulate.a = 0.0
	UITween.fade(_confirm, 1.0, 0.2)
	UITween.bump(_confirm_buy, 1.06)


func _close_confirm() -> void:
	_confirm.visible = false
	_pending = {}


func _buy_pending() -> void:
	if _pending.is_empty():
		return
	var kind: StringName = _pending["kind"]
	var id: StringName = _pending["id"]
	var title: String = _pending["title"]
	_close_confirm()
	var command: PurchaseCommand = PurchaseCommand.new(kind, id)
	if command.execute(SaveSystem):    # saves and emits item_purchased (purchase sound)
		var slot: StringName = ShopCatalog.slot_of(id)
		if slot != &"":
			SaveSystem.equip(slot, id)
			SaveSystem.save_game()
		_selected[_tab] = id
		_refresh()
		_show_toast(Tr.f(&"shop.bought", {"name": title}), UITheme.current().success)
		UITween.bump(_preview_name, 1.3)
		GameEvents.ui_feedback.emit(&"confirm")
	else:
		GameEvents.ui_feedback.emit(&"error")
		_show_toast(tr_key(&"shop.failed"), UITheme.current().danger)


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override(&"font_color", color)
	_toast.size = Vector2(size.x, _toast.size.y)
	_toast.position.x = 0.0
	_toast.pivot_offset = _toast.size * 0.5
	var tween: Tween = _toast.create_tween()
	_toast.modulate.a = 1.0
	_toast.scale = Vector2(0.6, 0.6)
	tween.tween_property(_toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.1)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.35)


func _build_key(bulk: float) -> StringName:
	if bulk < 0.95:
		return &"shop.build.slim"
	if bulk > 1.08:
		return &"shop.build.bulky"
	return &"shop.build.normal"

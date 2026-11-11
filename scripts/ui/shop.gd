## Shop: runners, trails, power-up upgrades and consumables. The upper part of the screen is
## left open so the live 3D runner previews skins and trails. Purchases go through
## PurchaseCommand (validation + rollback on a failed save).
extends UIScreen

const TABS: Array[StringName] = [&"shop.tab.characters", &"shop.tab.trails", &"shop.tab.upgrades", &"shop.tab.items"]

var _tab: int = 0
var _tab_buttons: Array[UIButton] = []
var _list: VBoxContainer = null
var _coins: Label = null


func build() -> void:
	var ui: UITheme = UITheme.current()
	var column: VBoxContainer = UIKit.vbox(18)
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
	_coins = UIKit.label("", ui.size_h2, ui.yellow, HORIZONTAL_ALIGNMENT_RIGHT)
	_coins.custom_minimum_size = Vector2(220.0, 0.0)
	top.add_child(_coins)
	# Preview window: the 3D runner shows through here.
	column.add_child(UIKit.spacer(560.0))
	var tabs: HBoxContainer = UIKit.hbox(10)
	column.add_child(tabs)
	_tab_buttons.clear()
	for i in range(TABS.size()):
		var b: UIButton = UIKit.button(tr_key(TABS[i]), &"primary")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override(&"font_size", UIKit.scaled(ui.size_small))
		b.pressed.connect(_select_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var panel: PanelContainer = UIKit.panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 3.0
	column.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_list = UIKit.vbox(14)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func connect_events() -> void:
	GameEvents.wallet_changed.connect(func(_c: int, _k: int) -> void:
		if visible:
			_refresh_wallet())


func on_enter(p_args: Dictionary) -> void:
	_tab = clampi(int(p_args.get("tab", _tab)), 0, TABS.size() - 1)
	_refresh()


func _select_tab(index: int) -> void:
	_tab = index
	_refresh()


func _refresh_wallet() -> void:
	_coins.text = "o " + MathUtils.group_digits(SaveSystem.coins())


func _refresh() -> void:
	_refresh_wallet()
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].modulate = Color.WHITE if i == _tab else Color(0.6, 0.6, 0.7)
	for child in _list.get_children():
		child.queue_free()
	match _tab:
		0:
			for def in ContentDB.CHARACTERS:
				_item_card(def.id, tr_key(def.name_key), def.price, def.body_color, &"character")
		1:
			for def in ContentDB.TRAILS:
				_item_card(def.id, tr_key(def.name_key), def.price, def.color, &"trail")
		2:
			for def in ContentDB.POWERUPS:
				_upgrade_card(def)
		3:
			for entry in ShopCatalog.CONSUMABLES:
				_consumable_card(entry)


func _item_card(id: StringName, title: String, price: int, color: Color, slot: StringName) -> void:
	var owned: bool = SaveSystem.owns(id)
	var equipped: bool = SaveSystem.equipped(slot) == id
	var action: UIButton = null
	if equipped:
		action = UIKit.button(tr_key(&"shop.equipped"), &"ghost", 300.0)
		action.disabled = true
	elif owned:
		action = UIKit.button(tr_key(&"shop.equip"), &"primary", 300.0)
		action.pressed.connect(func() -> void:
			SaveSystem.equip(slot, id)
			GameEvents.item_purchased.emit(id)
			_refresh())
	else:
		action = _buy_button(&"item", id, price)
	_card(title, "", color, action)


func _upgrade_card(def: PowerupDef) -> void:
	var level: int = SaveSystem.upgrade_level(def.id)
	var subtitle: String = Tr.f(&"shop.level", {"n": level, "s": "%.1f" % def.duration_for_level(level)})
	var cost: int = def.cost_for_next(level)
	var action: UIButton = null
	if cost < 0:
		action = UIKit.button(tr_key(&"shop.max"), &"ghost", 300.0)
		action.disabled = true
	else:
		action = _buy_button(&"upgrade", def.id, cost)
	_card("%s  %s" % [def.icon, tr_key(def.name_key)], subtitle, def.color, action)


func _consumable_card(entry: Dictionary) -> void:
	var id: StringName = entry["id"]
	var subtitle: String = "%s\n%s" % [tr_key(entry["desc_key"]),
			Tr.f(&"shop.owned", {"n": SaveSystem.consumable_count(id)})]
	_card(tr_key(entry["name_key"]), subtitle, UITheme.current().yellow,
			_buy_button(&"consumable", id, int(entry["price"])))


func _buy_button(kind: StringName, id: StringName, price: int) -> UIButton:
	var b: UIButton = UIKit.button("o %s" % MathUtils.group_digits(price), &"gold", 300.0)
	b.disabled = SaveSystem.coins() < price
	b.feedback = &"click"
	b.pressed.connect(func() -> void:
		var command: PurchaseCommand = PurchaseCommand.new(kind, id)
		if command.execute(SaveSystem):
			var slot: StringName = ShopCatalog.slot_of(id)
			if slot != &"":
				SaveSystem.equip(slot, id)
				GameEvents.item_purchased.emit(id)
			_refresh()
		else:
			GameEvents.ui_feedback.emit(&"error"))
	return b


func _card(title: String, subtitle: String, color: Color, action: UIButton) -> void:
	var ui: UITheme = UITheme.current()
	var card: PanelContainer = UIKit.panel(true, Color(color, 0.7))
	var row: HBoxContainer = UIKit.hbox(20)
	card.add_child(row)
	var swatch: ColorRect = ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(26.0, 90.0)
	row.add_child(swatch)
	var texts: VBoxContainer = UIKit.vbox(4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UIKit.label(title, ui.size_body, ui.text, HORIZONTAL_ALIGNMENT_LEFT))
	if not subtitle.is_empty():
		var sub: Label = UIKit.label(subtitle, ui.size_small, ui.text_dim, HORIZONTAL_ALIGNMENT_LEFT)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(sub)
	row.add_child(texts)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	_list.add_child(card)

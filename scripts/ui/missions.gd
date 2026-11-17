## Missions and achievements with progress bars. Rewards are granted automatically when a goal
## completes; finished rows play a claim animation (pop + shine) when the list opens.
extends UIScreen

var _tab: int = 0
var _tab_buttons: Array[UIButton] = []
var _list: VBoxContainer = null
var _header: Label = null


func build() -> void:
	var ui: UITheme = UITheme.current()
	add_child(UIKit.dimmer(0.82))
	var column: VBoxContainer = UIKit.vbox(16)
	var wrap: MarginContainer = UIKit.margin(column, 44, 50)
	UIKit.fill(wrap)
	add_child(wrap)
	var top: HBoxContainer = UIKit.hbox(20)
	column.add_child(top)
	var back: UIButton = UIKit.back_button()
	back.pressed.connect(func() -> void: SceneRouter.back())
	top.add_child(back)
	var title: Label = UIKit.label(tr_key(&"missions.title"), ui.size_h1, ui.accent)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var balance: Control = Control.new()
	balance.custom_minimum_size = Vector2(120.0, 0.0)
	top.add_child(balance)
	var tabs: HBoxContainer = UIKit.hbox(12)
	column.add_child(tabs)
	_tab_buttons.clear()
	var keys: Array[StringName] = [&"missions.tab.missions", &"missions.tab.achievements"]
	for i in range(keys.size()):
		var b: UIButton = UIKit.button(tr_key(keys[i]), &"primary")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	_header = UIKit.label("", ui.size_small, ui.text_dim)
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_header)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = UIKit.vbox(14)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func on_enter(_args: Dictionary) -> void:
	_refresh()


func _select_tab(index: int) -> void:
	_tab = index
	_refresh()


func _refresh() -> void:
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].modulate = Color.WHITE if i == _tab else Color(0.6, 0.6, 0.7)
	for child in _list.get_children():
		child.queue_free()
	var service: Object = Services.locate(&"missions")
	if service == null:
		return
	var rows: Array = service.call(&"mission_rows" if _tab == 0 else &"achievement_rows")
	_header.text = "%s\n%s" % [tr_key(&"missions.set_hint"),
			Tr.f(&"menu.multiplier", {"n": SaveSystem.account_multiplier()})] if _tab == 0 else ""
	var delay: float = 0.0
	for row: Dictionary in rows:
		_add_row(row, delay)
		delay += 0.05


func _add_row(row: Dictionary, delay: float) -> void:
	var ui: UITheme = UITheme.current()
	var def: MissionDef = row["def"]
	var done: bool = bool(row["done"])
	var card: PanelContainer = UIKit.panel(true, ui.accent if done else Color.TRANSPARENT)
	var column: VBoxContainer = UIKit.vbox(8)
	card.add_child(column)
	var head: HBoxContainer = UIKit.hbox(12)
	column.add_child(head)
	var text: Label = UIKit.label(Tr.f(def.text_key(), {"n": MathUtils.group_digits(def.target)}),
			ui.size_small, ui.text, HORIZONTAL_ALIGNMENT_LEFT)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(text)
	if done:
		head.add_child(UIKit.label(tr_key(&"missions.done"), ui.size_small, ui.accent))
	else:
		var reward: CoinCounter = CoinCounter.new(ui.size_small, ui.accent)
		reward.set_amount(def.reward_coins)
		head.add_child(reward)
	var bar: ProgressBar = UIKit.progress(0.0, float(row["target"]), ui.accent if done else ui.primary)
	column.add_child(bar)
	column.add_child(UIKit.label("%s / %s" % [MathUtils.group_digits(int(row["value"])),
			MathUtils.group_digits(int(row["target"]))], ui.size_small, ui.text_dim,
			HORIZONTAL_ALIGNMENT_RIGHT))
	_list.add_child(card)
	bar.create_tween().tween_property(bar, "value", float(row["value"]), 0.5).set_delay(delay)
	if done:
		var tween: Tween = card.create_tween()
		tween.tween_interval(delay + 0.3)
		tween.tween_callback(func() -> void: UITween.shine(card))

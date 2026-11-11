## Settings: volumes, vibration, quality preset, accessibility (shake, reduced effects,
## colour-blind palette, large text), swipe sensitivity, language, reset progress and credits.
extends UIScreen

var _reset: UIButton = null
var _reset_armed: bool = false


func build() -> void:
	var ui: UITheme = UITheme.current()
	var background: ColorRect = UIKit.dimmer(0.82)
	add_child(background)
	var column: VBoxContainer = UIKit.vbox(16)
	var wrap: MarginContainer = UIKit.margin(column, 44, 50)
	UIKit.fill(wrap)
	add_child(wrap)
	var top: HBoxContainer = UIKit.hbox(20)
	column.add_child(top)
	var back: UIButton = UIKit.button("<", &"ghost", 120.0)
	back.feedback = &"back"
	back.pressed.connect(func() -> void: SceneRouter.back())
	top.add_child(back)
	var title: Label = UIKit.label(tr_key(&"settings.title"), ui.size_h1, ui.cyan)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var balance: Control = Control.new()
	balance.custom_minimum_size = Vector2(120.0, 0.0)
	top.add_child(balance)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list: VBoxContainer = UIKit.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_slider(list, &"settings.music", "music", 0.0, 1.0)
	_slider(list, &"settings.sfx", "sfx", 0.0, 1.0)
	_slider(list, &"settings.ambience", "ambience", 0.0, 1.0)
	_slider(list, &"settings.shake", "shake", 0.0, 1.0)
	_slider(list, &"settings.sensitivity", "sensitivity", 0.5, 1.5)
	_toggle(list, &"settings.vibration", "vibration")
	_toggle(list, &"settings.reduce", "reduce_effects")
	_toggle(list, &"settings.colorblind", "colorblind")
	_toggle(list, &"settings.large_text", "large_text")
	_cycle(list, &"settings.quality", "quality", [0, 1, 2], [tr_key(&"settings.quality.0"),
			tr_key(&"settings.quality.1"), tr_key(&"settings.quality.2")])
	_cycle(list, &"settings.language", "language", Tr.LANGUAGES, Tr.LANGUAGE_NAMES)
	_reset = UIKit.button(tr_key(&"settings.reset"), &"danger")
	_reset.pressed.connect(_on_reset)
	list.add_child(_reset)
	list.add_child(UIKit.label(tr_key(&"settings.credits"), ui.size_body, ui.magenta))
	var credits: Label = UIKit.label(tr_key(&"settings.credits_text"), ui.size_small, ui.text_dim)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(credits)


func on_enter(_args: Dictionary) -> void:
	_reset_armed = false
	_reset.text = tr_key(&"settings.reset")


func _row(parent: Control, key: StringName) -> HBoxContainer:
	var ui: UITheme = UITheme.current()
	var panel: PanelContainer = UIKit.panel(true)
	var row: HBoxContainer = UIKit.hbox(20)
	panel.add_child(row)
	var name_label: Label = UIKit.label(tr_key(key), ui.size_body, ui.text, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)
	parent.add_child(panel)
	return row


func _slider(parent: Control, key: StringName, setting: String, low: float, high: float) -> void:
	var ui: UITheme = UITheme.current()
	var row: HBoxContainer = _row(parent, key)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = SettingsManager.get_float(setting)
	slider.custom_minimum_size = Vector2(420.0, 96.0)
	slider.add_theme_stylebox_override(&"slider", UIKit.box(Color(0.0, 0.0, 0.0, 0.6), 8))
	slider.add_theme_stylebox_override(&"grabber_area", UIKit.box(ui.cyan, 8))
	slider.add_theme_stylebox_override(&"grabber_area_highlight", UIKit.box(ui.cyan, 8))
	slider.value_changed.connect(func(value: float) -> void: SettingsManager.set_value(setting, value))
	slider.drag_ended.connect(func(_changed: bool) -> void: GameEvents.ui_feedback.emit(&"click"))
	row.add_child(slider)


func _toggle(parent: Control, key: StringName, setting: String) -> void:
	var row: HBoxContainer = _row(parent, key)
	var on: bool = SettingsManager.get_bool(setting)
	var b: UIButton = UIKit.button(tr_key(&"common.on" if on else &"common.off"),
			&"primary" if on else &"ghost", 200.0)
	b.pressed.connect(func() -> void:
		SettingsManager.set_value(setting, not SettingsManager.get_bool(setting))
		rebuild.call_deferred())
	row.add_child(b)


func _cycle(parent: Control, key: StringName, setting: String, values: Array, names: Array) -> void:
	var row: HBoxContainer = _row(parent, key)
	var index: int = maxi(values.find(SettingsManager.get_value(setting)), 0)
	if setting == "quality":
		index = clampi(int(SettingsManager.get_value(setting)), 0, values.size() - 1)
	var b: UIButton = UIKit.button(str(names[index]), &"accent", 320.0)
	b.pressed.connect(func() -> void:
		var next: int = (index + 1) % values.size()
		SettingsManager.set_value(setting, values[next])
		rebuild.call_deferred())
	row.add_child(b)


## Two taps are needed to wipe the profile.
func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset.text = tr_key(&"settings.reset_confirm")
		return
	SaveSystem.reset_progress()
	GameEvents.item_purchased.emit(&"volt")
	SceneRouter.back()

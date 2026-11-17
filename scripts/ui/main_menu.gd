## Main menu, drawn over the live 3D world (the camera stands in front of the caveman with the T-Rex
## lurking behind him, see CameraRig.MENU_*). Classic mobile-runner layout, everything on the edges
## so the centre column (roughly 30 % to 76 % of the height) stays free for the 3D scene:
##
##   top-left   BEST chip (trophy + score), round score-multiplier badge below it
##   top-right  egg and amber pills, round settings gear
##   under it   the logo, centred
##   left       round Missions and Daily Run buttons (with labels)    right  round Runners button
##   ~76 %      "TAP TO PLAY", big and pulsing
##   bottom     SHOP | PLAY | TRAILS in a row
##
## There is no background: a full-rect transparent control behind the buttons starts a run when
## the empty area is tapped (a drag or a swipe does not). Only the thin brown scrims at the very
## top and bottom darken the world a little so the small texts stay readable on a bright sky.
extends UIScreen

const SIDE: int = 40
const TOP: int = 48
const BOTTOM: int = 56
## Diameter of the round icon buttons of the side columns.
const ROUND: float = 128.0
const COLUMN_WIDTH: float = 200.0
const LOGO_TOP: float = 150.0
## Vertical anchors (share of the screen height).
const COLUMN_Y: float = 0.385
const TAP_Y: float = 0.76
## A tap may move this far and last this long before it counts as a drag.
const TAP_SLOP: float = 36.0
const TAP_SECONDS: float = 0.7
const SIDE_BUTTON: Vector2 = Vector2(270.0, 150.0)
const PLAY_BUTTON: Vector2 = Vector2(400.0, 190.0)

var _coins: CoinCounter = null
var _amber: Label = null
var _best: Label = null
var _multiplier: Label = null
var _play: UIButton = null
var _tap_hint: Label = null
var _daily_box: Control = null
var _daily_amount: Label = null
var _daily_egg: CoinIcon = null
var _missions_badge: Control = null
## A mission or achievement was completed since the list was last opened (session only: the
## mission system pays rewards out automatically, so there is nothing to claim).
var _missions_new: bool = false
var _pulses: Array[Tween] = []
var _press_pos: Vector2 = Vector2.ZERO
var _press_msec: int = 0
var _pressing: bool = false
var _dragged: bool = false


func build() -> void:
	var ui: UITheme = UITheme.current()
	# Empty-area tap target, behind everything else.
	var tap_area: Control = Control.new()
	UIKit.fill(tap_area)
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP
	tap_area.gui_input.connect(_on_tap_input)
	add_child(tap_area)
	add_child(_scrim())
	_build_top_left(ui)
	_build_top_right(ui)
	_build_logo()
	_build_side_columns(ui)
	_build_tap_hint(ui)
	_build_bottom_bar(ui)


func connect_events() -> void:
	GameEvents.wallet_changed.connect(func(_c: int, _k: int) -> void: _refresh())
	GameEvents.mission_completed.connect(func(_id: StringName) -> void: _flag_missions())
	GameEvents.achievement_unlocked.connect(func(_id: StringName) -> void: _flag_missions())
	GameEvents.mission_set_completed.connect(func(_multiplier: int) -> void: _flag_missions())


func on_enter(_args: Dictionary) -> void:
	_refresh()
	_start_pulses()


func on_exit() -> void:
	_stop_pulses()


func handle_back() -> bool:
	return true


# --- building --------------------------------------------------------------------------------

## Brown gradient over the top and bottom edge (no panel, no opaque fill).
func _scrim() -> TextureRect:
	var brown: Color = Color(0.12, 0.07, 0.03)
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(brown, 0.3), Color(brown, 0.0), Color(brown, 0.0), Color(brown, 0.42)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 128
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fill(rect)
	return rect


## BEST chip and the round multiplier badge below it.
func _build_top_left(ui: UITheme) -> void:
	var group: VBoxContainer = UIKit.vbox(14)
	var chip: HBoxContainer = UIKit.hbox(10)
	chip.add_child(UIIcon.new(UIIcon.Kind.TROPHY, 64.0))
	var texts: VBoxContainer = UIKit.vbox(-6)
	texts.add_child(UIKit.label(tr_key(&"menu.best_label"), 22, ui.text_dim, HORIZONTAL_ALIGNMENT_LEFT))
	_best = UIKit.label("0", 40, ui.accent, HORIZONTAL_ALIGNMENT_LEFT)
	_best.add_theme_font_override(&"font", UIKit.heading_font())
	texts.add_child(_best)
	chip.add_child(texts)
	var pill: PanelContainer = UIKit.pill(chip)
	pill.tooltip_text = tr_key(&"menu.best_label")
	group.add_child(pill)
	# Round multiplier badge: an amber medallion with "x3".
	var badge: PanelContainer = PanelContainer.new()
	badge.custom_minimum_size = Vector2(112.0, 112.0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_stylebox_override(&"panel", UITheme.button_style(ui.accent, &"normal", 56))
	_multiplier = UIKit.label("x1", 44, ui.text)
	_multiplier.add_theme_font_override(&"font", UIKit.heading_font())
	_multiplier.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badge.add_child(_multiplier)
	group.add_child(badge)
	place(group, Vector2(0.0, 0.0), Vector2(SIDE, TOP), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)


## Egg and amber pills and the settings gear, right-aligned.
func _build_top_right(ui: UITheme) -> void:
	var row: HBoxContainer = UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_END
	_coins = CoinCounter.new(40, ui.accent)
	var egg_pill: PanelContainer = UIKit.pill(_coins)
	egg_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	egg_pill.tooltip_text = tr_key(&"over.coins")
	row.add_child(egg_pill)
	var amber_box: HBoxContainer = UIKit.hbox(10)
	amber_box.add_child(KeyIcon.new(float(UIKit.scaled(40)) * 1.1))
	_amber = UIKit.label("0", 40, ui.accent, HORIZONTAL_ALIGNMENT_LEFT)
	_amber.add_theme_font_override(&"font", UIKit.heading_font())
	amber_box.add_child(_amber)
	var amber_pill: PanelContainer = UIKit.pill(amber_box)
	amber_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	amber_pill.tooltip_text = tr_key(&"menu.keys")
	row.add_child(amber_pill)
	var gear: UIButton = UIKit.round_button(UIIcon.Kind.GEAR, &"secondary", 104.0)
	gear.tooltip_text = tr_key(&"menu.settings")
	gear.pressed.connect(func() -> void: SceneRouter.push(&"settings"))
	row.add_child(gear)
	place(row, Vector2(1.0, 0.0), Vector2(-SIDE, TOP), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)


func _build_logo() -> void:
	var logo: GameLogo = GameLogo.new(GameConfig.GAME_TITLE)
	place(logo, Vector2(0.5, 0.0), Vector2(0.0, LOGO_TOP), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)


## Left: Missions and Daily Run. Right: Runners.
func _build_side_columns(ui: UITheme) -> void:
	var left: VBoxContainer = UIKit.vbox(26)
	var missions: UIButton = _round_item(left, UIIcon.Kind.SCROLL, &"secondary", &"menu.missions")
	missions.pressed.connect(func() -> void:
		_missions_new = false
		_refresh()
		SceneRouter.push(&"missions"))
	_missions_badge = _badge("!", ui.danger)
	missions.get_parent().add_child(_missions_badge)
	_missions_badge.position = Vector2(ROUND - 44.0, -6.0)
	var daily: UIButton = _round_item(left, UIIcon.Kind.GIFT, &"accent", &"menu.daily")
	daily.pressed.connect(func() -> void: GameEvents.request_play.emit(true))
	_daily_box = daily.get_parent().get_parent() as Control
	var reward_row: HBoxContainer = UIKit.hbox(6)
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_daily_amount = UIKit.label("", 28, ui.accent)
	_daily_amount.add_theme_font_override(&"font", UIKit.heading_font())
	reward_row.add_child(_daily_amount)
	_daily_egg = CoinIcon.new(float(UIKit.scaled(28)))
	reward_row.add_child(_daily_egg)
	_daily_box.add_child(reward_row)
	place(left, Vector2(0.0, COLUMN_Y), Vector2(SIDE, 0.0), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	var right: VBoxContainer = UIKit.vbox(26)
	var runners: UIButton = _round_item(right, UIIcon.Kind.HEAD, &"primary", &"menu.characters")
	runners.pressed.connect(func() -> void: SceneRouter.push(&"shop", {"tab": 0}))
	place(right, Vector2(1.0, COLUMN_Y), Vector2(-SIDE, 0.0), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)


## One column entry: a round icon button with its name under it. Returns the button; its parent is
## a holder control (so a badge can sit on its corner) and the holder's parent is the entry box.
func _round_item(parent: VBoxContainer, kind: UIIcon.Kind, style: StringName, label_key: StringName) -> UIButton:
	var entry: VBoxContainer = UIKit.vbox(6)
	entry.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(ROUND, ROUND)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button: UIButton = UIKit.round_button(kind, style, ROUND)
	UIKit.fill(button)
	holder.add_child(button)
	entry.add_child(holder)
	var caption: Label = UIKit.label(tr_key(label_key), 28, UITheme.current().text)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	UIKit.strong_outline(caption, 2)
	entry.add_child(caption)
	parent.add_child(entry)
	return button


## Small round notification dot with a glyph ("!").
func _badge(glyph: String, color: Color) -> Control:
	var node: Control = Control.new()
	node.custom_minimum_size = Vector2(44.0, 44.0)
	node.size = Vector2(44.0, 44.0)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline: Color = UITheme.current().outline
	var font: Font = UIKit.heading_font()
	node.draw.connect(func() -> void:
		node.draw_circle(Vector2(22.0, 22.0), 22.0, outline, true, -1.0, true)
		node.draw_circle(Vector2(22.0, 22.0), 17.0, color, true, -1.0, true)
		var width: float = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		node.draw_string(font, Vector2(22.0 - width * 0.5, 32.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE))
	return node


func _build_tap_hint(ui: UITheme) -> void:
	_tap_hint = UIKit.label(tr_key(&"menu.tap_to_play"), 64, ui.text)
	UIKit.strong_outline(_tap_hint, 3)
	# Airy lettering: the thick outline needs room between glyphs and words.
	_tap_hint.add_theme_font_override(&"font", UITheme.spaced_heading(2, 10))
	# Long translations shrink to fit the width instead of running off the screen.
	UIKit.fit_label(_tap_hint, 1080.0 - float(SIDE) * 2.0 - 60.0)
	place(_tap_hint, Vector2(0.5, TAP_Y), Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)


## SHOP | PLAY | TRAILS, bottom-aligned.
func _build_bottom_bar(ui: UITheme) -> void:
	var row: HBoxContainer = UIKit.hbox(24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = float(SIDE)
	row.offset_right = -float(SIDE)
	row.offset_top = 0.0
	row.offset_bottom = -float(BOTTOM)
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(row)
	var shop: UIButton = _tile_button(UIIcon.Kind.BAG, &"accent", &"menu.shop")
	shop.pressed.connect(func() -> void: SceneRouter.push(&"shop", {"tab": 2}))
	row.add_child(shop)
	_play = UIKit.button("", &"primary", PLAY_BUTTON.x)
	_play.custom_minimum_size = PLAY_BUTTON
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.size_flags_stretch_ratio = 1.5
	_play.size_flags_vertical = Control.SIZE_SHRINK_END
	_play.feedback = &"confirm"
	_play.hover_scale = 1.0
	var play_row: HBoxContainer = UIKit.hbox(14)
	play_row.alignment = BoxContainer.ALIGNMENT_CENTER
	play_row.add_child(UIIcon.new(UIIcon.Kind.PLAY, 76.0))
	var play_label: Label = UIKit.label(tr_key(&"menu.play").to_upper(), 76, ui.text)
	play_label.add_theme_font_override(&"font", UIKit.heading_font())
	# Inside the button: width minus the face margins, the triangle and the gap.
	UIKit.fit_label(play_label, PLAY_BUTTON.x - 28.0 - 76.0 - 14.0 - 12.0)
	play_row.add_child(play_label)
	_play.attach_content(play_row, 8, 4)
	_play.pressed.connect(func() -> void: GameEvents.request_play.emit(false))
	row.add_child(_play)
	var trails: UIButton = _tile_button(UIIcon.Kind.FOOTPRINTS, &"secondary", &"menu.trails")
	trails.pressed.connect(func() -> void: SceneRouter.push(&"shop", {"tab": 1}))
	row.add_child(trails)


## Chunky tile for the bottom bar: icon over a caps label.
func _tile_button(kind: UIIcon.Kind, style: StringName, label_key: StringName) -> UIButton:
	var button: UIButton = UIKit.button("", style, SIDE_BUTTON.x)
	button.custom_minimum_size = SIDE_BUTTON
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	var stack: VBoxContainer = UIKit.vbox(0)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon: UIIcon = UIIcon.new(kind, 68.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(icon)
	var text: Label = UIKit.label(tr_key(label_key).to_upper(), 34, UITheme.current().text)
	UIKit.fit_label(text, SIDE_BUTTON.x - 36.0)
	stack.add_child(text)
	button.attach_content(stack, 6, 2)
	return button


# --- behaviour -------------------------------------------------------------------------------

func _refresh() -> void:
	if _coins == null:
		return
	_coins.set_amount(SaveSystem.coins())
	_amber.text = MathUtils.group_digits(SaveSystem.keys())
	_best.text = MathUtils.group_digits(int(SaveSystem.data.get("best_score", 0)))
	_multiplier.text = "x%d" % SaveSystem.account_multiplier()
	_missions_badge.visible = _missions_new
	var daily: Dictionary = _daily_info()
	var done: bool = bool(daily["done"])
	_daily_amount.text = tr_key(&"menu.daily.done") if done else Tr.f(&"menu.daily.reward", {"n": MathUtils.group_digits(int(daily["reward"]))})
	_daily_amount.add_theme_color_override(&"font_color",
			UITheme.current().text_dim if done else UITheme.current().accent)
	_daily_egg.visible = not done
	_daily_box.modulate.a = 0.6 if done else 1.0


func _flag_missions() -> void:
	_missions_new = true
	if _missions_badge != null:
		_missions_badge.visible = true


## Reward of the next daily run (same formula as GameState._apply_daily) or "done today".
func _daily_info() -> Dictionary:
	var last: String = str(SaveSystem.data.get("last_daily_date", ""))
	if last == Rng.today_text():
		return {"done": true, "reward": 0}
	var yesterday: String = Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	var streak: int = int(SaveSystem.data.get("daily_streak", 0))
	var next_streak: int = streak + 1 if last == yesterday else 1
	var base: int = GameConfig.current().daily_reward_base
	return {"done": false, "reward": mini(base * next_streak, base * 7)}


func _start_pulses() -> void:
	_stop_pulses()
	_pulses.append(UITween.pulse(_play, 1.04, 2.4))
	_pulses.append(UITween.pulse(_tap_hint, 1.08, 1.1))


func _stop_pulses() -> void:
	for tween: Tween in _pulses:
		if tween != null and tween.is_valid():
			tween.kill()
	_pulses.clear()
	if _play != null:
		_play.scale = Vector2.ONE
	if _tap_hint != null:
		_tap_hint.scale = Vector2.ONE


## A tap (short press, barely moved) on the empty area starts a run; a drag or swipe does not.
func _on_tap_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_pressing = true
			_dragged = false
			_press_pos = button.position
			_press_msec = Time.get_ticks_msec()
		elif _pressing:
			_pressing = false
			var seconds: float = float(Time.get_ticks_msec() - _press_msec) / 1000.0
			if not _dragged and seconds <= TAP_SECONDS and button.position.distance_to(_press_pos) <= TAP_SLOP:
				GameEvents.ui_feedback.emit(&"confirm")
				GameEvents.request_play.emit(false)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _pressing and motion.position.distance_to(_press_pos) > TAP_SLOP:
		_dragged = true

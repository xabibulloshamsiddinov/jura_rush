## Main menu, drawn over the live 3D world (the camera orbits the jogging runner behind it).
## Layout: top bar (coins | keys), title + best + multiplier, an open middle where the runner is
## framed (see CameraRig.MENU_*), and every button in the lower third:
## PLAY (big, pulsing) / 2 PLAYERS / Daily Run (shows the reward) / Shop · Missions · Settings.
extends UIScreen

const PLAY_SIZE: Vector2 = Vector2(640.0, 176.0)
const WIDE_BUTTON: float = 640.0
const ROW_WIDTH: float = 940.0

var _coins: CoinCounter = null
var _keys: Label = null
var _best: Label = null
var _multiplier: Label = null
var _play: UIButton = null
var _daily: UIButton = null
var _versus: UIButton = null
var _glow_top: ColorRect = null
var _glow_bottom: ColorRect = null
var _time: float = 0.0
var _pulse: Tween = null


func build() -> void:
	var ui: UITheme = UITheme.current()
	# Two soft colour washes that drift slowly: cheap parallax behind the controls.
	_glow_top = _wash(Color(ui.magenta, 0.14))
	_glow_bottom = _wash(Color(ui.cyan, 0.12))
	var column: VBoxContainer = UIKit.vbox(18)
	var wrap: MarginContainer = UIKit.margin(column, 48, 56)
	UIKit.fill(wrap)
	add_child(wrap)

	# Top bar: coins on the left, revive keys (labelled) on the right.
	var top: HBoxContainer = UIKit.hbox(30)
	_coins = CoinCounter.new(ui.size_h2, ui.yellow)
	top.add_child(_coins)
	top.add_child(UIKit.spacer())
	var keys: HBoxContainer = UIKit.hbox(12)
	keys.add_child(KeyIcon.new(float(UIKit.scaled(ui.size_h2))))
	_keys = UIKit.label("0", ui.size_h2, ui.cyan, HORIZONTAL_ALIGNMENT_LEFT)
	keys.add_child(_keys)
	keys.add_child(UIKit.label(tr_key(&"menu.keys"), ui.size_small, ui.text_dim, HORIZONTAL_ALIGNMENT_LEFT))
	top.add_child(keys)
	column.add_child(top)

	column.add_child(_gap(6.0))
	var title: Label = UIKit.label(GameConfig.GAME_TITLE, ui.size_title, ui.cyan)
	title.add_theme_constant_override(&"outline_size", 14)
	title.add_theme_color_override(&"font_outline_color", Color(0.0, 0.05, 0.12, 0.9))
	column.add_child(title)
	_best = UIKit.label("", ui.size_h1, ui.yellow)
	_strong_outline(_best)
	column.add_child(_best)
	_multiplier = UIKit.label("", ui.size_h2, Color(1.0, 0.45, 0.92))
	_strong_outline(_multiplier)
	column.add_child(_multiplier)

	# The runner is framed in this open space.
	column.add_child(UIKit.spacer())

	_play = UIKit.button(tr_key(&"menu.play"), &"primary", PLAY_SIZE.x)
	_play.custom_minimum_size = PLAY_SIZE
	_play.add_theme_font_override(&"font", UIKit.heading_font())
	_play.add_theme_font_size_override(&"font_size", UIKit.scaled(ui.size_h1))
	_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play.feedback = &"confirm"
	_play.pressed.connect(func() -> void: GameEvents.request_play.emit(false))
	column.add_child(_play)

	_versus = UIKit.button(tr_key(&"menu.versus"), &"secondary", WIDE_BUTTON)
	_versus.custom_minimum_size = Vector2(WIDE_BUTTON, 120.0)
	_versus.add_theme_font_size_override(&"font_size", UIKit.scaled(ui.size_h2))
	_versus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_versus.feedback = &"confirm"
	_versus.pressed.connect(func() -> void: GameEvents.request_versus_open.emit())
	column.add_child(_versus)

	_daily = UIKit.button(tr_key(&"menu.daily"), &"accent", WIDE_BUTTON)
	_daily.custom_minimum_size = Vector2(WIDE_BUTTON, 132.0)
	_daily.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_daily.pressed.connect(func() -> void: GameEvents.request_play.emit(true))
	column.add_child(_daily)

	# One row of secondary navigation. Runners live as the first tab inside the shop.
	var row: HBoxContainer = UIKit.hbox(18)
	row.custom_minimum_size = Vector2(ROW_WIDTH, 0.0)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(row)
	_nav(row, &"menu.shop", &"secondary", &"shop", {"tab": 0})
	_nav(row, &"menu.missions", &"primary", &"missions", {})
	_nav(row, &"menu.settings", &"ghost", &"settings", {})


func connect_events() -> void:
	GameEvents.wallet_changed.connect(func(_c: int, _k: int) -> void: _refresh())


func on_enter(_args: Dictionary) -> void:
	_refresh()
	if _pulse == null or not _pulse.is_valid():
		_pulse = UITween.pulse(_play, 1.05, 1.4)


func handle_back() -> bool:
	return true


func _process(delta: float) -> void:
	if not visible or _glow_top == null:
		return
	_time += delta
	_glow_top.position = Vector2(sin(_time * 0.3) * 60.0, -200.0 + cos(_time * 0.2) * 40.0)
	_glow_bottom.position = Vector2(cos(_time * 0.25) * 80.0, size.y - 520.0 + sin(_time * 0.35) * 40.0)


func _refresh() -> void:
	if _coins == null:
		return
	_coins.set_amount(SaveSystem.coins())
	_keys.text = str(SaveSystem.keys())
	_best.text = Tr.f(&"menu.best", {"n": MathUtils.group_digits(int(SaveSystem.data.get("best_score", 0)))})
	_multiplier.text = Tr.f(&"menu.multiplier", {"n": SaveSystem.account_multiplier()})
	_daily.text = "%s\n%s" % [tr_key(&"menu.daily"), _daily_reward_text()]
	var played_today: bool = str(SaveSystem.data.get("last_daily_date", "")) == Rng.today_text()
	_daily.modulate.a = 0.65 if played_today else 1.0


## "Streak 2 → reward: 300" (same formula as GameState._apply_daily), or "done today".
func _daily_reward_text() -> String:
	var last: String = str(SaveSystem.data.get("last_daily_date", ""))
	if last == Rng.today_text():
		return tr_key(&"menu.daily.done")
	var yesterday: String = Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	var streak: int = int(SaveSystem.data.get("daily_streak", 0))
	var next_streak: int = streak + 1 if last == yesterday else 1
	var base: int = GameConfig.current().daily_reward_base
	var reward: int = mini(base * next_streak, base * 7)
	return Tr.f(&"menu.daily.reward", {"s": streak if last == yesterday else 0,
			"n": MathUtils.group_digits(reward)})


func _nav(parent: Control, key: StringName, style: StringName, screen: StringName,
		screen_args: Dictionary) -> void:
	var b: UIButton = UIKit.button(tr_key(key), style)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override(&"font_size", UIKit.scaled(UITheme.current().size_body))
	b.pressed.connect(func() -> void: SceneRouter.push(screen, screen_args))
	parent.add_child(b)


## Fixed-height gap (UIKit.spacer() always expands, which would steal space from the middle).
func _gap(height: float) -> Control:
	var node: Control = Control.new()
	node.custom_minimum_size = Vector2(0.0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _strong_outline(label: Label) -> void:
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.03, 0.9))
	label.add_theme_constant_override(&"outline_size", 12)


func _wash(color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(1400.0, 720.0)
	rect.rotation = -0.12
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect

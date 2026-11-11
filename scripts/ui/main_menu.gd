## Main menu, drawn over the live 3D world (the camera orbits the idle runner behind it).
extends UIScreen

var _coins: Label = null
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
	_glow_top = _wash(Color(ui.magenta, 0.16))
	_glow_bottom = _wash(Color(ui.cyan, 0.14))
	var column: VBoxContainer = UIKit.vbox(22)
	var wrap: MarginContainer = UIKit.margin(column, 48, 56)
	UIKit.fill(wrap)
	add_child(wrap)
	var top: HBoxContainer = UIKit.hbox(30)
	_coins = UIKit.counter("o", ui.yellow)
	_keys = UIKit.counter("#", ui.cyan)
	top.add_child(_coins)
	top.add_child(UIKit.spacer())
	top.add_child(_keys)
	column.add_child(top)
	column.add_child(UIKit.spacer(40.0))
	column.add_child(UIKit.label(GameConfig.GAME_TITLE, ui.size_title, ui.cyan))
	_best = UIKit.label("", ui.size_h2, ui.text)
	column.add_child(_best)
	_multiplier = UIKit.label("", ui.size_body, ui.magenta)
	column.add_child(_multiplier)
	column.add_child(UIKit.spacer(520.0))
	_play = UIKit.button(tr_key(&"menu.play"), &"primary", 520.0)
	_play.custom_minimum_size = Vector2(520.0, 170.0)
	_play.add_theme_font_size_override(&"font_size", UIKit.scaled(ui.size_h1))
	_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play.feedback = &"confirm"
	_play.pressed.connect(func() -> void: GameEvents.request_play.emit(false))
	column.add_child(_play)
	_versus = UIKit.button(tr_key(&"menu.versus"), &"accent", 520.0)
	_versus.custom_minimum_size = Vector2(520.0, 130.0)
	_versus.add_theme_font_size_override(&"font_size", UIKit.scaled(ui.size_h2))
	_versus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_versus.feedback = &"confirm"
	_versus.pressed.connect(func() -> void: GameEvents.request_versus_open.emit())
	column.add_child(_versus)
	_daily = UIKit.button(tr_key(&"menu.daily"), &"gold", 520.0)
	_daily.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_daily.pressed.connect(func() -> void: GameEvents.request_play.emit(true))
	column.add_child(_daily)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 20)
	grid.add_theme_constant_override(&"v_separation", 20)
	# Keep the grid phone-width on wide (desktop / web) screens.
	grid.custom_minimum_size = Vector2(980.0, 0.0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)
	_nav(grid, &"menu.shop", &"accent", &"shop", {"tab": 2})
	_nav(grid, &"menu.characters", &"accent", &"shop", {"tab": 0})
	_nav(grid, &"menu.missions", &"primary", &"missions", {})
	_nav(grid, &"menu.settings", &"ghost", &"settings", {})


func connect_events() -> void:
	GameEvents.wallet_changed.connect(func(_c: int, _k: int) -> void: _refresh())


func on_enter(_args: Dictionary) -> void:
	_refresh()
	if _pulse == null or not _pulse.is_valid():
		_pulse = UITween.pulse(_play)


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
	_coins.text = "o " + MathUtils.group_digits(SaveSystem.coins())
	_keys.text = "# " + str(SaveSystem.keys())
	_best.text = Tr.f(&"menu.best", {"n": MathUtils.group_digits(int(SaveSystem.data.get("best_score", 0)))})
	_multiplier.text = Tr.f(&"menu.multiplier", {"n": SaveSystem.account_multiplier()})
	var played_today: bool = str(SaveSystem.data.get("last_daily_date", "")) == Rng.today_text()
	_daily.text = "%s  (%s)" % [tr_key(&"menu.daily"),
			Tr.f(&"menu.streak", {"n": int(SaveSystem.data.get("daily_streak", 0))})]
	_daily.modulate.a = 0.6 if played_today else 1.0


func _nav(parent: Control, key: StringName, style: StringName, screen: StringName,
		screen_args: Dictionary) -> void:
	var b: UIButton = UIKit.button(tr_key(key), style)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: SceneRouter.push(screen, screen_args))
	parent.add_child(b)


func _wash(color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.size = Vector2(1400.0, 720.0)
	rect.rotation = -0.12
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect

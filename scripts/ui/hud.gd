## In-run HUD: score, coins, multiplier, distance, combo, power-up timers, mission ticker,
## countdown, biome banner and floating texts. Reads the game only through GameEvents, and
## every control ignores the mouse so swipes always reach the input handler.
extends UIScreen

const MAX_FLOATERS: int = 10
const MULTIPLIER_COLOR: Color = Color(1.0, 0.45, 0.92)
const MULTIPLIER_SIZE: int = 60
const DISTANCE_SIZE: int = 48

var _score: Label = null
var _coins: CoinCounter = null
var _multiplier: Label = null
var _distance: Label = null
var _combo: Label = null
var _ticker: Label = null
var _countdown: Label = null
var _banner: Label = null
var _powerups: HBoxContainer = null
var _secondary: Control = null
var _floaters: Control = null
var _timers: Dictionary = {}
var _ticker_tween: Tween = null
var _active_floaters: int = 0


func build() -> void:
	var ui: UITheme = UITheme.current()
	var column: VBoxContainer = UIKit.vbox(6)
	# Extra inset on top of the router's safe area: the pause button must not sit in a rounded
	# screen corner or under a notch.
	var wrap: MarginContainer = UIKit.margin(column, 56, 64)
	UIKit.fill(wrap)
	add_child(wrap)
	var top: HBoxContainer = UIKit.hbox(20)
	column.add_child(top)
	var pause: UIButton = UIKit.button("II", &"ghost", 110.0)
	pause.custom_minimum_size = Vector2(110.0, 110.0)
	pause.pressed.connect(func() -> void: GameEvents.request_pause.emit())
	top.add_child(pause)
	_score = UIKit.label("0", ui.size_h1, ui.text)
	_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_score)
	_coins = CoinCounter.new(ui.size_h2, ui.yellow, HORIZONTAL_ALIGNMENT_RIGHT)
	_coins.custom_minimum_size = Vector2(190.0, 0.0)
	top.add_child(_coins)
	_secondary = UIKit.hbox(20)
	column.add_child(_secondary)
	# Multiplier and distance: bigger, bright and heavily outlined so they read on the dark city.
	_multiplier = UIKit.label("x1", MULTIPLIER_SIZE, MULTIPLIER_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_multiplier.custom_minimum_size = Vector2(110.0, 0.0)
	_strong_outline(_multiplier)
	_secondary.add_child(_multiplier)
	_distance = UIKit.label("0 m", DISTANCE_SIZE, ui.text)
	_strong_outline(_distance)
	_distance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_secondary.add_child(_distance)
	var balance: Control = Control.new()
	balance.custom_minimum_size = Vector2(110.0, 0.0)
	_secondary.add_child(balance)
	_combo = UIKit.label("", ui.size_h2, ui.yellow)
	_combo.visible = false
	column.add_child(_combo)
	_banner = UIKit.label("", ui.size_h1, ui.cyan)
	_banner.modulate.a = 0.0
	column.add_child(_banner)
	column.add_child(UIKit.spacer())
	_countdown = UIKit.label("", 260, ui.text)
	_countdown.visible = false
	UIKit.fill(_countdown)
	add_child(_countdown)
	_ticker = UIKit.label("", ui.size_small, ui.text, HORIZONTAL_ALIGNMENT_LEFT)
	_ticker.modulate.a = 0.0
	column.add_child(_ticker)
	_powerups = UIKit.hbox(18)
	_powerups.alignment = BoxContainer.ALIGNMENT_CENTER
	_powerups.custom_minimum_size = Vector2(0.0, 120.0)
	column.add_child(_powerups)
	_floaters = Control.new()
	UIKit.fill(_floaters)
	add_child(_floaters)
	_timers.clear()
	_ignore_mouse(self, pause)


func connect_events() -> void:
	GameEvents.score_changed.connect(func(value: int) -> void:
		_score.text = MathUtils.group_digits(value))
	GameEvents.coins_changed.connect(func(value: int) -> void:
		_coins.text = str(value)
		if visible and value > 0:
			UITween.bump(_coins, 1.18))
	GameEvents.distance_changed.connect(func(metres: int) -> void: _distance.text = "%d m" % metres)
	GameEvents.multiplier_changed.connect(func(value: int) -> void:
		_multiplier.text = "x%d" % value
		if visible:
			UITween.bump(_multiplier, 1.3))
	GameEvents.combo_changed.connect(_on_combo)
	GameEvents.countdown_tick.connect(_on_countdown)
	GameEvents.powerup_activated.connect(_on_powerup_activated)
	GameEvents.powerup_expired.connect(_on_powerup_expired)
	GameEvents.floating_text.connect(_on_floating_text)
	GameEvents.coin_collected.connect(_on_coin)
	GameEvents.biome_changed.connect(func(_id: StringName, title: String) -> void: _show_banner(title))
	GameEvents.mission_progress.connect(_on_mission_progress)
	GameEvents.mission_completed.connect(func(_id: StringName) -> void:
		_show_ticker(tr_key(&"toast.mission"), UITheme.current().yellow))
	GameEvents.achievement_unlocked.connect(func(_id: StringName) -> void:
		_show_ticker(tr_key(&"toast.achievement"), UITheme.current().yellow))
	GameEvents.mission_set_completed.connect(func(multiplier: int) -> void:
		_show_banner(Tr.f(&"toast.set", {"n": multiplier})))
	GameEvents.mystery_box_opened.connect(_on_box)
	GameEvents.run_started.connect(_on_run_started)


func on_enter(_args: Dictionary) -> void:
	for id: StringName in _timers.keys():
		(_timers[id] as RadialTimer).queue_free()
	_timers.clear()
	_combo.visible = false
	_banner.modulate.a = 0.0
	_ticker.modulate.a = 0.0


func handle_back() -> bool:
	GameEvents.request_pause.emit()
	return true


func _on_run_started() -> void:
	if GameState.tutorial_active:
		SceneRouter.push.call_deferred(&"tutorial")


func _on_combo(combo: int) -> void:
	_combo.visible = combo > 1
	if combo > 1:
		_combo.text = Tr.f(&"hud.combo", {"n": combo})
		UITween.bump(_combo, 1.35)


func _on_countdown(remaining: int) -> void:
	_countdown.visible = true
	_countdown.text = tr_key(&"hud.go") if remaining <= 0 else str(remaining)
	_countdown.add_theme_color_override(&"font_color",
			UITheme.current().yellow if remaining <= 0 else UITheme.current().text)
	UITween.pop(_countdown, 0.0, 1.6)
	if remaining <= 0:
		var tween: Tween = _countdown.create_tween()
		tween.tween_interval(0.45)
		tween.tween_property(_countdown, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func() -> void: _countdown.visible = false)


func _on_powerup_activated(id: StringName, duration: float) -> void:
	var def: PowerupDef = ContentDB.powerup(id)
	if def == null:
		return
	var timer: RadialTimer = _timers.get(id) as RadialTimer
	if timer == null:
		timer = RadialTimer.new(112.0)
		timer.color = def.color
		timer.glyph = def.icon
		_powerups.add_child(timer)
		_timers[id] = timer
		UITween.pop(timer)
	timer.start(duration)


func _on_powerup_expired(id: StringName) -> void:
	var timer: RadialTimer = _timers.get(id) as RadialTimer
	if timer != null:
		_timers.erase(id)
		timer.queue_free()


func _on_floating_text(content: String, world_pos: Vector3, color: Color) -> void:
	var from: Vector2 = _to_screen(world_pos)
	_float(content, from, from + Vector2(0.0, -160.0), color, UIKit.scaled(52), 0.9)


func _on_coin(value: int, world_pos: Vector3) -> void:
	if not visible or _active_floaters >= MAX_FLOATERS:
		return
	var target: Vector2 = _coins.global_position + _coins.size * 0.5 - global_position
	_float("+%d" % value, _to_screen(world_pos), target, UITheme.current().yellow, 34, 0.45)


func _on_box(reward: StringName, amount: int) -> void:
	var content: String = Tr.f(&"box.coins", {"n": amount})
	if reward == &"keys":
		content = tr_key(&"box.keys")
	elif reward != &"coins":
		var def: PowerupDef = ContentDB.powerup(reward)
		content = tr_key(def.name_key) if def != null else String(reward)
	_show_banner(content)


func _on_mission_progress(id: StringName, value: int, target: int) -> void:
	var def: MissionDef = ContentDB.mission(id)
	if def == null or value >= target:
		return
	# Only whisper at quarter milestones so the ticker stays quiet.
	@warning_ignore("integer_division")
	var quarter: int = maxi(target / 4, 1)
	if value % quarter != 0:
		return
	_show_ticker("%s  %d / %d" % [Tr.f(def.text_key(), {"n": target}), value, target],
			UITheme.current().text)


func _show_ticker(content: String, color: Color) -> void:
	if not visible:
		return
	_ticker.text = content
	_ticker.add_theme_color_override(&"font_color", color)
	if _ticker_tween != null and _ticker_tween.is_valid():
		_ticker_tween.kill()
	_ticker_tween = _ticker.create_tween()
	_ticker_tween.tween_property(_ticker, "modulate:a", 1.0, 0.15)
	_ticker_tween.tween_interval(2.2)
	_ticker_tween.tween_property(_ticker, "modulate:a", 0.0, 0.4)


func _show_banner(content: String) -> void:
	if not visible:
		return
	_banner.text = content
	var tween: Tween = _banner.create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.6)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _float(content: String, from: Vector2, target: Vector2, color: Color, font_size: int,
		duration: float) -> void:
	if not visible:
		return
	var node: FloatingText = PoolManager.acquire(&"floating_text") as FloatingText
	if node == null:
		return
	_floaters.add_child(node)
	_active_floaters += 1
	node.launch(content, from, target, color, font_size, duration)
	get_tree().create_timer(duration + 0.05).timeout.connect(func() -> void: _active_floaters -= 1)


## World position -> HUD-local canvas position.
func _to_screen(world_pos: Vector3) -> Vector2:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return size * 0.5
	return camera.unproject_position(world_pos) - global_position


func _ignore_mouse(node: Node, except: Control) -> void:
	for child in node.get_children():
		if child == except:
			continue
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child, except)


func _strong_outline(label: Label) -> void:
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.02, 0.9))
	label.add_theme_constant_override(&"outline_size", 12)

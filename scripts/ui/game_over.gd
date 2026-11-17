## Results screen: animated count-up of score and coins, best-score highlight with confetti,
## mission progress and what to do next.
extends UIScreen

var _score: Label = null
var _coins: CoinCounter = null
var _distance: Label = null
var _best: Label = null
var _daily: Label = null
var _missions: VBoxContainer = null
var _double: UIButton = null
var _panel: PanelContainer = null
var _doubled: bool = false


func build() -> void:
	var ui: UITheme = UITheme.current()
	add_child(UIKit.dimmer(0.45))
	var column: VBoxContainer = UIKit.vbox(20)
	var wrap: MarginContainer = UIKit.margin(column, 56, 90)
	UIKit.fill(wrap)
	add_child(wrap)
	column.add_child(UIKit.label(tr_key(&"over.title"), ui.size_h1, ui.accent))
	_panel = UIKit.panel(false, ui.accent)
	column.add_child(_panel)
	var stats: VBoxContainer = UIKit.vbox(14)
	_panel.add_child(UIKit.margin(stats, 30, 30))
	stats.add_child(UIKit.label(tr_key(&"over.score"), ui.size_body, ui.text_dim))
	_score = UIKit.label("0", ui.size_title, ui.text)
	stats.add_child(_score)
	_best = UIKit.label("", ui.size_h2, ui.accent)
	stats.add_child(_best)
	stats.add_child(UIKit.label(tr_key(&"over.coins_run"), ui.size_small, ui.text_dim))
	_coins = CoinCounter.new(ui.size_h2, ui.accent, HORIZONTAL_ALIGNMENT_CENTER)
	stats.add_child(_coins)
	_distance = UIKit.label("", ui.size_h2, ui.text)
	stats.add_child(_distance)
	_daily = UIKit.label("", ui.size_body, ui.success)
	stats.add_child(_daily)
	_missions = UIKit.vbox(12)
	column.add_child(_missions)
	column.add_child(UIKit.spacer())
	_double = UIKit.button(tr_key(&"over.double"), &"gold")
	_double.pressed.connect(_on_double)
	column.add_child(_double)
	var again: UIButton = UIKit.button(tr_key(&"over.again"), &"primary")
	again.custom_minimum_size = Vector2(0.0, 150.0)
	again.feedback = &"confirm"
	again.pressed.connect(func() -> void: GameEvents.request_restart.emit())
	column.add_child(again)
	var row: HBoxContainer = UIKit.hbox(20)
	column.add_child(row)
	var menu: UIButton = UIKit.button(tr_key(&"over.menu"), &"ghost")
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func() -> void: GameEvents.request_menu.emit())
	row.add_child(menu)
	var shop: UIButton = UIKit.button(tr_key(&"over.shop"), &"secondary")
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.pressed.connect(func() -> void: SceneRouter.push(&"shop", {"tab": 2}))
	row.add_child(shop)


func on_enter(_args: Dictionary) -> void:
	var result: Dictionary = GameState.last_result
	var final_score: int = int(result.get("score", 0))
	var coins: int = int(result.get("coins", 0))
	_doubled = false
	_double.disabled = coins <= 0
	_double.visible = coins > 0
	_score.text = "0"
	UITween.count_up(_score, final_score, 1.1, "", 0.2)
	_coins.text = "0"
	UITween.count_up(_coins.label, coins, 0.8, "", 0.9)
	_distance.text = "%s: %d m" % [tr_key(&"over.distance"), int(result.get("distance", 0))]
	var new_best: bool = bool(result.get("new_best", false))
	_best.text = tr_key(&"over.new_best") if new_best else "%s: %s" % [tr_key(&"over.best"),
			MathUtils.group_digits(int(result.get("best", 0)))]
	_best.add_theme_color_override(&"font_color",
			UITheme.current().accent if new_best else UITheme.current().text_dim)
	_daily.visible = result.has("daily_reward")
	if result.has("daily_reward"):
		_daily.text = Tr.f(&"over.daily", {"n": int(result["daily_reward"]), "s": int(result["daily_streak"])})
	if new_best:
		var tween: Tween = create_tween()
		tween.tween_interval(1.3)
		tween.tween_callback(func() -> void:
			VFXManager.play_ui(&"confetti", Vector2(size.x * 0.5, size.y * 0.45))
			UITween.shine(_panel)
			UITween.bump(_best, 1.3))
	_fill_missions()
	# Smooth entrance: the results card pops in while the screen fades in (SceneRouter).
	UITween.pop(_panel, 0.0, 0.85)


func handle_back() -> bool:
	GameEvents.request_menu.emit()
	return true


func _fill_missions() -> void:
	for child in _missions.get_children():
		child.queue_free()
	var service: Object = Services.locate(&"missions")
	if service == null:
		return
	var rows: Array = service.call(&"mission_rows")
	var delay: float = 0.4
	for row: Dictionary in rows:
		var def: MissionDef = row["def"]
		var done: bool = bool(row["done"])
		var ui: UITheme = UITheme.current()
		var line: VBoxContainer = UIKit.vbox(4)
		line.add_child(UIKit.label("%s   %d / %d" % [Tr.f(def.text_key(), {"n": def.target}),
				int(row["value"]), int(row["target"])], ui.size_small,
				ui.accent if done else ui.text, HORIZONTAL_ALIGNMENT_LEFT))
		var bar: ProgressBar = UIKit.progress(0.0, float(row["target"]), ui.accent if done else ui.primary)
		line.add_child(bar)
		_missions.add_child(line)
		bar.create_tween().tween_property(bar, "value", float(row["value"]), 0.6).set_delay(delay)
		delay += 0.15


## Rewarded-ad stub: doubles the coins earned this run.
func _on_double() -> void:
	if _doubled:
		return
	_double.disabled = true
	var ads: Object = Services.locate(&"ads")
	ads.call(&"show_rewarded_ad", &"double_coins", func(success: bool) -> void:
		if not success or _doubled:
			return
		_doubled = true
		var coins: int = int(GameState.last_result.get("coins", 0))
		SaveSystem.add_coins(coins)
		UITween.count_up(_coins.label, coins * 2, 0.6, "")
		UITween.shine(_coins)
		GameEvents.ui_feedback.emit(&"confirm"))

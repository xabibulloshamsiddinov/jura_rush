## "Continue?" popup after a crash: a 5 s radial timer, revive for keys (price grows each use
## in a run) or by watching a (stubbed) rewarded ad. Timing out declines.
extends UIScreen

var _panel: PanelContainer = null
var _timer: RadialTimer = null
var _keys_button: UIButton = null
var _ad_button: UIButton = null
var _wallet: Label = null


func build() -> void:
	is_popup = true
	var ui: UITheme = UITheme.current()
	add_child(UIKit.dimmer(0.5))
	var center: CenterContainer = CenterContainer.new()
	UIKit.fill(center)
	add_child(center)
	_panel = UIKit.panel(false, ui.accent)
	_panel.custom_minimum_size = Vector2(760.0, 0.0)
	center.add_child(_panel)
	var column: VBoxContainer = UIKit.vbox(24)
	_panel.add_child(UIKit.margin(column, 40, 40))
	column.add_child(UIKit.label(tr_key(&"revive.title"), ui.size_h1, ui.accent))
	_timer = RadialTimer.new(200.0)
	_timer.color = ui.accent
	_timer.warn_below = 1.5
	_timer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.finished.connect(_decline)
	column.add_child(_timer)
	var wallet_row: HBoxContainer = UIKit.hbox(12)
	wallet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet_row.add_child(KeyIcon.new(float(UIKit.scaled(ui.size_body))))
	_wallet = UIKit.label("", ui.size_body, ui.accent)
	wallet_row.add_child(_wallet)
	column.add_child(wallet_row)
	_keys_button = UIKit.button("", &"primary")
	_keys_button.feedback = &"confirm"
	_keys_button.pressed.connect(func() -> void:
		_timer.running = false
		GameEvents.request_revive.emit(&"keys"))
	column.add_child(_keys_button)
	_ad_button = UIKit.button(tr_key(&"revive.ad"), &"gold")
	_ad_button.pressed.connect(func() -> void:
		_timer.running = false
		_ad_button.disabled = true
		GameEvents.request_revive.emit(&"ad"))
	column.add_child(_ad_button)
	var no: UIButton = UIKit.button(tr_key(&"revive.no"), &"ghost")
	no.pressed.connect(_decline)
	column.add_child(no)


func on_enter(_args: Dictionary) -> void:
	var cost: int = GameState.revive_cost()
	_keys_button.text = Tr.f(&"revive.keys", {"n": cost})
	_keys_button.disabled = SaveSystem.keys() < cost
	_ad_button.disabled = false
	_wallet.text = Tr.f(&"revive.wallet", {"n": SaveSystem.keys()})
	_timer.glyph = ""
	_timer.start(GameConfig.current().revive_timer)
	UITween.pop(_panel, 0.0, 0.85)


func on_exit() -> void:
	_timer.running = false


func handle_back() -> bool:
	_decline()
	return true


func _decline() -> void:
	_timer.running = false
	GameEvents.request_decline_revive.emit()

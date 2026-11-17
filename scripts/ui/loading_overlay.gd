## Splash / loading screen. mode "boot": logo reveal + loading bar while pools, effects and
## synthesised audio are prepared. mode "run": a short "GET READY" curtain while the track resets.
## The backdrop is the same painted prehistoric sunset as the generated splash image.
extends UIScreen

var _background: JuraBackdrop = null
var _title: Control = null
var _subtitle: Label = null
var _bar: ProgressBar = null


func build() -> void:
	var ui: UITheme = UITheme.current()
	_background = JuraBackdrop.new()
	UIKit.fill(_background)
	add_child(_background)
	# The logo breathes by itself (scale), so the entrance pop runs on a holder around it.
	var logo: GameLogo = GameLogo.new(GameConfig.GAME_TITLE)
	_title = Control.new()
	_title.custom_minimum_size = logo.custom_minimum_size
	UIKit.fill(logo)
	_title.add_child(logo)
	place(_title, Vector2(0.5, 0.3), Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	var column: VBoxContainer = UIKit.vbox(22)
	_subtitle = UIKit.label(tr_key(&"loading.loading"), ui.size_body, ui.text)
	column.add_child(_subtitle)
	_bar = UIKit.progress(0.0, 1.0, ui.accent)
	_bar.custom_minimum_size = Vector2(620.0, 30.0)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_bar)
	place(column, Vector2(0.5, 0.9), Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)


func on_enter(p_args: Dictionary) -> void:
	var boot: bool = str(p_args.get("mode", "boot")) == "boot"
	_bar.visible = boot
	_bar.value = 0.0
	_background.modulate.a = 1.0 if boot else 0.92
	_subtitle.text = tr_key(&"loading.loading" if boot else &"loading.ready")
	UITween.pop(_title, 0.05, 0.8)


## Loading bar position 0..1 (boot mode).
func set_progress(value: float) -> void:
	if _bar != null:
		_bar.value = value

## Splash / loading screen. mode "boot": logo reveal + loading bar while pools, effects and
## synthesised audio are prepared. mode "run": a short "GET READY" curtain while the track resets.
extends UIScreen

var _background: ColorRect = null
var _title: Label = null
var _subtitle: Label = null
var _bar: ProgressBar = null


func build() -> void:
	var ui: UITheme = UITheme.current()
	_background = ColorRect.new()
	_background.color = ui.background
	UIKit.fill(_background)
	add_child(_background)
	var column: VBoxContainer = UIKit.vbox(30)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	UIKit.fill(column)
	add_child(column)
	_title = UIKit.label(GameConfig.GAME_TITLE, ui.size_title, ui.cyan)
	column.add_child(_title)
	_subtitle = UIKit.label(tr_key(&"loading.loading"), ui.size_body, ui.text_dim)
	column.add_child(_subtitle)
	_bar = UIKit.progress(0.0, 1.0, ui.magenta)
	_bar.custom_minimum_size = Vector2(600.0, 22.0)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_bar)


func on_enter(p_args: Dictionary) -> void:
	var boot: bool = str(p_args.get("mode", "boot")) == "boot"
	_bar.visible = boot
	_bar.value = 0.0
	_background.color.a = 1.0 if boot else 0.9
	_subtitle.text = tr_key(&"loading.loading" if boot else &"loading.ready")
	UITween.pop(_title, 0.05, 0.8)


## Loading bar position 0..1 (boot mode).
func set_progress(value: float) -> void:
	if _bar != null:
		_bar.value = value

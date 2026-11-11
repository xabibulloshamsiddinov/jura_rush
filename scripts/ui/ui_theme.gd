## The one UI theme resource (config/ui_theme.tres): palette, sizes and font. Swap the font or
## tweak colours there; no code changes are needed.
class_name UITheme
extends Resource

@export var font: Font
@export var background: Color = Color(0.03, 0.035, 0.08)
@export var panel: Color = Color(0.07, 0.08, 0.17, 0.94)
@export var panel_light: Color = Color(0.12, 0.14, 0.28, 0.96)
@export var cyan: Color = Color(0.0, 0.9, 1.0)
@export var magenta: Color = Color(1.0, 0.2, 0.8)
@export var yellow: Color = Color(1.0, 0.86, 0.1)
@export var danger: Color = Color(1.0, 0.25, 0.3)
@export var text: Color = Color(0.95, 0.97, 1.0)
@export var text_dim: Color = Color(0.6, 0.66, 0.82)
@export var size_title: int = 104
@export var size_h1: int = 68
@export var size_h2: int = 48
@export var size_body: int = 36
@export var size_small: int = 28
@export var corner_radius: int = 30
## Minimum touch target height in base pixels (>= 96).
@export var button_height: int = 112

static var _instance: UITheme = null


## Shared theme (falls back to defaults when the .tres is missing).
static func current() -> UITheme:
	if _instance == null:
		if ResourceLoader.exists("res://config/ui_theme.tres"):
			_instance = ResourceLoader.load("res://config/ui_theme.tres") as UITheme
		if _instance == null:
			_instance = UITheme.new()
	return _instance

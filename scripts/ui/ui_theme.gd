## The one UI theme resource (config/ui_theme.tres): palette, sizes and fonts. Swap a font or
## tweak colours there; no code changes are needed.
##
## godot_theme() turns it into ONE shared Godot `Theme` (default font, labels, neon button
## variations, panels, scroll bars). SceneRouter sets it on the UI root, so every screen (menu,
## shop, HUD, pause, game over, settings, missions, tutorial) inherits it.
class_name UITheme
extends Resource

## Body / button font (Rajdhani Bold by default). Empty = the bundled default below.
@export var font: Font
## Title / big-number font (Orbitron by default). Empty = the bundled default below.
@export var heading_font: Font
@export var background: Color = Color(0.03, 0.035, 0.08)
@export var panel: Color = Color(0.07, 0.08, 0.17, 0.94)
@export var panel_light: Color = Color(0.12, 0.14, 0.28, 0.96)
@export var cyan: Color = Color(0.0, 0.9, 1.0)
@export var magenta: Color = Color(1.0, 0.2, 0.8)
@export var yellow: Color = Color(1.0, 0.86, 0.1)
@export var danger: Color = Color(1.0, 0.25, 0.3)
@export var success: Color = Color(0.25, 1.0, 0.55)
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
## Neon button border width and glow (shadow) size in base pixels.
@export var button_border: int = 2
@export var button_glow: int = 14

## Bundled open-licence fonts (SIL OFL 1.1, licences next to the files in assets/fonts).
## Orbitron and Rajdhani have no Cyrillic, so Exo 2 is chained as a fallback for Russian.
const BODY_FONT_PATH: String = "res://assets/fonts/Rajdhani-Bold.ttf"
const HEADING_FONT_PATH: String = "res://assets/fonts/Orbitron-Variable.ttf"
const FALLBACK_FONT_PATH: String = "res://assets/fonts/Exo2-Variable.ttf"
const HEADING_WEIGHT: int = 800
const FALLBACK_WEIGHT: int = 700

## Button variations: id -> palette colour name. "accent" = yellow, "secondary" = magenta.
const BUTTON_STYLES: Dictionary = {
	&"primary": &"cyan",
	&"secondary": &"magenta",
	&"accent": &"yellow",
	&"danger": &"danger",
	&"success": &"success",
	&"ghost": &"text_dim",
}

static var _instance: UITheme = null
static var _theme: Theme = null
static var _body: Font = null
static var _heading: Font = null


## Shared theme (falls back to defaults when the .tres is missing).
static func current() -> UITheme:
	if _instance == null:
		if ResourceLoader.exists("res://config/ui_theme.tres"):
			_instance = ResourceLoader.load("res://config/ui_theme.tres") as UITheme
		if _instance == null:
			_instance = UITheme.new()
	return _instance


## Body font with the Cyrillic fallback chained.
static func body_font() -> Font:
	if _body == null:
		var ui: UITheme = current()
		_body = ui.font if ui.font != null else _load_font(BODY_FONT_PATH, 0)
	return _body


## Heading font (titles, score, big numbers) with the Cyrillic fallback chained.
static func heading() -> Font:
	if _heading == null:
		var ui: UITheme = current()
		_heading = ui.heading_font if ui.heading_font != null else _load_font(HEADING_FONT_PATH, HEADING_WEIGHT)
	return _heading


## Theme variation name of a button style (e.g. &"NeonPrimary").
static func button_variation(style: StringName) -> StringName:
	var id: StringName = style if BUTTON_STYLES.has(style) else &"primary"
	return StringName("Neon" + String(id).capitalize())


## Colour of a button style.
static func style_color(style: StringName) -> Color:
	var ui: UITheme = current()
	var name: StringName = BUTTON_STYLES.get(style, &"cyan")
	return ui.get(name) as Color


## The single Godot Theme shared by all screens (built once from this resource).
static func godot_theme() -> Theme:
	if _theme != null:
		return _theme
	var ui: UITheme = current()
	var t: Theme = Theme.new()
	t.default_font = body_font()
	t.default_font_size = ui.size_body
	t.set_color(&"font_color", &"Label", ui.text)
	t.set_color(&"font_outline_color", &"Label", Color(0.0, 0.0, 0.0, 0.6))
	t.set_constant(&"outline_size", &"Label", 6)
	t.set_stylebox(&"panel", &"PanelContainer", _flat(ui.panel, ui.corner_radius))
	# Thin neon scroll bars (touch scrolling still drags the content itself).
	t.set_stylebox(&"scroll", &"VScrollBar", _flat(Color(1, 1, 1, 0.05), 6))
	t.set_stylebox(&"grabber", &"VScrollBar", _flat(Color(ui.cyan, 0.5), 6))
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", _flat(Color(ui.cyan, 0.8), 6))
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", _flat(ui.cyan, 6))
	for style: StringName in BUTTON_STYLES:
		_add_button_variation(t, button_variation(style), style_color(style))
	# Plain Buttons (not made through UIKit) look like primary ones.
	_fill_button_type(t, &"Button", ui.cyan)
	_theme = t
	return t


static func _add_button_variation(t: Theme, variation: StringName, color: Color) -> void:
	t.set_type_variation(variation, &"Button")
	_fill_button_type(t, variation, color)


## Dark translucent fill, 2 px neon border, soft outer glow; pressed fills with the colour;
## disabled is dim grey with no glow.
static func _fill_button_type(t: Theme, type: StringName, color: Color) -> void:
	var ui: UITheme = current()
	var fill: Color = Color(color.r * 0.16 + 0.02, color.g * 0.16 + 0.02, color.b * 0.2 + 0.04, 0.82)
	t.set_stylebox(&"normal", type, _neon(fill, color, 0.35))
	t.set_stylebox(&"hover", type, _neon(fill.lightened(0.1), color.lightened(0.25), 0.55))
	t.set_stylebox(&"pressed", type, _neon(Color(color, 0.5), Color.WHITE, 0.7))
	t.set_stylebox(&"disabled", type, _neon(Color(0.09, 0.09, 0.12, 0.75), Color(0.32, 0.32, 0.38), 0.0))
	t.set_stylebox(&"focus", type, StyleBoxEmpty.new())
	t.set_font(&"font", type, body_font())
	t.set_font_size(&"font_size", type, ui.size_body)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		t.set_color(state, type, Color.WHITE)
	t.set_color(&"font_disabled_color", type, Color(0.48, 0.48, 0.55))
	t.set_color(&"font_outline_color", type, Color(0.0, 0.0, 0.0, 0.55))
	t.set_constant(&"outline_size", type, 5)


static func _neon(fill: Color, border: Color, glow: float) -> StyleBoxFlat:
	var ui: UITheme = current()
	var style: StyleBoxFlat = _flat(fill, ui.corner_radius)
	style.set_border_width_all(ui.button_border)
	style.border_color = border
	if glow > 0.0:
		style.shadow_color = Color(border, glow)
		style.shadow_size = ui.button_glow
	style.set_content_margin_all(20.0)
	style.anti_aliasing = true
	return style


static func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


static func _load_font(path: String, weight: int) -> Font:
	var base: FontFile = load(path) as FontFile if ResourceLoader.exists(path) else null
	var fallback: FontFile = load(FALLBACK_FONT_PATH) as FontFile if ResourceLoader.exists(FALLBACK_FONT_PATH) else null
	if base == null:
		var system: SystemFont = SystemFont.new()
		system.font_names = PackedStringArray(["Roboto", "Noto Sans", "Segoe UI", "Arial", "sans-serif"])
		system.font_weight = 800
		return system
	var v: FontVariation = FontVariation.new()
	v.base_font = base
	if weight > 0:
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	if fallback != null:
		var fb: FontVariation = FontVariation.new()
		fb.base_font = fallback
		fb.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): FALLBACK_WEIGHT}
		v.fallbacks = [fb]
	return v

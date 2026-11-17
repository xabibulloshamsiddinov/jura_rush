## The one UI theme resource (config/ui_theme.tres): palette, sizes and fonts. Swap a font or
## tweak colours there; no code changes are needed.
##
## godot_theme() turns it into ONE shared Godot `Theme` (default font, labels, chunky button
## variations, panels, sliders, scroll bars). SceneRouter sets it on the UI root, so every screen
## (menu, shop, HUD, pause, game over, settings, missions, tutorial) inherits it.
##
## Look: warm, chunky, cartoon prehistoric. Every box has a thick dark-brown outline; buttons also
## have a darker lip along the bottom edge that a press squashes (see ChunkyStyle).
class_name UITheme
extends Resource

## Body / button font (Rubik, bold). Empty = the bundled default below.
@export var font: Font
## Title / big-number font (Rubik, heavy). Empty = the bundled default below.
@export var heading_font: Font
@export var background: Color = Color(0.16, 0.10, 0.06)
@export var panel: Color = Color(0.20, 0.14, 0.10, 0.92)
@export var panel_light: Color = Color(0.30, 0.21, 0.15, 0.95)
## The dark brown outline drawn around every chunky box, glyph and icon.
@export var outline: Color = Color(0.10, 0.06, 0.035)
## Leaf green: main buttons, progress.
@export var primary: Color = Color(0.42, 0.74, 0.20)
## Stone: secondary buttons.
@export var secondary: Color = Color(0.62, 0.56, 0.48)
## Amber / orange: rewards, highlights, numbers that matter.
@export var accent: Color = Color(1.0, 0.64, 0.12)
## Lava red: warnings and destructive actions.
@export var danger: Color = Color(0.90, 0.28, 0.16)
@export var success: Color = Color(0.30, 0.80, 0.42)
@export var text: Color = Color(1.0, 0.97, 0.90)
@export var text_dim: Color = Color(0.80, 0.72, 0.60)
@export var size_title: int = 104
@export var size_h1: int = 68
@export var size_h2: int = 48
@export var size_body: int = 36
@export var size_small: int = 28
@export var corner_radius: int = 30
## Minimum touch target height in base pixels (>= 96).
@export var button_height: int = 112
## Width of the dark outline around buttons and panels, in base pixels.
@export var button_border: int = 6
## Height of the 3D lip along the bottom of a button, in base pixels.
@export var button_lip: int = 10

## Bundled open-licence fonts (SIL OFL 1.1, licences next to the files in assets/fonts).
## Rubik covers Latin and Cyrillic; Exo 2 is chained as the fallback for the few glyphs Rubik
## lacks (the Uzbek modifier letters U+02BB).
const BODY_FONT_PATH: String = "res://assets/fonts/Rubik-Variable.ttf"
const HEADING_FONT_PATH: String = "res://assets/fonts/Rubik-Variable.ttf"
const FALLBACK_FONT_PATH: String = "res://assets/fonts/Exo2-Variable.ttf"
const BODY_WEIGHT: int = 700
const HEADING_WEIGHT: int = 850
## The logo letters use Rubik's heaviest cut.
const LOGO_WEIGHT: int = 900
const FALLBACK_WEIGHT: int = 700

## Button variations: id -> palette colour name ("ghost" is derived from the stone colour).
const BUTTON_STYLES: Dictionary = {
	&"primary": &"primary",
	&"secondary": &"secondary",
	&"accent": &"accent",
	&"danger": &"danger",
	&"success": &"success",
	&"ghost": &"secondary",
}

static var _instance: UITheme = null
static var _theme: Theme = null
static var _body: Font = null
static var _heading: Font = null
static var _logo: Font = null
static var _styles: Dictionary = {}
static var _grabber: Texture2D = null


## Shared theme (falls back to defaults when the .tres is missing).
static func current() -> UITheme:
	if _instance == null:
		if ResourceLoader.exists("res://config/ui_theme.tres"):
			_instance = ResourceLoader.load("res://config/ui_theme.tres") as UITheme
		if _instance == null:
			_instance = UITheme.new()
	return _instance


## Body font with the fallback chained.
static func body_font() -> Font:
	if _body == null:
		var ui: UITheme = current()
		_body = ui.font if ui.font != null else _load_font(BODY_FONT_PATH, BODY_WEIGHT)
	return _body


## Heading font (titles, score, big numbers) with the fallback chained.
static func heading() -> Font:
	if _heading == null:
		var ui: UITheme = current()
		_heading = ui.heading_font if ui.heading_font != null else _load_font(HEADING_FONT_PATH, HEADING_WEIGHT)
	return _heading


## Heaviest weight, for the logo and other lettering that has to look carved.
static func logo_font() -> Font:
	if _logo == null:
		_logo = _load_font(HEADING_FONT_PATH, LOGO_WEIGHT)
	return _logo


## Heading font with extra room between glyphs and words (big outlined call-outs such as "TAP TO
## PLAY"). Built from the font file again: a FontVariation of a FontVariation would lose its weight.
static func spaced_heading(glyph_spacing: int, space_spacing: int) -> Font:
	return _load_font(HEADING_FONT_PATH, HEADING_WEIGHT, glyph_spacing, space_spacing)


## Theme variation name of a button style (e.g. &"ChunkyPrimary").
static func button_variation(style: StringName) -> StringName:
	var id: StringName = style if BUTTON_STYLES.has(style) else &"primary"
	return StringName("Chunky" + String(id).capitalize())


## Face colour of a button style.
static func style_color(style: StringName) -> Color:
	var ui: UITheme = current()
	var color: Color = ui.get(BUTTON_STYLES.get(style, &"primary")) as Color
	return color.darkened(0.5) if style == &"ghost" else color


## Text colour on a button style.
static func style_text_color(style: StringName) -> Color:
	var ui: UITheme = current()
	return ui.text_dim.lightened(0.2) if style == &"ghost" else ui.text


## Chunky button box for one state (&"normal", &"hover", &"pressed", &"disabled"), cached.
## `radius` < 0 uses the theme's corner radius; a radius of half the size makes a round button.
static func button_style(color: Color, state: StringName = &"normal", radius: int = -1) -> ChunkyStyle:
	var key: String = "%s|%s|%d" % [color.to_html(), state, radius]
	if _styles.has(key):
		return _styles[key] as ChunkyStyle
	var ui: UITheme = current()
	var s: ChunkyStyle = ChunkyStyle.new()
	s.outline = ui.outline
	s.outline_width = float(ui.button_border)
	s.lip = float(ui.button_lip)
	s.radius = ui.corner_radius if radius < 0 else radius
	s.face = color
	match state:
		&"hover":
			s.face = color.lightened(0.12)
		&"pressed":
			s.face = color.darkened(0.06)
			s.pressed = true
		&"disabled":
			s.face = Color(0.40, 0.35, 0.31)
			s.lip_color = Color(0.25, 0.22, 0.19)
			s.shine = 0.06
	# Content sits on the face: the pressed box drops its content by exactly the lip height.
	var side: float = s.outline_width + 18.0
	var top: float = s.outline_width + 6.0
	var bottom: float = s.outline_width + 6.0 + s.lip
	if s.pressed:
		top += s.lip
		bottom -= s.lip
	s.content_margin_left = side
	s.content_margin_right = side
	s.content_margin_top = top
	s.content_margin_bottom = bottom
	_styles[key] = s
	return s


## Flat chunky panel (stone slab): dark outline, optional coloured ring, translucent brown fill.
static func panel_style(light: bool = false, ring: Color = Color.TRANSPARENT, radius: int = -1) -> ChunkyStyle:
	var ui: UITheme = current()
	var s: ChunkyStyle = ChunkyStyle.new()
	s.face = ui.panel_light if light else ui.panel
	s.outline = ui.outline
	s.outline_width = 5.0
	s.ring = ring
	s.ring_width = 4.0
	s.lip = 0.0
	s.shine = 0.0
	s.radius = ui.corner_radius if radius < 0 else radius
	var pad: float = 20.0 + s.outline_width + (s.ring_width if ring.a > 0.0 else 0.0)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


## The single Godot Theme shared by all screens (built once from this resource).
static func godot_theme() -> Theme:
	if _theme != null:
		return _theme
	var ui: UITheme = current()
	var t: Theme = Theme.new()
	t.default_font = body_font()
	t.default_font_size = ui.size_body
	t.set_color(&"font_color", &"Label", ui.text)
	t.set_color(&"font_outline_color", &"Label", Color(ui.outline, 0.95))
	t.set_constant(&"outline_size", &"Label", 8)
	t.set_stylebox(&"panel", &"PanelContainer", panel_style())
	# Stone scroll bars (touch scrolling still drags the content itself).
	t.set_stylebox(&"scroll", &"VScrollBar", _flat(Color(0.0, 0.0, 0.0, 0.18), 6))
	t.set_stylebox(&"grabber", &"VScrollBar", _flat(Color(ui.secondary, 0.55), 6))
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", _flat(Color(ui.secondary, 0.8), 6))
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", _flat(ui.secondary, 6))
	_fill_slider(t, ui)
	for style: StringName in BUTTON_STYLES:
		_add_button_variation(t, button_variation(style), style)
	# Plain Buttons (not made through UIKit) look like primary ones.
	_fill_button_type(t, &"Button", &"primary")
	_theme = t
	return t


static func _add_button_variation(t: Theme, variation: StringName, style: StringName) -> void:
	t.set_type_variation(variation, &"Button")
	_fill_button_type(t, variation, style)


## Face in the style colour, lip a darker shade, pressed sinks onto the lip, disabled is dull stone.
static func _fill_button_type(t: Theme, type: StringName, style: StringName) -> void:
	var ui: UITheme = current()
	var color: Color = style_color(style)
	t.set_stylebox(&"normal", type, button_style(color, &"normal"))
	t.set_stylebox(&"hover", type, button_style(color, &"hover"))
	t.set_stylebox(&"pressed", type, button_style(color, &"pressed"))
	t.set_stylebox(&"hover_pressed", type, button_style(color, &"pressed"))
	t.set_stylebox(&"disabled", type, button_style(color, &"disabled"))
	t.set_stylebox(&"focus", type, StyleBoxEmpty.new())
	t.set_font(&"font", type, body_font())
	t.set_font_size(&"font_size", type, ui.size_body)
	var font_color: Color = style_text_color(style)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_focus_color"]:
		t.set_color(state, type, font_color)
	t.set_color(&"font_disabled_color", type, Color(0.70, 0.63, 0.55))
	t.set_color(&"font_outline_color", type, Color(ui.outline, 0.95))
	t.set_constant(&"outline_size", type, 8)


## Slider: dark carved groove, leaf-green fill, round cream knob with a dark outline.
static func _fill_slider(t: Theme, ui: UITheme) -> void:
	var groove: StyleBoxFlat = _flat(Color(0.09, 0.055, 0.03, 0.9), 16)
	groove.set_border_width_all(3)
	groove.border_color = Color(ui.outline, 0.9)
	groove.content_margin_top = 13.0
	groove.content_margin_bottom = 13.0
	t.set_stylebox(&"slider", &"HSlider", groove)
	for name: StringName in [&"grabber_area", &"grabber_area_highlight"]:
		var fill: StyleBoxFlat = _flat(ui.primary, 16)
		fill.set_border_width_all(3)
		fill.border_color = Color(ui.outline, 0.9)
		fill.content_margin_top = 13.0
		fill.content_margin_bottom = 13.0
		t.set_stylebox(name, &"HSlider", fill)
	var knob: Texture2D = _grabber_texture()
	for name: StringName in [&"grabber", &"grabber_highlight", &"grabber_disabled"]:
		t.set_icon(name, &"HSlider", knob)


## Round knob drawn once into a texture: cream face, dark outline, small highlight.
static func _grabber_texture() -> Texture2D:
	if _grabber != null:
		return _grabber
	var ui: UITheme = current()
	var size: int = 64
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(c)
			var edge: float = clampf(31.0 - d, 0.0, 1.0)
			var rim: float = clampf(d - 22.0, 0.0, 1.0)
			var face: Color = ui.text.lerp(Color(1.0, 1.0, 1.0), clampf((c.y - float(y)) / 30.0, 0.0, 1.0) * 0.5)
			var color: Color = face.lerp(ui.outline, rim)
			color.a = edge
			image.set_pixel(x, y, color)
	_grabber = ImageTexture.create_from_image(image)
	return _grabber


static func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


static func _load_font(path: String, weight: int, glyph_spacing: int = 0, space_spacing: int = 0) -> Font:
	var base: FontFile = load(path) as FontFile if ResourceLoader.exists(path) else null
	var fallback: FontFile = load(FALLBACK_FONT_PATH) as FontFile if ResourceLoader.exists(FALLBACK_FONT_PATH) else null
	if base == null:
		var system: SystemFont = SystemFont.new()
		system.font_names = PackedStringArray(["Roboto", "Noto Sans", "Segoe UI", "Arial", "sans-serif"])
		system.font_weight = 800
		return system
	var v: FontVariation = FontVariation.new()
	v.base_font = base
	v.spacing_glyph = glyph_spacing
	v.spacing_space = space_spacing
	if weight > 0:
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	if fallback != null:
		var fb: FontVariation = FontVariation.new()
		fb.base_font = fallback
		fb.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): FALLBACK_WEIGHT}
		v.fallbacks = [fb]
	return v

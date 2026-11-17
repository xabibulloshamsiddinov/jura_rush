## UI building blocks. Screens are assembled in code from these helpers so the whole interface
## shares one look (warm prehistoric cartoon: chunky outlined buttons and stone panels, big touch
## targets).
class_name UIKit
extends RefCounted

## Body font of the shared theme (Rubik bold + fallback).
static func font() -> Font:
	return UITheme.body_font()


## Heading font of the shared theme (Rubik heavy + fallback).
static func heading_font() -> Font:
	return UITheme.heading()


## Font size after the "large text" accessibility option.
static func scaled(size: int) -> int:
	return int(float(size) * (1.2 if SettingsManager.get_bool("large_text") else 1.0))


## Outline thickness that suits a font size (already scaled): thick enough to read as cartoon
## lettering, thin enough not to fill the counters of the glyphs.
static func outline_for(font_size: int) -> int:
	return clampi(roundi(float(font_size) * 0.16), 6, 18)


## Text label.
static func label(text: String, size: int, color: Color = Color.WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Big text (titles, score, headings) uses the heavy heading weight.
	node.add_theme_font_override(&"font", heading_font() if size >= UITheme.current().size_h1 else font())
	node.add_theme_font_size_override(&"font_size", scaled(size))
	node.add_theme_color_override(&"font_color", color)
	node.add_theme_color_override(&"font_outline_color", Color(UITheme.current().outline, 0.95))
	node.add_theme_constant_override(&"outline_size", outline_for(scaled(size)))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Shrinks a label's font until its text (plus outline) fits `max_width`. Long translations
## (Russian, Uzbek) use this on fixed-width buttons instead of running off the edge.
static func fit_label(node: Label, max_width: float) -> void:
	var font: Font = node.get_theme_font(&"font")
	var px: int = node.get_theme_font_size(&"font_size")
	var outline: int = node.get_theme_constant(&"outline_size")
	var width: float = font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + float(outline)
	if width <= max_width or width <= 0.0:
		return
	var factor: float = max_width / width
	node.add_theme_font_size_override(&"font_size", maxi(int(float(px) * factor), 16))
	node.add_theme_constant_override(&"outline_size", maxi(int(float(outline) * factor), 4))


## Heavier outline for text that floats over the 3D world (multiplier, distance, "tap to play").
static func strong_outline(node: Label, extra: int = 4) -> void:
	node.add_theme_color_override(&"font_outline_color", Color(UITheme.current().outline, 1.0))
	node.add_theme_constant_override(&"outline_size", node.get_theme_constant(&"outline_size") + extra)


## Rounded flat style box (progress bars, badges, plain fills).
static func box(color: Color, radius: int = -1, border: Color = Color.TRANSPARENT,
		border_width: int = 0, margin: float = 20.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	var r: int = UITheme.current().corner_radius if radius < 0 else radius
	style.set_corner_radius_all(r)
	style.set_border_width_all(border_width)
	style.border_color = border
	style.set_content_margin_all(margin)
	return style


## Chunky button from the shared theme. style: &"primary" (leaf green), &"secondary" (stone),
## &"accent" (amber), &"success" (green), &"danger" (lava red), &"ghost" (dark stone). &"gold" is
## an old alias of &"accent". Disabled buttons automatically use the dull stone style.
static func button(text: String, style: StringName = &"primary", min_width: float = 0.0) -> UIButton:
	var theme: UITheme = UITheme.current()
	if style == &"gold":
		style = &"accent"
	var node: UIButton = UIButton.new()
	node.text = text
	node.custom_minimum_size = Vector2(min_width, float(theme.button_height))
	node.theme_type_variation = UITheme.button_variation(style)
	node.add_theme_font_size_override(&"font_size", scaled(theme.size_body))
	return node


## Round icon button (the left / right columns of the main menu, the settings gear). The icon sits
## on the face and drops with it when pressed.
static func round_button(icon: UIIcon.Kind, style: StringName = &"secondary", diameter: float = 128.0) -> UIButton:
	var node: UIButton = UIButton.new()
	node.custom_minimum_size = Vector2(diameter, diameter)
	var color: Color = UITheme.style_color(style)
	var radius: int = int(diameter * 0.5)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		node.add_theme_stylebox_override(state, UITheme.button_style(color, state, radius))
	node.add_theme_stylebox_override(&"hover_pressed", UITheme.button_style(color, &"pressed", radius))
	node.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	var center: CenterContainer = CenterContainer.new()
	center.add_child(UIIcon.new(icon, diameter * 0.58))
	node.attach_content(center, 0, 0)
	return node


## Square "back" button with a drawn chevron (screens connect `pressed` themselves).
static func back_button(size: float = 120.0) -> UIButton:
	var node: UIButton = button("", &"ghost", size)
	node.custom_minimum_size = Vector2(size, float(UITheme.current().button_height))
	node.feedback = &"back"
	var chevron: Control = Control.new()
	chevron.custom_minimum_size = Vector2(40.0, 56.0)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui: UITheme = UITheme.current()
	chevron.draw.connect(func() -> void:
		var points: PackedVector2Array = PackedVector2Array([Vector2(30.0, 6.0), Vector2(10.0, 28.0), Vector2(30.0, 50.0)])
		chevron.draw_polyline(points, ui.outline, 17.0, true)
		chevron.draw_polyline(points, ui.text, 9.0, true)
		for p: Vector2 in [points[0], points[2]]:
			chevron.draw_circle(p, 8.5, ui.outline, true, -1.0, true)
			chevron.draw_circle(p, 4.5, ui.text, true, -1.0, true))
	var center: CenterContainer = CenterContainer.new()
	center.add_child(chevron)
	node.attach_content(center, 0, 0)
	return node


## Stone-slab panel container with the dark outline (optionally a coloured ring inside it).
static func panel(light: bool = false, border: Color = Color.TRANSPARENT) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	node.add_theme_stylebox_override(&"panel", UITheme.panel_style(light, border))
	return node


## Small dark capsule that holds an icon and a number (currency, best score).
static func pill(content: Control, radius: int = 40) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	var style: ChunkyStyle = UITheme.panel_style(false, Color.TRANSPARENT, radius)
	style.face = Color(0.13, 0.08, 0.05, 0.82)
	style.outline_width = 4.0
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	node.add_theme_stylebox_override(&"panel", style)
	node.add_child(content)
	return node


## Vertical box with spacing.
static func vbox(separation: int = 20) -> VBoxContainer:
	var node: VBoxContainer = VBoxContainer.new()
	node.add_theme_constant_override(&"separation", separation)
	return node


## Horizontal box with spacing.
static func hbox(separation: int = 20) -> HBoxContainer:
	var node: HBoxContainer = HBoxContainer.new()
	node.add_theme_constant_override(&"separation", separation)
	return node


## Invisible expanding spacer.
static func spacer(min_height: float = 0.0) -> Control:
	var node: Control = Control.new()
	node.custom_minimum_size = Vector2(0.0, min_height)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Wraps a control in margins.
static func margin(child: Control, horizontal: int, vertical: int) -> MarginContainer:
	var node: MarginContainer = MarginContainer.new()
	node.add_theme_constant_override(&"margin_left", horizontal)
	node.add_theme_constant_override(&"margin_right", horizontal)
	node.add_theme_constant_override(&"margin_top", vertical)
	node.add_theme_constant_override(&"margin_bottom", vertical)
	node.add_child(child)
	return node


## Chunky progress bar: a carved dark groove with a coloured fill.
static func progress(value: float, max_value: float, color: Color) -> ProgressBar:
	var ui: UITheme = UITheme.current()
	var node: ProgressBar = ProgressBar.new()
	node.max_value = max_value
	node.value = value
	node.show_percentage = false
	node.custom_minimum_size = Vector2(0.0, 28.0)
	node.add_theme_stylebox_override(&"background", box(Color(0.09, 0.055, 0.03, 0.9), 14,
			Color(ui.outline, 0.95), 3, 0.0))
	node.add_theme_stylebox_override(&"fill", box(color, 14, Color(ui.outline, 0.95), 3, 0.0))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Opaque warm-brown backdrop (soft vertical gradient) for screens that own the whole display. It
## swallows clicks so nothing behind it can be tapped.
static func backdrop() -> TextureRect:
	var ui: UITheme = UITheme.current()
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([ui.background.lightened(0.14), ui.background.darkened(0.2)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 128
	var node: TextureRect = TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	fill(node)
	return node


## Full-rect dimmer behind popups (a warm near-black so it does not turn the scene blue).
static func dimmer(alpha: float = 0.6) -> ColorRect:
	var node: ColorRect = ColorRect.new()
	node.color = Color(0.06, 0.035, 0.015, alpha)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	return node


## "icon + number" label used for eggs and amber.
static func counter(symbol: String, color: Color) -> Label:
	var node: Label = label(symbol + " 0", UITheme.current().size_body, color, HORIZONTAL_ALIGNMENT_LEFT)
	return node


## Makes a control fill its parent.
static func fill(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0

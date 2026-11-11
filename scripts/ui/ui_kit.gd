## UI building blocks. Screens are assembled in code from these helpers so the whole interface
## shares one look (dark city + neon, rounded panels, big touch targets).
class_name UIKit
extends RefCounted

static var _font: Font = null


## The UI font: the theme's font if set, otherwise a bold system sans-serif.
static func font() -> Font:
	if _font == null:
		_font = UITheme.current().font
		if _font == null:
			var system: SystemFont = SystemFont.new()
			system.font_names = PackedStringArray(["Roboto", "Noto Sans", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
			system.font_weight = 800
			_font = system
	return _font


## Font size after the "large text" accessibility option.
static func scaled(size: int) -> int:
	return int(float(size) * (1.2 if SettingsManager.get_bool("large_text") else 1.0))


## Text label.
static func label(text: String, size: int, color: Color = Color.WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override(&"font", font())
	node.add_theme_font_size_override(&"font_size", scaled(size))
	node.add_theme_color_override(&"font_color", color)
	node.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	node.add_theme_constant_override(&"outline_size", 6)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Rounded flat style box.
static func box(color: Color, radius: int = -1, border: Color = Color.TRANSPARENT,
		border_width: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	var r: int = UITheme.current().corner_radius if radius < 0 else radius
	style.set_corner_radius_all(r)
	style.set_border_width_all(border_width)
	style.border_color = border
	style.set_content_margin_all(20.0)
	return style


## Neon button. style: &"primary" (cyan), &"accent" (magenta), &"gold", &"ghost", &"danger".
static func button(text: String, style: StringName = &"primary", min_width: float = 0.0) -> UIButton:
	var theme: UITheme = UITheme.current()
	var node: UIButton = UIButton.new()
	node.text = text
	node.custom_minimum_size = Vector2(min_width, float(theme.button_height))
	var color: Color = theme.cyan
	match style:
		&"accent":
			color = theme.magenta
		&"gold":
			color = theme.yellow
		&"danger":
			color = theme.danger
		&"ghost":
			color = theme.text_dim
	var fill: Color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.28, 0.92)
	node.add_theme_stylebox_override(&"normal", box(fill, -1, color, 4))
	node.add_theme_stylebox_override(&"hover", box(fill.lightened(0.12), -1, color.lightened(0.2), 4))
	node.add_theme_stylebox_override(&"pressed", box(Color(color, 0.55), -1, Color.WHITE, 4))
	node.add_theme_stylebox_override(&"disabled", box(Color(0.1, 0.1, 0.14, 0.8), -1, Color(0.3, 0.3, 0.36), 3))
	node.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	node.add_theme_font_override(&"font", font())
	node.add_theme_font_size_override(&"font_size", scaled(theme.size_body))
	node.add_theme_color_override(&"font_color", Color.WHITE)
	node.add_theme_color_override(&"font_hover_color", Color.WHITE)
	node.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	node.add_theme_color_override(&"font_disabled_color", Color(0.5, 0.5, 0.56))
	node.ripple_color = color.lightened(0.4)
	return node


## Rounded panel container.
static func panel(light: bool = false, border: Color = Color.TRANSPARENT) -> PanelContainer:
	var theme: UITheme = UITheme.current()
	var node: PanelContainer = PanelContainer.new()
	node.add_theme_stylebox_override(&"panel", box(theme.panel_light if light else theme.panel, -1,
			border, 3 if border.a > 0.0 else 0))
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


## Thin rounded progress bar.
static func progress(value: float, max_value: float, color: Color) -> ProgressBar:
	var node: ProgressBar = ProgressBar.new()
	node.max_value = max_value
	node.value = value
	node.show_percentage = false
	node.custom_minimum_size = Vector2(0.0, 22.0)
	node.add_theme_stylebox_override(&"background", box(Color(0.0, 0.0, 0.0, 0.5), 11))
	node.add_theme_stylebox_override(&"fill", box(color, 11))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Full-rect dimmer behind popups.
static func dimmer(alpha: float = 0.6) -> ColorRect:
	var node: ColorRect = ColorRect.new()
	node.color = Color(0.0, 0.0, 0.03, alpha)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	return node


## "icon + number" pill used for coins and keys.
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

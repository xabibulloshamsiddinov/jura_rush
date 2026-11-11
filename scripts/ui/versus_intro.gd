## 2 Player intro: shows each player's keys (WASD / arrows), the rules and the power-ups.
## Each player presses their FIRE key to get ready; the race starts when both are ready
## (or with the START button).
extends UIScreen

## Keycap drawn in code (works with any font, arrows included).
class KeyCap extends Control:
	var text: String = ""
	## 0 none, 1 up, 2 left, 3 down, 4 right.
	var arrow: int = 0
	var color: Color = Color.WHITE
	var lit: float = 0.0

	func _init(label_text: String, arrow_dir: int, tint: Color, width: float = 104.0) -> void:
		text = label_text
		arrow = arrow_dir
		color = tint
		custom_minimum_size = Vector2(width, 104.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var face: StyleBoxFlat = StyleBoxFlat.new()
		face.bg_color = Color(color.r * 0.18, color.g * 0.18, color.b * 0.24, 0.95).lerp(Color(color, 0.85), lit)
		face.set_corner_radius_all(16)
		face.set_border_width_all(4)
		face.border_width_bottom = 10
		face.border_color = color.lerp(Color.WHITE, lit * 0.6)
		draw_style_box(face, rect)
		var c: Vector2 = rect.get_center() - Vector2(0, 3)
		if arrow > 0:
			var s: float = 22.0
			var pts: PackedVector2Array = PackedVector2Array([Vector2(0, -s), Vector2(s, s * 0.7), Vector2(-s, s * 0.7)])
			var angle: float = [0.0, 0.0, -PI * 0.5, PI, PI * 0.5][arrow]
			var out: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in pts:
				out.append(c + p.rotated(angle))
			draw_colored_polygon(out, Color.WHITE)
			return
		var font: Font = UIKit.font()
		var fs: int = 40 if text.length() <= 2 else 30
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


var _ready_flags: Array[bool] = [false, false]
var _ready_labels: Array[Label] = []
var _caps: Array[Dictionary] = [{}, {}]
var _start_left: float = -1.0
var _start: UIButton = null


func build() -> void:
	VsInput.ensure()
	var ui: UITheme = UITheme.current()
	add_child(_backdrop())
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.fill(scroll)
	add_child(scroll)
	var column: VBoxContainer = UIKit.vbox(26)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var wrap: MarginContainer = UIKit.margin(column, 60, 50)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(wrap)
	var title: Label = UIKit.label(VsDefs.TITLE, ui.size_title, Color(1.0, 0.55, 0.15))
	title.add_theme_color_override(&"font_outline_color", Color(0.6, 0.05, 0.3, 0.9))
	title.add_theme_constant_override(&"outline_size", 18)
	column.add_child(title)
	column.add_child(UIKit.label(tr_key(&"vs.subtitle"), ui.size_body, ui.text_dim))
	var flow: HFlowContainer = HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override(&"h_separation", 30)
	flow.add_theme_constant_override(&"v_separation", 30)
	column.add_child(flow)
	flow.add_child(_player_panel(0))
	flow.add_child(_rules_panel())
	flow.add_child(_player_panel(1))
	var buttons: HBoxContainer = UIKit.hbox(30)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var back: UIButton = UIKit.button(tr_key(&"common.back"), &"ghost", 300.0)
	back.feedback = &"back"
	back.pressed.connect(func() -> void: GameEvents.request_versus_exit.emit())
	buttons.add_child(back)
	_start = UIKit.button(tr_key(&"vs.start"), &"gold", 560.0)
	_start.custom_minimum_size = Vector2(560.0, 130.0)
	_start.add_theme_font_size_override(&"font_size", UIKit.scaled(ui.size_h2))
	_start.feedback = &"confirm"
	_start.pressed.connect(_go)
	buttons.add_child(_start)


func on_enter(_args: Dictionary) -> void:
	_ready_flags = [false, false]
	_start_left = -1.0
	for i in range(2):
		_refresh_ready(i)
	UITween.pulse(_start)


func handle_back() -> bool:
	GameEvents.request_versus_exit.emit()
	return true


func _process(delta: float) -> void:
	if not visible:
		return
	for i in range(2):
		var p: String = "vs%d_" % (i + 1)
		var caps: Dictionary = _caps[i]
		for action: String in caps.keys():
			var cap: KeyCap = caps[action] as KeyCap
			var goal: float = 1.0 if Input.is_action_pressed(StringName(p + action)) else 0.0
			if not is_equal_approx(cap.lit, goal):
				cap.lit = move_toward(cap.lit, goal, delta * 8.0)
				cap.queue_redraw()
		if Input.is_action_just_pressed(StringName(p + "fire")) and _start_left < 0.0:
			_ready_flags[i] = not _ready_flags[i]
			GameEvents.ui_feedback.emit(&"confirm" if _ready_flags[i] else &"back")
			_refresh_ready(i)
			if _ready_flags[0] and _ready_flags[1]:
				_start_left = 0.6
	if _start_left >= 0.0:
		_start_left -= delta
		if _start_left < 0.0:
			_go()


func _go() -> void:
	_start_left = -1.0
	GameEvents.request_versus_start.emit()


func _refresh_ready(i: int) -> void:
	if i >= _ready_labels.size():
		return
	var l: Label = _ready_labels[i]
	if _ready_flags[i]:
		l.text = tr_key(&"vs.ready")
		l.add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.5))
		UITween.pop(l, 0.0, 0.7)
	else:
		l.text = Tr.f(&"vs.ready_hint", {"k": "SPACE" if i == 0 else "ENTER"})
		l.add_theme_color_override(&"font_color", UITheme.current().text_dim)


func _player_panel(i: int) -> Control:
	var ui: UITheme = UITheme.current()
	var col: Color = VsDefs.PLAYER_COLORS[i]
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _panel_style(col))
	panel.custom_minimum_size = Vector2(760.0, 0.0)
	var box: VBoxContainer = UIKit.vbox(18)
	panel.add_child(box)
	var head: Label = UIKit.label(tr_key(&"vs.p1" if i == 0 else &"vs.p2"), ui.size_h1, col)
	box.add_child(head)
	var stripe: ColorRect = ColorRect.new()
	stripe.color = col
	stripe.custom_minimum_size = Vector2(0.0, 6.0)
	box.add_child(stripe)
	var caps: Dictionary = {}
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	var arrows: bool = i == 1
	var up: KeyCap = KeyCap.new("" if arrows else "W", 1 if arrows else 0, col)
	var left: KeyCap = KeyCap.new("" if arrows else "A", 2 if arrows else 0, col)
	var down: KeyCap = KeyCap.new("" if arrows else "S", 3 if arrows else 0, col)
	var right: KeyCap = KeyCap.new("" if arrows else "D", 4 if arrows else 0, col)
	grid.add_child(_gap())
	grid.add_child(up)
	grid.add_child(_gap())
	grid.add_child(left)
	grid.add_child(down)
	grid.add_child(right)
	caps["gas"] = up
	caps["left"] = left
	caps["brake"] = down
	caps["right"] = right
	var center: CenterContainer = CenterContainer.new()
	center.add_child(grid)
	box.add_child(center)
	var fire: KeyCap = KeyCap.new("ENTER" if arrows else "SPACE", 0, col, 230.0)
	var cycle: KeyCap = KeyCap.new("R-SHIFT" if arrows else "Q", 0, col, 230.0 if arrows else 104.0)
	caps["fire"] = fire
	caps["cycle"] = cycle
	_caps[i] = caps
	var rows: VBoxContainer = UIKit.vbox(8)
	rows.add_child(_binding(KeyCap.new("" if arrows else "W", 1 if arrows else 0, col, 84.0), tr_key(&"vs.gas")))
	rows.add_child(_binding(KeyCap.new("" if arrows else "S", 3 if arrows else 0, col, 84.0), tr_key(&"vs.brake")))
	var lr: HBoxContainer = UIKit.hbox(6)
	lr.add_child(KeyCap.new("" if arrows else "A", 2 if arrows else 0, col, 84.0))
	lr.add_child(KeyCap.new("" if arrows else "D", 4 if arrows else 0, col, 84.0))
	rows.add_child(_binding(lr, tr_key(&"vs.lanes")))
	rows.add_child(_binding(fire, tr_key(&"vs.fire")))
	rows.add_child(_binding(cycle, tr_key(&"vs.switch")))
	box.add_child(rows)
	var ready_label: Label = UIKit.label("", ui.size_body, ui.text_dim)
	ready_label.custom_minimum_size = Vector2(0.0, 70.0)
	box.add_child(ready_label)
	if _ready_labels.size() <= i:
		_ready_labels.resize(i + 1)
	_ready_labels[i] = ready_label
	return panel


func _rules_panel() -> Control:
	var ui: UITheme = UITheme.current()
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _panel_style(Color(0.75, 0.35, 1.0)))
	panel.custom_minimum_size = Vector2(1100.0, 0.0)
	var box: VBoxContainer = UIKit.vbox(14)
	panel.add_child(box)
	box.add_child(UIKit.label(tr_key(&"vs.how"), ui.size_h2, ui.text))
	for key: StringName in [&"vs.rule1", &"vs.rule2", &"vs.rule3", &"vs.rule4"]:
		var line: Label = UIKit.label("•  " + tr_key(key), ui.size_small + 2, ui.text, HORIZONTAL_ALIGNMENT_LEFT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)
	box.add_child(UIKit.spacer(8.0))
	box.add_child(UIKit.label(tr_key(&"vs.powerups"), ui.size_h2, ui.text))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 14)
	box.add_child(grid)
	for id: StringName in VsDefs.POWERUPS:
		var row: HBoxContainer = UIKit.hbox(14)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(VsIcon.new(id, 84.0))
		var text: VBoxContainer = UIKit.vbox(0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label: Label = UIKit.label(VsDefs.title(id), ui.size_small + 2, VsDefs.color(id).lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT)
		text.add_child(name_label)
		var desc: Label = UIKit.label(tr_key(StringName("vs.pu." + String(id) + ".desc")), ui.size_small - 3, ui.text_dim, HORIZONTAL_ALIGNMENT_LEFT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(420.0, 0.0)
		text.add_child(desc)
		row.add_child(text)
		grid.add_child(row)
	var tip: Label = UIKit.label(tr_key(&"vs.back_tip"), ui.size_small, Color(1.0, 0.85, 0.3))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	return panel


func _binding(key: Control, text: String) -> HBoxContainer:
	var row: HBoxContainer = UIKit.hbox(18)
	var holder: HBoxContainer = UIKit.hbox(0)
	holder.custom_minimum_size = Vector2(250.0, 0.0)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_child(key)
	row.add_child(holder)
	var l: Label = UIKit.label(text, UITheme.current().size_small + 2, UITheme.current().text, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _gap() -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(104.0, 104.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _panel_style(border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = UIKit.box(Color(0.03, 0.03, 0.08, 0.86), 26, border, 4)
	style.set_content_margin_all(30.0)
	style.shadow_color = Color(border, 0.35)
	style.shadow_size = 24
	return style


## Dark gradient wash with neon streaks behind the intro.
func _backdrop() -> Control:
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(0.015, 0.01, 0.04, 0.9)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect

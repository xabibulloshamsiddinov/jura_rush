## 2 Player HUD: one corner panel per player (lives, health, three power-up slots, police
## meter, status), the match clock, per-player callouts, the countdown, the pause menu and the
## results card. Reads the match through Services.locate(&"versus").snapshot() and talks back
## only with GameEvents.request_versus_* signals.
extends UIScreen

## Small car silhouettes for the remaining lives.
class Lives extends Control:
	var count: int = 3
	var color: Color = Color.WHITE

	func _init(tint: Color) -> void:
		color = tint
		custom_minimum_size = Vector2(3.0 * 70.0, 50.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for k in range(VsDefs.LIVES):
			var on: bool = k < count
			var x: float = float(k) * 70.0 + 6.0
			var c: Color = color if on else Color(1.0, 1.0, 1.0, 0.14)
			draw_rect(Rect2(x, 18.0, 58.0, 20.0), c)
			draw_rect(Rect2(x + 12.0, 6.0, 32.0, 16.0), c)
			draw_circle(Vector2(x + 13.0, 40.0), 7.0, Color(0.0, 0.0, 0.0, 0.8) if on else Color(1, 1, 1, 0.1))
			draw_circle(Vector2(x + 45.0, 40.0), 7.0, Color(0.0, 0.0, 0.0, 0.8) if on else Color(1, 1, 1, 0.1))


## Segmented health bar that flashes when damage lands.
class Health extends Control:
	var value: float = 1.0
	var shown: float = 1.0
	var color: Color = Color.WHITE
	var flash: float = 0.0

	func _init(tint: Color) -> void:
		color = tint
		custom_minimum_size = Vector2(560.0, 34.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float, delta: float) -> void:
		if v < value - 0.001:
			flash = 1.0
		value = v
		shown = move_toward(shown, value, delta * 0.6) if shown > value else value
		flash = maxf(flash - delta * 3.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.55))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * shown, size.y)), Color(1.0, 1.0, 1.0, 0.55))
		var fill: Color = color
		if value < 0.3:
			fill = Color(1.0, 0.2, 0.2).lerp(Color(1.0, 0.6, 0.6), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), fill.lerp(Color.WHITE, flash * 0.6))
		for k in range(1, 10):
			var x: float = size.x * float(k) / 10.0
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(0.0, 0.0, 0.0, 0.5), 3.0)
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.35), false, 2.0)


class PlayerPanel extends RefCounted:
	var root: PanelContainer = null
	var lives: Lives = null
	var health: Health = null
	var fans: Label = null
	var slots: Array[VsIcon] = []
	var active_name: Label = null
	var police: ProgressBar = null
	var police_label: Label = null
	var status: Label = null
	var callout: Label = null
	var callout_tween: Tween = null
	var last_slots: Array = []


var _sides: Array[PlayerPanel] = []
var _clock: Label = null
var _countdown: Label = null
var _hint: Label = null
var _pause_layer: Control = null
var _result_layer: Control = null
var _result_box: VBoxContainer = null
var _paused: bool = false
var _finished: bool = false


func build() -> void:
	var ui: UITheme = UITheme.current()
	_sides.clear()
	for i in range(2):
		_sides.append(_build_side(i))
	var top: VBoxContainer = UIKit.vbox(4)
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 30.0
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(top)
	_clock = UIKit.label("3:00", ui.size_h1, ui.text)
	top.add_child(_clock)
	var pause: UIButton = UIKit.button("II", &"ghost", 110.0)
	pause.custom_minimum_size = Vector2(110.0, 96.0)
	pause.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pause.pressed.connect(func() -> void: _set_paused(true))
	top.add_child(pause)
	_countdown = UIKit.label("", 300, ui.text)
	UIKit.fill(_countdown)
	_countdown.visible = false
	add_child(_countdown)
	_hint = UIKit.label(tr_key(&"vs.keys_hint"), ui.size_small - 4, Color(1.0, 1.0, 1.0, 0.45))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -70.0
	_hint.offset_bottom = -24.0
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_hint)
	_build_pause()
	_build_results()


func connect_events() -> void:
	GameEvents.versus_countdown.connect(_on_countdown)
	GameEvents.versus_callout.connect(_on_callout)
	GameEvents.versus_finished.connect(_on_finished)


func on_enter(_args: Dictionary) -> void:
	_paused = false
	_finished = false
	_pause_layer.visible = false
	_result_layer.visible = false
	for s: PlayerPanel in _sides:
		s.callout.modulate.a = 0.0
		s.last_slots = []


func handle_back() -> bool:
	if _finished:
		GameEvents.request_versus_exit.emit()
	else:
		_set_paused(not _paused)
	return true


func _process(delta: float) -> void:
	if not visible:
		return
	var game: Object = Services.locate(&"versus")
	if game == null:
		return
	var snap: Dictionary = game.call(&"snapshot")
	var t: float = float(snap["time"])
	_clock.text = MathUtils.time_text(ceilf(t))
	_clock.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.3) if t < 20.0 else UITheme.current().text)
	var players: Array = snap["players"]
	for i in range(2):
		_update_side(_sides[i], players[i], delta)
	if Input.is_action_just_pressed(&"vs_pause_key"):
		_set_paused(not _paused)


func _update_side(s: PlayerPanel, p: Dictionary, delta: float) -> void:
	s.lives.count = int(p["lives"])
	s.lives.queue_redraw()
	s.health.set_value(float(p["health"]), delta)
	s.fans.text = "%s %s" % [MathUtils.group_digits(int(p["fans"])), tr_key(&"vs.fans")]
	var slots: Array = p["slots"]
	if slots != s.last_slots:
		var grew: bool = slots.size() > s.last_slots.size()
		s.last_slots = slots.duplicate()
		for k in range(VsDefs.SLOTS):
			s.slots[k].id = slots[k] if k < slots.size() else &""
			s.slots[k].active = k == 0
		if grew:
			UITween.bump(s.slots[mini(slots.size() - 1, VsDefs.SLOTS - 1)], 1.3)
		elif not slots.is_empty():
			UITween.bump(s.slots[0], 1.15)
		s.active_name.text = VsDefs.title(slots[0]) if not slots.is_empty() else ""
		if not slots.is_empty():
			s.active_name.add_theme_color_override(&"font_color", VsDefs.color(slots[0]).lightened(0.3))
	var bust: float = float(p["bust"])
	s.police.value = bust
	var near: bool = bust > 0.02 or float(p["police_gap"]) < VsDefs.BUST_RANGE + 3.0
	s.police_label.visible = near and bool(p["alive"]) and not _finished
	if s.police_label.visible:
		var blink: bool = fmod(Time.get_ticks_msec() * 0.001, 0.36) < 0.18
		s.police_label.add_theme_color_override(&"font_color", Color(1.0, 0.2, 0.25) if blink else Color(0.3, 0.5, 1.0))
	var status: String = ""
	var status_color: Color = UITheme.current().text_dim
	if not bool(p["alive"]):
		if int(p["lives"]) <= 0:
			status = tr_key(&"vs.out")
			status_color = Color(1.0, 0.3, 0.3)
		else:
			status = Tr.f(&"vs.respawning", {"n": "%.1f" % maxf(float(p["respawn"]), 0.0)})
	elif float(p["shield"]) > 0.0:
		status = "%s  %.1f" % [VsDefs.title(&"shield"), float(p["shield"])]
		status_color = VsDefs.color(&"shield").lightened(0.3)
	elif float(p["nitro"]) > 0.0:
		status = VsDefs.title(&"nitro") + "!"
		status_color = VsDefs.color(&"nitro")
	elif float(p["jam"]) > 0.0:
		status = VsDefs.title(&"emp") + "!"
		status_color = VsDefs.color(&"emp")
	s.status.text = status
	s.status.add_theme_color_override(&"font_color", status_color)


func _build_side(i: int) -> PlayerPanel:
	var ui: UITheme = UITheme.current()
	var col: Color = VsDefs.PLAYER_COLORS[i]
	var s: PlayerPanel = PlayerPanel.new()
	var right: bool = i == 1
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = UIKit.box(Color(0.02, 0.02, 0.06, 0.72), 24, Color(col, 0.9), 3)
	style.set_content_margin_all(22.0)
	style.shadow_color = Color(col, 0.25)
	style.shadow_size = 16
	panel.add_theme_stylebox_override(&"panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	panel.offset_left = -40.0 if right else 40.0
	panel.offset_right = -40.0 if right else 40.0
	panel.offset_top = 36.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	s.root = panel
	var box: VBoxContainer = UIKit.vbox(10)
	panel.add_child(box)
	var head: HBoxContainer = UIKit.hbox(16)
	var tag: Label = UIKit.label("P%d" % (i + 1), ui.size_h2, col, HORIZONTAL_ALIGNMENT_LEFT)
	s.lives = Lives.new(col)
	s.fans = UIKit.label("0", ui.size_small, Color(1.0, 0.85, 0.3), HORIZONTAL_ALIGNMENT_RIGHT if not right else HORIZONTAL_ALIGNMENT_LEFT)
	s.fans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if right:
		head.add_child(s.fans)
		head.add_child(s.lives)
		head.add_child(tag)
	else:
		head.add_child(tag)
		head.add_child(s.lives)
		head.add_child(s.fans)
	box.add_child(head)
	s.health = Health.new(col)
	box.add_child(s.health)
	var row: HBoxContainer = UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
	s.slots.clear()
	for k in range(VsDefs.SLOTS):
		var icon: VsIcon = VsIcon.new(&"", 128.0 if k == 0 else 92.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.resized.connect(func() -> void: icon.pivot_offset = icon.size * 0.5)
		s.slots.append(icon)
	var info: VBoxContainer = UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.active_name = UIKit.label("", ui.size_body, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
	s.status = UIKit.label("", ui.size_small, ui.text_dim, HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
	info.add_child(s.active_name)
	info.add_child(s.status)
	if right:
		row.add_child(info)
		for k in range(VsDefs.SLOTS - 1, -1, -1):
			row.add_child(s.slots[k])
	else:
		for icon: VsIcon in s.slots:
			row.add_child(icon)
		row.add_child(info)
	box.add_child(row)
	var cop_row: HBoxContainer = UIKit.hbox(12)
	s.police = UIKit.progress(0.0, 1.0, Color(1.0, 0.2, 0.3))
	s.police.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.police.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.police_label = UIKit.label(tr_key(&"vs.police"), ui.size_small, Color(1.0, 0.25, 0.3))
	s.police_label.custom_minimum_size = Vector2(220.0, 0.0)
	if right:
		cop_row.add_child(s.police_label)
		cop_row.add_child(s.police)
	else:
		cop_row.add_child(s.police)
		cop_row.add_child(s.police_label)
	box.add_child(cop_row)
	# Callout for this player, shown over their half of the screen.
	s.callout = UIKit.label("", ui.size_h1 + 10, col)
	s.callout.add_theme_constant_override(&"outline_size", 14)
	s.callout.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.callout.anchor_left = 0.5 if right else 0.0
	s.callout.anchor_right = 1.0 if right else 0.5
	s.callout.anchor_top = 0.42
	s.callout.anchor_bottom = 0.55
	s.callout.offset_left = 0.0
	s.callout.offset_right = 0.0
	s.callout.offset_top = 0.0
	s.callout.offset_bottom = 0.0
	s.callout.modulate.a = 0.0
	s.callout.resized.connect(func() -> void: s.callout.pivot_offset = s.callout.size * 0.5)
	add_child(s.callout)
	return s


func _build_pause() -> void:
	var ui: UITheme = UITheme.current()
	_pause_layer = Control.new()
	UIKit.fill(_pause_layer)
	_pause_layer.visible = false
	add_child(_pause_layer)
	_pause_layer.add_child(UIKit.dimmer(0.65))
	var center: CenterContainer = CenterContainer.new()
	UIKit.fill(center)
	_pause_layer.add_child(center)
	var panel: PanelContainer = UIKit.panel(false, Color(0.75, 0.35, 1.0))
	center.add_child(panel)
	var box: VBoxContainer = UIKit.vbox(22)
	panel.add_child(box)
	box.add_child(UIKit.label(tr_key(&"vs.pause"), ui.size_h1, ui.text))
	box.add_child(_menu_button(&"vs.resume", &"primary", func() -> void: _set_paused(false)))
	box.add_child(_menu_button(&"vs.restart", &"gold", func() -> void:
		_set_paused(false)
		GameEvents.request_versus_rematch.emit()
		on_enter({})))
	box.add_child(_menu_button(&"vs.quit", &"ghost", func() -> void: GameEvents.request_versus_exit.emit()))


func _build_results() -> void:
	_result_layer = Control.new()
	UIKit.fill(_result_layer)
	_result_layer.visible = false
	add_child(_result_layer)
	_result_layer.add_child(UIKit.dimmer(0.55))
	var center: CenterContainer = CenterContainer.new()
	UIKit.fill(center)
	_result_layer.add_child(center)
	var panel: PanelContainer = UIKit.panel(false, Color(1.0, 0.85, 0.3))
	center.add_child(panel)
	_result_box = UIKit.vbox(20)
	panel.add_child(_result_box)


func _menu_button(key: StringName, style: StringName, action: Callable) -> UIButton:
	var b: UIButton = UIKit.button(tr_key(key), style, 560.0)
	b.pressed.connect(action)
	return b


func _set_paused(value: bool) -> void:
	if _finished:
		return
	_paused = value
	_pause_layer.visible = value
	GameEvents.request_versus_pause.emit(value)


func _on_countdown(n: int) -> void:
	if not visible:
		return
	_countdown.visible = true
	_countdown.text = str(n) if n > 0 else tr_key(&"hud.go")
	_countdown.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3) if n > 0 else Color(0.4, 1.0, 0.5))
	_countdown.pivot_offset = _countdown.size * 0.5
	_countdown.modulate.a = 1.0
	UITween.pop(_countdown, 0.0, 1.8)
	if n <= 0:
		var tw: Tween = create_tween()
		tw.tween_interval(0.5)
		tw.tween_property(_countdown, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void: _countdown.visible = false)


func _on_callout(player: int, text: String, color: Color) -> void:
	if not visible or text.is_empty():
		return
	for i in range(2):
		if player >= 0 and player != i:
			continue
		var s: PlayerPanel = _sides[i]
		if s.callout_tween != null and s.callout_tween.is_valid():
			s.callout_tween.kill()
		s.callout.text = text
		s.callout.add_theme_color_override(&"font_color", color)
		s.callout.modulate.a = 1.0
		s.callout.scale = Vector2(0.5, 0.5)
		s.callout_tween = create_tween()
		s.callout_tween.tween_property(s.callout, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		s.callout_tween.tween_interval(0.7)
		s.callout_tween.tween_property(s.callout, "modulate:a", 0.0, 0.35)


func _on_finished(result: Dictionary) -> void:
	_finished = true
	_paused = false
	_pause_layer.visible = false
	var ui: UITheme = UITheme.current()
	for child in _result_box.get_children():
		child.queue_free()
	var winner: int = int(result.get("winner", -1))
	var title: String = tr_key(&"vs.draw")
	var col: Color = ui.text
	if winner >= 0:
		title = Tr.f(&"vs.wins", {"p": tr_key(&"vs.p1" if winner == 0 else &"vs.p2")})
		col = VsDefs.PLAYER_COLORS[winner]
	var heading: Label = UIKit.label(title, ui.size_title - 10, col)
	heading.add_theme_constant_override(&"outline_size", 16)
	_result_box.add_child(heading)
	var table: GridContainer = GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override(&"h_separation", 60)
	table.add_theme_constant_override(&"v_separation", 10)
	_result_box.add_child(table)
	var players: Array = result.get("players", [])
	table.add_child(UIKit.label("", ui.size_body, ui.text))
	table.add_child(UIKit.label("P1", ui.size_h2, VsDefs.PLAYER_COLORS[0]))
	table.add_child(UIKit.label("P2", ui.size_h2, VsDefs.PLAYER_COLORS[1]))
	var rows: Array[Array] = [[&"vs.fans", "fans"], [&"vs.stat.lives", "lives"], [&"vs.stat.wrecks", "wrecks"],
			[&"vs.stat.hits", "hits"], [&"vs.stat.busts", "busts"], [&"vs.stat.smashed", "smashed"],
			[&"vs.stat.used", "used"]]
	for row: Array in rows:
		table.add_child(UIKit.label(tr_key(row[0]), ui.size_body, ui.text_dim, HORIZONTAL_ALIGNMENT_LEFT))
		for k in range(2):
			var value: int = int((players[k] as Dictionary).get(row[1], 0)) if k < players.size() else 0
			var cell: Label = UIKit.label(MathUtils.group_digits(value), ui.size_body, ui.text)
			table.add_child(cell)
			if winner == k and row[1] == "fans":
				cell.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3))
	var buttons: HBoxContainer = UIKit.hbox(26)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_box.add_child(buttons)
	var again: UIButton = UIKit.button(tr_key(&"vs.rematch"), &"gold", 420.0)
	again.feedback = &"confirm"
	again.pressed.connect(func() -> void:
		GameEvents.request_versus_rematch.emit()
		on_enter({}))
	buttons.add_child(again)
	var menu: UIButton = UIKit.button(tr_key(&"vs.menu"), &"ghost", 300.0)
	menu.pressed.connect(func() -> void: GameEvents.request_versus_exit.emit())
	buttons.add_child(menu)
	# Let the final crash play out before the card slides in.
	var tw: Tween = create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(func() -> void:
		_result_layer.visible = true
		_result_layer.modulate.a = 0.0
		UITween.fade(_result_layer, 1.0, 0.3)
		UITween.pop(heading, 0.1, 0.5)
		if winner >= 0:
			VFXManager.play_ui(&"confetti", Vector2(size.x * 0.5, size.y * 0.35)))

## In-round overlay of the multiplayer split screen. One column per strip (same split as the
## PartyMatch views): name badge in the player's colour, score, eggs, lives, live place and big
## messages (CRASH!, OUT, PHONE LOST, GET READY); across the top the round clock, in the middle the
## shared 3-2-1-GO. Esc pauses.
extends UIScreen

const STRIP_GAP: int = 10

var _party: PartyMode = null
var _row: HBoxContainer = null
var _clock: Label = null
var _clock_box: Control = null
var _count: Label = null
var _columns: Array[Dictionary] = []
var _built_for: PartyMatch = null


class Hearts extends Control:
	var lives: int = 3
	var total: int = 3
	var color: Color = Color(0.95, 0.25, 0.2)

	func _init() -> void:
		custom_minimum_size = Vector2(150.0, 44.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_lives(value: int) -> void:
		if value != lives:
			lives = value
			queue_redraw()

	func _draw() -> void:
		var outline: Color = UITheme.current().outline
		for i in range(total):
			var c: Vector2 = Vector2(22.0 + i * 48.0, 22.0)
			var fill: Color = color if i < lives else Color(0.25, 0.18, 0.14)
			_heart(c, 20.0, outline)
			_heart(c, 15.0, fill)

	func _heart(c: Vector2, r: float, fill: Color) -> void:
		draw_circle(c + Vector2(-r * 0.5, -r * 0.2), r * 0.55, fill, true, -1.0, true)
		draw_circle(c + Vector2(r * 0.5, -r * 0.2), r * 0.55, fill, true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.02, -r * 0.05), c + Vector2(r * 1.02, -r * 0.05),
				c + Vector2(0.0, r * 0.95)]), fill)


func build() -> void:
	var ui: UITheme = UITheme.current()
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", STRIP_GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fill(_row)
	add_child(_row)
	_clock = UIKit.label("3:00", ui.size_h2, ui.text)
	_clock.add_theme_font_override(&"font", UIKit.heading_font())
	_clock_box = UIKit.pill(_clock)
	place(_clock_box, Vector2(0.5, 0.0), Vector2(0.0, 16.0), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	_count = UIKit.label("", 260, ui.accent)
	_count.add_theme_font_override(&"font", UIKit.heading_font())
	UIKit.strong_outline(_count, 10)
	_count.visible = false
	place(_count, Vector2(0.5, 0.45), Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)


func connect_events() -> void:
	pass


func on_enter(_args: Dictionary) -> void:
	_party = Services.locate(&"party") as PartyMode
	if _party == null:
		return
	if not _party.countdown.is_connected(_on_countdown):
		_party.countdown.connect(_on_countdown)
		_party.runner_event.connect(_on_runner_event)
	_count.visible = false
	_rebuild_columns()


func on_exit() -> void:
	if _party != null and _party.countdown.is_connected(_on_countdown):
		_party.countdown.disconnect(_on_countdown)
		_party.runner_event.disconnect(_on_runner_event)


func handle_back() -> bool:
	if _party != null:
		_party.set_paused(true)
	return true


func _process(_delta: float) -> void:
	if not visible or _party == null or _party.round_match == null:
		return
	if _party.round_match != _built_for:
		_rebuild_columns()
	var m: PartyMatch = _party.round_match
	var seconds: int = ceili(maxf(m.time_left, 0.0))
	_clock.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_clock.add_theme_color_override(&"font_color",
			UITheme.current().danger if seconds <= 10 and m.phase == PartyMatch.Phase.RUNNING else UITheme.current().text)
	for column: Dictionary in _columns:
		var snap: Dictionary = m.snapshot(int(column["slot"]))
		if snap.is_empty():
			continue
		(column["score"] as Label).text = MathUtils.group_digits(int(snap["score"]))
		(column["eggs"] as Label).text = MathUtils.group_digits(int(snap["eggs"]))
		(column["hearts"] as Hearts).set_lives(int(snap["lives"]))
		var place: int = int(snap["place"])
		(column["place"] as Label).text = _place_text(place)
		(column["place"] as Label).add_theme_color_override(&"font_color", _medal_color(place))


func _rebuild_columns() -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_columns.clear()
	_built_for = _party.round_match if _party != null else null
	if _built_for == null:
		return
	# With an even number of strips the top centre is a divider between a score and a name badge:
	# the clock goes below them.
	var clock_y: float = 16.0 if _built_for.runners.size() % 2 == 1 else 170.0
	_clock_box.offset_top = clock_y
	_clock_box.offset_bottom = clock_y
	var ui: UITheme = UITheme.current()
	for r: PartyMatch.Runner in _built_for.runners:
		var column: Control = Control.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(column)
		var color: Color = r.member.color()
		# Top-left: name badge, lives below. Top-right: score, eggs below.
		var left: VBoxContainer = UIKit.vbox(8)
		var badge: PanelContainer = PanelContainer.new()
		badge.add_theme_stylebox_override(&"panel", UIKit.box(color, 22, ui.outline, 5, 12.0))
		var name_label: Label = UIKit.label(r.member.name, ui.size_body, ui.text)
		badge.add_child(name_label)
		left.add_child(badge)
		var hearts: Hearts = Hearts.new()
		left.add_child(hearts)
		_pin(column, left, Vector2(0.0, 0.0), Vector2(24.0, 22.0), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
		var right: VBoxContainer = UIKit.vbox(0)
		var score: Label = UIKit.label("0", ui.size_h1, ui.text, HORIZONTAL_ALIGNMENT_RIGHT)
		score.add_theme_font_override(&"font", UIKit.heading_font())
		UIKit.strong_outline(score)
		right.add_child(score)
		var egg_row: HBoxContainer = UIKit.hbox(8)
		egg_row.alignment = BoxContainer.ALIGNMENT_END
		var eggs: Label = UIKit.label("0", ui.size_body, ui.accent, HORIZONTAL_ALIGNMENT_RIGHT)
		UIKit.strong_outline(eggs, 2)
		egg_row.add_child(eggs)
		egg_row.add_child(CoinIcon.new(float(UIKit.scaled(ui.size_body))))
		right.add_child(egg_row)
		_pin(column, right, Vector2(1.0, 0.0), Vector2(-24.0, 22.0), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
		var place_label: Label = UIKit.label("", ui.size_h1, ui.text)
		place_label.add_theme_font_override(&"font", UIKit.heading_font())
		UIKit.strong_outline(place_label, 4)
		_pin(column, place_label, Vector2(0.5, 1.0), Vector2(0.0, -28.0), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
		var message: Label = UIKit.label("", 84, ui.text)
		message.add_theme_font_override(&"font", UIKit.heading_font())
		UIKit.strong_outline(message, 8)
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message.visible = false
		var sub: Label = UIKit.label("", ui.size_body, ui.text)
		UIKit.strong_outline(sub, 3)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.visible = false
		var center: VBoxContainer = UIKit.vbox(10)
		center.add_child(message)
		center.add_child(sub)
		center.anchor_left = 0.0
		center.anchor_right = 1.0
		center.anchor_top = 0.3
		center.anchor_bottom = 0.3
		center.offset_left = 20.0
		center.offset_right = -20.0
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(center)
		_columns.append({"slot": r.member.slot, "score": score, "eggs": eggs, "hearts": hearts,
				"place": place_label, "message": message, "sub": sub, "tween": null})


func _pin(parent: Control, node: Control, anchor: Vector2, offset: Vector2, grow_h: Control.GrowDirection,
		grow_v: Control.GrowDirection) -> void:
	node.anchor_left = anchor.x
	node.anchor_right = anchor.x
	node.anchor_top = anchor.y
	node.anchor_bottom = anchor.y
	node.offset_left = offset.x
	node.offset_right = offset.x
	node.offset_top = offset.y
	node.offset_bottom = offset.y
	node.grow_horizontal = grow_h
	node.grow_vertical = grow_v
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)


func _column(slot: int) -> Dictionary:
	for column: Dictionary in _columns:
		if int(column["slot"]) == slot:
			return column
	return {}


func _on_countdown(n: int) -> void:
	if n < 0:
		_count.visible = false
		return
	_count.text = str(n) if n > 0 else tr_key(&"hud.go")
	_count.visible = true
	UITween.pop(_count, 0.0, 0.4)
	if n <= 0:
		var tween: Tween = create_tween()
		tween.tween_interval(0.6)
		tween.tween_callback(func() -> void: _count.visible = false)


func _on_runner_event(slot: int, kind: StringName) -> void:
	var column: Dictionary = _column(slot)
	if column.is_empty():
		return
	var ui: UITheme = UITheme.current()
	match kind:
		&"crash":
			_message(column, tr_key(&"party.hud.crash"), "", ui.danger, 1.5)
		&"respawn":
			_message(column, tr_key(&"party.hud.ready"), "", ui.accent, 1.4)
		&"out":
			var snap: Dictionary = _party.round_match.snapshot(slot) if _party.round_match != null else {}
			_message(column, tr_key(&"party.hud.out"),
					Tr.f(&"party.hud.out_score", {"n": MathUtils.group_digits(int(snap.get("score", 0)))}), ui.danger, -1.0)
		&"finished":
			_message(column, tr_key(&"party.hud.finish"), "", ui.success, -1.0)
		&"frozen":
			_message(column, tr_key(&"party.hud.lost"), tr_key(&"party.hud.lost_hint"), ui.danger, -1.0)
		&"resumed":
			_message(column, tr_key(&"party.hud.ready"), "", ui.accent, 1.2)


## Big message in a strip; seconds < 0 keeps it up.
func _message(column: Dictionary, text: String, sub_text: String, color: Color, seconds: float) -> void:
	var message: Label = column["message"] as Label
	var sub: Label = column["sub"] as Label
	var old: Tween = column["tween"] as Tween
	if old != null and old.is_valid():
		old.kill()
	message.text = text
	message.add_theme_color_override(&"font_color", color)
	message.visible = true
	sub.text = sub_text
	sub.visible = not sub_text.is_empty()
	UITween.pop(message, 0.0, 0.5)
	if seconds > 0.0:
		var tween: Tween = create_tween()
		tween.tween_interval(seconds)
		tween.tween_callback(func() -> void:
			message.visible = false
			sub.visible = false)
		column["tween"] = tween


func _place_text(place: int) -> String:
	if place < 1 or place > 3:
		return ""
	return tr_key([&"party.place1", &"party.place2", &"party.place3"][place - 1])


func _medal_color(place: int) -> Color:
	match place:
		1:
			return Color(1.0, 0.82, 0.2)
		2:
			return Color(0.85, 0.88, 0.92)
		3:
			return Color(0.86, 0.55, 0.3)
	return Color.WHITE

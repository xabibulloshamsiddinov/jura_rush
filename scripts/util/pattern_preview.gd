## Pattern preview (run scenes/obstacles/pattern_preview.tscn): flip through every pattern,
## drawn as a lane grid, with its tags and the solvability verdict per difficulty.
extends Control

const CELL: Vector2 = Vector2(150.0, 110.0)
const COLORS: Dictionary = {
	Cell.Type.EMPTY: Color(0.1, 0.11, 0.2), Cell.Type.COIN: Color(0.9, 0.75, 0.1),
	Cell.Type.COIN_ARC: Color(0.9, 0.6, 0.1), Cell.Type.COIN_DIAG_RIGHT: Color(0.9, 0.75, 0.1),
	Cell.Type.COIN_DIAG_LEFT: Color(0.9, 0.75, 0.1), Cell.Type.TRAIN_LONG: Color(0.15, 0.35, 0.8),
	Cell.Type.TRAIN_SHORT: Color(0.45, 0.25, 0.8), Cell.Type.TRAIN_MOVING: Color(0.85, 0.2, 0.2),
	Cell.Type.BARRIER_LOW: Color(0.2, 0.75, 0.3), Cell.Type.BARRIER_HIGH: Color(0.85, 0.3, 0.75),
	Cell.Type.BARRIER_FULL: Color(0.6, 0.1, 0.1), Cell.Type.RAMP_UP: Color(0.2, 0.8, 0.7),
	Cell.Type.GAP: Color(0.0, 0.0, 0.0), Cell.Type.POWERUP_SLOT: Color(0.2, 0.7, 1.0),
	Cell.Type.MYSTERY_BOX: Color(1.0, 0.85, 0.3), Cell.Type.DECOR: Color(0.4, 0.4, 0.45),
}
const NAMES: Dictionary = {
	Cell.Type.EMPTY: "", Cell.Type.COIN: "coin", Cell.Type.COIN_ARC: "arc",
	Cell.Type.COIN_DIAG_RIGHT: "coin >", Cell.Type.COIN_DIAG_LEFT: "< coin",
	Cell.Type.TRAIN_LONG: "TRAIN", Cell.Type.TRAIN_SHORT: "train", Cell.Type.TRAIN_MOVING: "MOVING",
	Cell.Type.BARRIER_LOW: "low", Cell.Type.BARRIER_HIGH: "high", Cell.Type.BARRIER_FULL: "FULL",
	Cell.Type.RAMP_UP: "ramp", Cell.Type.GAP: "gap", Cell.Type.POWERUP_SLOT: "power",
	Cell.Type.MYSTERY_BOX: "box", Cell.Type.DECOR: "light",
}

var _library: PatternLibrary = null
var _validator: SolvabilityValidator = null
var _index: int = 0
var _info: Label = null
var _cfg: GameConfig = GameConfig.current()


func _ready() -> void:
	_library = PatternLibrary.new(_cfg)
	_validator = SolvabilityValidator.new(_cfg)
	_info = Label.new()
	_info.position = Vector2(520.0, 40.0)
	_info.add_theme_font_size_override(&"font_size", 30)
	add_child(_info)
	for entry: Array in [["< prev", -1, 520.0], ["next >", 1, 800.0]]:
		var b: Button = Button.new()
		b.text = str(entry[0])
		b.position = Vector2(float(entry[2]), 1500.0)
		b.custom_minimum_size = Vector2(240.0, 110.0)
		b.add_theme_font_size_override(&"font_size", 34)
		b.pressed.connect(_step.bind(int(entry[1])))
		add_child(b)
	_step(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right"):
		_step(1)
	elif event.is_action_pressed(&"ui_left"):
		_step(-1)


func _step(direction: int) -> void:
	_index = posmod(_index + direction, _library.size())
	var def: ChunkDef = _library.defs[_index]
	var verdict: String = ""
	for difficulty in range(1, 11):
		verdict += "%d:%s  " % [difficulty, "ok" if _library.is_solvable_alone(_index, difficulty, _validator) else "--"]
	_info.text = "%d / %d   %s\ndifficulty %d   window %d-%d   weight %.1f\ntags: %s\nneeds: %s\nsafe lanes: %s\n\nsolvable alone at difficulty\n%s\n\n%s" % [
			_index + 1, _library.size(), def.id, def.difficulty, def.min_difficulty,
			def.max_difficulty, def.weight, ", ".join(def.tags), ", ".join(def.required_actions),
			str(def.safe_lanes), verdict, "\n".join(_library.errors)]
	queue_redraw()


func _draw() -> void:
	if _library == null:
		return
	var grid: PackedInt32Array = _library.grids[_index]
	var rows: int = _cfg.rows_per_chunk
	var font: Font = ThemeDB.fallback_font
	# Row 0 (reached first) is drawn at the bottom, like the view from behind the runner.
	for row in range(rows):
		for lane in range(_cfg.lane_count):
			var cell: int = grid[row * _cfg.lane_count + lane]
			var t: int = cell & Cell.TYPE_MASK
			var pos: Vector2 = Vector2(40.0 + float(lane) * CELL.x, 40.0 + float(rows - 1 - row) * CELL.y)
			var rect: Rect2 = Rect2(pos, CELL - Vector2(6.0, 6.0))
			var color: Color = COLORS.get(t, Color.GRAY)
			draw_rect(rect, color)
			var text: String = str(NAMES.get(t, "?"))
			if (cell & Cell.FLAG_COINS) != 0:
				text += " +c"
			if (cell & Cell.FLAG_ARC) != 0:
				text += " +arc"
			draw_string(font, pos + Vector2(8.0, 62.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
					Color.WHITE if color.get_luminance() < 0.5 else Color.BLACK)

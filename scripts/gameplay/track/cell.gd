## Pattern grid cells. A grid is a PackedInt32Array of rows * lanes ints: low byte = Type,
## higher bits = flags. Index = row * lanes + lane, row 0 is reached first.
class_name Cell
extends RefCounted

enum Type {
	EMPTY, COIN, TRAIN_LONG, TRAIN_SHORT, BARRIER_LOW, BARRIER_HIGH, RAMP_UP, GAP,
	POWERUP_SLOT, COIN_ARC, DECOR, BARRIER_FULL, TRAIN_MOVING, MYSTERY_BOX,
	COIN_DIAG_RIGHT, COIN_DIAG_LEFT,
}

const TYPE_MASK: int = 0xFF
## Coins ride along: on a train roof, or under a high barrier.
const FLAG_COINS: int = 1 << 8
## A coin arc spans the cell (over a low barrier or a gap).
const FLAG_ARC: int = 1 << 9

## DSL legend (see pattern_data.gd).
const CHARS: Dictionary = {
	".": Type.EMPTY, "c": Type.COIN, "a": Type.COIN_ARC,
	">": Type.COIN_DIAG_RIGHT, "<": Type.COIN_DIAG_LEFT,
	"T": Type.TRAIN_SHORT, "t": Type.TRAIN_SHORT | FLAG_COINS, "M": Type.TRAIN_MOVING,
	"l": Type.BARRIER_LOW, "J": Type.BARRIER_LOW | FLAG_ARC,
	"h": Type.BARRIER_HIGH, "u": Type.BARRIER_HIGH | FLAG_COINS,
	"X": Type.BARRIER_FULL, "R": Type.RAMP_UP,
	"G": Type.GAP, "g": Type.GAP | FLAG_ARC,
	"P": Type.POWERUP_SLOT, "B": Type.MYSTERY_BOX, "d": Type.DECOR,
}


## Cell type without flags.
static func type_of(cell: int) -> int:
	return cell & TYPE_MASK


## True for static trains (walkable roof).
static func is_roof_train(t: int) -> bool:
	return t == Type.TRAIN_LONG or t == Type.TRAIN_SHORT


## True for anything that blocks the lane at ground level regardless of jumping or rolling.
static func is_solid(t: int) -> bool:
	return t == Type.TRAIN_LONG or t == Type.TRAIN_SHORT or t == Type.TRAIN_MOVING \
			or t == Type.BARRIER_FULL


## True when a runner can simply run through the cell on the ground.
static func is_open(t: int) -> bool:
	return not is_solid(t) and t != Type.BARRIER_LOW and t != Type.BARRIER_HIGH \
			and t != Type.GAP and t != Type.RAMP_UP


## Parses DSL rows into a grid. Train runs of 3+ cells become TRAIN_LONG. Returns an empty
## array when the rows are malformed.
static func parse_rows(rows: PackedStringArray, lanes: int) -> PackedInt32Array:
	var grid: PackedInt32Array = PackedInt32Array()
	grid.resize(rows.size() * lanes)
	for r in range(rows.size()):
		var row: String = rows[r]
		if row.length() != lanes:
			return PackedInt32Array()
		for l in range(lanes):
			var ch: String = row[l]
			if not CHARS.has(ch):
				return PackedInt32Array()
			var value: int = CHARS[ch]
			grid[r * lanes + l] = value
	_mark_long_trains(grid, lanes)
	return grid


## Returns the left-right mirrored grid (diagonal coin trails are flipped too).
static func mirror(grid: PackedInt32Array, lanes: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(grid.size())
	@warning_ignore("integer_division")
	var rows: int = grid.size() / lanes
	for r in range(rows):
		for l in range(lanes):
			var cell: int = grid[r * lanes + l]
			var t: int = cell & TYPE_MASK
			if t == Type.COIN_DIAG_RIGHT:
				cell = (cell & ~TYPE_MASK) | Type.COIN_DIAG_LEFT
			elif t == Type.COIN_DIAG_LEFT:
				cell = (cell & ~TYPE_MASK) | Type.COIN_DIAG_RIGHT
			out[r * lanes + (lanes - 1 - l)] = cell
	return out


## A grid of EMPTY cells.
static func empty_grid(rows: int, lanes: int) -> PackedInt32Array:
	var grid: PackedInt32Array = PackedInt32Array()
	grid.resize(rows * lanes)
	return grid


## Length (in rows) of the run of same-type cells starting at (row, lane).
static func run_length(grid: PackedInt32Array, lanes: int, row: int, lane: int) -> int:
	@warning_ignore("integer_division")
	var rows: int = grid.size() / lanes
	var t: int = grid[row * lanes + lane] & TYPE_MASK
	var n: int = 1
	while row + n < rows and (grid[(row + n) * lanes + lane] & TYPE_MASK) == t:
		n += 1
	return n


static func _mark_long_trains(grid: PackedInt32Array, lanes: int) -> void:
	@warning_ignore("integer_division")
	var rows: int = grid.size() / lanes
	for l in range(lanes):
		var r: int = 0
		while r < rows:
			if (grid[r * lanes + l] & TYPE_MASK) == Type.TRAIN_SHORT:
				var n: int = run_length(grid, lanes, r, l)
				if n >= 3:
					for k in range(n):
						var idx: int = (r + k) * lanes + l
						grid[idx] = (grid[idx] & ~TYPE_MASK) | Type.TRAIN_LONG
				r += n
			else:
				r += 1

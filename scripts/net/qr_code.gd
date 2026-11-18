## QR Code encoder (ISO/IEC 18004), written from scratch so the game needs no plugin: byte mode,
## error correction level M (~15 % of the symbol may be damaged), versions 1..40, the mask with
## the lowest penalty score. Follows the reference algorithm of Project Nayuki's MIT-licensed
## "QR Code generator library" step by step (bit stream, Reed-Solomon over GF(256), interleaving,
## zig-zag placement, masking, format and version information).
##
##   var qr: QrCode = QrCode.encode("http://192.168.1.5:8080")
##   texture = ImageTexture.create_from_image(qr.to_image(8, 4))
##
## A phone camera reads it from a few metres when every module is at least ~6 screen pixels.
class_name QrCode
extends RefCounted

## Error correction codewords per block, level M, by version (index 0 unused).
const ECC_PER_BLOCK: PackedInt32Array = [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22,
		24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
		28, 28, 28, 28]
## Error correction blocks, level M, by version (index 0 unused).
const ECC_BLOCKS: PackedInt32Array = [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11,
		13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49]
## Format bits of level M (L = 1, M = 0, Q = 3, H = 2).
const FORMAT_BITS_M: int = 0
const PENALTY_N1: int = 3
const PENALTY_N2: int = 3
const PENALTY_N3: int = 40
const PENALTY_N4: int = 10

## Side length in modules (version * 4 + 17).
var size: int = 0
var version: int = 0
## The mask pattern (0..7) that was applied.
var mask: int = 0

var _modules: PackedByteArray = PackedByteArray()
var _function: PackedByteArray = PackedByteArray()


## Encodes UTF-8 text in the smallest version that holds it. Returns null when the text does not
## fit in max_version. force_mask = 0..7 skips the penalty search (tests).
static func encode(text: String, min_version: int = 1, max_version: int = 40, force_mask: int = -1) -> QrCode:
	var data: PackedByteArray = text.to_utf8_buffer()
	var chosen: int = -1
	for v in range(clampi(min_version, 1, 40), clampi(max_version, 1, 40) + 1):
		var count_bits: int = 8 if v <= 9 else 16
		if data.size() >= (1 << count_bits):
			continue
		if 4 + count_bits + data.size() * 8 <= data_codewords(v) * 8:
			chosen = v
			break
	if chosen < 0:
		return null
	# Bit stream: mode 0100 (byte), character count, the bytes, terminator, padding.
	var bits: PackedByteArray = PackedByteArray()
	_append_bits(bits, 0x4, 4)
	_append_bits(bits, data.size(), 8 if chosen <= 9 else 16)
	for b: int in data:
		_append_bits(bits, b, 8)
	var capacity: int = data_codewords(chosen) * 8
	_append_bits(bits, 0, mini(4, capacity - bits.size()))
	_append_bits(bits, 0, (8 - bits.size() % 8) % 8)
	var pad: int = 0xEC
	while bits.size() < capacity:
		_append_bits(bits, pad, 8)
		pad = 0x11 if pad == 0xEC else 0xEC
	var codewords: PackedByteArray = PackedByteArray()
	codewords.resize(bits.size() / 8)
	for i in range(bits.size()):
		codewords[i >> 3] = codewords[i >> 3] | (bits[i] << (7 - (i & 7)))
	var qr: QrCode = QrCode.new()
	qr._build(chosen, codewords, force_mask)
	return qr


## Data codewords (bytes) a version holds at level M.
static func data_codewords(v: int) -> int:
	return raw_data_modules(v) / 8 - ECC_PER_BLOCK[v] * ECC_BLOCKS[v]


## Modules left for data + error correction after the function patterns.
static func raw_data_modules(v: int) -> int:
	var result: int = (16 * v + 128) * v + 64
	if v >= 2:
		var align: int = v / 7 + 2
		result -= (25 * align - 10) * align - 55
		if v >= 7:
			result -= 36
	return result


## True for a dark module (x = column, y = row, from the top-left).
func is_dark(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size and _modules[y * size + x] != 0


## The symbol as an image: `scale` pixels per module and a quiet zone of `border` modules.
func to_image(scale: int = 8, border: int = 4, dark: Color = Color.BLACK, light: Color = Color.WHITE) -> Image:
	var side: int = (size + border * 2) * scale
	var image: Image = Image.create(side, side, false, Image.FORMAT_RGB8)
	image.fill(light)
	for y in range(size):
		for x in range(size):
			if _modules[y * size + x] != 0:
				image.fill_rect(Rect2i((x + border) * scale, (y + border) * scale, scale, scale), dark)
	return image


## Rows of "1" / "0" characters (tests and debugging).
func to_strings() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for y in range(size):
		var row: String = ""
		for x in range(size):
			row += "1" if _modules[y * size + x] != 0 else "0"
		rows.append(row)
	return rows


func _build(p_version: int, codewords: PackedByteArray, force_mask: int) -> void:
	version = p_version
	size = version * 4 + 17
	_modules.resize(size * size)
	_modules.fill(0)
	_function.resize(size * size)
	_function.fill(0)
	_draw_function_patterns()
	_draw_codewords(_add_ecc_and_interleave(codewords))
	mask = force_mask
	if mask < 0 or mask > 7:
		var best: int = 1 << 30
		for m in range(8):
			_apply_mask(m)
			_draw_format_bits(m)
			var penalty: int = _penalty_score()
			if penalty < best:
				best = penalty
				mask = m
			_apply_mask(m)
	_apply_mask(mask)
	_draw_format_bits(mask)


# --- function patterns -------------------------------------------------------------------------

func _set_function(x: int, y: int, dark: bool) -> void:
	_modules[y * size + x] = 1 if dark else 0
	_function[y * size + x] = 1


func _draw_function_patterns() -> void:
	for i in range(size):
		_set_function(6, i, i % 2 == 0)
		_set_function(i, 6, i % 2 == 0)
	_draw_finder(3, 3)
	_draw_finder(size - 4, 3)
	_draw_finder(3, size - 4)
	var positions: PackedInt32Array = _alignment_positions()
	var n: int = positions.size()
	for i in range(n):
		for j in range(n):
			# Not on the three finder corners.
			if not ((i == 0 and j == 0) or (i == 0 and j == n - 1) or (i == n - 1 and j == 0)):
				_draw_alignment(positions[i], positions[j])
	_draw_format_bits(0)
	_draw_version()


func _draw_finder(cx: int, cy: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var dist: int = maxi(absi(dx), absi(dy))
			var x: int = cx + dx
			var y: int = cy + dy
			if x >= 0 and x < size and y >= 0 and y < size:
				_set_function(x, y, dist != 2 and dist != 4)


func _draw_alignment(cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_function(cx + dx, cy + dy, maxi(absi(dx), absi(dy)) != 1)


func _alignment_positions() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if version == 1:
		return result
	var n: int = version / 7 + 2
	var step: int = (version * 8 + n * 3 + 5) / (n * 4 - 4) * 2
	result.append(6)
	var tail: PackedInt32Array = PackedInt32Array()
	for i in range(n - 1):
		tail.append(size - 7 - i * step)
	tail.reverse()
	result.append_array(tail)
	return result


## 15 format bits (level + mask, BCH-protected, XOR-masked), both copies plus the dark module.
func _draw_format_bits(m: int) -> void:
	var data: int = (FORMAT_BITS_M << 3) | m
	var rem: int = data
	for i in range(10):
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits: int = ((data << 10) | rem) ^ 0x5412
	for i in range(6):
		_set_function(8, i, _bit(bits, i))
	_set_function(8, 7, _bit(bits, 6))
	_set_function(8, 8, _bit(bits, 7))
	_set_function(7, 8, _bit(bits, 8))
	for i in range(9, 15):
		_set_function(14 - i, 8, _bit(bits, i))
	for i in range(8):
		_set_function(size - 1 - i, 8, _bit(bits, i))
	for i in range(8, 15):
		_set_function(8, size - 15 + i, _bit(bits, i))
	_set_function(8, size - 8, true)


## 18 version bits (version >= 7), BCH-protected, in the two 6x3 blocks.
func _draw_version() -> void:
	if version < 7:
		return
	var rem: int = version
	for i in range(12):
		rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
	var bits: int = (version << 12) | rem
	for i in range(18):
		var dark: bool = _bit(bits, i)
		var a: int = size - 11 + i % 3
		var b: int = i / 3
		_set_function(a, b, dark)
		_set_function(b, a, dark)


# --- codewords ---------------------------------------------------------------------------------

func _add_ecc_and_interleave(data: PackedByteArray) -> PackedByteArray:
	var blocks_count: int = ECC_BLOCKS[version]
	var ecc_len: int = ECC_PER_BLOCK[version]
	var raw: int = raw_data_modules(version) / 8
	var short_blocks: int = blocks_count - raw % blocks_count
	var short_len: int = raw / blocks_count
	var divisor: PackedByteArray = _rs_divisor(ecc_len)
	var blocks: Array[PackedByteArray] = []
	var k: int = 0
	for i in range(blocks_count):
		var length: int = short_len - ecc_len + (0 if i < short_blocks else 1)
		var block: PackedByteArray = data.slice(k, k + length)
		k += length
		var ecc: PackedByteArray = _rs_remainder(block, divisor)
		if i < short_blocks:
			block.append(0)
		block.append_array(ecc)
		blocks.append(block)
	var result: PackedByteArray = PackedByteArray()
	for i in range(blocks[0].size()):
		for j in range(blocks.size()):
			# The padding byte of the short blocks is skipped.
			if i != short_len - ecc_len or j >= short_blocks:
				result.append(blocks[j][i])
	return result


## Zig-zag placement: two-module columns from the right, alternating up and down, skipping the
## vertical timing column.
func _draw_codewords(data: PackedByteArray) -> void:
	var i: int = 0
	var total_bits: int = data.size() * 8
	var right: int = size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in range(size):
			for j in range(2):
				var x: int = right - j
				var upward: bool = ((right + 1) & 2) == 0
				var y: int = (size - 1 - vert) if upward else vert
				if _function[y * size + x] == 0 and i < total_bits:
					_modules[y * size + x] = 1 if _bit(data[i >> 3], 7 - (i & 7)) else 0
					i += 1
		right -= 2


func _apply_mask(m: int) -> void:
	for y in range(size):
		for x in range(size):
			var invert: bool = false
			match m:
				0:
					invert = (x + y) % 2 == 0
				1:
					invert = y % 2 == 0
				2:
					invert = x % 3 == 0
				3:
					invert = (x + y) % 3 == 0
				4:
					invert = (x / 3 + y / 2) % 2 == 0
				5:
					invert = x * y % 2 + x * y % 3 == 0
				6:
					invert = (x * y % 2 + x * y % 3) % 2 == 0
				7:
					invert = ((x + y) % 2 + x * y % 3) % 2 == 0
			var index: int = y * size + x
			if invert and _function[index] == 0:
				_modules[index] = 1 - _modules[index]


# --- mask penalty --------------------------------------------------------------------------------

func _penalty_score() -> int:
	var result: int = 0
	for horizontal: bool in [true, false]:
		for a in range(size):
			var run_color: int = 0
			var run: int = 0
			var history: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
			for b in range(size):
				var color: int = _modules[a * size + b] if horizontal else _modules[b * size + a]
				if color == run_color:
					run += 1
					if run == 5:
						result += PENALTY_N1
					elif run > 5:
						result += 1
				else:
					_history_add(run, history)
					if run_color == 0:
						result += _finder_count(history) * PENALTY_N3
					run_color = color
					run = 1
			result += _finder_terminate(run_color, run, history) * PENALTY_N3
	for y in range(size - 1):
		for x in range(size - 1):
			var c: int = _modules[y * size + x]
			if c == _modules[y * size + x + 1] and c == _modules[(y + 1) * size + x] \
					and c == _modules[(y + 1) * size + x + 1]:
				result += PENALTY_N2
	var dark: int = 0
	for v: int in _modules:
		dark += v
	var total: int = size * size
	var k: int = (absi(dark * 20 - total * 10) + total - 1) / total - 1
	result += k * PENALTY_N4
	return result


func _finder_count(history: PackedInt32Array) -> int:
	var n: int = history[1]
	var core: bool = n > 0 and history[2] == n and history[3] == n * 3 and history[4] == n and history[5] == n
	return (1 if core and history[0] >= n * 4 and history[6] >= n else 0) \
			+ (1 if core and history[6] >= n * 4 and history[0] >= n else 0)


func _finder_terminate(run_color: int, run: int, history: PackedInt32Array) -> int:
	var length: int = run
	if run_color != 0:
		_history_add(length, history)
		length = 0
	length += size
	_history_add(length, history)
	return _finder_count(history)


func _history_add(run: int, history: PackedInt32Array) -> void:
	var length: int = run
	if history[0] == 0:
		length += size
	for i in range(history.size() - 1, 0, -1):
		history[i] = history[i - 1]
	history[0] = length


# --- helpers -------------------------------------------------------------------------------------

static func _append_bits(bits: PackedByteArray, value: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)


static func _bit(value: int, i: int) -> bool:
	return ((value >> i) & 1) != 0


## Reed-Solomon generator polynomial of the given degree (coefficients high to low, the leading 1
## omitted).
static func _rs_divisor(degree: int) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(degree)
	result.fill(0)
	result[degree - 1] = 1
	var root: int = 1
	for _i in range(degree):
		for j in range(degree):
			result[j] = _gf_mul(result[j], root)
			if j + 1 < degree:
				result[j] = result[j] ^ result[j + 1]
		root = _gf_mul(root, 0x02)
	return result


static func _rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(divisor.size())
	result.fill(0)
	for b: int in data:
		var factor: int = b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in range(divisor.size()):
			result[i] = result[i] ^ _gf_mul(divisor[i], factor)
	return result


## Multiplication in GF(2^8) modulo x^8 + x^4 + x^3 + x^2 + 1.
static func _gf_mul(x: int, y: int) -> int:
	var z: int = 0
	for i in range(7, -1, -1):
		z = ((z << 1) ^ ((z >> 7) * 0x11D)) & 0xFF
		z ^= ((y >> i) & 1) * x
	return z

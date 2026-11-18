## "Train" obstacles are dinosaurs now (gameplay is unchanged: same collision box, hit types,
## walkable top, moving speed and telegraph timing).
##   train_long / train_short  a Brachiosaurus herd (static, walkable backs at the top). Tail-first
##                             when ChunkBuilder reports a ramp leading in (set_ramp_lead), else
##                             head-first, an unclimbable wall facing the runner.
##   train_moving              a small Triceratops stampede: idles, paws / snorts / shakes its head
##                             when it telegraphs, then gallops at the runner when active.
class_name Train
extends ObstacleBase

## Stampede: animals are about this long; at most this many in one run.
const TRIKE_LEN: float = 4.5
const MAX_TRIKES: int = 3
## Moving herds beyond this distance (fog) are not animated.
const ANIMATE_RANGE: float = 175.0
## Hide margins beyond the measured visual (ObstacleBase.far_overhang): idle neck / tail sway of
## the sauropods, the trike tails.
const HERD_SWAY_MARGIN: float = 0.25
const TRIKE_TAIL_MARGIN: float = 0.6

static var _prewarmed: bool = false

var herd: Brachiosaurus = null
var trikes: Array[Triceratops] = []

var _active: bool = false
var _warned: bool = false
var _ramp_length: float = 0.0
var _ramp_height: float = 3.0
var _middle_side: float = 0.0
var _trike_count: int = 0
var _cfg: GameConfig = GameConfig.current()


func on_acquire() -> void:
	super.on_acquire()
	_active = false
	_warned = false
	_ramp_length = 0.0
	_middle_side = 0.0
	for t: Triceratops in trikes:
		t.reset_pose()


## Called by ChunkBuilder when a ramp in the same lane leads straight into this run: the herd
## turns tail-first and the nearest animal's tail becomes the ramp.
func set_ramp_lead(ramp_length: float, ramp_height: float) -> void:
	_ramp_length = ramp_length
	_ramp_height = ramp_height
	_apply_length()


## Which way middle-lane necks curl (-1 = -X, +1 = +X); ChunkBuilder picks the free side.
func set_neck_side(side: float) -> void:
	_middle_side = side
	_apply_length()


## True when the herd stands tail-first over a ramp.
func is_tail_first() -> bool:
	return _ramp_length > 0.0


func telegraph() -> void:
	_warned = true
	EventScope.of(self).moving_train_warning.emit(lane)


func tick(delta: float, world_speed: float, chunk_z: float) -> void:
	var front_z: float = chunk_z + position.z + length * 0.5
	if not _warned and front_z > -(_cfg.moving_train_activation + 35.0):
		telegraph()
	if front_z > -_cfg.moving_train_activation:
		_active = true
	var own_speed: float = world_speed * _cfg.moving_train_speed_factor
	if _active:
		position.z += own_speed * delta
	if not visible or front_z < -ANIMATE_RANGE:
		return
	var mode: Triceratops.Mode = Triceratops.Mode.IDLE
	if _active:
		mode = Triceratops.Mode.CHARGE
	elif _warned:
		mode = Triceratops.Mode.TELEGRAPH
	for i in range(_trike_count):
		var t: Triceratops = trikes[i]
		t.ground_drift = Vector3(0.0, 0.0, world_speed)
		t.animate(delta, mode, own_speed)


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	if def.moving:
		for i in range(MAX_TRIKES):
			var t: Triceratops = Triceratops.new(i * 31 + def.pool_size)
			t.rotation.y = PI
			t.visible = false
			root.add_child(t)
			trikes.append(t)
	else:
		if not _prewarmed:
			_prewarmed = true
			Brachiosaurus.prewarm([6.0, 3.0, 9.0])
		herd = Brachiosaurus.new(Brachiosaurus.MAX_ANIMALS if def.id == &"train_long" else 2)
		root.add_child(herd)
	return root


func _apply_length() -> void:
	if herd != null:
		var outward: float = 0.0
		if lane == 0:
			outward = -1.0
		elif lane == _cfg.lane_count - 1:
			outward = 1.0
		var side: float = _middle_side if _middle_side != 0.0 else (1.0 if int(absf(position.z)) % 2 == 0 else -1.0)
		herd.layout(length, _ramp_length, _ramp_height, outward, side, absf(position.z) * 0.13 + float(lane))
		# Necks / tails beyond the box stay drawn until they are behind the runner too (+ sway).
		far_overhang = maxf(-herd.far_extent() - length * 0.5, 0.0) + HERD_SWAY_MARGIN
	elif not trikes.is_empty():
		# Tails (whipping in the charge) reach a little past the box.
		far_overhang = TRIKE_TAIL_MARGIN
		_trike_count = clampi(roundi(length / TRIKE_LEN), 1, MAX_TRIKES)
		var a: float = length / float(_trike_count)
		var s: float = clampf(a / 4.7, 0.85, 1.05)
		for i in range(trikes.size()):
			var t: Triceratops = trikes[i]
			t.visible = i < _trike_count
			# Centre each animal's nose-to-tail extent (beak at -2.76, tail at +2.3 in its model).
			t.position = Vector3(0.06 * sin(float(i) * 2.3 + position.z), 0.0,
					length * 0.5 - (float(i) + 0.5) * a - 0.23 * s)
			t.scale = Vector3.ONE * s

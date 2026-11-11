## The automatic coin trail flown through during the jetpack power-up: one CoinField that
## scrolls with the world, filled with a weaving line of coins at flight height.
class_name SkyCoinTrail
extends Node3D

const SPACING: float = 4.0
const LEAD_IN: float = 28.0

var field: CoinField = null

var _cfg: GameConfig = GameConfig.current()


func _ready() -> void:
	field = CoinField.new()
	add_child(field)


## Lays out coins for a flight of `duration` seconds at `speed`, starting in `lane`.
func spawn(speed: float, duration: float, lane: int) -> void:
	field.clear()
	field.position = Vector3.ZERO
	var count: int = mini(CoinField.CAPACITY, int(maxf(speed * duration - LEAD_IN, 0.0) / SPACING))
	var y: float = _cfg.jetpack_height + 0.9
	var current: float = _cfg.lane_x(lane)
	var target: float = current
	for i in range(count):
		# Hold a lane for a stretch, then slide to a neighbouring one.
		if i % 12 == 8:
			var next_lane: int = clampi(_cfg.lane_at_x(target) + (1 if (i / 12) % 2 == 0 else -1), 0,
					_cfg.lane_count - 1)
			target = _cfg.lane_x(next_lane)
		current = move_toward(current, target, _cfg.lane_width / 4.0)
		field.add(Vector3(current, y, -LEAD_IN - float(i) * SPACING))


## Scrolls the trail with the world.
func advance(step: float) -> void:
	if field.count > 0:
		field.position.z += step


## Removes the trail (new run).
func clear() -> void:
	field.clear()
	field.position = Vector3.ZERO

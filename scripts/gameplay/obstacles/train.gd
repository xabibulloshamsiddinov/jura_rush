## Train car(s). Static trains have a walkable roof; moving trains drive toward the player once
## they are within the activation distance and telegraph with a blinking headlight.
class_name Train
extends ObstacleBase

const BODY_LIFT: float = 0.35

var _body: MeshInstance3D = null
var _stripe_l: MeshInstance3D = null
var _stripe_r: MeshInstance3D = null
var _roof: MeshInstance3D = null
var _front: MeshInstance3D = null
var _active: bool = false
var _warned: bool = false
var _blink: float = 0.0
var _cfg: GameConfig = GameConfig.current()


func on_acquire() -> void:
	super.on_acquire()
	_active = false
	_warned = false
	_blink = 0.0
	if _front != null:
		_front.scale = Vector3(1.3, 0.5, 0.06)


func telegraph() -> void:
	_warned = true
	GameEvents.moving_train_warning.emit(lane)


func tick(delta: float, world_speed: float, chunk_z: float) -> void:
	var front_z: float = chunk_z + position.z + length * 0.5
	if not _warned and front_z > -(_cfg.moving_train_activation + 35.0):
		telegraph()
	if front_z > -_cfg.moving_train_activation:
		_active = true
	if _active:
		position.z += world_speed * _cfg.moving_train_speed_factor * delta
	if _warned and _front != null:
		_blink += delta * 10.0
		var pulse: float = 1.0 + 0.6 * absf(sin(_blink))
		_front.scale = Vector3(1.3 * pulse, 0.5 * pulse, 0.06)


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	var h: float = def.size.y
	var w: float = def.size.x
	var energy: float = 2.4 if def.moving else 1.6
	_body = MeshLib.mi(MeshLib.box(), Mats.lit(def.color), Vector3(0.0, BODY_LIFT + (h - BODY_LIFT) * 0.5, 0.0))
	_stripe_l = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, energy), Vector3(-w * 0.5, h * 0.62, 0.0))
	_stripe_r = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, energy), Vector3(w * 0.5, h * 0.62, 0.0))
	_roof = MeshLib.mi(MeshLib.box(), Mats.lit(def.color.lightened(0.12)), Vector3(0.0, h - 0.03, 0.0))
	_front = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, Color(1.0, 0.95, 0.75), 3.0))
	for node: MeshInstance3D in [_body, _stripe_l, _stripe_r, _roof, _front]:
		node.extra_cull_margin = 12.0
		root.add_child(node)
	return root


func _apply_length() -> void:
	if _body == null:
		return
	var h: float = def.size.y
	var w: float = def.size.x
	_body.scale = Vector3(w, h - BODY_LIFT, length)
	_stripe_l.scale = Vector3(0.04, 0.32, length - 0.4)
	_stripe_r.scale = Vector3(0.04, 0.32, length - 0.4)
	_roof.scale = Vector3(w * 0.8, 0.08, length - 0.3)
	_front.position = Vector3(0.0, h * 0.42, length * 0.5 + 0.02)
	_front.scale = Vector3(1.3, 0.5, 0.06)

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
var _under: MeshInstance3D = null
var _win_l: MeshInstance3D = null
var _win_r: MeshInstance3D = null
var _edge_l: MeshInstance3D = null
var _edge_r: MeshInstance3D = null
var _shield: MeshInstance3D = null
var _sign: MeshInstance3D = null
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


## Look (key art): dark body on a darker undercarriage, a row of lit cabin windows per side, a
## neon stripe in the obstacle colour, magenta roof edges and destination sign, a dark windscreen
## and a bright headlight.
const GLASS_COLOR: Color = Color(0.03, 0.035, 0.08)
const CABIN_LIGHT: Color = Color(0.72, 0.88, 1.0)
const UNDER_COLOR: Color = Color(0.025, 0.02, 0.045)
const WINDOW_PITCH: float = 1.6


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	var h: float = def.size.y
	var energy: float = 2.4 if def.moving else 1.6
	_body = MeshLib.mi(MeshLib.box(), Mats.lit(def.color), Vector3.ZERO)
	_under = MeshLib.mi(MeshLib.box(), Mats.lit(UNDER_COLOR), Vector3(0.0, BODY_LIFT * 0.5, 0.0))
	var windows: ShaderMaterial = Mats.lit_segmented(GLASS_COLOR, CABIN_LIGHT, 0.85, WINDOW_PITCH, 0.7)
	_win_l = MeshLib.mi(MeshLib.box(), windows)
	_win_r = MeshLib.mi(MeshLib.box(), windows)
	_stripe_l = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, energy))
	_stripe_r = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, def.glow, energy))
	_edge_l = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, Color.WHITE, 1.8, 2.0))
	_edge_r = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, Color.WHITE, 1.8, 2.0))
	_roof = MeshLib.mi(MeshLib.box(), Mats.lit(def.color.lightened(0.12)), Vector3(0.0, h - 0.03, 0.0))
	_shield = MeshLib.mi(MeshLib.box(), Mats.lit(GLASS_COLOR, Color(0.3, 0.75, 1.0), 0.12))
	_sign = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, Color.WHITE, 1.6, 2.0))
	_front = MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, Color(1.0, 0.95, 0.75), 3.0))
	for node: MeshInstance3D in [_body, _under, _win_l, _win_r, _stripe_l, _stripe_r, _edge_l, _edge_r,
			_roof, _shield, _sign, _front]:
		node.extra_cull_margin = 12.0
		root.add_child(node)
	return root


func _apply_length() -> void:
	if _body == null:
		return
	var h: float = def.size.y
	var w: float = def.size.x
	var half_w: float = w * 0.5
	var body_h: float = h - BODY_LIFT
	_body.position = Vector3(0.0, BODY_LIFT + body_h * 0.5, 0.0)
	_body.scale = Vector3(w, body_h, length)
	_under.scale = Vector3(w * 0.78, BODY_LIFT, length - 0.6)
	for side: float in [-1.0, 1.0]:
		var win: MeshInstance3D = _win_l if side < 0.0 else _win_r
		win.position = Vector3(side * (half_w + 0.01), h * 0.66, 0.0)
		win.scale = Vector3(0.03, h * 0.22, length - 1.0)
		var stripe: MeshInstance3D = _stripe_l if side < 0.0 else _stripe_r
		stripe.position = Vector3(side * (half_w + 0.012), h * 0.36, 0.0)
		stripe.scale = Vector3(0.03, 0.12, length - 0.4)
		var edge: MeshInstance3D = _edge_l if side < 0.0 else _edge_r
		edge.position = Vector3(side * (half_w - 0.04), h + 0.01, 0.0)
		edge.scale = Vector3(0.07, 0.06, length - 0.3)
	_roof.scale = Vector3(w * 0.8, 0.08, length - 0.3)
	_shield.position = Vector3(0.0, h * 0.7, length * 0.5 + 0.015)
	_shield.scale = Vector3(w * 0.78, h * 0.26, 0.04)
	_sign.position = Vector3(0.0, h * 0.9, length * 0.5 + 0.02)
	_sign.scale = Vector3(w * 0.6, 0.1, 0.04)
	_front.position = Vector3(0.0, h * 0.4, length * 0.5 + 0.02)
	_front.scale = Vector3(1.3, 0.5, 0.06)

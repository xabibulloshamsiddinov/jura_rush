## Shared chase camera for the versus mode: high behind both cars, framing the pair and the
## police behind them. Pulls back as the cars spread out, punches FOV on nitro, shakes on hits.
## On portrait screens it keeps the road width in view instead of the height.
class_name VsCamera
extends Node3D

var camera: Camera3D = null
var shake: ScreenShake = null

var _mid_x: float = 0.0
var _mid_z: float = 0.0
var _spread: float = 0.0
var _fov_punch: float = 0.0
var _intro: float = 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 0.3
	camera.far = 420.0
	camera.fov = 58.0
	add_child(camera)
	shake = ScreenShake.new()
	add_child(shake)


## Makes this the active camera and starts the intro swoop.
func activate() -> void:
	camera.current = true
	_intro = 0.0


## FOV kick (nitro, big hits).
func punch(amount: float) -> void:
	_fov_punch = maxf(_fov_punch, amount)


## Follows the cars. xs / zs = positions of the cars currently on the road.
func tick(delta: float, xs: Array[float], zs: Array[float]) -> void:
	shake.tick(delta)
	_intro = minf(_intro + delta * 0.55, 1.0)
	var mx: float = 0.0
	var mz: float = VsDefs.SPAWN_Z
	var spread: float = 0.0
	if not xs.is_empty():
		var lo: float = 1e9
		var hi: float = -1e9
		mx = 0.0
		for i in range(xs.size()):
			mx += xs[i]
			lo = minf(lo, zs[i])
			hi = maxf(hi, zs[i])
		mx /= float(xs.size())
		mz = (lo + hi) * 0.5
		spread = hi - lo
	_mid_x = MathUtils.damp(_mid_x, mx, 0.5, delta)
	_mid_z = MathUtils.damp(_mid_z, mz, 0.7, delta)
	_spread = MathUtils.damp(_spread, spread, 0.6, delta)
	_fov_punch = MathUtils.damp(_fov_punch, 0.0, 0.35, delta)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = view.y > view.x * 1.05
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	var pull: float = clampf(_spread / 18.0, 0.0, 1.0)
	var height: float = lerpf(10.5, 13.0, pull) + (6.0 if portrait else 0.0)
	var back: float = 18.5 + pull * 3.0 + (8.0 if portrait else 0.0)
	var anchor_z: float = clampf(_mid_z, VsDefs.FRONT_Z + 4.0, 2.0) * 0.55
	var eye: Vector3 = Vector3(_mid_x * 0.35, height, anchor_z + back)
	var look: Vector3 = Vector3(_mid_x * 0.25, 0.0, anchor_z - 10.0)
	# Intro: start low and wide beside the cars, sweep up into the chase view.
	var t: float = MathUtils.ease_out_cubic(_intro)
	eye = Vector3(-14.0, 3.0, -10.0).lerp(eye, t)
	look = Vector3(0.0, 1.0, VsDefs.SPAWN_Z).lerp(look, t)
	var goal: Transform3D = Transform3D(Basis.IDENTITY, eye).looking_at(look)
	goal.basis = goal.basis.rotated(goal.basis.z, shake.roll)
	goal.origin += goal.basis * (shake.offset * 2.0)
	camera.global_transform = goal
	camera.fov = (78.0 if portrait else 56.0) + _fov_punch

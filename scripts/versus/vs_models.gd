## Procedural vehicle and prop models for the versus mode, built from the shared unit
## primitives (MeshLib) and curved-world materials (Mats). 1 unit = 1 m, front of a car = -Z.
class_name VsModels
extends RefCounted

const GLASS: Color = Color(0.03, 0.05, 0.1)
const TYRE: Color = Color(0.03, 0.03, 0.04)
const RIM: Color = Color(0.55, 0.58, 0.66)
const HEAD: Color = Color(1.0, 0.95, 0.85)
const TAIL: Color = Color(1.0, 0.08, 0.1)
const TRAFFIC_PAINT: Array[Color] = [Color(0.55, 0.57, 0.62), Color(0.16, 0.18, 0.24),
		Color(0.62, 0.12, 0.14), Color(0.88, 0.88, 0.9), Color(0.15, 0.3, 0.55), Color(0.75, 0.62, 0.2),
		Color(0.22, 0.42, 0.3)]


## A vehicle body: wheels to spin, siren lights to flash, and optional extras.
class Vehicle extends Node3D:
	var wheels: Array[Node3D] = []
	var siren_red: Array[MeshInstance3D] = []
	var siren_blue: Array[MeshInstance3D] = []
	var body: Node3D = null
	var underglow: MeshInstance3D = null
	var flames: Node3D = null
	var shield: MeshInstance3D = null
	var shield_material: ShaderMaterial = null
	var length: float = 4.4
	var half_width: float = 1.0
	var _spin: float = 0.0
	var _siren_t: float = 0.0

	## Spins the wheels for a road speed (m/s) and flashes the siren if there is one.
	func animate(delta: float, road_speed: float) -> void:
		_spin = fmod(_spin + road_speed * delta / 0.38, TAU)
		for w: Node3D in wheels:
			w.rotation.x = -_spin
		if siren_red.is_empty():
			return
		_siren_t += delta
		var phase: bool = fmod(_siren_t, 0.36) < 0.18
		for m: MeshInstance3D in siren_red:
			m.visible = phase
		for m: MeshInstance3D in siren_blue:
			m.visible = not phase


## The player's sports car: low wedge body, neon underglow, light bar, nitro flames, shield.
static func player_car(paint: Color, glow: Color) -> Vehicle:
	var v: Vehicle = Vehicle.new()
	v.length = 4.4
	v.half_width = 1.0
	var body: Node3D = Node3D.new()
	v.body = body
	v.add_child(body)
	var paint_mat: ShaderMaterial = Mats.lit(paint, glow, 0.12)
	var dark: ShaderMaterial = Mats.lit(paint.darkened(0.55))
	body.add_child(MeshLib.mi(MeshLib.box(), paint_mat, Vector3(0.0, 0.52, 0.1), Vector3(2.0, 0.46, 4.3)))
	body.add_child(MeshLib.mi(MeshLib.box(), paint_mat, Vector3(0.0, 0.42, -1.75), Vector3(1.9, 0.3, 1.0)))
	body.add_child(MeshLib.mi(MeshLib.box(), dark, Vector3(0.0, 0.3, 0.0), Vector3(2.06, 0.18, 4.5)))
	var cabin: MeshInstance3D = MeshLib.mi(MeshLib.box(), Mats.lit(GLASS, glow, 0.25),
			Vector3(0.0, 0.95, 0.35), Vector3(1.55, 0.42, 1.9))
	body.add_child(cabin)
	body.add_child(MeshLib.mi(MeshLib.box(), paint_mat, Vector3(0.0, 1.18, 0.45), Vector3(1.4, 0.06, 1.3)))
	# Rear wing.
	body.add_child(MeshLib.mi(MeshLib.box(), dark, Vector3(0.0, 1.12, 2.05), Vector3(2.0, 0.07, 0.42)))
	for x: float in [-0.75, 0.75]:
		body.add_child(MeshLib.mi(MeshLib.box(), dark, Vector3(x, 0.92, 2.05), Vector3(0.08, 0.36, 0.2)))
	# Racing stripe and side neon.
	body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, glow, 2.2), Vector3(0.0, 0.755, -0.9),
			Vector3(0.32, 0.02, 2.0)))
	for x: float in [-1.03, 1.03]:
		body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, glow, 2.6), Vector3(x, 0.42, 0.1),
				Vector3(0.03, 0.06, 3.6)))
	_lights(body, 2.24, 0.98, 1.0)
	_wheels(v, body, 0.98, 1.35, 1.4)
	var under: MeshInstance3D = MeshLib.mi(MeshLib.plane(), Mats.glow(glow, 1.4, 1.0), Vector3(0.0, 0.04, 0.0),
			Vector3(3.0, 1.0, 5.6))
	v.underglow = under
	v.add_child(under)
	v.add_child(MeshLib.mi(MeshLib.plane(), Mats.blob_shadow(), Vector3(0.0, 0.03, 0.0), Vector3(2.6, 1.0, 5.0)))
	var flames: Node3D = Node3D.new()
	flames.visible = false
	for x: float in [-0.45, 0.45]:
		var flame: MeshInstance3D = MeshLib.mi(MeshLib.cone(), Mats.glow(Color(0.4, 1.0, 0.5), 3.0),
				Vector3(x, 0.45, 2.75), Vector3(0.3, 1.1, 0.3))
		flame.rotation.x = -PI * 0.5
		flames.add_child(flame)
		var core: MeshInstance3D = MeshLib.mi(MeshLib.cone(), Mats.glow(Color(1.0, 1.0, 0.8), 3.0),
				Vector3(x, 0.45, 2.55), Vector3(0.16, 0.6, 0.16))
		core.rotation.x = -PI * 0.5
		flames.add_child(core)
	v.flames = flames
	body.add_child(flames)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	v.shield_material = Mats.shield(VsDefs.color(&"shield"))
	v.shield = MeshLib.mi(sphere, v.shield_material, Vector3(0.0, 0.8, 0.1), Vector3(1.7, 1.25, 3.0))
	v.shield.visible = false
	v.add_child(v.shield)
	return v


## Civilian traffic: 0 sedan, 1 van, 2 truck (long trailer).
static func traffic(kind: int, rng: RandomNumberGenerator) -> Vehicle:
	var v: Vehicle = Vehicle.new()
	var paint: Color = TRAFFIC_PAINT[rng.randi_range(0, TRAFFIC_PAINT.size() - 1)]
	var mat: ShaderMaterial = Mats.lit(paint)
	var body: Node3D = Node3D.new()
	v.body = body
	v.add_child(body)
	match kind:
		1:
			v.length = 5.4
			v.half_width = 1.1
			body.add_child(MeshLib.mi(MeshLib.box(), mat, Vector3(0.0, 1.2, 0.25), Vector3(2.2, 1.85, 4.9)))
			body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(GLASS), Vector3(0.0, 1.5, -2.2), Vector3(2.0, 0.7, 0.12)))
			_lights(body, 2.72, 1.0, 0.75)
			_wheels(v, body, 1.0, 1.8, 1.6)
		2:
			v.length = 10.0
			v.half_width = 1.25
			var trailer: Color = Color(0.7, 0.72, 0.78) if rng.randf() < 0.6 else paint
			body.add_child(MeshLib.mi(MeshLib.box(), mat, Vector3(0.0, 1.35, -3.9), Vector3(2.4, 2.2, 2.2)))
			body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(GLASS), Vector3(0.0, 1.8, -5.02), Vector3(2.2, 0.8, 0.08)))
			body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(trailer), Vector3(0.0, 1.95, 1.1), Vector3(2.5, 2.9, 7.6)))
			# Amber clearance lights along the trailer.
			for z: float in [-2.2, 0.0, 2.2, 4.4]:
				for x: float in [-1.27, 1.27]:
					body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, Color(1.0, 0.6, 0.1), 2.5),
							Vector3(x, 3.3, z), Vector3(0.04, 0.12, 0.2)))
			_lights(body, 5.0, 1.15, 0.7)
			_wheels(v, body, 1.12, 3.5, -3.6)
			_wheels(v, body, 1.12, 3.5, 3.6)
		_:
			v.length = 4.5
			v.half_width = 1.0
			body.add_child(MeshLib.mi(MeshLib.box(), mat, Vector3(0.0, 0.65, 0.0), Vector3(1.95, 0.7, 4.5)))
			body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(GLASS), Vector3(0.0, 1.22, 0.2), Vector3(1.7, 0.5, 2.3)))
			body.add_child(MeshLib.mi(MeshLib.box(), mat, Vector3(0.0, 1.5, 0.2), Vector3(1.6, 0.06, 2.0)))
			_lights(body, 2.27, 0.92, 0.8)
			_wheels(v, body, 0.98, 1.45, 1.45)
	v.add_child(MeshLib.mi(MeshLib.plane(), Mats.blob_shadow(), Vector3(0.0, 0.03, 0.0),
			Vector3(v.half_width * 2.6, 1.0, v.length + 0.8)))
	return v


## Police interceptor: black and white body with a flashing red / blue light bar and a
## coloured glow on the road under it.
static func police() -> Vehicle:
	var v: Vehicle = Vehicle.new()
	v.length = 4.8
	v.half_width = 1.05
	var body: Node3D = Node3D.new()
	v.body = body
	v.add_child(body)
	var black: ShaderMaterial = Mats.lit(Color(0.05, 0.05, 0.07))
	var white: ShaderMaterial = Mats.lit(Color(0.92, 0.93, 0.96))
	body.add_child(MeshLib.mi(MeshLib.box(), black, Vector3(0.0, 0.62, 0.0), Vector3(2.05, 0.66, 4.8)))
	body.add_child(MeshLib.mi(MeshLib.box(), white, Vector3(0.0, 0.66, 0.3), Vector3(2.08, 0.42, 1.9)))
	body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(GLASS), Vector3(0.0, 1.2, 0.35), Vector3(1.75, 0.5, 2.3)))
	body.add_child(MeshLib.mi(MeshLib.box(), white, Vector3(0.0, 1.47, 0.35), Vector3(1.65, 0.05, 2.0)))
	# Push bar.
	body.add_child(MeshLib.mi(MeshLib.box(), black, Vector3(0.0, 0.55, -2.55), Vector3(1.6, 0.5, 0.2)))
	body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color(0.1, 0.1, 0.12)), Vector3(0.0, 1.55, 0.3),
			Vector3(1.4, 0.12, 0.34)))
	for x: float in [-0.42, 0.42]:
		var red: bool = x < 0.0
		var lamp: MeshInstance3D = MeshLib.mi(MeshLib.box(),
				Mats.lit(Color.BLACK, Color(1.0, 0.05, 0.1) if red else Color(0.1, 0.3, 1.0), 4.0),
				Vector3(x, 1.63, 0.3), Vector3(0.55, 0.14, 0.3))
		body.add_child(lamp)
		var halo: MeshInstance3D = MeshLib.mi(MeshLib.sphere(),
				Mats.glow(Color(1.0, 0.1, 0.15) if red else Color(0.15, 0.35, 1.0), 1.4),
				Vector3(x * 1.4, 1.65, 0.3), Vector3(1.4, 0.6, 1.0))
		body.add_child(halo)
		var pool: MeshInstance3D = MeshLib.mi(MeshLib.plane(),
				Mats.glow(Color(1.0, 0.1, 0.15) if red else Color(0.15, 0.35, 1.0), 0.9, 1.0),
				Vector3(x * 4.0, 0.05, 0.0), Vector3(3.2, 1.0, 7.0))
		v.add_child(pool)
		if red:
			v.siren_red.append(lamp)
			v.siren_red.append(halo)
			v.siren_red.append(pool)
		else:
			v.siren_blue.append(lamp)
			v.siren_blue.append(halo)
			v.siren_blue.append(pool)
	_lights(body, 2.42, 0.98, 0.85)
	_wheels(v, body, 1.0, 1.5, 1.5)
	v.add_child(MeshLib.mi(MeshLib.plane(), Mats.blob_shadow(), Vector3(0.0, 0.03, 0.0), Vector3(2.7, 1.0, 5.6)))
	return v


## Floating power-up orb: glowing core, spinning rings and a light pillar.
static func orb(id: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	var c: Color = VsDefs.color(id)
	root.add_child(MeshLib.mi(MeshLib.sphere(), Mats.lit(c.lightened(0.3), c, 2.4), Vector3(0.0, 1.1, 0.0),
			Vector3.ONE * 0.85))
	root.add_child(MeshLib.mi(MeshLib.sphere(), Mats.glow(c, 1.2), Vector3(0.0, 1.1, 0.0), Vector3.ONE * 1.6))
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 20
	torus.ring_segments = 4
	var ring: MeshInstance3D = MeshLib.mi(torus, Mats.glow(c, 2.2), Vector3(0.0, 1.1, 0.0), Vector3.ONE * 1.05)
	ring.name = "Ring"
	root.add_child(ring)
	var pillar: MeshInstance3D = MeshLib.mi(MeshLib.cylinder(), Mats.glow(c, 0.7), Vector3(0.0, 4.0, 0.0),
			Vector3(0.9, 8.0, 0.9))
	root.add_child(pillar)
	root.add_child(MeshLib.mi(MeshLib.plane(), Mats.glow(c, 1.1, 1.0), Vector3(0.0, 0.04, 0.0), Vector3(2.6, 1.0, 2.6)))
	return root


## Homing rocket / bolt projectile (a glowing slug with a tail).
static func projectile(id: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	var c: Color = VsDefs.color(id)
	if id == &"seeker":
		var shell: MeshInstance3D = MeshLib.mi(MeshLib.capsule(), Mats.lit(Color(0.9, 0.9, 0.95), c, 1.2),
				Vector3(0.0, 0.9, 0.0), Vector3(0.36, 0.5, 0.36))
		shell.rotation.x = PI * 0.5
		root.add_child(shell)
		root.add_child(MeshLib.mi(MeshLib.sphere(), Mats.glow(c, 2.6), Vector3(0.0, 0.9, 0.0), Vector3(1.3, 1.3, 1.3)))
		var tail: MeshInstance3D = MeshLib.mi(MeshLib.cone(), Mats.glow(c, 2.2), Vector3(0.0, 0.9, 1.6),
				Vector3(0.6, 2.6, 0.6))
		tail.rotation.x = -PI * 0.5
		root.add_child(tail)
	else:
		root.add_child(MeshLib.mi(MeshLib.box(), Mats.glow(c.lightened(0.4), 3.2), Vector3(0.0, 0.8, 0.0),
				Vector3(0.3, 0.3, 2.6)))
		root.add_child(MeshLib.mi(MeshLib.box(), Mats.glow(c, 1.6), Vector3(0.0, 0.8, 0.6), Vector3(0.7, 0.7, 4.0)))
	return root


## Road mine: flat puck with a blinking light ring.
static func mine() -> Node3D:
	var root: Node3D = Node3D.new()
	var c: Color = VsDefs.color(&"mine")
	root.add_child(MeshLib.mi(MeshLib.cylinder(), Mats.lit(Color(0.12, 0.12, 0.14), c, 0.6), Vector3(0.0, 0.18, 0.0),
			Vector3(1.2, 0.3, 1.2)))
	var light: MeshInstance3D = MeshLib.mi(MeshLib.sphere(), Mats.glow(c, 3.0), Vector3(0.0, 0.42, 0.0),
			Vector3.ONE * 0.45)
	light.name = "Blink"
	root.add_child(light)
	root.add_child(MeshLib.mi(MeshLib.plane(), Mats.glow(c, 1.2, 1.0), Vector3(0.0, 0.04, 0.0), Vector3(3.0, 1.0, 3.0)))
	return root


## EMP dome: a translucent electric half-sphere sitting on one lane.
static func dome() -> Node3D:
	var root: Node3D = Node3D.new()
	var c: Color = VsDefs.color(&"emp")
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.is_hemisphere = true
	sphere.radial_segments = 20
	sphere.rings = 8
	var shell: MeshInstance3D = MeshLib.mi(sphere, Mats.shield(c), Vector3.ZERO, Vector3(1.7, 1.5, 1.7))
	shell.name = "Shell"
	root.add_child(shell)
	root.add_child(MeshLib.mi(MeshLib.sphere(), Mats.glow(c, 2.4), Vector3(0.0, 0.5, 0.0), Vector3.ONE * 0.6))
	root.add_child(MeshLib.mi(MeshLib.plane(), Mats.glow(c, 1.4, 1.0), Vector3(0.0, 0.04, 0.0), Vector3(3.6, 1.0, 3.6)))
	return root


static func _lights(body: Node3D, half_len: float, half_w: float, height: float) -> void:
	for side: float in [-1.0, 1.0]:
		body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, HEAD, 3.0),
				Vector3(side * (half_w - 0.3), height * 0.62, -half_len), Vector3(0.42, 0.13, 0.06)))
		body.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, TAIL, 3.2),
				Vector3(side * (half_w - 0.32), height * 0.68, half_len), Vector3(0.5, 0.12, 0.06)))
	# Headlight beams on the road.
	body.add_child(MeshLib.mi(MeshLib.plane(), Mats.glow(Color(0.9, 0.85, 0.6), 0.05, 1.0),
			Vector3(0.0, 0.05, -half_len - 4.0), Vector3(half_w * 1.8, 1.0, 7.5)))


static func _wheels(v: Vehicle, body: Node3D, half_w: float, front_z: float, back_z: float) -> void:
	for x: float in [-half_w, half_w]:
		for z: float in [-front_z, back_z]:
			var pivot: Node3D = Node3D.new()
			pivot.position = Vector3(x, 0.38, z)
			var tyre: MeshInstance3D = MeshLib.mi(MeshLib.cylinder(), Mats.lit(TYRE), Vector3.ZERO,
					Vector3(0.76, 0.34, 0.76))
			tyre.rotation.z = PI * 0.5
			pivot.add_child(tyre)
			var rim: MeshInstance3D = MeshLib.mi(MeshLib.box(), Mats.lit(RIM), Vector3(signf(x) * 0.15, 0.0, 0.0),
					Vector3(0.06, 0.5, 0.12))
			pivot.add_child(rim)
			body.add_child(pivot)
			v.wheels.append(pivot)

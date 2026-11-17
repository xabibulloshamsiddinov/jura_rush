## Builds the pooled one-shot particle effects. CPUParticles3D is used on purpose: counts are
## tiny, it behaves identically on the Mobile and Compatibility renderers, and it avoids the
## shader-compile hitch GPU particles cause the first time they appear on phones.
## Jura Rush look: earthy dust puffs (soft alpha), tumbling pebbles and rock chunks (lit), a shell
## sparkle with a small warm burst for eggs. No neon: only sparkles and bursts add light.
## An effect may carry child CPUParticles3D (VFXManager.play restarts them together).
class_name VfxFactory
extends RefCounted

## id -> lifetime in seconds (how long before the node returns to its pool).
const LIFETIMES: Dictionary = {
	&"coin_pickup": 0.55, &"dust": 0.6, &"land": 0.75, &"sparks": 0.7, &"crash": 1.4,
	&"shards": 0.9, &"burst": 0.7, &"debris": 1.2,
}
## id -> instances pre-created at boot.
const POOL_SIZES: Dictionary = {
	&"coin_pickup": 12, &"dust": 4, &"land": 2, &"sparks": 4, &"crash": 1,
	&"shards": 1, &"burst": 3, &"debris": 4,
}
const DUST: Color = Color(0.74, 0.63, 0.48, 0.5)
const PEBBLE: Color = Color(0.6, 0.55, 0.48)

static var _quad_material: StandardMaterial3D = null
static var _quad: QuadMesh = null
static var _soft_material: StandardMaterial3D = null
static var _soft_quad: QuadMesh = null
static var _pebble: ArrayMesh = null
static var _solid: StandardMaterial3D = null


## Creates the particle node for an effect id.
static func build(id: StringName) -> Node:
	match id:
		&"coin_pickup":
			# Shell sparkle (light) + a small warm burst.
			var sparkle: CPUParticles3D = _particles(7, 0.38, &"add", Color(1.6, 1.5, 1.25), 180.0, 1.8, 3.8,
					Vector3(0, -1.5, 0), 0.06, 0.14)
			sparkle.add_child(_particles(5, 0.5, &"add", Color(1.4, 0.8, 0.3, 0.8), 180.0, 0.6, 1.6,
					Vector3(0, 0.6, 0), 0.14, 0.3))
			return sparkle
		&"dust":
			return _particles(5, 0.55, &"soft", DUST, 60.0, 0.4, 1.4, Vector3(0, 0.8, 4.0), 0.16, 0.32)
		&"land":
			return _particles(12, 0.7, &"soft", Color(DUST, 0.55), 85.0, 1.4, 3.6, Vector3(0, 0.4, 5.0), 0.2, 0.42)
		&"sparks":
			# Lane change / stumble: a puff of dust with a few pebbles kicked up.
			var puff: CPUParticles3D = _particles(7, 0.55, &"soft", DUST, 80.0, 1.0, 2.6, Vector3(0, 0.5, 5.0), 0.16, 0.34)
			puff.add_child(_particles(5, 0.6, &"pebble", PEBBLE, 70.0, 2.0, 4.5, Vector3(0, -14.0, 6.0), 0.05, 0.1))
			return puff
		&"crash":
			# A big dust cloud (rock debris comes from "debris").
			return _particles(22, 1.3, &"soft", Color(0.72, 0.6, 0.45, 0.6), 180.0, 1.5, 4.5, Vector3(0, 0.6, 1.0), 0.45, 0.9)
		&"shards":
			return _particles(18, 0.8, &"pebble", Color(0.7, 0.9, 0.86), 180.0, 3.0, 7.0, Vector3(0, -8.0, 0), 0.06, 0.14)
		&"burst":
			return _particles(16, 0.6, &"add", Color(1.4, 1.2, 0.9, 0.85), 180.0, 2.0, 5.0, Vector3(0, -2.0, 0), 0.08, 0.22)
		&"debris":
			return _particles(12, 1.1, &"pebble", PEBBLE, 150.0, 3.5, 9.0, Vector3(0, -18.0, 8.0), 0.1, 0.24)
	return Node3D.new()


## kind: &"add" glowing camera-facing quads, &"soft" alpha-blended dust puffs, &"pebble" tumbling
## lit stones.
static func _particles(amount: int, lifetime: float, kind: StringName, color: Color,
		spread: float, vel_min: float, vel_max: float, gravity: Vector3, scale_min: float,
		scale_max: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(int(float(amount) * SettingsManager.particle_scale()), 2)
	p.lifetime = lifetime
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.gravity = gravity
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color = color
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		&"add":
			p.mesh = _billboard_quad()
		&"soft":
			p.mesh = _soft_puff()
			# Dust grows as it fades.
			var grow: Curve = Curve.new()
			grow.add_point(Vector2(0.0, 0.55))
			grow.add_point(Vector2(1.0, 1.0))
			p.scale_amount_curve = grow
		_:
			p.mesh = _pebble_mesh()
			p.material_override = _solid_material()
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
	return p


## Soft round additive sprite (sparkles, bursts).
static func _billboard_quad() -> QuadMesh:
	if _quad == null:
		_quad_material = _sprite_material(BaseMaterial3D.BLEND_MODE_ADD)
		_quad = QuadMesh.new()
		_quad.material = _quad_material
	return _quad


## Soft round alpha-blended sprite (dust).
static func _soft_puff() -> QuadMesh:
	if _soft_quad == null:
		_soft_material = _sprite_material(BaseMaterial3D.BLEND_MODE_MIX)
		_soft_quad = QuadMesh.new()
		_soft_quad.material = _soft_material
	return _soft_quad


static func _sprite_material(blend: BaseMaterial3D.BlendMode) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = blend
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.disable_receive_shadows = true
	# Soft round sprite: without it every particle was a hard-edged square.
	var dot: Gradient = Gradient.new()
	dot.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	dot.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	dot.add_point(0.35, Color(1.0, 1.0, 1.0, 0.75))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = dot
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	mat.albedo_texture = tex
	return mat


## A faceted pebble (an icosahedron squashed a little), white so the particle colour shows.
static func _pebble_mesh() -> ArrayMesh:
	if _pebble == null:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var t: float = (1.0 + sqrt(5.0)) * 0.5
		var v: Array[Vector3] = [
			Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5
		for i in range(v.size()):
			v[i] = v[i].normalized() * rng.randf_range(0.8, 1.1) * Vector3(0.5, 0.38, 0.45)
		for f: Vector3i in NatureMesh.ICO_FACES:
			var a: Vector3 = v[f.x]
			var b: Vector3 = v[f.y]
			var c: Vector3 = v[f.z]
			var n: Vector3 = (c - a).cross(b - a).normalized()
			if n.dot(a + b + c) < 0.0:
				n = -n
				var tmp: Vector3 = b
				b = c
				c = tmp
			for p: Vector3 in [a, b, c]:
				st.set_normal(n)
				st.add_vertex(p)
		_pebble = st.commit()
	return _pebble


## Lit, vertex-coloured (particle colour) material for pebbles and rock chunks.
static func _solid_material() -> StandardMaterial3D:
	if _solid == null:
		_solid = StandardMaterial3D.new()
		_solid.vertex_color_use_as_albedo = true
		_solid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_solid.roughness = 1.0
		_solid.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _solid

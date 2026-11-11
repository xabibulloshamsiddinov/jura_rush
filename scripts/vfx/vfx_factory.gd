## Builds the pooled one-shot particle effects. CPUParticles3D is used on purpose: counts are
## tiny, it behaves identically on the Mobile and Compatibility renderers, and it avoids the
## shader-compile hitch GPU particles cause the first time they appear on phones.
class_name VfxFactory
extends RefCounted

## id -> lifetime in seconds (how long before the node returns to its pool).
const LIFETIMES: Dictionary = {
	&"coin_pickup": 0.45, &"dust": 0.5, &"land": 0.6, &"sparks": 0.4, &"crash": 1.2,
	&"shards": 0.9, &"burst": 0.7, &"debris": 1.1,
}
## id -> instances pre-created at boot.
const POOL_SIZES: Dictionary = {
	&"coin_pickup": 12, &"dust": 4, &"land": 2, &"sparks": 4, &"crash": 1,
	&"shards": 1, &"burst": 3, &"debris": 4,
}

static var _quad_material: StandardMaterial3D = null
static var _quad: QuadMesh = null


## Creates the particle node for an effect id.
static func build(id: StringName) -> Node:
	match id:
		&"coin_pickup":
			return _particles(6, 0.4, true, Color(2.2, 1.8, 0.5), 180.0, 1.5, 3.5, Vector3(0, -2, 0), 0.1, 0.22)
		&"dust":
			return _particles(5, 0.45, true, Color(0.55, 0.6, 0.8, 0.28), 60.0, 0.5, 1.6, Vector3(0, 1.0, 4.0), 0.07, 0.18)
		&"land":
			return _particles(12, 0.55, true, Color(0.6, 0.65, 0.85, 0.4), 85.0, 1.5, 4.0, Vector3(0, 0.5, 5.0), 0.1, 0.3)
		&"sparks":
			return _particles(14, 0.35, true, Color(3.0, 1.8, 0.6), 70.0, 3.0, 8.0, Vector3(0, -12.0, 6.0), 0.05, 0.14)
		&"crash":
			return _particles(28, 1.0, true, Color(3.0, 2.2, 1.2), 180.0, 4.0, 11.0, Vector3(0, -9.0, 0), 0.08, 0.3)
		&"shards":
			return _particles(22, 0.8, false, Color(0.4, 0.85, 1.6), 180.0, 3.0, 8.0, Vector3(0, -8.0, 0), 0.08, 0.22)
		&"burst":
			return _particles(18, 0.6, true, Color(2.0, 2.0, 2.0), 180.0, 2.5, 6.5, Vector3(0, -3.0, 0), 0.08, 0.26)
		&"debris":
			return _particles(12, 1.0, false, Color(0.25, 0.27, 0.4), 150.0, 4.0, 10.0, Vector3(0, -18.0, 8.0), 0.15, 0.4)
	return Node3D.new()


## billboard = glowing camera-facing quads; otherwise tumbling solid cubes.
static func _particles(amount: int, lifetime: float, billboard: bool, color: Color,
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
	if billboard:
		p.mesh = _billboard_quad()
	else:
		p.mesh = MeshLib.box()
		p.material_override = _solid_material()
		p.angular_velocity_min = -400.0
		p.angular_velocity_max = 400.0
	return p


static func _billboard_quad() -> QuadMesh:
	if _quad == null:
		_quad_material = StandardMaterial3D.new()
		_quad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_quad_material.vertex_color_use_as_albedo = true
		_quad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_quad_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_quad_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_quad_material.billboard_keep_scale = true
		_quad = QuadMesh.new()
		_quad.material = _quad_material
	return _quad


static var _solid: StandardMaterial3D = null


static func _solid_material() -> StandardMaterial3D:
	if _solid == null:
		_solid = StandardMaterial3D.new()
		_solid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_solid.vertex_color_use_as_albedo = true
		_solid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _solid

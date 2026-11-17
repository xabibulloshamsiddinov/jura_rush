## Soft dust puffs for creature footfalls, pawing and snorts. One MultiMesh (one draw call) per
## creature with a small ring buffer of puffs simulated on the CPU; nothing is allocated after
## construction. Lives in world space (top_level) so a puff stays where it was kicked up; `drift`
## is the ground velocity (the treadmill moves toward +Z at the world speed).
class_name CreatureDust
extends MultiMeshInstance3D

const DEFAULT_TINT: Color = Color(0.86, 0.76, 0.6)

static var _quad: QuadMesh = null

## Ground velocity added to every live puff (world space, m/s).
var drift: Vector3 = Vector3.ZERO
var tint: Color = DEFAULT_TINT

var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _alpha: PackedFloat32Array = PackedFloat32Array()
var _next: int = 0
var _alive: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(count: int = 16) -> void:
	top_level = true
	if _quad == null:
		_quad = QuadMesh.new()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _quad
	multimesh.instance_count = count
	material_override = CreatureMats.dust()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 40.0
	_pos.resize(count)
	_vel.resize(count)
	_age.resize(count)
	_life.resize(count)
	_size.resize(count)
	_alpha.resize(count)
	_rng.seed = 4242
	clear()


## Kicks up `amount` puffs at a world position. velocity = initial velocity (world), spread =
## random extra speed, size = final puff size in metres, life in seconds.
func puff(at: Vector3, velocity: Vector3, amount: int = 3, size: float = 0.9, life: float = 0.7,
		spread: float = 1.2, alpha: float = 0.55) -> void:
	var n: int = maxi(int(round(float(amount) * SettingsManager.particle_scale())), 1)
	for k in range(n):
		var i: int = _next
		_next = (_next + 1) % _age.size()
		if _age[i] >= _life[i]:
			_alive += 1
		_pos[i] = at + Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.0, 0.15),
				_rng.randf_range(-0.25, 0.25)) * size
		_vel[i] = velocity + Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.2, 1.0),
				_rng.randf_range(-1.0, 1.0)) * spread
		_age[i] = 0.0
		_life[i] = life * _rng.randf_range(0.75, 1.2)
		_size[i] = size * _rng.randf_range(0.7, 1.25)
		_alpha[i] = alpha
	visible = true


## Advances every live puff (call once per frame while the owner animates).
func tick(delta: float) -> void:
	if _alive <= 0:
		return
	_alive = 0
	for i in range(_age.size()):
		if _age[i] >= _life[i]:
			continue
		_age[i] += delta
		var t: float = _age[i] / _life[i]
		if t >= 1.0:
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), _pos[i]))
			multimesh.set_instance_color(i, Color(tint, 0.0))
			continue
		_alive += 1
		_vel[i] *= exp(-delta * 3.0)
		_pos[i] += (_vel[i] + drift) * delta
		var s: float = _size[i] * (0.35 + 0.65 * sqrt(t))
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), _pos[i]))
		multimesh.set_instance_color(i, Color(tint, _alpha[i] * (1.0 - t) * minf(t * 6.0, 1.0)))
	if _alive == 0:
		visible = false


## Kills every puff.
func clear() -> void:
	for i in range(_age.size()):
		_age[i] = 1.0
		_life[i] = 0.0
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO))
		multimesh.set_instance_color(i, Color(tint, 0.0))
	_alive = 0
	visible = false

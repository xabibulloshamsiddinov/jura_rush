## TrailComponent: a ribbon drawn behind the runner. Because the world is a treadmill, trail
## points drift toward the camera at world speed instead of the emitter moving forward.
class_name TrailComponent
extends MeshInstance3D

const MAX_POINTS: int = 20

var _points: PackedVector3Array = PackedVector3Array()
var _count: int = 0
var _mesh: ImmediateMesh = ImmediateMesh.new()
var _width: float = 0.45
var _length: int = 10
var _boost: float = 0.0
var _spacing_left: float = 0.0
## true: the ribbon lies flat (spreads along X), a light streak on the ground behind the runner.
## false: an upright ribbon (versus-mode cars). Seen from the chase camera an upright ribbon
## collapses into a thin vertical line, which read as a laser beam under the runner.
var flat: bool = false


func _ready() -> void:
	_points.resize(MAX_POINTS)
	mesh = _mesh
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 30.0
	apply_trail(ContentDB.TRAILS[0])


## Applies a purchasable trail style.
func apply_trail(def: TrailDef) -> void:
	_width = def.width
	_length = clampi(def.length, 2, MAX_POINTS)
	material_override = Mats.glow(def.color, 1.6, 1.0, 0.0, true)
	# A flat streak covers rails and coins, so it stays fainter and narrower than the upright ribbon.
	(material_override as ShaderMaterial).set_shader_parameter(&"albedo", Color(def.color, 0.28 if flat else 0.7))


## Makes the ribbon briefly wider (lane change, dash).
func burst() -> void:
	_boost = 1.0


## Removes all points (teleport / reset).
func clear_points() -> void:
	_count = 0
	_mesh.clear_surfaces()


## Advances the ribbon: drift existing points back, drop a new one at `emit_pos`, rebuild mesh.
func tick(delta: float, world_speed: float, emit_pos: Vector3, emitting: bool) -> void:
	_boost = maxf(_boost - delta * 3.0, 0.0)
	var drift: float = world_speed * delta
	for i in range(_count):
		_points[i].z += drift
	_spacing_left -= drift
	if emitting and (_spacing_left <= 0.0 or _count == 0):
		_spacing_left = 0.6
		var keep: int = mini(_count, _length - 1)
		for i in range(keep, 0, -1):
			_points[i] = _points[i - 1]
		_points[0] = emit_pos
		_count = keep + 1
	elif not emitting and _count > 0 and _points[_count - 1].z > 12.0:
		_count -= 1
	_mesh.clear_surfaces()
	if _count < 1 or world_speed < 1.0:
		return
	var half: float = _width * (0.5 + _boost * 0.5)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	_add_pair(emit_pos, half, 0.0)
	for i in range(_count):
		_add_pair(_points[i], half, float(i + 1) / float(_count))
	_mesh.surface_end()


func _add_pair(p: Vector3, half: float, t: float) -> void:
	var fade: Color = Color(1.0, 1.0, 1.0, 1.0 - t)
	var w: float = half * (1.0 - t * 0.7) * (0.4 if flat else 1.0)
	_mesh.surface_set_color(fade)
	_mesh.surface_set_uv(Vector2(t, 0.0))
	var offset: Vector3 = Vector3(w, 0.0, 0.0) if flat else Vector3(0.0, w, 0.0)
	_mesh.surface_add_vertex(p + offset)
	_mesh.surface_set_color(fade)
	_mesh.surface_set_uv(Vector2(t, 1.0))
	_mesh.surface_add_vertex(p - offset)

## Debug view (F3): draws chunk bounds, lane lines and the recycle line on top of the world.
class_name TrackDebugDraw
extends MeshInstance3D

var _track: TrackManager = null
var _mesh: ImmediateMesh = ImmediateMesh.new()
var _cfg: GameConfig = GameConfig.current()


func _init(track: TrackManager) -> void:
	_track = track
	mesh = _mesh
	visible = false
	material_override = Mats.glow(Color(1.0, 1.0, 1.0), 2.0)
	extra_cull_margin = 300.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed(&"debug_overlay"):
		visible = not visible
		if not visible:
			_mesh.clear_surfaces()


func _physics_process(_delta: float) -> void:
	if not visible or _track.chunks.is_empty():
		return
	var length: float = _cfg.chunk_length
	var half: float = _cfg.lane_width * float(_cfg.lane_count) * 0.5
	var near_z: float = _track.chunks[0].position.z
	var far_z: float = _track.chunks[_track.chunks.size() - 1].position.z - length
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# Lane boundaries.
	_mesh.surface_set_color(Color(0.2, 1.0, 0.4))
	for i in range(_cfg.lane_count + 1):
		var x: float = -half + float(i) * _cfg.lane_width
		_mesh.surface_add_vertex(Vector3(x, 0.15, near_z))
		_mesh.surface_add_vertex(Vector3(x, 0.15, far_z))
	# Chunk bounds.
	_mesh.surface_set_color(Color(1.0, 0.9, 0.1))
	for chunk in _track.chunks:
		var z: float = chunk.position.z
		_mesh.surface_add_vertex(Vector3(-half - 1.0, 0.2, z))
		_mesh.surface_add_vertex(Vector3(half + 1.0, 0.2, z))
		_mesh.surface_add_vertex(Vector3(half + 1.0, 0.2, z))
		_mesh.surface_add_vertex(Vector3(half + 1.0, 2.0, z))
	# Recycle line.
	_mesh.surface_set_color(Color(1.0, 0.2, 0.2))
	var rz: float = _cfg.recycle_threshold
	_mesh.surface_add_vertex(Vector3(-half - 3.0, 0.3, rz))
	_mesh.surface_add_vertex(Vector3(half + 3.0, 0.3, rz))
	_mesh.surface_end()

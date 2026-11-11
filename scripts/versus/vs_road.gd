## The 5-lane night highway: recycled road segments (one shared merged mesh: asphalt, glowing
## lane markings, crash barriers, street lamps with wet-road reflections, overhead gantries) and
## a city skyline MultiMesh per segment using the lit-window building shader.
class_name VsRoad
extends Node3D

const SEG_LEN: float = 40.0
const SEGMENTS: int = 7
const DECOR_PER_SIDE: int = 6
const ASPHALT: Color = Color(0.045, 0.05, 0.075)
const SHOULDER: Color = Color(0.03, 0.032, 0.05)
const BARRIER: Color = Color(0.22, 0.24, 0.3)
const POLE: Color = Color(0.09, 0.09, 0.13)
const GROUND: Color = Color(0.015, 0.018, 0.035)

## Metres of road driven (drives spawning and the sky drift).
var distance: float = 0.0

var _segments: Array[Node3D] = []
var _decor: Array[MultiMesh] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _mesh: ArrayMesh = null


func _ready() -> void:
	_rng.seed = 7
	var mesh: ArrayMesh = road_mesh()
	for i in range(SEGMENTS):
		var seg: Node3D = Node3D.new()
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 8.0
		seg.add_child(mi)
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = MeshLib.box()
		mm.instance_count = DECOR_PER_SIDE * 2 + 2
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _building_material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 40.0
		seg.add_child(mmi)
		add_child(seg)
		_segments.append(seg)
		_decor.append(mm)
		seg.position.z = SEG_LEN - float(i) * SEG_LEN
		_fill_decor(mm)


## Back to the start.
func reset() -> void:
	distance = 0.0
	for i in range(SEGMENTS):
		_segments[i].position.z = SEG_LEN - float(i) * SEG_LEN


## Scrolls the road toward the camera and recycles segments that passed behind it.
func advance(step: float) -> void:
	distance += step
	var far_z: float = 1e9
	for seg: Node3D in _segments:
		seg.position.z += step
		far_z = minf(far_z, seg.position.z)
	for i in range(SEGMENTS):
		var seg: Node3D = _segments[i]
		if seg.position.z - SEG_LEN > VsDefs.DESPAWN_Z + 10.0:
			seg.position.z = far_z - SEG_LEN
			far_z = seg.position.z
			_fill_decor(_decor[i])


func _fill_decor(mm: MultiMesh) -> void:
	var count: int = 0
	var slot: float = SEG_LEN / float(DECOR_PER_SIDE)
	for side: float in [-1.0, 1.0]:
		for i in range(DECOR_PER_SIDE):
			var w: float = _rng.randf_range(5.0, 11.0)
			var h: float = _rng.randf_range(14.0, 46.0)
			if _rng.randf() < 0.25:
				h = _rng.randf_range(6.0, 10.0)
			var d: float = _rng.randf_range(slot * 0.6, slot * 0.95)
			var x: float = side * (VsDefs.ROAD_HALF + _rng.randf_range(13.0, 24.0) + w * 0.5)
			var z: float = -(float(i) + 0.5) * slot
			mm.set_instance_transform(count, Transform3D(Basis().scaled(Vector3(w, h, d)), Vector3(x, h * 0.5 - 0.4, z)))
			var shade: float = _rng.randf_range(0.7, 1.5)
			mm.set_instance_color(count, Color(shade, shade, shade * 1.15))
			count += 1
	# Far skyline towers.
	for side: float in [-1.0, 1.0]:
		var w2: float = _rng.randf_range(10.0, 18.0)
		var h2: float = _rng.randf_range(50.0, 90.0)
		mm.set_instance_transform(count, Transform3D(Basis().scaled(Vector3(w2, h2, w2)),
				Vector3(side * _rng.randf_range(48.0, 70.0), h2 * 0.5, -_rng.randf_range(5.0, 35.0))))
		mm.set_instance_color(count, Color(0.8, 0.8, 0.95))
		count += 1
	mm.visible_instance_count = count


## Own copy of the building shader with dimmer, sparser windows (the shared one is tuned for
## the runner's narrower corridor).
static var _building: ShaderMaterial = null


static func _building_material() -> ShaderMaterial:
	if _building == null:
		_building = ShaderMaterial.new()
		_building.shader = Mats.BUILDING_SHADER
		_building.set_shader_parameter(&"window_energy", 1.05)
		_building.set_shader_parameter(&"lit_ratio", 0.32)
	return _building


## The merged static mesh of one road segment. Surface 0 is vertex-coloured solid geometry,
## surface 1 glows with the biome accent (lane dashes, barrier strips), surface 2 is warm lamp
## light (lamp heads and their reflections on the wet asphalt).
static func road_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var solid: SurfaceTool = SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var accent: SurfaceTool = SurfaceTool.new()
	accent.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lamp: SurfaceTool = SurfaceTool.new()
	lamp.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wet: SurfaceTool = SurfaceTool.new()
	wet.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid: float = -SEG_LEN * 0.5
	var half: float = VsDefs.ROAD_HALF
	MeshLib.add_box(solid, Vector3(0.0, -0.1, mid), Vector3(half * 2.0, 0.2, SEG_LEN), ASPHALT)
	MeshLib.add_box(solid, Vector3(0.0, -0.32, mid), Vector3(200.0, 0.2, SEG_LEN), GROUND)
	# Shoulders and the darker tyre tracks in every lane (gives the asphalt some texture).
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(solid, Vector3(side * (half + 1.6), -0.08, mid), Vector3(3.2, 0.2, SEG_LEN), SHOULDER)
	for lane in range(VsDefs.LANES):
		var lx: float = VsDefs.lane_x(lane)
		for off: float in [-0.75, 0.75]:
			MeshLib.add_box(solid, Vector3(lx + off, 0.002, mid), Vector3(0.55, 0.01, SEG_LEN), Color(0.035, 0.038, 0.058))
	# Dashed lane lines.
	for boundary in range(1, VsDefs.LANES):
		var bx: float = VsDefs.lane_x(boundary) - VsDefs.LANE_W * 0.5
		for i in range(int(SEG_LEN / 8.0)):
			MeshLib.add_box(accent, Vector3(bx, 0.012, -(float(i) + 0.5) * 8.0), Vector3(0.12, 0.02, 3.4))
	# Solid edge lines + concrete barriers with a neon strip.
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(accent, Vector3(side * (half - 0.35), 0.012, mid), Vector3(0.16, 0.02, SEG_LEN))
		MeshLib.add_box(solid, Vector3(side * (half + 0.3), 0.45, mid), Vector3(0.5, 0.9, SEG_LEN), BARRIER)
		MeshLib.add_box(solid, Vector3(side * (half + 0.3), 0.98, mid), Vector3(0.3, 0.16, SEG_LEN), BARRIER.darkened(0.3))
		MeshLib.add_box(accent, Vector3(side * (half + 0.04), 0.62, mid), Vector3(0.04, 0.1, SEG_LEN))
		# Street lamps every 20 m, arm over the road, warm head + reflection streak on the road.
		for i in range(2):
			var z: float = -(float(i) + 0.25) * 20.0
			var px: float = side * (half + 1.1)
			MeshLib.add_box(solid, Vector3(px, 4.2, z), Vector3(0.22, 8.4, 0.22), POLE)
			MeshLib.add_box(solid, Vector3(px - side * 1.6, 8.3, z), Vector3(3.3, 0.16, 0.2), POLE)
			MeshLib.add_box(lamp, Vector3(px - side * 2.9, 8.15, z), Vector3(1.0, 0.12, 0.42))
			# Wet-asphalt reflection: a long faint additive streak under the lamp.
			MeshLib.add_box(wet, Vector3(px - side * 2.9, 0.02, z + 3.0), Vector3(0.6, 0.004, 9.0))
			MeshLib.add_box(wet, Vector3(px - side * 2.9, 0.025, z + 2.0), Vector3(0.22, 0.004, 5.0))
	# Overhead gantry with glowing sign boards (once per segment), high enough to pass over the
	# chase camera.
	var gz: float = -SEG_LEN * 0.72
	var gy: float = 15.5
	for side: float in [-1.0, 1.0]:
		MeshLib.add_box(solid, Vector3(side * (half + 1.0), gy * 0.5, gz), Vector3(0.5, gy, 0.5), POLE)
	MeshLib.add_box(solid, Vector3(0.0, gy, gz), Vector3(half * 2.0 + 2.5, 0.6, 0.6), POLE)
	MeshLib.add_box(solid, Vector3(-4.0, gy - 1.3, gz), Vector3(5.5, 2.0, 0.2), Color(0.03, 0.035, 0.06))
	MeshLib.add_box(solid, Vector3(4.6, gy - 1.3, gz), Vector3(4.2, 2.0, 0.2), Color(0.03, 0.035, 0.06))
	MeshLib.add_box(accent, Vector3(-4.0, gy - 1.3, gz + 0.12), Vector3(5.2, 0.12, 0.05))
	MeshLib.add_box(accent, Vector3(-4.0, gy - 1.7, gz + 0.12), Vector3(3.6, 0.3, 0.05))
	MeshLib.add_box(lamp, Vector3(4.6, gy - 1.1, gz + 0.12), Vector3(3.9, 0.35, 0.05))
	MeshLib.add_box(lamp, Vector3(4.6, gy - 1.6, gz + 0.12), Vector3(2.4, 0.18, 0.05))
	_mesh = ArrayMesh.new()
	solid.commit(_mesh)
	accent.commit(_mesh)
	lamp.commit(_mesh)
	wet.commit(_mesh)
	var base: ShaderMaterial = Mats.lit(Color.WHITE)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# Web builds: lift the near-black asphalt so the road reads as a surface.
		base = base.duplicate() as ShaderMaterial
		base.set_shader_parameter(&"albedo", Color(2.0, 2.0, 2.3))
	_mesh.surface_set_material(0, base)
	_mesh.surface_set_material(1, Mats.lit(Color.BLACK, Color.WHITE, 1.8, 1.0))
	_mesh.surface_set_material(2, Mats.lit(Color.BLACK, Color.WHITE, 1.4, 2.0))
	_mesh.surface_set_material(3, Mats.glow(Color(1.0, 0.55, 0.25, 0.5), 0.3))
	return _mesh

## Shared unit primitives. All procedural art is these few meshes scaled through node transforms,
## so the GPU only ever holds a handful of vertex buffers. Scale: 1 unit = 1 metre.
class_name MeshLib
extends RefCounted

static var _box: BoxMesh = null
static var _sphere: SphereMesh = null
static var _capsule: CapsuleMesh = null
static var _cylinder: CylinderMesh = null
static var _quad: QuadMesh = null
static var _plane: PlaneMesh = null
static var _coin: CylinderMesh = null
static var _wedge: PrismMesh = null
static var _cone: CylinderMesh = null


## 1 x 1 x 1 box centred on the origin.
static func box() -> BoxMesh:
	if _box == null:
		_box = BoxMesh.new()
	return _box


## Sphere of diameter 1.
static func sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radial_segments = 14
		_sphere.rings = 7
	return _sphere


## Capsule of radius 0.5 and total height 2.
static func capsule() -> CapsuleMesh:
	if _capsule == null:
		_capsule = CapsuleMesh.new()
		_capsule.radial_segments = 12
		_capsule.rings = 4
	return _capsule


## Cylinder of diameter 1 and height 1.
static func cylinder() -> CylinderMesh:
	if _cylinder == null:
		_cylinder = CylinderMesh.new()
		_cylinder.height = 1.0
		_cylinder.radial_segments = 12
		_cylinder.rings = 1
	return _cylinder


## Cone of base diameter 1 and height 1 (flames, light cones).
static func cone() -> CylinderMesh:
	if _cone == null:
		_cone = CylinderMesh.new()
		_cone.top_radius = 0.0
		_cone.height = 1.0
		_cone.radial_segments = 10
		_cone.rings = 1
	return _cone


## Vertical 1 x 1 quad facing +Z.
static func quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
	return _quad


## Horizontal 1 x 1 plane facing +Y.
static func plane() -> PlaneMesh:
	if _plane == null:
		_plane = PlaneMesh.new()
		_plane.size = Vector2.ONE
	return _plane


## Coin disc (axis along Y; the MultiMesh instance basis stands it upright).
static func coin() -> CylinderMesh:
	if _coin == null:
		_coin = CylinderMesh.new()
		_coin.top_radius = VisualTuning.COIN_RADIUS
		_coin.bottom_radius = VisualTuning.COIN_RADIUS
		_coin.height = VisualTuning.COIN_THICKNESS
		_coin.radial_segments = 10
		_coin.rings = 1
	return _coin


## Right-angled wedge (1 x 1 x 1): high at x = -0.5, sloping down to x = +0.5.
static func wedge() -> PrismMesh:
	if _wedge == null:
		_wedge = PrismMesh.new()
		_wedge.left_to_right = 0.0
	return _wedge


## Convenience: creates a MeshInstance3D with a material, position and scale.
static func mi(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO,
		scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.scale = scale
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Appends an axis-aligned box to a SurfaceTool (used to merge static track geometry).
static func add_box(st: SurfaceTool, center: Vector3, size: Vector3,
		color: Color = Color.WHITE) -> void:
	var h: Vector3 = size * 0.5
	var faces: Array[Array] = [
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var c: Vector3 = center + n * h
		var du: Vector3 = u * h
		var dv: Vector3 = v * h
		var p0: Vector3 = c - du - dv
		var p1: Vector3 = c + du - dv
		var p2: Vector3 = c + du + dv
		var p3: Vector3 = c - du + dv
		# Clockwise winding seen from outside (Godot's front face).
		for p: Vector3 in [p0, p1, p2, p0, p2, p3]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(p)

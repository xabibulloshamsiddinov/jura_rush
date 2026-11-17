## Gap / chasm in a lane. It has no collision box: it removes the ground, so a runner who does not
## jump simply falls in. Drawn as a ravine: a flat plane over the lane whose shader traces into a
## virtual pit (rock strata darkening with depth, lava glowing at the bottom - strongest in Volcano
## Ridge), framed by jagged edge stones. The rim mesh is cached per gap length.
class_name Gap
extends ObstacleBase

const DEPTH: float = -30.0
## Height of the chasm plane: just above the flagstone path surface (TrackVisuals.PATH_TOP).
const SLAB_TOP: float = 0.055

static var _rims: Dictionary = {}

var _pit: MeshInstance3D = null
var _rim: MeshInstance3D = null


func setup(p_def: ObstacleDef) -> void:
	super.setup(p_def)
	shapes_ground = true


func ground_height_at(_dz: float) -> float:
	return DEPTH


func blocks(_feet_y: float, _top_y: float, _dz: float, _step: float) -> bool:
	return false


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	_pit = MeshLib.mi(MeshLib.plane(), Mats.chasm(def.color), Vector3(0.0, SLAB_TOP, 0.0))
	_pit.extra_cull_margin = 4.0
	_rim = MeshInstance3D.new()
	_rim.material_override = Mats.nature(Color.WHITE, Color.BLACK, 0.0, 0.35)
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_rim.extra_cull_margin = 4.0
	root.add_child(_pit)
	root.add_child(_rim)
	return root


func _apply_length() -> void:
	if _pit == null:
		return
	var w: float = def.size.x
	_pit.scale = Vector3(w, 1.0, length)
	_rim.mesh = _rim_mesh(w, length)


## Jagged stones along the near and far edges and low lips along the sides (cached per length).
static func _rim_mesh(w: float, run_length: float) -> ArrayMesh:
	var key: int = roundi(run_length * 10.0) * 1000 + roundi(w * 10.0)
	if _rims.has(key):
		return _rims[key] as ArrayMesh
	var st: SurfaceTool = NatureMesh.begin()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = key
	var stone: Color = Color(0.4, 0.36, 0.32)
	var half_l: float = run_length * 0.5
	for edge: float in [1.0, -1.0]:
		var count: int = 6
		for i in range(count):
			var x: float = lerpf(-w * 0.5, w * 0.5, (float(i) + 0.5) / float(count)) + rng.randf_range(-0.08, 0.08)
			var s: float = rng.randf_range(0.17, 0.27)
			# Edge stones turn into hazard stripes with the colour-blind setting (TAG_EDGE_ROCK).
			NatureMesh.rock(st, Vector3(x, 0.02, edge * (half_l + s * 0.35)), Vector3(s * 1.1, s * 0.75, s * 0.85),
					rng, NatureMesh.shade(stone, rng.randf_range(0.85, 1.1)), 0, 0.25, 0.4,
					Color(0, 0, 0, 0), NatureMesh.TAG_EDGE_ROCK)
	for side: float in [-1.0, 1.0]:
		var z: float = half_l - 0.1
		while z > -half_l + 0.1:
			var s: float = rng.randf_range(0.11, 0.18)
			NatureMesh.rock(st, Vector3(side * (w * 0.5 + 0.02), 0.0, z), Vector3(s * 0.8, s * 0.6, s * 1.2), rng,
					NatureMesh.shade(stone, rng.randf_range(0.8, 1.05)), 0, 0.25, 0.4)
			z -= rng.randf_range(0.35, 0.5)
	var mesh: ArrayMesh = NatureMesh.commit(st)
	_rims[key] = mesh
	return mesh

## The floating power-up item found on the track: a carved stone totem disc with a glowing inlay
## ring and a soft amber halo, stone and glow tinted in the power-up's own natural colour.
## One pooled node type serves all five power-ups: it is recoloured and relabelled from the
## PowerupDef when placed.
class_name PowerupPickup
extends PickupBase

const STONE: Color = Color(0.66, 0.61, 0.54)
const AMBER: Color = Color(1.0, 0.68, 0.18)

static var _disc_mesh: ArrayMesh = null
static var _ring_mesh: ArrayMesh = null
static var _halo_shader: Shader = preload("res://assets/shaders/halo.gdshader")

var powerup_id: StringName = &""

var _core: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _ring_back: MeshInstance3D = null
var _halo: MeshInstance3D = null
var _halo_material: ShaderMaterial = null
var _label: Label3D = null


func _init() -> void:
	pool_id = &"pickup_powerup"
	radius = 1.1
	_spin = Node3D.new()
	# The disc is modelled at 0.8 m; shown a third bigger so it reads from far down the track.
	_spin.scale = Vector3.ONE * 1.35
	add_child(_spin)
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = _halo_shader
	_halo = MeshLib.mi(MeshLib.quad(), _halo_material)
	_halo.extra_cull_margin = 2.0
	add_child(_halo)
	_core = MeshLib.mi(_disc(), null)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_ring = MeshLib.mi(_inlay(), null, Vector3(0.0, 0.0, 0.118))
	_ring_back = MeshLib.mi(_inlay(), null, Vector3(0.0, 0.0, -0.118))
	_spin.add_child(_core)
	_spin.add_child(_ring)
	_spin.add_child(_ring_back)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.pixel_size = 0.0055
	_label.outline_size = 18
	_label.no_depth_test = true
	_label.position = Vector3(0.0, 0.95, 0.0)
	add_child(_label)


## Configures the pickup for a power-up definition.
func set_powerup(def: PowerupDef) -> void:
	powerup_id = def.id
	var stone: Color = STONE.lerp(def.color, 0.35)
	_core.material_override = Mats.nature(stone, Color.BLACK, 0.0, 0.0)
	var glow: Color = def.color.lerp(AMBER, 0.25)
	var inlay: ShaderMaterial = Mats.nature(Color(0.15, 0.12, 0.1), glow, 1.5, 0.0)
	_ring.material_override = inlay
	_ring_back.material_override = inlay
	_halo_material.set_shader_parameter(&"tint", glow.lerp(AMBER, 0.4))
	_label.text = def.icon
	_label.modulate = def.color.lightened(0.55)
	_label.outline_modulate = Color(0.22, 0.14, 0.08, 0.9)


func _on_collect(player: Player) -> void:
	player.powerups.activate(powerup_id)


## The carved disc: a thick stone wheel facing the runner (axis +Z) with domed faces.
static func _disc() -> ArrayMesh:
	if _disc_mesh != null:
		return _disc_mesh
	var st: SurfaceTool = NatureMesh.begin()
	var sides: int = 12
	var c: Color = Color(0.9, 0.88, 0.84)
	NatureMesh.tube(st, PackedVector3Array([Vector3(0, 0, -0.11), Vector3(0, 0, -0.075), Vector3(0, 0, 0.075),
			Vector3(0, 0, 0.11)]), PackedFloat32Array([0.33, 0.4, 0.4, 0.33]), sides,
			PackedColorArray([c]), PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, false)
	for face: float in [-1.0, 1.0]:
		var centre: Vector3 = Vector3(0.0, 0.0, face * 0.13)
		for j in range(sides):
			var a0: float = TAU * float(j) / float(sides)
			var a1: float = TAU * float(j + 1) / float(sides)
			var p0: Vector3 = Vector3(cos(a0) * 0.33, sin(a0) * 0.33, face * 0.11)
			var p1: Vector3 = Vector3(cos(a1) * 0.33, sin(a1) * 0.33, face * 0.11)
			NatureMesh.tri(st, centre, p0, p1, NatureMesh.shade(c, 1.05), NatureMesh.TAG_PLAIN, 0.0, 0.0, 0.0,
					Vector3(0.0, 0.0, face))
	_disc_mesh = NatureMesh.commit(st)
	return _disc_mesh


## The glowing inlay ring carved into each face (a closed tube in the XY plane).
static func _inlay() -> ArrayMesh:
	if _ring_mesh == null:
		var st: SurfaceTool = NatureMesh.begin()
		var pts: PackedVector3Array = PackedVector3Array()
		for i in range(19):
			var a: float = TAU * float(i) / 18.0
			pts.append(Vector3(cos(a) * 0.235, sin(a) * 0.235, 0.0))
		NatureMesh.tube(st, pts, PackedFloat32Array([0.032]), 5, PackedColorArray([Color.WHITE]),
				PackedFloat32Array([0.0]), NatureMesh.TAG_PLAIN, true)
		_ring_mesh = NatureMesh.commit(st)
	return _ring_mesh

## 3D preview for the shop: a SubViewport with its own World3D showing the selected runner on a
## slowly turning pedestal, its trail as a glowing ribbon, or a glowing orb for power-ups and
## items. Renders only while visible (SubViewport UPDATE_WHEN_VISIBLE), so it costs nothing
## outside the shop.
class_name RunnerPreview
extends SubViewportContainer

const TURN_SPEED: float = 0.55

var _viewport: SubViewport = null
var _turntable: Node3D = null
var _visual: PlayerVisual = null
var _ribbon: MeshInstance3D = null
var _orb: MeshInstance3D = null
var _pedestal: MeshInstance3D = null


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 30.0
	camera.current = true
	_viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.3, 4.0), Vector3(0.0, 0.92, 0.0))
	_pedestal = MeshLib.mi(MeshLib.cylinder(), Mats.glow(Color(0.0, 0.9, 1.0), 1.2), Vector3(0.0, -0.03, 0.0),
			Vector3(1.5, 0.04, 1.5))
	_viewport.add_child(_pedestal)
	_turntable = Node3D.new()
	_viewport.add_child(_turntable)
	_visual = PlayerVisual.new()
	_turntable.add_child(_visual)
	_ribbon = MeshInstance3D.new()
	var ribbon_mesh: BoxMesh = BoxMesh.new()
	ribbon_mesh.size = Vector3(0.5, 0.05, 2.2)
	_ribbon.mesh = ribbon_mesh
	_ribbon.position = Vector3(0.0, 0.95, 1.25)
	_turntable.add_child(_ribbon)
	_orb = MeshLib.mi(MeshLib.sphere(), Mats.glow(Color.WHITE, 2.0), Vector3(0.0, 1.0, 0.0), Vector3(0.9, 0.9, 0.9))
	_turntable.add_child(_orb)
	show_character(ContentDB.character(SaveSystem.equipped(&"character")))


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _turntable == null:
		return
	_turntable.rotation.y += delta * TURN_SPEED
	if _visual.visible:
		_visual.animate(delta, 9.0, 0.0)
	if _orb.visible:
		_orb.position.y = 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.08


## Shows a runner skin (instant, no reload).
func show_character(def: CharacterDef) -> void:
	if def == null or _visual == null:
		return
	_visual.visible = true
	_visual.apply_character(def)
	_visual.set_pose(PlayerVisual.Pose.IDLE)
	_ribbon.visible = false
	_orb.visible = false


## Shows the equipped runner with a trail ribbon in the trail colour.
func show_trail(def: TrailDef) -> void:
	if def == null or _visual == null:
		return
	show_character(ContentDB.character(SaveSystem.equipped(&"character")))
	_visual.set_pose(PlayerVisual.Pose.RUN)
	_ribbon.material_override = Mats.glow(def.color, 2.2)
	(_ribbon.mesh as BoxMesh).size = Vector3(def.width, 0.05, 2.2)
	_ribbon.visible = true


## Shows a glowing orb (power-up upgrades and consumable items).
func show_orb(color: Color) -> void:
	if _visual == null:
		return
	_visual.visible = false
	_ribbon.visible = false
	_orb.material_override = Mats.glow(color, 2.0)
	_orb.visible = true

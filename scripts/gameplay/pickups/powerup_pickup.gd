## The floating power-up item found on the track. One pooled node type serves all five power-ups:
## it is recoloured and relabelled from the PowerupDef when placed.
class_name PowerupPickup
extends PickupBase

var powerup_id: StringName = &""

var _core: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _label: Label3D = null


func _init() -> void:
	pool_id = &"pickup_powerup"
	radius = 1.1
	_spin = Node3D.new()
	add_child(_spin)
	_core = MeshLib.mi(MeshLib.sphere(), null, Vector3.ZERO, Vector3(0.75, 0.75, 0.75))
	_ring = MeshLib.mi(MeshLib.box(), null, Vector3.ZERO, Vector3(1.15, 0.1, 1.15))
	_ring.rotation = Vector3(0.5, 0.0, 0.4)
	_spin.add_child(_core)
	_spin.add_child(_ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.pixel_size = 0.006
	_label.outline_size = 16
	_label.no_depth_test = true
	_label.position = Vector3(0.0, 0.9, 0.0)
	add_child(_label)


## Configures the pickup for a power-up definition.
func set_powerup(def: PowerupDef) -> void:
	powerup_id = def.id
	_core.material_override = Mats.lit(def.color.darkened(0.3), def.color, 1.6)
	_ring.material_override = Mats.lit(Color.BLACK, Color.WHITE, 1.4)
	_label.text = def.icon
	_label.modulate = def.color.lightened(0.5)


func _on_collect(player: Player) -> void:
	player.powerups.activate(powerup_id)

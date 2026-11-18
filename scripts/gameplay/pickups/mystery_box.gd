## Mystery box, shown as a painted clay pot with a lid and a carved "?": a random reward (coins,
## a key or a power-up). The opening burst and floating text are produced by VFX / HUD listening
## to GameEvents.mystery_box_opened.
class_name MysteryBox
extends PickupBase

const COIN_REWARDS: Array[int] = [20, 30, 50, 80]
const CLAY: Color = Color(0.78, 0.43, 0.24)
const PAINT_DARK: Color = Color(0.32, 0.17, 0.1)
const PAINT_CREAM: Color = Color(0.93, 0.82, 0.62)

static var _pot_mesh: ArrayMesh = null


func _init() -> void:
	pool_id = &"pickup_box"
	radius = 1.1
	_spin = Node3D.new()
	add_child(_spin)
	var pot: MeshInstance3D = MeshLib.mi(_pot(), Mats.nature(), Vector3(0.0, -0.42, 0.0))
	pot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_spin.add_child(pot)
	var label: Label3D = Label3D.new()
	label.text = "?"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 120
	label.pixel_size = 0.0055
	label.outline_size = 22
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.86, 0.45)
	label.outline_modulate = Color(0.3, 0.15, 0.07)
	label.position = Vector3(0.0, 0.0, 0.42)
	add_child(label)


func _on_collect(player: Player) -> void:
	var roll: float = randf()
	if roll < 0.6:
		var amount: int = COIN_REWARDS[randi() % COIN_REWARDS.size()]
		player.events.mystery_box_opened.emit(&"coins", amount)
	elif roll < 0.75:
		player.events.mystery_box_opened.emit(&"keys", 1)
	else:
		var def: PowerupDef = ContentDB.POWERUPS[randi() % ContentDB.POWERUPS.size()]
		player.events.mystery_box_opened.emit(def.id, 1)
		player.powerups.activate(def.id)


## The pot: a lathed terracotta jar with painted bands and a knobbed lid (pivot at its foot).
static func _pot() -> ArrayMesh:
	if _pot_mesh != null:
		return _pot_mesh
	var st: SurfaceTool = NatureMesh.begin()
	var profile: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.3, 0.07), Vector2(0.38, 0.22), Vector2(0.4, 0.36),
		Vector2(0.36, 0.5), Vector2(0.27, 0.62), Vector2(0.21, 0.68), Vector2(0.25, 0.73), Vector2(0.24, 0.76),
		Vector2(0.2, 0.77), Vector2(0.17, 0.8), Vector2(0.09, 0.86), Vector2(0.06, 0.9), Vector2(0.07, 0.94),
		Vector2(0.0, 0.96)])
	var cols: PackedColorArray = PackedColorArray([
		NatureMesh.shade(CLAY, 0.8), CLAY, CLAY, PAINT_DARK, PAINT_DARK, PAINT_CREAM, CLAY, CLAY,
		NatureMesh.shade(CLAY, 1.08), CLAY, NatureMesh.shade(CLAY, 0.85), CLAY, CLAY, PAINT_DARK, PAINT_DARK,
		PAINT_DARK])
	NatureMesh.lathe(st, Vector3.ZERO, profile, 14, cols, true)
	_pot_mesh = NatureMesh.commit(st)
	return _pot_mesh

## Mystery box: a random reward (coins, a key or a power-up). The opening burst and floating
## text are produced by VFX / HUD listening to GameEvents.mystery_box_opened.
class_name MysteryBox
extends PickupBase

const COIN_REWARDS: Array[int] = [20, 30, 50, 80]


func _init() -> void:
	pool_id = &"pickup_box"
	radius = 1.1
	_spin = Node3D.new()
	add_child(_spin)
	_spin.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color(0.25, 0.1, 0.4), Color(1.0, 0.85, 0.2), 0.5),
			Vector3.ZERO, Vector3(0.8, 0.8, 0.8)))
	_spin.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, Color(1.0, 0.85, 0.2), 2.2),
			Vector3.ZERO, Vector3(0.84, 0.12, 0.84)))
	_spin.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color.BLACK, Color(1.0, 0.85, 0.2), 2.2),
			Vector3.ZERO, Vector3(0.12, 0.84, 0.84)))
	var label: Label3D = Label3D.new()
	label.text = "?"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 110
	label.pixel_size = 0.006
	label.outline_size = 18
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.95, 0.5)
	label.position = Vector3(0.0, 0.95, 0.0)
	add_child(label)


func _on_collect(player: Player) -> void:
	var roll: float = randf()
	if roll < 0.6:
		var amount: int = COIN_REWARDS[randi() % COIN_REWARDS.size()]
		GameEvents.mystery_box_opened.emit(&"coins", amount)
	elif roll < 0.75:
		GameEvents.mystery_box_opened.emit(&"keys", 1)
	else:
		var def: PowerupDef = ContentDB.POWERUPS[randi() % ContentDB.POWERUPS.size()]
		GameEvents.mystery_box_opened.emit(def.id, 1)
		player.powerups.activate(def.id)

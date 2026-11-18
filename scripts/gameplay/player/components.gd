## Player components (composition over inheritance). Each is a small child node of the player
## owning one concern: health, shield, magnet.
class_name PlayerComponents
extends RefCounted


## Stumble bookkeeping: a second hit inside stumble_window is fatal.
class Health extends Node:
	## Seconds left in which another hit kills.
	var stumble_left: float = 0.0
	var _window: float = GameConfig.current().stumble_window

	## Registers a non-lethal hit. Returns true when it should kill (second hit in the window).
	func register_hit() -> bool:
		if stumble_left > 0.0:
			return true
		stumble_left = _window
		return false

	## True while the chaser is on the player's heels.
	func is_stumbling() -> bool:
		return stumble_left > 0.0

	## Counts the window down.
	func tick(delta: float) -> void:
		stumble_left = maxf(stumble_left - delta, 0.0)

	## Clears the window (new run, revive).
	func reset() -> void:
		stumble_left = 0.0


## Shield bubble: absorbs hits while active.
class Shield extends Node3D:
	var active: bool = false
	var hits_left: int = 0
	var _bubble: MeshInstance3D = null
	var _material: ShaderMaterial = null
	var _hit_flash: float = 0.0

	func _ready() -> void:
		var def: PowerupDef = ContentDB.powerup(&"shield")
		_material = Mats.shield(def.color if def != null else Color(0.32, 0.76, 0.7))
		_bubble = MeshLib.mi(MeshLib.sphere(), _material, Vector3(0.0, 0.95, 0.0), Vector3(2.3, 2.5, 2.3))
		_bubble.visible = false
		add_child(_bubble)

	## Turns the shield on with a number of hits it can absorb.
	func activate(hits: int) -> void:
		active = true
		hits_left = hits
		_bubble.visible = true

	## Turns the shield off without breaking effects.
	func deactivate() -> void:
		active = false
		hits_left = 0
		_bubble.visible = false

	## Tries to absorb a hit. Returns true when the hit was eaten by the shield.
	func absorb() -> bool:
		if not active:
			return false
		hits_left -= 1
		_hit_flash = 1.0
		EventScope.of(self).shield_hit.emit()
		if hits_left <= 0:
			deactivate()
			EventScope.of(self).shield_broken.emit()
		return true

	## Animates the hit ripple.
	func tick(delta: float) -> void:
		if _hit_flash > 0.0:
			_hit_flash = maxf(_hit_flash - delta * 3.0, 0.0)
			_material.set_shader_parameter(&"hit", _hit_flash)


## Magnet: PickupSystem pulls coins toward the player while this is active.
class Magnet extends Node:
	var active: bool = false
	var radius: float = GameConfig.current().magnet_radius

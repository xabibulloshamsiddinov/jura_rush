## Vibration feedback. Respects the "vibration" setting and listens to the event bus.
extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Services.provide(&"haptics", self)
	GameEvents.coin_collected.connect(func(_v: int, _p: Vector3) -> void: light())
	GameEvents.player_stumbled.connect(func(_k: StringName) -> void: medium())
	GameEvents.player_crashed.connect(func(_k: StringName) -> void: heavy())
	GameEvents.shield_broken.connect(medium)
	GameEvents.ui_feedback.connect(func(kind: StringName) -> void:
		if kind != &"hover":
			light())


## Short tick (coins, buttons).
func light() -> void:
	_vibrate(12)


## Medium bump (stumble, shield break).
func medium() -> void:
	_vibrate(35)


## Strong buzz (crash).
func heavy() -> void:
	_vibrate(90)


func _vibrate(msec: int) -> void:
	if SettingsManager.get_bool("vibration"):
		Input.vibrate_handheld(msec)

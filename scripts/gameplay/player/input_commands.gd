## Player input as Command objects. InputHandler (or the bot, or a replay) creates them and
## pushes them into the player's buffer; states decide whether a command may run.
class_name InputCommand
extends Command


## Change lane: direction -1 (left) or +1 (right).
class Lane extends InputCommand:
	var direction: int = 0

	func _init(p_direction: int) -> void:
		super._init()
		direction = p_direction

	func execute(target: Object) -> bool:
		return (target as Player).do_lane(direction)

	func label() -> StringName:
		return &"left" if direction < 0 else &"right"


## Jump (buffered until the player is grounded or inside coyote time).
class Jump extends InputCommand:
	func execute(target: Object) -> bool:
		return (target as Player).do_jump()

	func label() -> StringName:
		return &"jump"


## Roll on the ground, or slam down then roll when airborne.
class Roll extends InputCommand:
	func execute(target: Object) -> bool:
		return (target as Player).do_roll()

	func label() -> StringName:
		return &"roll"

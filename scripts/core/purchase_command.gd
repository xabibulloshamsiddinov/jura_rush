## Shop purchase as a Command with validation and rollback. execute() checks the price and the
## balance, takes the coins, grants the goods and saves; if the save fails, undo() restores
## the previous state so a failed transaction never costs the player anything.
class_name PurchaseCommand
extends Command

var kind: StringName = &"item"
var id: StringName = &""
## Why the last execute() failed: &"", &"unavailable", &"owned", &"funds", &"save".
var failure: StringName = &""

var _paid: int = 0
var _applied: bool = false
var _previous_level: int = 1


func _init(p_kind: StringName, p_id: StringName) -> void:
	super._init()
	kind = p_kind
	id = p_id


## Runs the purchase against a save service. Returns true on success.
func execute(target: Object) -> bool:
	failure = &""
	var cost: int = ShopCatalog.price(kind, id, target)
	if cost < 0:
		failure = &"unavailable"
		return false
	if kind == &"item" and bool(target.call(&"owns", id)):
		failure = &"owned"
		return false
	if not bool(target.call(&"spend", &"coins", cost)):
		failure = &"funds"
		return false
	_paid = cost
	match kind:
		&"item":
			target.call(&"grant", id)
		&"upgrade":
			_previous_level = int(target.call(&"upgrade_level", id))
			target.call(&"set_upgrade_level", id, _previous_level + 1)
		&"consumable":
			target.call(&"add_consumable", id, 1)
	_applied = true
	if not bool(target.call(&"save_game")):
		undo(target)
		failure = &"save"
		return false
	GameEvents.item_purchased.emit(id)
	return true


## Rolls the purchase back: refunds the coins and removes what was granted.
func undo(target: Object) -> void:
	if not _applied:
		return
	_applied = false
	match kind:
		&"item":
			target.call(&"revoke", id)
		&"upgrade":
			target.call(&"set_upgrade_level", id, _previous_level)
		&"consumable":
			target.call(&"add_consumable", id, -1)
	target.call(&"add_coins", _paid)
	_paid = 0


func label() -> StringName:
	return &"purchase"

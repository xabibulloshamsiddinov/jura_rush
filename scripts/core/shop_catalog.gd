## What the shop sells and what it costs. Characters, trails and upgrades come from their
## definition resources; the two consumables are listed here.
class_name ShopCatalog
extends RefCounted

const CONSUMABLES: Array[Dictionary] = [
	{"id": &"headstart", "name_key": &"item.headstart", "desc_key": &"item.headstart.desc", "price": 300},
	{"id": &"booster", "name_key": &"item.booster", "desc_key": &"item.booster.desc", "price": 400},
]


## Coin price of a purchase. kind: &"item" (character / trail), &"upgrade", &"consumable".
## Returns -1 when the purchase is impossible (unknown id or already maxed).
static func price(kind: StringName, id: StringName, save: Object) -> int:
	match kind:
		&"item":
			for c in ContentDB.CHARACTERS:
				if c.id == id:
					return c.price
			for t in ContentDB.TRAILS:
				if t.id == id:
					return t.price
		&"upgrade":
			var def: PowerupDef = ContentDB.powerup(id)
			if def != null:
				return def.cost_for_next(int(save.call(&"upgrade_level", id)))
		&"consumable":
			for entry in CONSUMABLES:
				if entry["id"] == id:
					return int(entry["price"])
	return -1


## Equipment slot of an item id (&"character" or &"trail"), or &"" when it is neither.
static func slot_of(id: StringName) -> StringName:
	for c in ContentDB.CHARACTERS:
		if c.id == id:
			return &"character"
	for t in ContentDB.TRAILS:
		if t.id == id:
			return &"trail"
	return &""

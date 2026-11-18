## Finds the event bus a node belongs to. A world that owns a private EventBus (the multiplayer
## split screen) tags its root with META; everything below it, pooled obstacles included, emits
## there. Nodes outside such a world (the single-player game, labs, menus) get the GameEvents
## autoload, so single-player code paths are unchanged.
class_name EventScope
extends RefCounted

const META: StringName = &"event_bus"


## The bus of the nearest tagged ancestor (or the node itself), else GameEvents.
static func of(node: Node) -> EventBus:
	var n: Node = node
	while n != null:
		if n.has_meta(META):
			var bus: EventBus = n.get_meta(META) as EventBus
			if bus != null:
				return bus
		n = n.get_parent()
	return GameEvents

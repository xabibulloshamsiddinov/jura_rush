## Analytics placeholder. Keeps the last events in memory; replace log_event with a real SDK call.
extends Node

const MAX_EVENTS: int = 64

var events: Array[Dictionary] = []


func _ready() -> void:
	Services.provide(&"analytics", self)
	GameEvents.run_started.connect(func() -> void: log_event(&"run_start", {}))
	GameEvents.run_ended.connect(func(result: Dictionary) -> void: log_event(&"run_end", result))
	GameEvents.item_purchased.connect(func(id: StringName) -> void:
		log_event(&"purchase", {"id": String(id)}))


## Records an event with a parameter dictionary.
func log_event(event_name: StringName, params: Dictionary) -> void:
	events.append({"name": String(event_name), "params": params, "t": Time.get_ticks_msec()})
	if events.size() > MAX_EVENTS:
		events.pop_front()
	Log.info(&"analytics", "%s %s" % [event_name, params])

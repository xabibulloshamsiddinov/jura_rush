## Monetisation interface with no real-money code. Plug an ads / IAP SDK in here later:
## implement show_rewarded_ad() and keep the same callback contract.
extends Node

## Simulated ad length in seconds.
const FAKE_AD_SECONDS: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Services.provide(&"ads", self)


## True when a rewarded ad could be shown. The stub always says yes.
func is_rewarded_ready() -> bool:
	return true


## Shows a rewarded ad, then calls on_done(success). The stub waits a moment and succeeds.
func show_rewarded_ad(placement: StringName, on_done: Callable) -> void:
	Log.info(&"ads", "simulated rewarded ad: %s" % placement)
	var timer: SceneTreeTimer = get_tree().create_timer(FAKE_AD_SECONDS, true, false, true)
	timer.timeout.connect(func() -> void: on_done.call(true))

## Trauma-based screen shake. add_trauma(0..1) piles up, shake = trauma^2 sampled from smooth
## noise, and trauma decays over time. Scaled by the player's shake setting (0 = off).
class_name ScreenShake
extends Node

const DECAY: float = 1.6
const MAX_OFFSET: float = 0.35
const MAX_ROLL: float = 0.05

## Current positional offset to add to the camera.
var offset: Vector3 = Vector3.ZERO
## Current roll (radians) to add to the camera.
var roll: float = 0.0
var trauma: float = 0.0

var _noise: FastNoiseLite = FastNoiseLite.new()
var _time: float = 0.0


func _ready() -> void:
	_noise.frequency = 1.0
	_noise.seed = 1337


## Adds trauma (clamped to 1).
func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## Updates offset / roll for this frame.
func tick(delta: float) -> void:
	if trauma <= 0.0:
		offset = Vector3.ZERO
		roll = 0.0
		return
	_time += delta * 28.0
	trauma = maxf(trauma - DECAY * delta, 0.0)
	var amount: float = trauma * trauma * SettingsManager.shake_scale()
	offset = Vector3(_noise.get_noise_2d(_time, 0.0), _noise.get_noise_2d(0.0, _time), 0.0) * MAX_OFFSET * amount
	roll = _noise.get_noise_2d(_time, _time) * MAX_ROLL * amount

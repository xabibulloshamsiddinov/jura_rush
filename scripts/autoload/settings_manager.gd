## Player settings (stored inside the save file). Applies quality presets and notifies listeners
## through GameEvents.settings_changed.
extends Node

const DEFAULTS: Dictionary = {
	"music": 0.7,
	"sfx": 0.9,
	"music_on": true,
	"sfx_on": true,
	"ambience": 0.6,
	"vibration": true,
	"quality": 1,
	"shake": 1.0,
	"reduce_effects": false,
	"sensitivity": 1.0,
	"language": "en",
	"colorblind": false,
	"large_text": false,
	"show_fps": false,
}

## Render scale per quality preset (Low / Medium / High).
const RENDER_SCALE: Array[float] = [0.75, 0.9, 1.0]
## Decor instances per chunk side per preset.
const DECOR_DENSITY: Array[int] = [3, 5, 7]
## Particle amount multiplier per preset.
const PARTICLE_SCALE: Array[float] = [0.4, 0.75, 1.0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stored: Dictionary = SaveSystem.section("settings")
	for key: String in DEFAULTS.keys():
		if not stored.has(key):
			stored[key] = DEFAULTS[key]
	if not stored.has("language_picked"):
		stored["language_picked"] = true
		var locale: String = OS.get_locale_language()
		if locale == "uz" or locale == "ru":
			stored["language"] = locale
	apply_quality.call_deferred()


## Reads a setting.
func get_value(key: String) -> Variant:
	return SaveSystem.section("settings").get(key, DEFAULTS.get(key))


## Reads a numeric setting as float.
func get_float(key: String) -> float:
	return float(get_value(key))


## Reads a boolean setting.
func get_bool(key: String) -> bool:
	return bool(get_value(key))


## Changes a setting, applies it and broadcasts settings_changed.
func set_value(key: String, value: Variant) -> void:
	SaveSystem.section("settings")[key] = value
	if key == "quality":
		apply_quality()
	SaveSystem.mark_dirty()
	GameEvents.settings_changed.emit()


## Quality preset index: 0 Low, 1 Medium, 2 High.
func quality() -> int:
	return clampi(int(get_value("quality")), 0, 2)


## True when flashy effects should be toned down (accessibility or Low quality).
func reduce_effects() -> bool:
	return get_bool("reduce_effects")


## Screen shake multiplier (0 disables shake).
func shake_scale() -> float:
	return clampf(get_float("shake"), 0.0, 1.0)


## Particle amount multiplier for the current preset.
func particle_scale() -> float:
	var s: float = PARTICLE_SCALE[quality()]
	return s * 0.5 if reduce_effects() else s


## Decor instances per chunk side for the current preset.
func decor_density() -> int:
	return DECOR_DENSITY[quality()]


## Active chunk count for the current preset (Low draws one chunk less).
func chunk_count() -> int:
	var base: int = GameConfig.current().active_chunks
	return base - 1 if quality() == 0 else base


## Applies render scale and MSAA for the current preset.
func apply_quality() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	viewport.scaling_3d_scale = RENDER_SCALE[quality()]
	viewport.msaa_3d = Viewport.MSAA_DISABLED if quality() == 0 else Viewport.MSAA_2X

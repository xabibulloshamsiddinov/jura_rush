## Maps sound ids to real audio files. Anything listed here (or any file found at
## res://assets/audio/<id>.ogg / .wav) replaces the procedural placeholder with no code changes.
class_name AudioConfig
extends Resource

## Sound id (String) -> AudioStream.
@export var overrides: Dictionary = {}
## Optional real music tracks; when set they replace the procedural sequencer layers.
@export var music_menu: AudioStream
@export var music_drums: AudioStream
@export var music_bass: AudioStream
@export var music_lead: AudioStream
@export var bpm: float = 128.0


## Returns the override stream for an id, or null when the procedural sound should be used.
func find(id: StringName) -> AudioStream:
	if overrides.has(String(id)):
		return overrides[String(id)] as AudioStream
	for ext: String in [".ogg", ".wav", ".mp3"]:
		var path: String = "res://assets/audio/%s%s" % [id, ext]
		if ResourceLoader.exists(path):
			return ResourceLoader.load(path) as AudioStream
	return null

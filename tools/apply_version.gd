## Copies the version from version.cfg into project.godot and every export preset.
##   godot --headless --path . --script res://tools/apply_version.gd
## Files are patched line by line so nothing else in them is reformatted.
extends SceneTree


func _init() -> void:
	var version: ConfigFile = ConfigFile.new()
	if version.load("res://version.cfg") != OK:
		push_error("version.cfg not found")
		quit(1)
		return
	var version_name: String = str(version.get_value("version", "name", "1.0.0"))
	var version_code: int = int(version.get_value("version", "code", 1))
	_patch("res://project.godot", {"config/version=": "config/version=\"%s\"" % version_name})
	_patch("res://export_presets.cfg", {
		"version/name=": "version/name=\"%s\"" % version_name,
		"version/code=": "version/code=%d" % version_code,
	})
	print("version %s (code %d) applied" % [version_name, version_code])
	quit()


## Replaces every line starting with one of the given prefixes.
func _patch(path: String, replacements: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		return
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for i in range(lines.size()):
		for prefix: String in replacements.keys():
			if lines[i].begins_with(prefix):
				lines[i] = str(replacements[prefix])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()

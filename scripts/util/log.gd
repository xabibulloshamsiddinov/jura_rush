## Leveled logging facade (Log.info / Log.warn / Log.error). Silent in release builds.
class_name Log
extends RefCounted

enum Level { INFO, WARN, ERROR, OFF }

static var level: Level = Level.INFO
static var enabled: bool = OS.is_debug_build()


## Logs an informational message.
static func info(tag: StringName, msg: String) -> void:
	if enabled and level <= Level.INFO:
		print("[I][%s] %s" % [tag, msg])


## Logs a warning (also shows in the Godot debugger).
static func warn(tag: StringName, msg: String) -> void:
	if enabled and level <= Level.WARN:
		push_warning("[%s] %s" % [tag, msg])


## Logs an error (also shows in the Godot debugger).
static func error(tag: StringName, msg: String) -> void:
	if enabled and level <= Level.ERROR:
		push_error("[%s] %s" % [tag, msg])

## Persistent profile: JSON in user://save.json with checksum, atomic write and a backup file.
## Load order: main file -> backup -> defaults. Registered as the &"save" service.
extends Node

const DEFAULT_PATH: String = "user://save.json"

## Live profile data (see SaveCodec.defaults for the schema).
var data: Dictionary = {}
## File path; tests point this somewhere else.
var path: String = DEFAULT_PATH
## Where the last load came from: "main", "backup" or "defaults".
var last_load_source: String = ""

var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Services.provide(&"save", self)
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not data.is_empty():
			save_game()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		save_game()


## Loads the profile, recovering from corruption through the backup file.
func load_game() -> void:
	var loaded: Dictionary = _read(path)
	last_load_source = "main"
	if loaded.is_empty():
		loaded = _read(path + ".bak")
		last_load_source = "backup"
	if loaded.is_empty():
		loaded = SaveCodec.defaults()
		last_load_source = "defaults"
	data = SaveCodec.migrate(loaded)


## Writes the profile atomically (temp file, backup, rename). Returns true on success.
func save_game() -> bool:
	var tmp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		Log.error(&"save", "cannot open %s" % tmp)
		return false
	file.store_string(SaveCodec.encode(data))
	file.close()
	if FileAccess.file_exists(path):
		if not _read(path).is_empty():
			DirAccess.copy_absolute(path, path + ".bak")
		DirAccess.remove_absolute(path)
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		Log.error(&"save", "rename failed: %d" % err)
		return false
	return true


## Requests a save at the end of the frame (coalesces bursts of changes).
func mark_dirty() -> void:
	_dirty = true


## Wipes all progress but keeps the settings.
func reset_progress() -> void:
	var settings: Dictionary = data.get("settings", {})
	data = SaveCodec.defaults()
	data["settings"] = settings
	save_game()
	_emit_wallet()


## Returns a nested Dictionary section (missions, stats, upgrades...), creating it if needed.
func section(key: String) -> Dictionary:
	if not (data.get(key) is Dictionary):
		data[key] = {}
	var out: Dictionary = data[key]
	return out


## Soft currency balance.
func coins() -> int:
	return int(data.get("coins", 0))


## Key balance.
func keys() -> int:
	return int(data.get("keys", 0))


## Adds (or removes, when negative) coins.
func add_coins(amount: int) -> void:
	data["coins"] = maxi(coins() + amount, 0)
	_emit_wallet()
	mark_dirty()


## Adds (or removes, when negative) keys.
func add_keys(amount: int) -> void:
	data["keys"] = maxi(keys() + amount, 0)
	_emit_wallet()
	mark_dirty()


## Pays a price in &"coins" or &"keys". Returns false (and changes nothing) when too poor.
func spend(currency: StringName, amount: int) -> bool:
	if currency == &"keys":
		if keys() < amount:
			return false
		add_keys(-amount)
		return true
	if coins() < amount:
		return false
	add_coins(-amount)
	return true


## True when an item id is owned.
func owns(id: StringName) -> bool:
	var owned: Array = data.get("owned", [])
	return owned.has(String(id))


## Adds an item to the owned list.
func grant(id: StringName) -> void:
	var owned: Array = data.get("owned", [])
	if not owned.has(String(id)):
		owned.append(String(id))
	data["owned"] = owned
	mark_dirty()


## Removes an item from the owned list (purchase rollback).
func revoke(id: StringName) -> void:
	var owned: Array = data.get("owned", [])
	owned.erase(String(id))
	data["owned"] = owned
	mark_dirty()


## Equips an owned item into a slot (&"character" or &"trail").
func equip(slot: StringName, id: StringName) -> void:
	section("equipped")[String(slot)] = String(id)
	mark_dirty()


## Item id currently equipped in a slot.
func equipped(slot: StringName) -> StringName:
	return StringName(str(section("equipped").get(String(slot), "")))


## Upgrade level (1-based) of a power-up.
func upgrade_level(id: StringName) -> int:
	return int(section("upgrades").get(String(id), 1))


## Sets the upgrade level of a power-up.
func set_upgrade_level(id: StringName, level: int) -> void:
	section("upgrades")[String(id)] = level
	mark_dirty()


## Owned count of a consumable.
func consumable_count(id: StringName) -> int:
	return int(section("consumables").get(String(id), 0))


## Adds (or removes) consumables.
func add_consumable(id: StringName, amount: int) -> void:
	section("consumables")[String(id)] = maxi(consumable_count(id) + amount, 0)
	mark_dirty()


## Account score multiplier earned from mission sets.
func account_multiplier() -> int:
	return int(section("missions").get("multiplier", 1))


func _emit_wallet() -> void:
	GameEvents.wallet_changed.emit(coins(), keys())


func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	return SaveCodec.decode(text)

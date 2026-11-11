## Pure save-data logic (no file access): defaults, checksum envelope, schema migration.
## Kept separate from SaveSystem so it can be unit-tested in isolation.
class_name SaveCodec
extends RefCounted

const VERSION: int = 2


## Fresh profile for a new player.
static func defaults() -> Dictionary:
	return {
		"save_version": VERSION,
		"coins": 0,
		"keys": 2,
		"best_score": 0,
		"total_distance": 0.0,
		"owned": ["volt", "cyan"],
		"equipped": {"character": "volt", "trail": "cyan"},
		"upgrades": {},
		"consumables": {"headstart": 0, "booster": 0},
		"missions": {"active": [], "set_index": 0, "multiplier": 1, "done": []},
		"achievements": [],
		"stats": {},
		"tutorial_done": false,
		"settings": {},
		"daily_streak": 0,
		"last_daily_date": "",
	}


## Wraps data in an envelope carrying a SHA-256 checksum of the payload.
static func encode(data: Dictionary) -> String:
	var payload: String = JSON.stringify(data)
	return JSON.stringify({"checksum": payload.sha256_text(), "payload": payload})


## Parses an envelope. Returns an empty Dictionary when the text is corrupt or tampered.
static func decode(text: String) -> Dictionary:
	if text.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	var envelope: Dictionary = json.data
	if not envelope.has("checksum") or not envelope.has("payload"):
		return {}
	var payload: String = str(envelope["payload"])
	if payload.sha256_text() != str(envelope["checksum"]):
		return {}
	var inner: JSON = JSON.new()
	if inner.parse(payload) != OK or not (inner.data is Dictionary):
		return {}
	var result: Dictionary = inner.data
	return result


## Upgrades any older schema to the current one, then fills in missing keys.
static func migrate(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var version: int = int(out.get("save_version", 1))
	if version < 2:
		out = _v1_to_v2(out)
	out["save_version"] = VERSION
	return merge_defaults(out)


## Adds keys that exist in defaults() but are missing from data (one level of nesting).
static func merge_defaults(data: Dictionary) -> Dictionary:
	var base: Dictionary = defaults()
	for key: String in base.keys():
		if not data.has(key):
			data[key] = base[key]
		elif base[key] is Dictionary and data[key] is Dictionary:
			var sub_base: Dictionary = base[key]
			var sub: Dictionary = data[key]
			for sub_key: String in sub_base.keys():
				if not sub.has(sub_key):
					sub[sub_key] = sub_base[sub_key]
	return data


## v1 stored "best", "skins" and "skin"; v2 renames them and adds keys, trails and upgrades.
static func _v1_to_v2(old: Dictionary) -> Dictionary:
	var out: Dictionary = old.duplicate(true)
	if out.has("best"):
		out["best_score"] = int(out["best"])
		out.erase("best")
	var owned: Array = ["volt", "cyan"]
	if out.has("skins") and out["skins"] is Array:
		var skins: Array = out["skins"]
		for skin: Variant in skins:
			if not owned.has(str(skin)):
				owned.append(str(skin))
		out.erase("skins")
	out["owned"] = owned
	var character: String = str(out.get("skin", "volt"))
	out.erase("skin")
	out["equipped"] = {"character": character, "trail": "cyan"}
	if not out.has("keys"):
		out["keys"] = 2
	return out

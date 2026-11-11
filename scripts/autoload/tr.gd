## Localisation autoload. Every visible string goes through Tr.t(key) / Tr.f(key, args).
## Languages: English (en), Uzbek (uz), Russian (ru). Table lives in strings_table.gd.
extends Node

const LANGUAGES: Array[String] = ["en", "uz", "ru"]
const LANGUAGE_NAMES: Array[String] = ["English", "O'zbekcha", "Русский"]

var _lang_index: int = 0


func _ready() -> void:
	_refresh()
	GameEvents.settings_changed.connect(_refresh)


## Translates a key. Unknown keys are returned as-is so they are easy to spot.
func t(key: StringName) -> String:
	var entry: Variant = StringsTable.TABLE.get(String(key))
	if entry == null:
		return String(key)
	var row: Array = entry
	if _lang_index < row.size() and not str(row[_lang_index]).is_empty():
		return str(row[_lang_index])
	return str(row[0])


## Translates a key and substitutes {name} placeholders from args.
func f(key: StringName, args: Dictionary) -> String:
	return t(key).format(args)


## Current language code.
func language() -> String:
	return LANGUAGES[_lang_index]


func _refresh() -> void:
	var code: String = str(SettingsManager.get_value("language"))
	_lang_index = maxi(LANGUAGES.find(code), 0)

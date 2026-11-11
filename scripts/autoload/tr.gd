## Localisation autoload. Every visible string goes through Tr.t(key) / Tr.f(key, args).
## Languages: English (en), Uzbek (uz), Russian (ru).
##
## All texts live in ONE translation file: res://localization/strings.csv (columns: keys, en, uz,
## ru). Godot imports it into strings.<lang>.translation resources (listed in Project Settings >
## Localization), and lookups go through TranslationServer. To add a language: add a column to
## the CSV, its code + name below, and the new .translation file to the project settings.
extends Node

const LANGUAGES: Array[String] = ["en", "uz", "ru"]
const LANGUAGE_NAMES: Array[String] = ["English", "O'zbekcha", "Русский"]
const FALLBACK: String = "en"

var _lang_index: int = 0


func _ready() -> void:
	TranslationServer.set_locale(FALLBACK)
	_refresh()
	GameEvents.settings_changed.connect(_refresh)


## Translates a key. Unknown keys are returned as-is so they are easy to spot.
func t(key: StringName) -> String:
	return String(TranslationServer.translate(key))


## Translates a key and substitutes {name} placeholders from args.
func f(key: StringName, args: Dictionary) -> String:
	return t(key).format(args)


## Current language code.
func language() -> String:
	return LANGUAGES[_lang_index]


func _refresh() -> void:
	var code: String = str(SettingsManager.get_value("language"))
	_lang_index = maxi(LANGUAGES.find(code), 0)
	TranslationServer.set_locale(LANGUAGES[_lang_index])

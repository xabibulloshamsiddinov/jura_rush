## Dev tool: `godot --path . -- --ui-shots=<dir>` opens every menu screen in turn and saves a
## screenshot of each (layout review at any --resolution): the menu in en / uz / ru over the live
## 3D world, the shop with every runner skin in its 3D preview, the flow screens. Uses the throw-away automation save,
## seeded with a few coins and purchases so the shop shows every button state.
class_name UiShots
extends Node

var _dir: String = ""


func _init(dir: String) -> void:
	_dir = dir
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	SaveSystem.data["coins"] = 2500
	SaveSystem.grant(&"ember")
	SaveSystem.data["best_score"] = 48210
	await _wait(1.6)
	await _save("menu")
	# The menu over the live 3D world in every language.
	for code: String in ["uz", "ru"]:
		SettingsManager.set_value("language", code)
		await _wait(0.8)
		await _save("menu_" + code)
	SettingsManager.set_value("language", "en")
	await _wait(0.6)
	SceneRouter.push(&"shop", {"tab": 0})
	await _wait(0.8)
	await _save("shop_runners")
	var shop: Node = SceneRouter.get_screen(&"shop")
	# Every runner skin in the 3D preview (row tap = select).
	var selected: Dictionary = shop.get(&"_selected")
	for def: CharacterDef in ContentDB.CHARACTERS:
		selected[0] = def.id
		shop.call(&"_refresh")
		await _wait(0.7)
		await _save("shop_runner_" + String(def.id))
	selected.erase(0)
	for code: String in ["uz", "ru"]:
		SettingsManager.set_value("language", code)
		await _wait(0.8)
		shop = SceneRouter.get_screen(&"shop")
		await _save("shop_runners_" + code)
	SettingsManager.set_value("language", "en")
	await _wait(0.8)
	shop = SceneRouter.get_screen(&"shop")
	shop.call(&"_ask_confirm", &"item", &"pixel", "Pixel", 2000)
	await _wait(0.5)
	await _save("shop_confirm")
	shop.call(&"_close_confirm")
	for tab: int in [1, 2, 3]:
		shop.call(&"_select_tab", tab)
		await _wait(0.6)
		await _save("shop_tab%d" % tab)
	SceneRouter.back()
	for id: StringName in [&"settings", &"missions"]:
		SceneRouter.push(id, {})
		await _wait(0.6)
		await _save(String(id))
		SceneRouter.back()
	# Flow screens with a made-up result (layout check only).
	GameState.last_result = {"score": 52340, "coins": 187, "distance": 1240, "best": 52340,
			"new_best": true, "daily_reward": 200, "daily_streak": 2}
	SceneRouter.show_screen(&"game_over")
	await _wait(2.6)
	await _save("game_over")
	SceneRouter.push(&"revive_popup", {})
	await _wait(0.8)
	await _save("revive")
	SceneRouter.close(&"revive_popup")
	SceneRouter.push(&"tutorial", {})
	await _wait(1.2)
	await _save("tutorial")
	await _wait(0.3)
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))

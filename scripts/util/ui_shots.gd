## Dev tool: `godot --path . -- --ui-shots=<dir>` opens every menu screen in turn and saves a
## screenshot of each (layout review at any --resolution). Uses the throw-away automation save,
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
	SceneRouter.push(&"shop", {"tab": 0})
	await _wait(0.8)
	await _save("shop_runners")
	var shop: Node = SceneRouter.get_screen(&"shop")
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

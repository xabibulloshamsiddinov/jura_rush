## Multiplayer mode ("Party Run"): 1-3 players on one computer screen split into vertical strips,
## each controlling their runner from their own phone (a web page served by this computer over
## Wi-Fi, opened by scanning a QR code) or from the keyboard. Opened from the main menu on desktop
## builds; it runs next to the single-player game without touching its flow: the single-player
## world leaves the tree while the mode is open (GameState stays in the menu state) and comes back
## with its look restored afterwards.
##
## Phases: lobby (join, pick a runner, READY; starts by itself when everybody is ready, or with
##         START) -> playing (PartyMatch; Esc pauses) -> results (PLAY AGAIN, from the PC or once
##         every phone pressed it; CHANGE PLAYERS back to the lobby; back to the lobby by itself
##         after RESULTS_TIMEOUT).
##
## Keyboard (no phone needed): K adds a keyboard player (first W A S D + Space, then the arrow
## keys), L removes the last one, B adds a bot, N removes a bot. In the lobby A / D (left / right)
## change the runner and W / Space (up) toggle READY; Enter starts. F11 toggles full screen.
##
## UI screens (party_lobby, party_hud, party_pause, party_results, party_help) read it through
## Services.locate(&"party") and its signals.
##
## Dev command line (after "--"):  --party            open the lobby at boot
##                                 --party-bots=N     N bots (1-3) start a round at boot
##                                 --party-keys=N     N keyboard players (1-2) join the lobby
##                                 --party-help       open the HOW TO CONNECT window
##                                 --party-time=S     round length override (seconds)
##                                 --party-shot=p.png screenshot after --party-shot-at=S seconds
##                                                    (default 9), then quit
##                                 --party-close-at=S back to the main menu after S seconds, quit
##                                                    2 s later (checks the window comes back)
class_name PartyMode
extends Node

signal changed
signal countdown(n: int)
signal runner_event(slot: int, kind: StringName)
signal results_ready(results: Array[Dictionary])

const CLOSED: StringName = &"closed"
const LOBBY: StringName = &"lobby"
const PLAYING: StringName = &"playing"
const PAUSED: StringName = &"paused"
const RESULTS: StringName = &"results"

const LANDSCAPE_BASE: Vector2i = Vector2i(1920, 1080)
const AUTO_START_DELAY: float = 2.5
const RESULTS_TIMEOUT: float = 45.0
const TICK_INTERVAL: float = 0.2
const MAX_BOTS: int = 3

var phase: StringName = CLOSED
var roster: PartyRoster = PartyRoster.new()
var hub: PhoneHub = null
var round_match: PartyMatch = null
var results: Array[Dictionary] = []
## Seconds until the lobby starts by itself (< 0 = not everybody is ready).
var auto_start_left: float = -1.0
## Seconds until the results screen goes back to the lobby.
var results_left: float = 0.0
var server_ok: bool = false
## Running inside the Godot editor's Game tab (embedded): the window belongs to the editor and
## cannot be maximized; the lobby says how to get a real window.
var embedded: bool = false

var _world: Node3D = null
var _world_parent: Node = null
## Size / position of the desktop window before the mode maximized it (ZERO = not touched).
var _saved_window: Vector2i = Vector2i.ZERO
var _saved_position: Vector2i = Vector2i.ZERO
var _saved_scale_size: Vector2i = Vector2i.ZERO
var _tick_left: float = 0.0
var _dev_keys: int = 0
var _dev_help: bool = false
var _dev_close_at: float = 0.0


func _init(single_player_world: Node3D) -> void:
	_world = single_player_world


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hub = PhoneHub.new(roster)
	hub.name = "PhoneHub"
	add_child(hub)
	hub.action.connect(_on_action)
	hub.again_pressed.connect(func(_slot: int) -> void:
		if phase == RESULTS and roster.all_phones_again():
			restart())
	hub.member_lost.connect(func(slot: int) -> void:
		if round_match != null and (phase == PLAYING or phase == PAUSED):
			round_match.set_frozen(slot, true))
	hub.member_back.connect(func(slot: int) -> void:
		if round_match != null and (phase == PLAYING or phase == PAUSED):
			round_match.set_frozen(slot, false))
	roster.changed.connect(func() -> void:
		_update_auto_start()
		changed.emit())
	Services.provide(&"party", self)
	GameEvents.request_party_open.connect(open)
	_parse_dev_flags()


func _exit_tree() -> void:
	if phase != CLOSED:
		_free_match()
		hub.stop()
		# Quitting while the mode is open: the detached single-player world is not in the tree.
		if _world != null and is_instance_valid(_world) and not _world.is_inside_tree():
			_world.free()


## True on builds that can host (a desktop: it runs the server and drives a big screen).
static func available() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("web")


func is_open() -> bool:
	return phase != CLOSED


## Opens the lobby (from the main menu).
func open() -> void:
	if phase != CLOSED or not available():
		return
	if _world != null and _world.is_inside_tree():
		_world_parent = _world.get_parent()
		_world_parent.remove_child(_world)
	_landscape(true)
	server_ok = hub.start()
	roster.clear()
	results.clear()
	_set_phase(LOBBY)
	AudioManager.set_music_mode(&"menu")
	SceneRouter.show_screen(&"party_lobby")


## Leaves the mode and returns to the single-player main menu.
func close() -> void:
	if phase == CLOSED:
		return
	GameState.set_tree_paused(false)
	_free_match()
	hub.stop()
	roster.clear()
	_set_phase(CLOSED)
	if _world != null and _world_parent != null and not _world.is_inside_tree():
		_world_parent.add_child(_world)
		_world_parent.move_child(_world, 0)
		_world.call(&"restore_menu")
	_landscape(false)
	AudioManager.set_music_mode(&"menu")
	AudioManager.set_paused_filter(false)
	SceneRouter.show_screen(&"main_menu")


## Starts a round with everybody in the room (START, auto start, PLAY AGAIN).
func start_round() -> void:
	if roster.count() == 0 or (phase != LOBBY and phase != RESULTS and phase != PAUSED):
		return
	GameState.set_tree_paused(false)
	AudioManager.set_paused_filter(false)
	_free_match()
	results.clear()
	auto_start_left = -1.0
	for m: PartyRoster.Member in roster.list():
		m.again = false
	round_match = PartyMatch.new()
	round_match.name = "PartyMatch"
	round_match.setup(roster.list(), Rng.random_seed(), randi() % ContentDB.BIOMES.size())
	round_match.countdown.connect(_on_countdown)
	round_match.runner_event.connect(_on_runner_event)
	round_match.finished.connect(_on_finished)
	add_child(round_match)
	_set_phase(PLAYING)
	_tick_left = 0.0
	AudioManager.set_music_mode(&"game")
	AudioManager.set_intensity(0.4)
	SceneRouter.show_screen(&"party_hud")


## Same players, same runners, a fresh round.
func restart() -> void:
	start_round()


## Back to the lobby: keeps the players (lost phones are removed), clears READY.
func to_lobby() -> void:
	if phase == CLOSED or phase == LOBBY:
		return
	GameState.set_tree_paused(false)
	AudioManager.set_paused_filter(false)
	_free_match()
	hub.drop_lost_members()
	roster.reset_flags()
	_set_phase(LOBBY)
	AudioManager.set_music_mode(&"menu")
	SceneRouter.show_screen(&"party_lobby")


func set_paused(value: bool) -> void:
	if value and phase == PLAYING:
		GameState.set_tree_paused(true)
		AudioManager.set_paused_filter(true)
		_set_phase(PAUSED)
		SceneRouter.push(&"party_pause")
	elif not value and phase == PAUSED:
		GameState.set_tree_paused(false)
		AudioManager.set_paused_filter(false)
		_set_phase(PLAYING)
		SceneRouter.close(&"party_pause")


## Adds a keyboard player (at most two: W A S D and the arrow keys).
func add_keyboard_player() -> void:
	if phase != LOBBY or roster.by_keys(0) != null and roster.by_keys(1) != null:
		return
	var m: PartyRoster.Member = roster.add(PartyRoster.Kind.KEYBOARD, "")
	if m != null:
		m.name = Tr.t(&"party.keys_name_wasd" if m.keys == 0 else &"party.keys_name_arrows")
		roster.changed.emit()


func add_bot() -> void:
	if phase != LOBBY:
		return
	var bots: int = 0
	for m: PartyRoster.Member in roster.list():
		if m.kind == PartyRoster.Kind.BOT:
			bots += 1
	if bots >= MAX_BOTS:
		return
	var bot: PartyRoster.Member = roster.add(PartyRoster.Kind.BOT, "")
	if bot != null:
		bot.name = Tr.f(&"party.bot_name", {"n": bot.slot + 1})
		roster.changed.emit()


## Removes the last member of a kind (keyboard: L, bot: N).
func remove_last(kind: PartyRoster.Kind) -> void:
	if phase != LOBBY:
		return
	var members: Array[PartyRoster.Member] = roster.list()
	for i in range(members.size() - 1, -1, -1):
		if members[i].kind == kind:
			roster.remove(members[i].slot)
			return


## Removes a member from the lobby (the ✕ on a keyboard / bot card; phones leave from the phone).
func remove_member(slot: int) -> void:
	var m: PartyRoster.Member = roster.at(slot)
	if phase == LOBBY and m != null:
		if m.kind == PartyRoster.Kind.PHONE and m.client != 0:
			hub.server.kick(m.client)
		roster.remove(slot)


## Everything the HOW TO CONNECT window shows.
func connection_info() -> Dictionary:
	var server: NetServer = hub.server
	var addresses: Array[Dictionary] = NetServer.lan_addresses()
	var urls: PackedStringArray = PackedStringArray()
	for a: Dictionary in addresses:
		urls.append("http://%s:%d" % [a["ip"], server.port])
	return {
		"listening": server.is_listening(),
		"port": server.port,
		"addresses": addresses,
		"urls": urls,
		"url": main_url(),
		"page_hits": server.page_hits,
		"ws_total": server.ws_total,
		"ws_now": server.open_count(),
		"last_address": server.last_address,
	}


## The address to put in the QR code: the best real LAN address (or localhost).
func main_url() -> String:
	var port: int = hub.server.port
	for a: Dictionary in NetServer.lan_addresses():
		if not bool(a["virtual"]):
			return "http://%s:%d" % [a["ip"], port]
	var all: Array[Dictionary] = NetServer.lan_addresses()
	if not all.is_empty():
		return "http://%s:%d" % [all[0]["ip"], port]
	return "http://localhost:%d" % port


func _process(delta: float) -> void:
	match phase:
		LOBBY:
			if auto_start_left > 0.0:
				auto_start_left -= delta
				if auto_start_left <= 0.0:
					start_round()
		PLAYING:
			_tick_left -= delta
			if _tick_left <= 0.0 and round_match != null:
				_tick_left = TICK_INTERVAL
				for m: PartyRoster.Member in roster.list():
					var snap: Dictionary = round_match.snapshot(m.slot)
					if not snap.is_empty():
						snap["t"] = "tick"
						hub.send_to(m.slot, snap)
		RESULTS:
			results_left -= delta
			if results_left <= 0.0:
				to_lobby()


func _unhandled_input(event: InputEvent) -> void:
	if phase == CLOSED:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code: Key = key.physical_keycode
	if code == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	var handled: bool = false
	match phase:
		LOBBY:
			handled = _lobby_key(code)
		PLAYING:
			handled = _game_key(code)
		RESULTS:
			if code == KEY_ENTER or code == KEY_KP_ENTER:
				restart()
				handled = true
			elif code == KEY_L:
				to_lobby()
				handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _lobby_key(code: Key) -> bool:
	match code:
		KEY_K:
			add_keyboard_player()
			return true
		KEY_L:
			remove_last(PartyRoster.Kind.KEYBOARD)
			return true
		KEY_B:
			add_bot()
			return true
		KEY_N:
			remove_last(PartyRoster.Kind.BOT)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			start_round()
			return true
	var wasd: PartyRoster.Member = roster.by_keys(0)
	var arrows: PartyRoster.Member = roster.by_keys(1)
	if wasd != null:
		match code:
			KEY_A:
				roster.cycle_character(wasd.slot, -1)
				return true
			KEY_D:
				roster.cycle_character(wasd.slot, 1)
				return true
			KEY_W, KEY_SPACE:
				roster.set_ready(wasd.slot, not wasd.ready)
				return true
	if arrows != null:
		match code:
			KEY_LEFT:
				roster.cycle_character(arrows.slot, -1)
				return true
			KEY_RIGHT:
				roster.cycle_character(arrows.slot, 1)
				return true
			KEY_UP:
				roster.set_ready(arrows.slot, not arrows.ready)
				return true
	return false


func _game_key(code: Key) -> bool:
	var wasd: PartyRoster.Member = roster.by_keys(0)
	var arrows: PartyRoster.Member = roster.by_keys(1)
	var slot: int = -1
	var action: StringName = &""
	if wasd != null:
		match code:
			KEY_A:
				action = &"left"
			KEY_D:
				action = &"right"
			KEY_W, KEY_SPACE:
				action = &"jump"
			KEY_S:
				action = &"roll"
		if action != &"":
			slot = wasd.slot
	if arrows != null and action == &"":
		match code:
			KEY_LEFT:
				action = &"left"
			KEY_RIGHT:
				action = &"right"
			KEY_UP:
				action = &"jump"
			KEY_DOWN:
				action = &"roll"
		if action != &"":
			slot = arrows.slot
	if slot < 0:
		return false
	_on_action(slot, action)
	return true


func _on_action(slot: int, action: StringName) -> void:
	if phase == PLAYING and round_match != null:
		round_match.push_input(slot, action)


func _on_countdown(n: int) -> void:
	hub.broadcast({"t": "count", "n": n})
	GameEvents.countdown_tick.emit(n)
	countdown.emit(n)


func _on_runner_event(slot: int, kind: StringName) -> void:
	match kind:
		&"crash":
			hub.send_to(slot, {"t": "buzz", "k": "crash"})
		&"stumble":
			hub.send_to(slot, {"t": "buzz", "k": "hit"})
		&"respawn":
			hub.send_to(slot, {"t": "count", "n": -1})
	runner_event.emit(slot, kind)


func _on_finished(list: Array[Dictionary]) -> void:
	results = list.duplicate()
	var phone_list: Array[Dictionary] = []
	for r: Dictionary in results:
		phone_list.append({"slot": r["slot"], "place": r["place"], "name": r["name"], "score": r["score"],
				"color": "#" + (r["color"] as Color).to_html(false)})
	results_left = RESULTS_TIMEOUT
	_set_phase(RESULTS)
	hub.broadcast({"t": "results", "list": phone_list})
	AudioManager.set_music_mode(&"menu")
	AudioManager.play(&"mission_complete", 0.0)
	results_ready.emit(results)
	SceneRouter.show_screen(&"party_results")


func _set_phase(value: StringName) -> void:
	phase = value
	var phone_phase: String = "lobby"
	match value:
		PLAYING:
			phone_phase = "game"
		PAUSED:
			phone_phase = "paused"
		RESULTS:
			phone_phase = "results"
	hub.set_phase(phone_phase)
	_update_auto_start()
	changed.emit()


func _update_auto_start() -> void:
	if phase != LOBBY or not roster.all_ready():
		auto_start_left = -1.0
	elif auto_start_left < 0.0:
		auto_start_left = AUTO_START_DELAY


func _free_match() -> void:
	if round_match == null:
		return
	remove_child(round_match)
	round_match.queue_free()
	round_match = null


## Desktop windows open in portrait for the runner; the shared screen wants all of it: the window
## is maximized (title bar and taskbar stay; F11 goes full screen) and the canvas base switches to
## 1920 x 1080 so the party screens lay out like a TV picture. Leaving the mode puts the window
## back where and how big it was. A window that was already maximized or full screen is left alone.
func _landscape(on: bool) -> void:
	var root: Window = get_tree().root
	if on:
		_saved_scale_size = root.content_scale_size
		root.content_scale_size = LANDSCAPE_BASE
	elif _saved_scale_size != Vector2i.ZERO:
		root.content_scale_size = _saved_scale_size
	if OS.has_feature("web") or OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	embedded = is_embedded()
	if embedded:
		Log.warn(&"party", "embedded in the editor's Game tab: the window cannot be maximized")
		return
	if on:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			_saved_window = DisplayServer.window_get_size()
			_saved_position = DisplayServer.window_get_position()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	elif _saved_window != Vector2i.ZERO:
		var old_size: Vector2i = _saved_window
		var old_position: Vector2i = _saved_position
		_saved_window = Vector2i.ZERO
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Leaving maximized / full screen restores the previous size a frame later; set ours after.
		await get_tree().process_frame
		DisplayServer.window_set_size(old_size)
		DisplayServer.window_set_position(old_position)
	Log.info(&"party", "window mode %d, size %s" % [DisplayServer.window_get_mode(), DisplayServer.window_get_size()])


func _parse_dev_flags() -> void:
	var open_lobby: bool = false
	var bots: int = 0
	var shot: String = ""
	var shot_at: float = 9.0
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--party":
			open_lobby = true
		elif arg.begins_with("--party-keys="):
			_dev_keys = clampi(int(arg.get_slice("=", 1)), 1, 2)
			open_lobby = true
		elif arg == "--party-help":
			_dev_help = true
			open_lobby = true
		elif arg.begins_with("--party-bots="):
			bots = clampi(int(arg.get_slice("=", 1)), 1, PartyRoster.MAX_PLAYERS)
		elif arg.begins_with("--party-time="):
			PartyMatch.round_time_override = float(arg.get_slice("=", 1))
		elif arg.begins_with("--party-shot="):
			shot = arg.get_slice("=", 1)
		elif arg.begins_with("--party-shot-at="):
			shot_at = float(arg.get_slice("=", 1))
		elif arg.begins_with("--party-close-at="):
			_dev_close_at = float(arg.get_slice("=", 1))
	if open_lobby or bots > 0:
		_dev_start.call_deferred(bots, shot, shot_at)


func _dev_start(bots: int, shot: String, shot_at: float) -> void:
	while GameState.current() != &"menu":
		await get_tree().process_frame
	open()
	for i in range(_dev_keys):
		add_keyboard_player()
	if _dev_keys > 0:
		roster.set_ready(roster.list()[0].slot, true)
	if _dev_help:
		SceneRouter.push(&"party_help")
	for i in range(bots):
		add_bot()
	if bots > 0:
		start_round()
	if _dev_close_at > 0.0:
		await get_tree().create_timer(_dev_close_at, true, false, true).timeout
		close()
		await get_tree().create_timer(2.0, true, false, true).timeout
		Log.info(&"party", "after close: window mode %d, size %s" % [DisplayServer.window_get_mode(), DisplayServer.window_get_size()])
		get_tree().quit(0)
		return
	if shot.is_empty():
		return
	await get_tree().create_timer(shot_at, true, false, true).timeout
	get_viewport().get_texture().get_image().save_png(shot)
	Log.info(&"party", "screenshot saved to %s" % shot)
	get_tree().quit(0)


## True when the game runs inside the Godot editor's Game tab. The editor starts the game with
## "--wid <parent window>"; Engine.is_embedded_in_editor() does not report every such launch, and
## changing the window mode of an embedded window only logs "Embedded window only supports
## Windowed mode", so both are checked before touching the window.
static func is_embedded() -> bool:
	return Engine.is_embedded_in_editor() or OS.get_cmdline_args().has("--wid")


## F11: full screen, and back to the maximized window (the mode always fills the screen).
func _toggle_fullscreen() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless" or is_embedded():
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

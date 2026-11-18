## The phones' side of the multiplayer room: turns NetServer WebSocket messages into roster changes
## and controller actions for PartyMode, and keeps every phone's screen in step with the room.
##
## Phone -> computer (JSON, field "t")
##   hello {cid, name}   on every (re)connect; a known cid takes its slot back
##   join  {name}        take a free slot (lobby only)        name {name}  rename
##   pick  {c}           choose a runner (no duplicates)      ready {v}    READY on / off
##   in    {a}           l / r / u / d = lane left / right, jump, roll
##   again               "Play again" on the results screen   ka           keep-alive
## Computer -> phone
##   welcome {lang, chars}            state {phase, you, players}       full
##   tick {score, eggs, lives, place, players, time, out, state}  (5 per second in a round)
##   count {n} (3, 2, 1, 0 = GO, -1 = hide)   buzz {k: hit | crash}   results {list}
##
## Phones that drop out of the lobby keep their slot for LOBBY_GRACE_MS (a page refresh); in a
## round they keep it until the round ends (their world waits for them).
class_name PhoneHub
extends Node

## A connected phone member pressed a controller action (left, right, jump, roll).
signal action(slot: int, action: StringName)
signal again_pressed(slot: int)
signal member_lost(slot: int)
signal member_back(slot: int)

const LOBBY_GRACE_MS: int = 5000
const ACTIONS: Dictionary = {"l": &"left", "r": &"right", "u": &"jump", "d": &"roll"}

var server: NetServer = null
var roster: PartyRoster = null
## lobby, game, paused, results (what the phones show).
var phase: String = "lobby"

## Connection id -> phone cid, for phones that said hello (members or not).
var _hello: Dictionary = {}


func _init(p_roster: PartyRoster) -> void:
	roster = p_roster


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	server = NetServer.new()
	server.name = "NetServer"
	server.page = ControllerPage.html()
	add_child(server)
	server.client_opened.connect(func(_id: int, _address: String) -> void: pass)
	server.client_closed.connect(_on_closed)
	server.message_received.connect(_on_message)
	roster.changed.connect(broadcast_state)


## Starts the server; false when no port of 8080-8090 is free.
func start() -> bool:
	_hello.clear()
	return server.start()


func stop() -> void:
	server.stop()
	_hello.clear()


func set_phase(value: String) -> void:
	if phase == value:
		return
	phase = value
	broadcast_state()


## Room state to every phone that said hello (each sees its own "you").
func broadcast_state() -> void:
	for client: int in _hello.keys():
		_send_state(client)


## Sends a message to a member's phone (no-op for keyboard / bot members or a lost phone).
func send_to(slot: int, message: Dictionary) -> void:
	var m: PartyRoster.Member = roster.at(slot)
	if m != null and m.kind == PartyRoster.Kind.PHONE and m.client != 0:
		server.send(m.client, JSON.stringify(message))


## Sends a message to every phone that said hello.
func broadcast(message: Dictionary) -> void:
	var text: String = JSON.stringify(message)
	for client: int in _hello.keys():
		server.send(client, text)


## Lobby housekeeping: phones gone longer than the grace time lose their slot.
func _process(_delta: float) -> void:
	if phase != "lobby":
		return
	var now: int = Time.get_ticks_msec()
	for m: PartyRoster.Member in roster.list():
		if m.kind == PartyRoster.Kind.PHONE and m.client == 0 and m.lost_ms > 0 and now - m.lost_ms > LOBBY_GRACE_MS:
			roster.remove(m.slot)


## Removes members whose phone is gone (called when a round ends and the lobby opens).
func drop_lost_members() -> void:
	for m: PartyRoster.Member in roster.list():
		if m.kind == PartyRoster.Kind.PHONE and m.client == 0:
			roster.remove(m.slot)


func _on_message(client: int, text: String) -> void:
	# JSON.parse (not parse_string): a malformed message from a phone is dropped silently.
	var json: JSON = JSON.new()
	if text.length() > 4096 or json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = json.data as Dictionary
	var kind: String = str(msg.get("t", ""))
	if kind == "hello":
		_on_hello(client, msg)
		return
	if not _hello.has(client):
		return
	var m: PartyRoster.Member = roster.by_client(client)
	match kind:
		"join":
			_on_join(client, str(msg.get("name", "")))
		"name":
			if m != null:
				m.name = PartyRoster.clean_name(str(msg.get("name", "")), m.slot)
				roster.changed.emit()
		"pick":
			if m != null and phase == "lobby":
				if not roster.pick(m.slot, StringName(str(msg.get("c", "")))):
					_send_state(client)
		"ready":
			if m != null and phase == "lobby":
				roster.set_ready(m.slot, bool(msg.get("v", false)))
		"in":
			if m != null and ACTIONS.has(str(msg.get("a", ""))):
				action.emit(m.slot, ACTIONS[str(msg.get("a", ""))] as StringName)
		"again":
			if m != null and phase == "results":
				m.again = true
				again_pressed.emit(m.slot)
		"leave":
			if m != null and phase == "lobby":
				roster.remove(m.slot)
		_:
			pass


func _on_hello(client: int, msg: Dictionary) -> void:
	var cid: String = str(msg.get("cid", "")).substr(0, 40)
	_hello[client] = cid
	server.send(client, JSON.stringify(_welcome()))
	var m: PartyRoster.Member = roster.by_cid(cid)
	if m != null:
		# Same phone again (refresh, Wi-Fi hiccup): its slot, runner and score are waiting.
		if m.client != 0 and m.client != client:
			server.kick(m.client)
			_hello.erase(m.client)
		var was_lost: bool = m.client == 0
		m.client = client
		m.lost_ms = 0
		if was_lost:
			member_back.emit(m.slot)
		roster.changed.emit()
		return
	_send_state(client)


func _on_join(client: int, raw_name: String) -> void:
	if roster.by_client(client) != null:
		_send_state(client)
		return
	if phase != "lobby":
		_send_state(client)
		return
	var m: PartyRoster.Member = roster.add(PartyRoster.Kind.PHONE, raw_name, str(_hello.get(client, "")))
	if m == null:
		server.send(client, JSON.stringify({"t": "full"}))
		return
	m.client = client
	# add() already told everybody; tell them again now that the slot knows its phone, so this
	# phone's own state carries "you".
	roster.changed.emit()


func _on_closed(client: int) -> void:
	_hello.erase(client)
	var m: PartyRoster.Member = roster.by_client(client)
	if m == null:
		return
	m.client = 0
	m.lost_ms = Time.get_ticks_msec()
	member_lost.emit(m.slot)
	roster.changed.emit()


func _send_state(client: int) -> void:
	server.send(client, JSON.stringify(_state_for(client)))


## The room as one phone sees it ("you" = its own slot, or null).
func _state_for(client: int) -> Dictionary:
	var players: Array[Dictionary] = []
	for member: PartyRoster.Member in roster.list():
		players.append(member.to_dict())
	var m: PartyRoster.Member = roster.by_client(client)
	var you: Variant = null
	if m != null:
		var d: Dictionary = m.to_dict()
		d["again"] = m.again
		you = d
	return {"t": "state", "phase": phase, "you": you, "players": players}


func _welcome() -> Dictionary:
	var chars: Array[Dictionary] = []
	for def: CharacterDef in ContentDB.CHARACTERS:
		chars.append({"id": String(def.id), "name": Tr.t(def.name_key),
				"body": "#" + def.body_color.to_html(false), "accent": "#" + def.glow_color.to_html(false)})
	return {"t": "welcome", "lang": Tr.language(), "chars": chars}

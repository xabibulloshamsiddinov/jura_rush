## Multiplayer: QR encoder, WebSocket / HTTP codec, the LAN server end to end on localhost, the
## room rules, the phone protocol (join, pick, ready, reconnect) and a whole bot round on a split
## screen (separate event buses, nothing leaks into the single-player game, pools come back).
extends TestCase

const TEST_PORT_FIRST: int = 18080
const TEST_PORT_LAST: int = 18095


func test_event_scope() -> void:
	var outer: Node = Node.new()
	var bus: EventBus = EventBus.new()
	outer.set_meta(EventScope.META, bus)
	var inner: Node = Node.new()
	outer.add_child(inner)
	check(EventScope.of(inner) == bus, "a node under a tagged world uses that world's bus")
	var loose: Node = Node.new()
	check(EventScope.of(loose) == GameEvents, "an untagged node uses GameEvents")
	bus.state_changed.emit(&"boot", &"running")
	check_eq(bus.flow, &"running", "bus keeps its flow in step with state_changed")
	loose.free()
	outer.free()
	bus.free()


func test_qr_encoder() -> void:
	# Golden symbols, decoded and verified with an independent decoder (zxing-cpp) when written.
	var a: QrCode = QrCode.encode("http://192.168.1.5:8080")
	check(a != null, "url encodes")
	check_eq(a.version, 2, "23 bytes at level M need version 2")
	check_eq(a.size, 25, "version 2 is 25 modules")
	check_eq(_sha("\n".join(a.to_strings())), "98de4cfaef2c110b8356c5bb3454c49a696640ddaf4ada010fdb5f682392cb13",
			"version 2 symbol matches the verified golden")
	var b: QrCode = QrCode.encode("http://192.168.100.100:8080")
	check_eq(b.version, 3, "27 bytes need version 3")
	check_eq(_sha("\n".join(b.to_strings())), "57f0c0c9b702edaf4e1cd64797cbce0c7d3ec16325491da4c3477d78f4c9a089",
			"version 3 symbol matches the verified golden")
	check_eq(QrCode.encode("x".repeat(14)).version, 1, "14 bytes still fit version 1-M")
	check_eq(QrCode.encode("x".repeat(15)).version, 2, "15 bytes move to version 2")
	check(QrCode.encode("x".repeat(200), 1, 5) == null, "too long for the version cap gives null")
	var big: QrCode = QrCode.encode("https://example.com/" + "a".repeat(150))
	check(big != null and big.version >= 7, "long text uses a version with version-information blocks")
	# Finder pattern corners are dark, the separator next to them light.
	check(a.is_dark(0, 0) and a.is_dark(6, 6) and not a.is_dark(7, 7), "finder pattern and separator")
	var image: Image = a.to_image(4, 2)
	check_eq(image.get_width(), (25 + 4) * 4, "image size = (modules + border) * scale")


func test_websocket_codec() -> void:
	# RFC 6455 section 1.3 example.
	check_eq(NetServer.accept_key("dGhlIHNhbXBsZSBub25jZQ=="), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "accept key")
	var payload: PackedByteArray = "hello phone".to_utf8_buffer()
	var frame: Dictionary = NetServer.parse_frame(NetServer.encode_client_frame(NetServer.OP_TEXT, payload), 1024)
	check(bool(frame.get("fin", false)) and int(frame.get("opcode", -1)) == NetServer.OP_TEXT, "text frame header")
	check_eq((frame["payload"] as PackedByteArray).get_string_from_utf8(), "hello phone", "payload unmasked")
	var long: PackedByteArray = "y".repeat(300).to_utf8_buffer()
	var wire: PackedByteArray = NetServer.encode_client_frame(NetServer.OP_TEXT, long)
	check_eq(int(NetServer.parse_frame(wire, 1024)["consumed"]), wire.size(), "16-bit length frame consumed whole")
	check(NetServer.parse_frame(wire.slice(0, 20), 1024).is_empty(), "partial frame waits for more bytes")
	check(NetServer.parse_frame(wire, 100).has("error"), "frame over the size cap is refused")
	var unmasked: PackedByteArray = NetServer.encode_frame(NetServer.OP_TEXT, payload)
	check(NetServer.parse_frame(unmasked, 1024).has("error"), "unmasked client frame is refused")
	var server_frame: PackedByteArray = NetServer.encode_frame(NetServer.OP_TEXT, long)
	check_eq(server_frame[1], 126, "server frame uses the 16-bit length form")
	check_eq(server_frame.size(), 4 + long.size(), "server frame size")


func test_http_parse() -> void:
	var req: Dictionary = NetServer.parse_request("GET /ws?x=1 HTTP/1.1\r\nHost: 1.2.3.4:8080\r\nUpgrade: websocket\r\nSec-WebSocket-Key: abc")
	check_eq(str(req.get("path", "")), "/ws", "query string stripped")
	check_eq(str((req["headers"] as Dictionary).get("upgrade", "")), "websocket", "header names lower-cased")
	check(NetServer.parse_request("garbage").is_empty(), "malformed request line")
	var buf: PackedByteArray = "GET / HTTP/1.1\r\nA: b\r\n\r\nrest".to_utf8_buffer()
	check_eq(NetServer.find_header_end(buf), 20, "header end found")
	check(NetServer._is_lan_ipv4("192.168.1.20") and NetServer._is_lan_ipv4("10.0.0.7"), "private ranges")
	check(NetServer._is_lan_ipv4("172.20.1.1") and not NetServer._is_lan_ipv4("172.40.1.1"), "172.16/12 only")
	check(not NetServer._is_lan_ipv4("127.0.0.1") and not NetServer._is_lan_ipv4("169.254.3.3"), "loopback and link-local out")
	check(not NetServer._is_lan_ipv4("fe80::1"), "IPv6 out")
	check(NetServer._is_virtual_adapter("VirtualBox Host-Only Network") and NetServer._is_virtual_adapter("vEthernet (WSL)"),
			"virtual adapters recognised")
	check(not NetServer._is_virtual_adapter("Wi-Fi"), "a real Wi-Fi adapter is not virtual")


func test_roster_rules() -> void:
	var roster: PartyRoster = PartyRoster.new()
	var a: PartyRoster.Member = roster.add(PartyRoster.Kind.PHONE, "  Ali  <b>  ", "cid-a")
	var b: PartyRoster.Member = roster.add(PartyRoster.Kind.KEYBOARD, "")
	var c: PartyRoster.Member = roster.add(PartyRoster.Kind.BOT, "")
	a.client = 5
	check(roster.add(PartyRoster.Kind.PHONE, "Late") == null, "a fourth player is refused")
	check_eq(a.name, "Ali b", "names lose markup and extra spaces")
	check_eq(b.name, Tr.f(&"party.player_n", {"n": 2}), "empty name becomes Player N")
	check(a.character != b.character and b.character != c.character and a.character != c.character,
			"every member gets a different runner")
	check(not roster.pick(b.slot, a.character), "a taken runner cannot be picked")
	var before: StringName = b.character
	roster.cycle_character(b.slot, 1)
	check(b.character != before and b.character != a.character and b.character != c.character,
			"cycling skips runners other players have")
	check(c.ready and not a.ready, "bots are ready, people are not")
	check(not roster.all_ready(), "not everybody ready")
	roster.set_ready(b.slot, true)
	check(not roster.all_ready(), "phone still not ready")
	a.client = 0
	check(roster.all_ready(), "a lost phone does not block the start")
	a.client = 5
	check(not roster.all_ready(), "the phone is back and not ready")
	roster.set_ready(a.slot, true)
	check(roster.all_ready(), "everybody ready")
	check(not roster.all_phones_again(), "no phone pressed play again")
	a.again = true
	check(roster.all_phones_again(), "the only phone pressed play again")
	check(roster.by_cid("cid-a") == a and roster.by_client(5) == a, "lookups by phone id and connection")
	roster.remove(a.slot)
	check_eq(roster.count(), 2, "member removed")
	var d: PartyRoster.Member = roster.add(PartyRoster.Kind.PHONE, "Dina")
	check_eq(d.slot, 0, "the freed slot is reused")
	check_eq(PartyRoster.clean_name("a".repeat(40), 0).length(), PartyRoster.NAME_MAX, "names are capped")


func test_server_end_to_end() -> void:
	var server: NetServer = NetServer.new()
	server.page = "<html>pad</html>"
	tree.root.add_child(server)
	check(server.start(TEST_PORT_FIRST, TEST_PORT_LAST), "server listens on a test port")
	var received: Array[String] = []
	var opened: Array[int] = []
	server.message_received.connect(func(_id: int, text: String) -> void: received.append(text))
	server.client_opened.connect(func(id: int, _a: String) -> void: opened.append(id))
	# Plain HTTP: /ping and the page.
	var ping: String = await _http_get(server, "/ping")
	check(ping.begins_with("HTTP/1.1 200") and ping.ends_with("ok"), "GET /ping answers ok")
	var page: String = await _http_get(server, "/")
	check(page.contains("<html>pad</html>") and server.page_hits == 1, "GET / serves the page and counts it")
	var missing: String = await _http_get(server, "/nope")
	check(missing.begins_with("HTTP/1.1 404"), "unknown path is 404")
	# WebSocket: handshake, a masked message in, a message out.
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", server.port)
	await _wait_connected(peer)
	var key: String = "dGhlIHNhbXBsZSBub25jZQ=="
	peer.put_data(("GET /ws HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n" % key).to_utf8_buffer())
	var head: PackedByteArray = await _read_until(peer, func(b: PackedByteArray) -> bool: return NetServer.find_header_end(b) >= 0)
	var head_text: String = head.get_string_from_utf8()
	check(head_text.begins_with("HTTP/1.1 101"), "upgrade accepted")
	check(head_text.contains("s3pPLMBiTxaQ9kYGzzhZRbK+xOo="), "correct Sec-WebSocket-Accept")
	check_eq(opened.size(), 1, "client_opened fired once")
	peer.put_data(NetServer.encode_client_frame(NetServer.OP_TEXT, "{\"t\":\"ka\"}".to_utf8_buffer()))
	for i in range(30):
		if not received.is_empty():
			break
		await tree.process_frame
	check(received.size() == 1 and received[0] == "{\"t\":\"ka\"}", "masked text frame delivered")
	check(server.send(opened[0], "pong!"), "send to the client")
	var reply: PackedByteArray = await _read_until(peer, func(b: PackedByteArray) -> bool: return b.size() >= 2 + 5)
	check(reply.size() >= 7 and reply[0] == 0x81 and reply[1] == 5 and reply.slice(2, 7).get_string_from_utf8() == "pong!",
			"server frame is a FIN text frame, unmasked")
	check_eq(server.open_count(), 1, "one WebSocket open")
	var closed: Array[int] = []
	server.client_closed.connect(func(id: int) -> void: closed.append(id))
	peer.disconnect_from_host()
	for i in range(30):
		if not closed.is_empty():
			break
		await tree.process_frame
	check_eq(closed.size(), 1, "client_closed fired when the phone went away")
	server.stop()
	server.queue_free()


func test_phone_hub_protocol() -> void:
	var roster: PartyRoster = PartyRoster.new()
	var hub: PhoneHub = PhoneHub.new(roster)
	tree.root.add_child(hub)
	var lost: Array[int] = []
	var back: Array[int] = []
	var actions: Array[StringName] = []
	hub.member_lost.connect(func(slot: int) -> void: lost.append(slot))
	hub.member_back.connect(func(slot: int) -> void: back.append(slot))
	hub.action.connect(func(_slot: int, a: StringName) -> void: actions.append(a))
	hub._on_message(11, JSON.stringify({"t": "join", "name": "Ghost"}))
	check_eq(roster.count(), 0, "no join before hello")
	hub._on_message(11, JSON.stringify({"t": "hello", "cid": "phone-1"}))
	hub._on_message(11, JSON.stringify({"t": "join", "name": "Ali"}))
	var m: PartyRoster.Member = roster.by_cid("phone-1")
	check(m != null and m.name == "Ali" and m.client == 11, "hello + join takes a slot")
	# The state a joined phone gets must name it ("you"), or the page never leaves the join form.
	var state_you: Variant = hub._state_for(11)["you"]
	check(state_you != null and int((state_you as Dictionary)["slot"]) == m.slot, "a joined phone's state carries you")
	var other: StringName = PartyRoster.character_ids()[3]
	hub._on_message(11, JSON.stringify({"t": "pick", "c": String(other)}))
	check_eq(m.character, other, "pick changes the runner")
	hub._on_message(11, JSON.stringify({"t": "ready", "v": true}))
	check(m.ready, "ready")
	hub._on_message(11, "not json at all")
	hub._on_message(11, JSON.stringify({"t": "in", "a": "u"}))
	check(actions == [&"jump"], "u = jump")
	hub._on_message(11, JSON.stringify({"t": "in", "a": "zzz"}))
	check_eq(actions.size(), 1, "unknown action ignored")
	hub._on_closed(11)
	check(m.client == 0 and lost == [m.slot], "connection drop keeps the slot and reports it")
	hub._on_message(12, JSON.stringify({"t": "hello", "cid": "phone-1"}))
	check(m.client == 12 and back == [m.slot], "same phone id takes its slot back")
	check(m.ready and m.character == other, "and keeps runner and READY")
	hub.set_phase("game")
	hub._on_message(13, JSON.stringify({"t": "hello", "cid": "phone-2"}))
	hub._on_message(13, JSON.stringify({"t": "join", "name": "Late"}))
	check_eq(roster.count(), 1, "nobody joins in the middle of a round")
	hub.set_phase("results")
	hub._on_message(12, JSON.stringify({"t": "again"}))
	check(m.again and roster.all_phones_again(), "play again recorded")
	hub.queue_free()


func test_party_round_with_bots() -> void:
	var pools_before: int = PoolManager.total_in_use()
	var leaks: Array[int] = [0]
	var leak: Callable = func(_v: int) -> void: leaks[0] += 1
	GameEvents.score_changed.connect(leak)
	var roster: PartyRoster = PartyRoster.new()
	roster.add(PartyRoster.Kind.BOT, "One")
	roster.add(PartyRoster.Kind.BOT, "Two")
	PartyMatch.round_time_override = 8.0
	var round_match: PartyMatch = PartyMatch.new()
	round_match.setup(roster.list(), 4242, 1)
	var done: Array = []
	round_match.finished.connect(func(list: Array[Dictionary]) -> void: done.append(list))
	var counts: Array[int] = []
	round_match.countdown.connect(func(n: int) -> void: counts.append(n))
	tree.root.add_child(round_match)
	check_eq(round_match.runners.size(), 2, "two strips")
	var bus_a: EventBus = round_match.runners[0].view.bus
	var bus_b: EventBus = round_match.runners[1].view.bus
	check(bus_a != bus_b and bus_a != GameEvents, "every strip has its own event bus")
	check(round_match.runners[0].view.world.events == bus_a, "the world uses its view's bus")
	check(not round_match.runners[0].view.world.solo, "split-screen worlds are not solo")
	Engine.time_scale = 4.0
	var waited: float = 0.0
	while done.is_empty() and waited < 30.0:
		await tree.process_frame
		waited += 1.0 / 60.0
	Engine.time_scale = 1.0
	PartyMatch.round_time_override = 0.0
	check(not done.is_empty(), "the round finished")
	check(counts.slice(0, 4) == [3, 2, 1, 0], "3-2-1-GO countdown")
	if not done.is_empty():
		var list: Array = done[0]
		check_eq(list.size(), 2, "two results")
		check(int(list[0]["place"]) == 1, "the best score is 1st")
		var tied: bool = int(list[0]["score"]) == int(list[1]["score"])
		check_eq(int(list[1]["place"]), 1 if tied else 2, "2nd, or 1st too when the scores tie")
		check(int(list[0]["score"]) >= int(list[1]["score"]), "best score first")
		check(int(list[0]["distance"]) > 0 and int(list[1]["distance"]) > 0, "both runners ran")
	check_eq(leaks[0], 0, "no split-screen score reached the single-player GameEvents")
	GameEvents.score_changed.disconnect(leak)
	tree.root.remove_child(round_match)
	round_match.free()
	check_eq(PoolManager.total_in_use(), pools_before, "every pooled chunk / obstacle came back")


func test_party_screens_build() -> void:
	for id: String in ["party_lobby", "party_hud", "party_pause", "party_results", "party_help"]:
		var scene: PackedScene = load("res://scenes/ui/%s.tscn" % id) as PackedScene
		check(scene != null, "%s scene loads" % id)
		if scene == null:
			continue
		var screen: UIScreen = scene.instantiate() as UIScreen
		check(screen != null, "%s is a UIScreen" % id)
		if screen != null:
			tree.root.add_child(screen)
			check(screen.get_child_count() > 0, "%s builds its controls" % id)
			screen.queue_free()
	var page: String = ControllerPage.html()
	check(page.begins_with("<!doctype html>") and page.contains("new WebSocket") and page.ends_with("</html>\n"),
			"controller page is complete")


# --- helpers ---------------------------------------------------------------------------------

func _sha(text: String) -> String:
	return text.sha256_text()


func _wait_connected(peer: StreamPeerTCP) -> void:
	for i in range(120):
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			return
		await tree.process_frame


func _read_until(peer: StreamPeerTCP, done: Callable) -> PackedByteArray:
	var buf: PackedByteArray = PackedByteArray()
	for i in range(180):
		peer.poll()
		var n: int = peer.get_available_bytes()
		if n > 0:
			buf.append_array(peer.get_data(n)[1] as PackedByteArray)
			if bool(done.call(buf)):
				return buf
		await tree.process_frame
	return buf


func _http_get(server: NetServer, path: String) -> String:
	var peer: StreamPeerTCP = StreamPeerTCP.new()
	peer.connect_to_host("127.0.0.1", server.port)
	await _wait_connected(peer)
	peer.put_data(("GET %s HTTP/1.1\r\nHost: localhost\r\n\r\n" % path).to_utf8_buffer())
	var buf: PackedByteArray = PackedByteArray()
	for i in range(180):
		peer.poll()
		var n: int = peer.get_available_bytes()
		if n > 0:
			buf.append_array(peer.get_data(n)[1] as PackedByteArray)
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var text: String = buf.get_string_from_utf8()
		var end: int = text.find("\r\n\r\n")
		if end >= 0:
			var length: int = int(text.get_slice("Content-Length: ", 1).get_slice("\r\n", 0))
			if text.length() - (end + 4) >= length:
				break
		await tree.process_frame
	peer.disconnect_from_host()
	var all: String = buf.get_string_from_utf8()
	return all

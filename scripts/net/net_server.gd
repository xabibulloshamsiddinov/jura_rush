## A tiny HTTP + WebSocket server on the local network (no plugin, no threads): serves the phone
## controller page and carries the controllers' JSON messages. Polled from _process, so it keeps
## working while the scene tree is paused (process_mode ALWAYS) and needs no locking.
##
##   GET /        the controller page (`page`)
##   GET /ping    "ok" (connection test from a phone browser)
##   GET /ws      upgrades to a WebSocket (RFC 6455, text frames, server pings every 5 s)
##   anything else 404
##
## Ports PORT_FIRST..PORT_LAST are tried in turn. Plain HTTP / WS on the LAN only: there is no
## authentication, so the server only ever accepts game-controller messages (see PhoneHub) and
## runs only while the multiplayer mode is open.
class_name NetServer
extends Node

signal client_opened(id: int, address: String)
signal client_closed(id: int)
signal message_received(id: int, text: String)

const PORT_FIRST: int = 8080
const PORT_LAST: int = 8090
const WS_GUID: String = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const MAX_HEADER: int = 8192
const MAX_MESSAGE: int = 64 * 1024
const MAX_CLIENTS: int = 24
const PING_INTERVAL: float = 5.0
## A WebSocket that sends nothing (not even a pong) for this long is dropped.
const IDLE_TIMEOUT_MS: int = 15000
## An HTTP request that never completes is dropped after this long.
const HTTP_TIMEOUT_MS: int = 10000

enum Mode { HTTP, WS, CLOSING }

const OP_CONTINUATION: int = 0x0
const OP_TEXT: int = 0x1
const OP_BINARY: int = 0x2
const OP_CLOSE: int = 0x8
const OP_PING: int = 0x9
const OP_PONG: int = 0xA

## Body of GET / (HTML).
var page: String = ""
## Port in use (0 = not listening).
var port: int = 0
## Diagnostics: controller page loads and WebSocket connections since start().
var page_hits: int = 0
var ws_total: int = 0
## Address of the last HTTP request (diagnostics: "a phone reached the computer").
var last_address: String = ""

var _server: TCPServer = null
var _clients: Dictionary = {}
var _next_id: int = 1
var _page_bytes: PackedByteArray = PackedByteArray()


class Client extends RefCounted:
	var id: int = 0
	var peer: StreamPeerTCP = null
	var address: String = ""
	var mode: Mode = Mode.HTTP
	var buffer: PackedByteArray = PackedByteArray()
	var fragments: PackedByteArray = PackedByteArray()
	var fragment_opcode: int = -1
	var opened_ms: int = 0
	var seen_ms: int = 0
	var close_ms: int = 0
	var ping_left: float = PING_INTERVAL


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	stop()


## Starts listening on the first free port of PORT_FIRST..PORT_LAST. Returns false when none is.
func start(first: int = PORT_FIRST, last: int = PORT_LAST) -> bool:
	stop()
	_page_bytes = page.to_utf8_buffer()
	page_hits = 0
	ws_total = 0
	last_address = ""
	for p in range(first, last + 1):
		var server: TCPServer = TCPServer.new()
		if server.listen(p, "*") == OK:
			_server = server
			port = p
			Log.info(&"net", "controller server listening on port %d" % port)
			return true
	Log.warn(&"net", "no free port in %d-%d" % [first, last])
	return false


## Closes every connection and stops listening.
func stop() -> void:
	for id: int in _clients.keys():
		_drop(_clients[id] as Client)
	_clients.clear()
	if _server != null:
		_server.stop()
		_server = null
	port = 0


func is_listening() -> bool:
	return _server != null and _server.is_listening()


## Replaces the controller page served at / (e.g. after a language change).
func set_page(html: String) -> void:
	page = html
	_page_bytes = page.to_utf8_buffer()


## WebSocket connections open right now.
func open_count() -> int:
	var n: int = 0
	for c: Client in _clients.values():
		if c.mode == Mode.WS:
			n += 1
	return n


## Sends a text message to one WebSocket client. Returns false if it is gone.
func send(id: int, text: String) -> bool:
	var c: Client = _clients.get(id) as Client
	if c == null or c.mode != Mode.WS:
		return false
	if c.peer.put_data(encode_frame(OP_TEXT, text.to_utf8_buffer())) != OK:
		_drop(c)
		return false
	return true


## Closes one WebSocket with a close frame.
func kick(id: int) -> void:
	var c: Client = _clients.get(id) as Client
	if c == null:
		return
	if c.mode == Mode.WS:
		c.peer.put_data(encode_frame(OP_CLOSE, PackedByteArray([0x03, 0xE8])))
	_drop(c)


func _process(delta: float) -> void:
	if _server == null:
		return
	var now: int = Time.get_ticks_msec()
	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		if peer == null:
			break
		if _clients.size() >= MAX_CLIENTS:
			peer.disconnect_from_host()
			continue
		peer.set_no_delay(true)
		var c: Client = Client.new()
		c.id = _next_id
		_next_id += 1
		c.peer = peer
		c.address = peer.get_connected_host()
		c.opened_ms = now
		c.seen_ms = now
		_clients[c.id] = c
	for id: int in _clients.keys():
		var c: Client = _clients.get(id) as Client
		if c == null:
			continue
		c.peer.poll()
		if c.peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_drop(c)
			continue
		var available: int = c.peer.get_available_bytes()
		if available > 0:
			var got: Array = c.peer.get_data(available)
			if int(got[0]) != OK:
				_drop(c)
				continue
			c.buffer.append_array(got[1] as PackedByteArray)
			c.seen_ms = now
		match c.mode:
			Mode.HTTP:
				if now - c.opened_ms > HTTP_TIMEOUT_MS:
					_drop(c)
				else:
					_handle_http(c)
			Mode.WS:
				_handle_ws(c)
				if not _clients.has(id):
					continue
				if now - c.seen_ms > IDLE_TIMEOUT_MS:
					_drop(c)
					continue
				c.ping_left -= delta
				if c.ping_left <= 0.0:
					c.ping_left = PING_INTERVAL
					c.peer.put_data(encode_frame(OP_PING, PackedByteArray()))
			Mode.CLOSING:
				if now > c.close_ms:
					_drop(c)


# --- HTTP ----------------------------------------------------------------------------------------

func _handle_http(c: Client) -> void:
	var end: int = find_header_end(c.buffer)
	if end < 0:
		if c.buffer.size() > MAX_HEADER:
			_respond(c, "431 Request Header Fields Too Large", "text/plain", "Too large".to_utf8_buffer())
		return
	var head: String = c.buffer.slice(0, end).get_string_from_utf8()
	c.buffer = c.buffer.slice(end + 4)
	var request: Dictionary = parse_request(head)
	if request.is_empty():
		_respond(c, "400 Bad Request", "text/plain", "Bad request".to_utf8_buffer())
		return
	var path: String = str(request["path"])
	var headers: Dictionary = request["headers"] as Dictionary
	var method: String = str(request["method"])
	last_address = c.address
	if path == "/ws" and str(headers.get("upgrade", "")).to_lower() == "websocket":
		_upgrade(c, str(headers.get("sec-websocket-key", "")))
		return
	if method != "GET" and method != "HEAD":
		_respond(c, "405 Method Not Allowed", "text/plain", "Method not allowed".to_utf8_buffer())
		return
	Log.info(&"net", "HTTP %s from %s" % [path, c.address])
	match path:
		"/", "/index.html":
			page_hits += 1
			_respond(c, "200 OK", "text/html; charset=utf-8", _page_bytes, method == "HEAD")
		"/ping":
			_respond(c, "200 OK", "text/plain; charset=utf-8", "ok".to_utf8_buffer(), method == "HEAD")
		_:
			_respond(c, "404 Not Found", "text/plain; charset=utf-8", "Not found".to_utf8_buffer(), method == "HEAD")


func _respond(c: Client, status: String, content_type: String, body: PackedByteArray, head_only: bool = false) -> void:
	var header: String = "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" \
			% [status, content_type, body.size()]
	var out: PackedByteArray = header.to_utf8_buffer()
	if not head_only:
		out.append_array(body)
	c.peer.put_data(out)
	# The browser closes the socket once it has the whole body (Connection: close).
	c.mode = Mode.CLOSING
	c.close_ms = Time.get_ticks_msec() + 3000


func _upgrade(c: Client, key: String) -> void:
	if key.strip_edges().is_empty():
		_respond(c, "400 Bad Request", "text/plain", "Missing Sec-WebSocket-Key".to_utf8_buffer())
		return
	var reply: String = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n" \
			% accept_key(key.strip_edges())
	if c.peer.put_data(reply.to_utf8_buffer()) != OK:
		_drop(c)
		return
	c.mode = Mode.WS
	c.ping_left = PING_INTERVAL
	ws_total += 1
	client_opened.emit(c.id, c.address)
	# Bytes that came right behind the handshake are already WebSocket frames.
	if _clients.has(c.id):
		_handle_ws(c)


# --- WebSocket -----------------------------------------------------------------------------------

func _handle_ws(c: Client) -> void:
	while _clients.has(c.id) and c.mode == Mode.WS:
		var frame: Dictionary = parse_frame(c.buffer, MAX_MESSAGE)
		if frame.has("error"):
			kick(c.id)
			return
		if frame.is_empty():
			return
		c.buffer = c.buffer.slice(int(frame["consumed"]))
		var opcode: int = int(frame["opcode"])
		var payload: PackedByteArray = frame["payload"] as PackedByteArray
		var fin: bool = bool(frame["fin"])
		match opcode:
			OP_TEXT, OP_BINARY:
				if fin:
					_deliver(c, opcode, payload)
				else:
					c.fragment_opcode = opcode
					c.fragments = payload
			OP_CONTINUATION:
				if c.fragment_opcode < 0:
					kick(c.id)
					return
				c.fragments.append_array(payload)
				if c.fragments.size() > MAX_MESSAGE:
					kick(c.id)
					return
				if fin:
					var whole: PackedByteArray = c.fragments
					var op: int = c.fragment_opcode
					c.fragments = PackedByteArray()
					c.fragment_opcode = -1
					_deliver(c, op, whole)
			OP_CLOSE:
				c.peer.put_data(encode_frame(OP_CLOSE, payload.slice(0, 2)))
				_drop(c)
				return
			OP_PING:
				c.peer.put_data(encode_frame(OP_PONG, payload))
			OP_PONG:
				pass
			_:
				kick(c.id)
				return


func _deliver(c: Client, opcode: int, payload: PackedByteArray) -> void:
	if opcode == OP_TEXT:
		message_received.emit(c.id, payload.get_string_from_utf8())


func _drop(c: Client) -> void:
	if not _clients.has(c.id):
		return
	_clients.erase(c.id)
	var was_open: bool = c.mode == Mode.WS
	c.peer.disconnect_from_host()
	if was_open:
		client_closed.emit(c.id)


# --- protocol helpers (static, unit-tested) ------------------------------------------------------

## Index of the blank line ending an HTTP header ("\r\n\r\n"), or -1.
static func find_header_end(buffer: PackedByteArray) -> int:
	for i in range(buffer.size() - 3):
		if buffer[i] == 13 and buffer[i + 1] == 10 and buffer[i + 2] == 13 and buffer[i + 3] == 10:
			return i
	return -1


## {"method", "path" (query stripped), "headers" (lower-case names)} or {} when malformed.
static func parse_request(head: String) -> Dictionary:
	var lines: PackedStringArray = head.split("\r\n")
	if lines.is_empty():
		return {}
	var parts: PackedStringArray = lines[0].split(" ", false)
	if parts.size() < 3 or not parts[2].begins_with("HTTP/"):
		return {}
	var headers: Dictionary = {}
	for i in range(1, lines.size()):
		var colon: int = lines[i].find(":")
		if colon > 0:
			headers[lines[i].substr(0, colon).strip_edges().to_lower()] = lines[i].substr(colon + 1).strip_edges()
	return {"method": parts[0].to_upper(), "path": parts[1].get_slice("?", 0), "headers": headers}


## Sec-WebSocket-Accept for a client key: base64(SHA-1(key + GUID)).
static func accept_key(key: String) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update((key + WS_GUID).to_utf8_buffer())
	return Marshalls.raw_to_base64(ctx.finish())


## One server-to-client frame (FIN set, unmasked).
static func encode_frame(opcode: int, payload: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray([0x80 | (opcode & 0x0F)])
	var n: int = payload.size()
	if n < 126:
		out.append(n)
	elif n < 65536:
		out.append(126)
		out.append((n >> 8) & 0xFF)
		out.append(n & 0xFF)
	else:
		out.append(127)
		for i in range(7, -1, -1):
			out.append((n >> (i * 8)) & 0xFF)
	out.append_array(payload)
	return out


## Client frames for tests: masked as RFC 6455 requires.
static func encode_client_frame(opcode: int, payload: PackedByteArray, fin: bool = true,
		mask_key: PackedByteArray = PackedByteArray([0x12, 0x34, 0x56, 0x78])) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray([(0x80 if fin else 0x00) | (opcode & 0x0F)])
	var n: int = payload.size()
	if n < 126:
		out.append(0x80 | n)
	elif n < 65536:
		out.append(0x80 | 126)
		out.append((n >> 8) & 0xFF)
		out.append(n & 0xFF)
	else:
		out.append(0x80 | 127)
		for i in range(7, -1, -1):
			out.append((n >> (i * 8)) & 0xFF)
	out.append_array(mask_key)
	for i in range(n):
		out.append(payload[i] ^ mask_key[i & 3])
	return out


## Parses the first client frame in `buffer`.
##   {} = need more bytes
##   {"error": reason} = protocol violation (unmasked, too large)
##   {"fin", "opcode", "payload" (unmasked), "consumed"} otherwise
static func parse_frame(buffer: PackedByteArray, max_payload: int) -> Dictionary:
	if buffer.size() < 2:
		return {}
	var b0: int = buffer[0]
	var b1: int = buffer[1]
	var length: int = b1 & 0x7F
	var offset: int = 2
	if length == 126:
		if buffer.size() < 4:
			return {}
		length = (buffer[2] << 8) | buffer[3]
		offset = 4
	elif length == 127:
		if buffer.size() < 10:
			return {}
		length = 0
		for i in range(2, 10):
			length = (length << 8) | buffer[i]
		offset = 10
	if (b1 & 0x80) == 0:
		return {"error": "unmasked"}
	if length > max_payload or length < 0:
		return {"error": "too large"}
	if buffer.size() < offset + 4 + length:
		return {}
	var key: PackedByteArray = buffer.slice(offset, offset + 4)
	var payload: PackedByteArray = buffer.slice(offset + 4, offset + 4 + length)
	for i in range(length):
		payload[i] = payload[i] ^ key[i & 3]
	return {"fin": (b0 & 0x80) != 0, "opcode": b0 & 0x0F, "payload": payload, "consumed": offset + 4 + length}


## LAN addresses phones can reach, best first: [{"ip", "name", "virtual"}]. 192.168.x.x first,
## then 10.x and 172.16-31.x; loopback, link-local and IPv6 are left out, virtual adapters
## (VirtualBox, VMware, Hyper-V, WSL, Docker, VPNs) go last and are flagged.
static func lan_addresses() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	for iface: Dictionary in IP.get_local_interfaces():
		var name: String = str(iface.get("friendly", iface.get("name", "")))
		var virtual: bool = _is_virtual_adapter(name)
		for ip: String in iface.get("addresses", PackedStringArray()):
			if not _is_lan_ipv4(ip) or seen.has(ip):
				continue
			seen[ip] = true
			# VirtualBox's host-only network is 192.168.56.x even when the adapter name is generic.
			found.append({"ip": ip, "name": name, "virtual": virtual or ip.begins_with("192.168.56.")})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _address_rank(a) < _address_rank(b))
	return found


static func _address_rank(entry: Dictionary) -> int:
	var ip: String = str(entry["ip"])
	var rank: int = 2
	if ip.begins_with("192.168."):
		rank = 0
	elif ip.begins_with("10."):
		rank = 1
	return rank + (10 if bool(entry["virtual"]) else 0)


static func _is_lan_ipv4(ip: String) -> bool:
	if not ip.is_valid_ip_address() or ip.contains(":"):
		return false
	if ip.begins_with("127.") or ip.begins_with("169.254.") or ip.begins_with("0."):
		return false
	if ip.begins_with("192.168.") or ip.begins_with("10."):
		return true
	if ip.begins_with("172."):
		var second: int = int(ip.get_slice(".", 1))
		return second >= 16 and second <= 31
	return false


static func _is_virtual_adapter(name: String) -> bool:
	var n: String = name.to_lower()
	for word: String in ["virtualbox", "vmware", "vethernet", "hyper-v", "wsl", "docker", "loopback",
			"vpn", "tap-", "tun", "tailscale", "zerotier", "hamachi", "bluetooth", "virtual"]:
		if n.contains(word):
			return true
	return false

## Who is in the multiplayer room: up to MAX_PLAYERS slots, each a phone, a keyboard or a bot,
## with a name, a runner skin (no two players share one), a slot colour and a ready flag. Pure data
## and rules (unit-tested); PhoneHub and PartyMode drive it and listen to `changed`.
class_name PartyRoster
extends RefCounted

signal changed

const MAX_PLAYERS: int = 3
const NAME_MAX: int = 14
## Player colours (badges, cards, phone accents): orange, sky blue, leaf green.
const SLOT_COLORS: Array[Color] = [Color(1.0, 0.55, 0.12), Color(0.25, 0.68, 1.0), Color(0.52, 0.86, 0.24)]
## Keyboard layouts: 0 = W A S D (+ Space), 1 = arrow keys (+ Enter).
const KEY_LAYOUTS: int = 2

enum Kind { PHONE, KEYBOARD, BOT }


class Member extends RefCounted:
	var slot: int = 0
	var kind: Kind = Kind.PHONE
	var name: String = ""
	## Phone id kept in the phone browser's localStorage (reconnects find their slot by it).
	var cid: String = ""
	## NetServer connection of the phone (0 = not connected).
	var client: int = 0
	var character: StringName = &""
	var ready: bool = false
	## Pressed "Play again" on the results screen.
	var again: bool = false
	## Keyboard layout (KEYBOARD members).
	var keys: int = 0
	## Ticks (ms) when the phone connection dropped, 0 while connected.
	var lost_ms: int = 0

	func connected() -> bool:
		return kind != Kind.PHONE or client != 0

	func color() -> Color:
		return PartyRoster.SLOT_COLORS[slot]

	func to_dict() -> Dictionary:
		return {"slot": slot, "name": name, "char": String(character), "ready": ready,
				"on": connected(), "kind": ["phone", "keys", "bot"][kind], "color": "#" + color().to_html(false)}


var _members: Array[Member] = []


func _init() -> void:
	_members.resize(MAX_PLAYERS)


## Adds a member in the first free slot (null when the room is full). A free runner is picked for
## them straight away, so READY works at once; phones may change it.
func add(kind: Kind, raw_name: String, cid: String = "") -> Member:
	var slot: int = _members.find(null)
	if slot < 0:
		return null
	var m: Member = Member.new()
	m.slot = slot
	m.kind = kind
	m.cid = cid
	m.name = clean_name(raw_name, slot)
	m.character = first_free_character()
	m.ready = kind == Kind.BOT
	if kind == Kind.KEYBOARD:
		m.keys = _free_key_layout()
	_members[slot] = m
	changed.emit()
	return m


## Removes the member in a slot.
func remove(slot: int) -> void:
	if slot < 0 or slot >= MAX_PLAYERS or _members[slot] == null:
		return
	_members[slot] = null
	changed.emit()


## Empties the room.
func clear() -> void:
	for i in range(MAX_PLAYERS):
		_members[i] = null
	changed.emit()


func at(slot: int) -> Member:
	return _members[slot] if slot >= 0 and slot < MAX_PLAYERS else null


## Members in slot order (no gaps).
func list() -> Array[Member]:
	var out: Array[Member] = []
	for m: Member in _members:
		if m != null:
			out.append(m)
	return out


func count() -> int:
	return list().size()


func is_full() -> bool:
	return _members.find(null) < 0


func by_cid(cid: String) -> Member:
	if cid.is_empty():
		return null
	for m: Member in list():
		if m.cid == cid:
			return m
	return null


func by_client(client: int) -> Member:
	if client == 0:
		return null
	for m: Member in list():
		if m.client == client:
			return m
	return null


## Keyboard member using a layout (null when none).
func by_keys(layout: int) -> Member:
	for m: Member in list():
		if m.kind == Kind.KEYBOARD and m.keys == layout:
			return m
	return null


## Gives a member a runner. False when another member has it or the id is unknown.
func pick(slot: int, character: StringName) -> bool:
	var m: Member = at(slot)
	if m == null or ContentDB.character(character) == null:
		return false
	for other: Member in list():
		if other != m and other.character == character:
			return false
	if m.character != character:
		m.character = character
		changed.emit()
	return true


## Steps a member's runner to the next free one (keyboard: A / D).
func cycle_character(slot: int, direction: int) -> void:
	var m: Member = at(slot)
	if m == null:
		return
	var ids: Array[StringName] = character_ids()
	var i: int = maxi(ids.find(m.character), 0)
	for _step in range(ids.size()):
		i = posmod(i + direction, ids.size())
		if pick(slot, ids[i]):
			return


func set_ready(slot: int, value: bool) -> void:
	var m: Member = at(slot)
	if m != null and m.ready != value:
		m.ready = value
		changed.emit()


## Clears every ready / play-again flag (bots stay ready).
func reset_flags() -> void:
	for m: Member in list():
		m.ready = m.kind == Kind.BOT
		m.again = false
	changed.emit()


## True when there is at least one member and every connected member is ready.
func all_ready() -> bool:
	var any: bool = false
	for m: Member in list():
		if not m.connected():
			continue
		any = true
		if not m.ready:
			return false
	return any


## True when every connected phone pressed "Play again" (and there is at least one phone).
func all_phones_again() -> bool:
	var phones: int = 0
	for m: Member in list():
		if m.kind == Kind.PHONE and m.connected():
			phones += 1
			if not m.again:
				return false
	return phones > 0


## Runners chosen by members.
func taken() -> Array[StringName]:
	var out: Array[StringName] = []
	for m: Member in list():
		if m.character != &"":
			out.append(m.character)
	return out


func first_free_character() -> StringName:
	var used: Array[StringName] = taken()
	for id: StringName in character_ids():
		if not used.has(id):
			return id
	return character_ids()[0]


## Every runner skin; in multiplayer all of them can be picked, bought or not.
static func character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def: CharacterDef in ContentDB.CHARACTERS:
		ids.append(def.id)
	return ids


## A safe display name: trimmed, no control or markup characters, at most NAME_MAX characters;
## empty becomes "Player N".
static func clean_name(raw: String, slot: int) -> String:
	var out: String = ""
	for i in range(raw.length()):
		var ch: String = raw[i]
		var code: int = raw.unicode_at(i)
		if code < 32 or code == 127 or "<>&\"\\[]{}".contains(ch):
			continue
		out += ch
	out = out.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	if out.length() > NAME_MAX:
		out = out.substr(0, NAME_MAX).strip_edges()
	if out.is_empty():
		out = Tr.f(&"party.player_n", {"n": slot + 1})
	return out


func _free_key_layout() -> int:
	for layout in range(KEY_LAYOUTS):
		if by_keys(layout) == null:
			return layout
	return 0

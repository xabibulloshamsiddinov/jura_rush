## One player's part of the split screen: a SubViewport with its own World3D holding a complete
## GameWorld (solo = false, private EventBus), shown by this TextureRect. The viewport renders at the
## strip's real pixel size (not the 1920 x 1080 canvas size), so three views cost about one
## full-screen frame. Also turns the world's events into effects inside its own 3D world and into
## sounds (the single-player VFX / audio routers only hear GameEvents).
class_name PartyView
extends TextureRect

const WORLD_SCENE: PackedScene = preload("res://scenes/game/game_world.tscn")

var viewport: SubViewport = null
var world: GameWorld = null
var bus: EventBus = null
var slot: int = 0

var _seed: int = 0
var _biome: int = 0
var _character: StringName = &""
var _trail: StringName = &""
var _drives_bend: bool = false


## Sets the run up; the world is built when the view enters the tree.
func setup(p_slot: int, run_seed: int, biome: int, character: StringName, trail: StringName,
		drives_bend: bool) -> void:
	slot = p_slot
	_seed = run_seed
	_biome = biome
	_character = character
	_trail = trail
	_drives_bend = drives_bend


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(640, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X if SettingsManager.quality() > 0 else Viewport.MSAA_DISABLED
	viewport.scaling_3d_scale = [0.75, 0.9, 1.0][clampi(SettingsManager.quality(), 0, 2)]
	viewport.audio_listener_enable_3d = false
	add_child(viewport)
	texture = viewport.get_texture()
	bus = EventBus.new()
	bus.name = "Events"
	add_child(bus)
	world = WORLD_SCENE.instantiate() as GameWorld
	world.events = bus
	world.solo = false
	world.party_seed = _seed
	world.party_biome = _biome
	viewport.add_child(world)
	world.track.drives_bend = _drives_bend
	world.player.look_character = _character
	world.player.look_trail = _trail
	world.player.apply_loadout()
	_connect_feedback()
	resized.connect(_fit_viewport)
	get_tree().root.size_changed.connect(_fit_viewport)
	_fit_viewport.call_deferred()


## Gives the world's pooled nodes back (call right before freeing the view).
func dispose() -> void:
	if world != null:
		world.dispose()


## Sends the world to a flow state (menu, loading, countdown, running, revive, game_over).
func set_flow(to: StringName) -> void:
	bus.state_changed.emit(bus.flow, to)


func _fit_viewport() -> void:
	if viewport == null or not is_inside_tree():
		return
	var canvas: Vector2 = get_viewport().get_visible_rect().size
	var window: Vector2 = Vector2(get_tree().root.size)
	var factor: float = window.y / maxf(canvas.y, 1.0)
	var px: Vector2i = Vector2i(maxi(int(size.x * factor), 16), maxi(int(size.y * factor), 16))
	if px != viewport.size:
		viewport.size = px


func _player_pos() -> Vector3:
	return world.player.position if world != null and world.player != null else Vector3.ZERO


## Effects inside this view's 3D world and sounds for the main events.
func _connect_feedback() -> void:
	bus.coin_collected.connect(func(_value: int, pos: Vector3) -> void:
		VFXManager.play(&"coin_pickup", pos, Color.WHITE, world)
		AudioManager.play_coin())
	bus.player_jumped.connect(func() -> void: AudioManager.play(&"jump", 0.08))
	bus.player_rolled.connect(func() -> void: AudioManager.play(&"roll", 0.08))
	bus.player_stumbled.connect(func(_kind: StringName) -> void:
		VFXManager.play(&"sparks", _player_pos() + Vector3(0.0, 1.0, -0.3), Color.WHITE, world)
		AudioManager.play(&"stumble"))
	bus.player_crashed.connect(func(_kind: StringName) -> void:
		var pos: Vector3 = _player_pos() + Vector3(0.0, 1.0, 0.0)
		VFXManager.play(&"crash", pos, Color.WHITE, world)
		VFXManager.play(&"debris", pos, Color.WHITE, world)
		AudioManager.duck(-6.0)
		AudioManager.play(&"crash", 0.0))
	bus.obstacle_smashed.connect(func(pos: Vector3) -> void:
		VFXManager.play(&"debris", pos, Color.WHITE, world)
		AudioManager.play(&"smash"))
	bus.powerup_activated.connect(func(id: StringName, _d: float) -> void:
		var def: PowerupDef = ContentDB.powerup(id)
		var color: Color = def.color if def != null else Color.WHITE
		VFXManager.play(&"burst", _player_pos() + Vector3(0.0, 1.0, 0.0),
				Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.85), world)
		AudioManager.play(&"powerup_start", 0.0))
	bus.powerup_expired.connect(func(_id: StringName) -> void: AudioManager.play(&"powerup_end", 0.0))
	bus.shield_hit.connect(func() -> void: AudioManager.play(&"shield_hit"))
	bus.shield_broken.connect(func() -> void:
		VFXManager.play(&"shards", _player_pos() + Vector3(0.0, 1.0, 0.0), Color.WHITE, world)
		AudioManager.play(&"shield_break"))
	bus.mystery_box_opened.connect(func(_reward: StringName, _amount: int) -> void:
		VFXManager.play(&"burst", _player_pos() + Vector3(0.0, 1.2, -0.5), Color(1.5, 1.05, 0.45, 0.9), world)
		AudioManager.play(&"box_open"))
	bus.moving_train_warning.connect(func(_lane: int) -> void: AudioManager.play(&"train_horn", 0.05))
	bus.near_miss.connect(func(_lane: int) -> void: AudioManager.play(&"near_miss", 0.08))

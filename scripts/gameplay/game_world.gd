## The 3D world and the conductor of one run. Builds every gameplay system as a child node,
## steps them in a fixed order each physics tick, and reacts to flow-state changes. It never
## talks to UI: everything leaves through GameEvents.
##
## Step order while running: director -> track -> player -> collisions -> pickups -> score ->
## biomes -> chaser -> camera.
class_name GameWorld
extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/game/player.tscn")
const CHASER_SCENE: PackedScene = preload("res://scenes/game/chaser.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/game/camera_rig.tscn")
const HEADSTART_SECONDS: float = 5.0
const BOOSTER_BONUS: int = 5

var track: TrackManager = null
var player: Player = null
var chaser: Chaser = null
var camera_rig: CameraRig = null
var director: DifficultyDirector = null
var score: ScoreSystem = null
var missions: MissionSystem = null
var biomes: BiomeDirector = null
var collisions: CollisionSystem = null
var pickups: PickupSystem = null
var sky_coins: SkyCoinTrail = null
var input: InputHandler = null
var bot: BotController = null

var _cfg: GameConfig = GameConfig.current()
var _state: StringName = &"boot"


func _ready() -> void:
	Factories.register_pools(_cfg.active_chunks)
	biomes = BiomeDirector.new()
	add_child(biomes)
	director = DifficultyDirector.new()
	add_child(director)
	track = TrackManager.new()
	track.director = director
	add_child(track)
	biomes.track = track
	player = PLAYER_SCENE.instantiate() as Player
	player.track = track
	add_child(player)
	sky_coins = SkyCoinTrail.new()
	add_child(sky_coins)
	player.sky_coins = sky_coins
	chaser = CHASER_SCENE.instantiate() as Chaser
	add_child(chaser)
	camera_rig = CAMERA_SCENE.instantiate() as CameraRig
	camera_rig.target = player
	add_child(camera_rig)
	collisions = CollisionSystem.new()
	collisions.track = track
	collisions.player = player
	add_child(collisions)
	pickups = PickupSystem.new()
	pickups.track = track
	pickups.player = player
	pickups.sky_coins = sky_coins
	add_child(pickups)
	score = ScoreSystem.new()
	score.track = track
	add_child(score)
	missions = MissionSystem.new()
	add_child(missions)
	input = InputHandler.new()
	input.player = player
	add_child(input)
	bot = BotController.new()
	bot.setup(track, player)
	add_child(bot)
	add_child(TrackDebugDraw.new(track))
	Services.provide(&"world", self)
	track.set_bend_scale(0.3)
	GameEvents.state_changed.connect(_on_state_changed)
	GameEvents.player_crashed.connect(func(_kind: StringName) -> void: track.halt())
	GameEvents.tutorial_finished.connect(func() -> void: track.generator.forced_empty = false)
	GameEvents.item_purchased.connect(func(_id: StringName) -> void: player.apply_loadout())


func _physics_process(delta: float) -> void:
	match _state:
		&"running":
			_step_run(delta)
		&"menu", &"boot":
			track.target_speed = _cfg.menu_scroll_speed
			track.advance(delta)
			player.idle_tick(delta, true)
		&"countdown", &"loading":
			player.idle_tick(delta, false)
		&"revive", &"game_over":
			player.tick(delta)
			chaser.tick(delta)
	camera_rig.tick(delta)


func _step_run(delta: float) -> void:
	director.tick(delta)
	track.target_speed = director.target_speed()
	bot.tick()
	track.advance(delta)
	var step: float = track.world_speed * delta
	player.tick(delta)
	collisions.tick(step)
	pickups.tick(delta, step)
	score.tick(delta)
	biomes.tick(delta)
	chaser.tick(delta)


func _on_state_changed(from: StringName, to: StringName) -> void:
	_state = to
	input.enabled = to == &"running"
	match to:
		&"menu":
			_show_menu_world()
		&"loading":
			_prepare_run()
		&"countdown":
			camera_rig.set_mode(CameraRig.Mode.RUN, 1.0)
			if from == &"revive":
				track.clear_obstacles_between(-60.0, 15.0)
				player.revive()
		&"running":
			if from == &"countdown" and score.run_time <= 0.0:
				_apply_consumables()
		&"revive", &"game_over":
			track.halt()
			camera_rig.set_mode(CameraRig.Mode.DEATH, 0.5)


func _show_menu_world() -> void:
	track.reset(1, true)
	track.set_bend_scale(0.3)
	biomes.reset()
	player.reset()
	player.apply_loadout()
	chaser.hide_now()
	sky_coins.clear()
	camera_rig.set_mode(CameraRig.Mode.MENU, 1.2)


func _prepare_run() -> void:
	director.reset()
	biomes.reset((GameState.run_seed % 4) if GameState.is_daily else 0)
	track.reset(GameState.run_seed, GameState.tutorial_active)
	track.set_bend_scale(1.0)
	player.reset()
	player.apply_loadout()
	chaser.hide_now()
	sky_coins.clear()
	score.reset()
	bot.reset()


## Auto-uses owned consumables at the start of a run: head-start dash and score booster.
func _apply_consumables() -> void:
	if GameState.tutorial_active:
		return
	if SaveSystem.consumable_count(&"headstart") > 0:
		SaveSystem.add_consumable(&"headstart", -1)
		player.powerups.activate_for(&"dash", HEADSTART_SECONDS)
	if SaveSystem.consumable_count(&"booster") > 0:
		SaveSystem.add_consumable(&"booster", -1)
		score.booster_bonus = BOOSTER_BONUS
		GameEvents.multiplier_changed.emit(score.total_multiplier())

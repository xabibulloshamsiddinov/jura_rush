## The 3D world and the conductor of one run. Builds every gameplay system as a child node,
## steps them in a fixed order, and reacts to flow-state changes. It never talks to UI:
## everything leaves through GameEvents.
##
## Frame pacing: everything that moves on screen (treadmill, runner, chaser, pickups, camera)
## advances once per RENDERED frame in _process, split into equal sub-steps of at most 1/60 s
## (the size the gameplay was tuned for). Nothing visible moves on the physics tick, so there is
## no physics-vs-render beat (the old 60 Hz physics loop showed every tick on 60 Hz panels but
## stuttered whenever a frame took 0 or 2 ticks, and always on 90 / 120 Hz displays).
##
## Step order while running: director -> track -> player -> collisions -> pickups -> score ->
## biomes -> chaser; then the camera once per frame. The chaser is stepped here in every flow state
## (it has no clock of its own). Paused: the tree is paused, nothing steps. Hit-stop / crash slow
## motion: Engine.time_scale shrinks the frame delta, so every system slows together. Only
## shader-TIME idle motion (creature neck / tail sway, character hair flutter, foliage wind) keeps
## running through a pause, by design.
##
## Multiplayer: PartyMatch builds one GameWorld per player inside its own SubViewport (own World3D)
## with `solo = false` and a private EventBus. Such a world is driven by the match through its bus
## (state_changed), never touches GameState, the save, missions or services, and its runner takes
## commands from a phone instead of the touch screen.
class_name GameWorld
extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/game/player.tscn")
const CHASER_SCENE: PackedScene = preload("res://scenes/game/chaser.tscn")
const CAMERA_SCENE: PackedScene = preload("res://scenes/game/camera_rig.tscn")
const HEADSTART_SECONDS: float = 5.0
const BOOSTER_BONUS: int = 5
## Largest simulation sub-step (seconds). A 60 fps frame is one step; slower frames are split.
const MAX_STEP: float = 1.0 / 60.0

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
## Event bus of this world. Null = the GameEvents autoload (the single-player world).
var events: EventBus = null
## False for a multiplayer world: no services, missions, consumables, save writes, power-up
## upgrades, touch / keyboard input or biome cycle (see the header).
var solo: bool = true
## Multiplayer run setup, read by _prepare_run when solo is false.
var party_seed: int = 0
var party_biome: int = 0
## Speed of this world's clock. Multiplayer crash slow motion and "phone lost" freezes are per
## world; the single-player game uses Engine.time_scale through GameState instead.
var local_time_scale: float = 1.0

var _cfg: GameConfig = GameConfig.current()
var _state: StringName = &"boot"


func _ready() -> void:
	if events == null:
		events = GameEvents
	else:
		set_meta(EventScope.META, events)
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
	player.powerups.use_upgrades = solo
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
	score.persist = solo
	add_child(score)
	if solo:
		missions = MissionSystem.new()
		add_child(missions)
	input = InputHandler.new()
	input.player = player
	add_child(input)
	bot = BotController.new()
	bot.setup(track, player)
	add_child(bot)
	track.set_bend_scale(0.3)
	events.state_changed.connect(_on_state_changed)
	events.player_crashed.connect(func(_kind: StringName) -> void: track.halt())
	if solo:
		add_child(TrackDebugDraw.new(track))
		Services.provide(&"world", self)
		GameEvents.tutorial_finished.connect(func() -> void: track.generator.forced_empty = false)
		GameEvents.item_purchased.connect(func(_id: StringName) -> void: player.apply_loadout())


func _process(delta: float) -> void:
	if local_time_scale != 1.0:
		if local_time_scale <= 0.0:
			return
		delta *= local_time_scale
	# Equal sub-steps no longer than MAX_STEP (a little slack so 59-61 fps stays one step).
	var steps: int = maxi(1, ceili(delta / MAX_STEP - 0.2))
	var h: float = delta / float(steps)
	for i in range(steps):
		_step(h)
	camera_rig.tick(delta)


func _step(delta: float) -> void:
	match _state:
		&"running":
			_step_run(delta)
		&"menu", &"boot", &"loading":
			# The caveman stands in front of the camera; the world (nearly) stands still and the
			# T-Rex idles behind him (on PLAY: roars and stalks off).
			track.target_speed = _cfg.menu_scroll_speed
			track.advance(delta)
			player.showcase_tick(delta, PlayerVisual.Pose.IDLE)
			chaser.tick(delta)
		&"countdown":
			player.showcase_tick(delta, PlayerVisual.Pose.READY)
			chaser.tick(delta)
		&"revive", &"game_over":
			player.tick(delta)
			chaser.tick(delta)


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
	if solo:
		biomes.tick(delta)
	chaser.tick(delta)


func _on_state_changed(from: StringName, to: StringName) -> void:
	_state = to
	input.enabled = solo and to == &"running"
	match to:
		&"menu":
			_show_menu_world()
		&"loading":
			_prepare_run()
		&"countdown":
			# Swing round behind the runner while he turns to face the track and crouches.
			camera_rig.set_mode(CameraRig.Mode.RUN, CameraRig.START_BLEND if from == &"loading" else 1.0)
			player.visual.set_facing(0.0)
			player.visual.idle_look_yaw = 0.0
			if from == &"revive":
				track.clear_obstacles_between(-60.0, 15.0)
				player.revive()
		&"running":
			# GO: out of the ready crouch into the run cycle.
			player.sync_pose()
			if solo and from == &"countdown" and score.run_time <= 0.0:
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
	# Turned a little toward the camera, glancing at it now and then.
	player.visual.set_facing(CameraRig.MENU_FACING)
	player.visual.idle_look_yaw = CameraRig.MENU_HEAD_YAW
	chaser.hide_now()
	sky_coins.clear()
	camera_rig.set_mode(CameraRig.Mode.MENU, 1.2)


func _prepare_run() -> void:
	director.reset()
	if solo:
		biomes.reset((GameState.run_seed % 4) if GameState.is_daily else 0)
		track.reset(GameState.run_seed, GameState.tutorial_active)
	else:
		biomes.reset(party_biome)
		track.reset(party_seed, false)
	track.set_bend_scale(1.0)
	player.reset()
	player.apply_loadout()
	chaser.hide_now()
	sky_coins.clear()
	score.reset()
	bot.reset()


## Rebuilds the menu backdrop after the multiplayer mode had the screen: track, biome look, fog and
## bend globals (the split-screen worlds overwrote them) and the menu camera.
func restore_menu() -> void:
	_show_menu_world()
	camera_rig.camera.make_current()


## Gives pooled nodes (chunks with their obstacles and pickups, sky eggs, effects) back before a
## multiplayer world is freed, so the pools do not lose them.
func dispose() -> void:
	track.release_all()
	sky_coins.clear()
	VFXManager.release_under(self)


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
		events.multiplier_changed.emit(score.total_multiplier())

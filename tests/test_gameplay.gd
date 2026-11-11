## Tests that need gameplay systems: pattern library, generator solvability over 1,000 seeds,
## command buffering on a real Player, and the full boot -> menu -> run -> crash -> menu loop.
extends TestCase

const SEEDS: int = 1000
const CHUNKS_PER_SEED: int = 8


func test_pattern_library() -> void:
	var cfg: GameConfig = GameConfig.current()
	var library: PatternLibrary = PatternLibrary.new(cfg)
	check(library.size() >= 40, "at least 40 patterns (have %d)" % library.size())
	check(library.errors.is_empty(), "no pattern errors: %s" % ", ".join(library.errors))
	var rest: int = 0
	for def in library.defs:
		if def.is_rest():
			rest += 1
		check(def.max_difficulty >= def.min_difficulty, "%s has a valid difficulty window" % def.id)
	check(rest >= 5, "enough rest patterns")
	var grid: PackedInt32Array = library.grids[library.index_of(&"zigzag_coins")]
	check_eq(Cell.mirror(Cell.mirror(grid, 3), 3), grid, "mirroring twice is the identity")


## Every generated sequence must be survivable from a clean start, checked independently by
## running the validator over the whole concatenated track.
func test_generator_solvable_1000_seeds() -> void:
	var cfg: GameConfig = GameConfig.current()
	var library: PatternLibrary = PatternLibrary.new(cfg)
	var generator: ChunkGenerator = ChunkGenerator.new(cfg, library)
	var checker: SolvabilityValidator = SolvabilityValidator.new(cfg)
	var unsolvable: int = 0
	var rejects: int = 0
	var first_bad: String = ""
	for run_seed in range(SEEDS):
		generator.reset(run_seed)
		var difficulty: float = 1.0 + float(run_seed % 10)
		var speed: float = library.speed_for_difficulty(difficulty)
		var whole: PackedInt32Array = Cell.empty_grid(cfg.rows_per_chunk, cfg.lane_count)
		var ids: PackedStringArray = PackedStringArray()
		for i in range(CHUNKS_PER_SEED):
			var plan: SpawnStrategy.Plan = generator.next_plan(difficulty, speed)
			whole.append_array(plan.grid)
			ids.append(String(plan.id))
		rejects += generator.failures
		var rows: int = cfg.rows_per_chunk * (CHUNKS_PER_SEED + 1)
		if not checker.solve(whole, rows, library.start_sources(), speed):
			unsolvable += 1
			if first_bad.is_empty():
				first_bad = "seed %d difficulty %.0f: %s" % [run_seed, difficulty, " > ".join(ids)]
	check_eq(unsolvable, 0, "all %d seeds solvable (first bad: %s)" % [SEEDS, first_bad])
	print("    generator: %d seeds x %d chunks, %d proposals rejected and replaced" % [SEEDS,
			CHUNKS_PER_SEED, rejects])


func test_random_safe_strategy_is_validated() -> void:
	var cfg: GameConfig = GameConfig.current()
	var library: PatternLibrary = PatternLibrary.new(cfg)
	var generator: ChunkGenerator = ChunkGenerator.new(cfg, library)
	generator.strategy = SpawnStrategy.create(&"random_safe")
	var checker: SolvabilityValidator = SolvabilityValidator.new(cfg)
	var bad: int = 0
	for run_seed in range(100):
		generator.reset(run_seed)
		var whole: PackedInt32Array = Cell.empty_grid(cfg.rows_per_chunk, cfg.lane_count)
		for i in range(6):
			whole.append_array(generator.next_plan(5.0, 24.0).grid)
		if not checker.solve(whole, cfg.rows_per_chunk * 7, library.start_sources(), 24.0):
			bad += 1
	check_eq(bad, 0, "random-safe output is always solvable after validation")


func test_command_buffering() -> void:
	Factories.register_pools(GameConfig.current().active_chunks)
	var track: TrackManager = TrackManager.new()
	tree.root.add_child(track)
	var player: Player = (load("res://scenes/game/player.tscn") as PackedScene).instantiate() as Player
	player.track = track
	tree.root.add_child(player)
	player.reset()
	player.push_command(InputCommand.Lane.new(1))
	check_eq(player.lane, 2, "lane command runs immediately")
	player.push_command(InputCommand.Lane.new(1))
	check_eq(player.lane, 2, "cannot leave the track")
	player.push_command(InputCommand.Roll.new())
	check(player.machine.is_in(Player.ROLL), "roll starts")
	player.push_command(InputCommand.Roll.new())
	check(player.get(&"_buffered") != null, "second roll is buffered while rolling")
	player.push_command(InputCommand.Jump.new())
	check(player.machine.is_in(Player.JUMP), "jump cancels the roll")
	check(player.get(&"_buffered") == null, "executed command clears the buffer")
	player.push_command(InputCommand.Jump.new())
	check(player.get(&"_buffered") != null, "mid-air jump is buffered")
	var landed: bool = false
	for i in range(120):
		player.tick(1.0 / 60.0)
		if player.on_ground:
			landed = true
			break
	check(landed, "player lands after a jump")
	check_near(player.feet_y, 0.0, 0.001, "lands on the rails")
	player.queue_free()
	track.queue_free()
	await tree.process_frame


func test_integration_loop() -> void:
	SaveSystem.path = "user://test_profile.json"
	SaveSystem.data = SaveCodec.defaults()
	SaveSystem.data["tutorial_done"] = true
	VFXManager.prewarm()
	if not PoolManager.has_pool(&"floating_text"):
		PoolManager.register_factory(&"floating_text", func() -> Node: return FloatingText.new(), 4)
	var world: GameWorld = (load("res://scenes/game/game_world.tscn") as PackedScene).instantiate() as GameWorld
	tree.root.add_child(world)
	await tree.process_frame
	GameState.boot_finished()
	check_eq(GameState.current(), GameState.MENU, "boot -> menu")
	check_eq(SceneRouter.current(), &"main_menu", "menu screen shown")
	GameEvents.request_play.emit(false)
	check_eq(GameState.current(), GameState.LOADING, "menu -> loading")
	await _wait_for(GameState.RUNNING, 8.0)
	check_eq(GameState.current(), GameState.RUNNING, "countdown -> running")
	check_eq(SceneRouter.current(), &"hud", "hud shown")
	await tree.create_timer(0.5).timeout
	check(world.track.distance_travelled > 1.0, "the world is moving")
	GameEvents.request_pause.emit()
	check_eq(GameState.current(), GameState.PAUSED, "running -> paused")
	check(tree.paused, "tree paused")
	GameEvents.request_resume.emit()
	await _wait_for(GameState.RUNNING, 6.0)
	check(not tree.paused, "tree resumed")
	world.player.die(&"test")
	await _wait_for(GameState.REVIVE, 4.0)
	check_eq(GameState.current(), GameState.REVIVE, "crash -> revive offer")
	check_near(Engine.time_scale, 1.0, 0.001, "time scale restored after the crash sequence")
	GameEvents.request_revive.emit(&"keys")
	await _wait_for(GameState.RUNNING, 6.0)
	check_eq(GameState.current(), GameState.RUNNING, "revive -> running")
	check(not world.player.is_dead, "player alive after revive")
	check_eq(SaveSystem.keys(), 1, "revive cost one key")
	world.player.die(&"test")
	await _wait_for(GameState.REVIVE, 4.0)
	GameEvents.request_decline_revive.emit()
	check_eq(GameState.current(), GameState.GAME_OVER, "decline -> game over")
	check(GameState.last_result.has("score"), "result recorded")
	check_eq(SceneRouter.current(), &"game_over", "results screen shown")
	GameEvents.request_menu.emit()
	check_eq(GameState.current(), GameState.MENU, "game over -> menu")
	await tree.create_timer(0.3).timeout
	# Open every secondary screen once (all shop tabs, both mission tabs) and go back.
	for tab in range(4):
		SceneRouter.push(&"shop", {"tab": tab})
		await tree.process_frame
		check_eq(SceneRouter.current(), &"shop", "shop tab %d opens" % tab)
		SceneRouter.back()
	for id: StringName in [&"settings", &"missions", &"tutorial"]:
		SceneRouter.push(id)
		await tree.process_frame
		check_eq(SceneRouter.current(), id, "%s opens" % id)
		if id == &"missions":
			SceneRouter.get_screen(id).call(&"_select_tab", 1)
			await tree.process_frame
		SceneRouter.back()
		check_eq(SceneRouter.current(), &"main_menu", "back from %s" % id)
	var buy: PurchaseCommand = PurchaseCommand.new(&"consumable", &"headstart")
	SaveSystem.add_coins(1000)
	check(buy.execute(SaveSystem), "real purchase through SaveSystem succeeds")
	check_eq(SaveSystem.consumable_count(&"headstart"), 1, "consumable granted")
	SettingsManager.set_value("language", "ru")
	await tree.process_frame
	await tree.process_frame
	check_eq(Tr.t(&"menu.play"), "ИГРАТЬ", "language switch applies")
	SettingsManager.set_value("language", "en")
	await tree.process_frame
	world.queue_free()
	await tree.process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("user://test_profile.json" + suffix)


func _wait_for(state: StringName, timeout: float) -> void:
	var waited: float = 0.0
	while GameState.current() != state and waited < timeout:
		await tree.process_frame
		waited += 1.0 / 60.0

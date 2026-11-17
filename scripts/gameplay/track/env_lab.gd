## Dev tool (run with: godot --path . -- --env-lab=<dir>): stages deterministic dioramas of the
## Jura Rush environment on the real track and saves them from the run camera: every biome, a cave
## and a bridge (approach and inside), a gap, each stone obstacle, the torch, eggs in a line and in
## an arc, the pickups, a biome transition and the egg-collect / crash effects. Then it quits.
## Creature / warning dioramas: herds (tail-first, head-first, trikes), herd_cave, herd_climb,
## herd_back and warnings, in the biome style given by --lab-style=N (default Fern Valley); --lab-colorblind
## turns the colour-blind palette on first; --lab-perf prints the average GPU time and draw calls.
## Not used by the game. The world conductor is frozen while it runs; the menu UI is hidden.
class_name EnvLab
extends Node

const EYE: Vector3 = Vector3(0.0, 4.2, 6.5)
const LOOK: Vector3 = Vector3(0.0, 1.3, -7.0)

var _world: GameWorld = null
var _dir: String = ""
var _cfg: GameConfig = GameConfig.current()
## Biome style of the creature scenes (--lab-style=N).
var _creature_style: int = 0
## --lab-perf: average GPU time and draw calls over 90 frames per scene (printed).
var _perf: bool = false


func _init(world: GameWorld, dir: String) -> void:
	_world = world
	_dir = dir
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	await get_tree().create_timer(1.2).timeout
	# GameWorld steps everything (and places the camera) in _process: freeze it.
	_world.set_process(false)
	_hide_ui()
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-only="):
			only = arg.get_slice("=", 1)
		elif arg.begins_with("--lab-style="):
			_creature_style = clampi(int(arg.get_slice("=", 1)), 0, BiomeStyle.COUNT - 1)
		elif arg == "--lab-perf":
			_perf = true
			RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		elif arg == "--lab-colorblind":
			# Automated runs use a throwaway save, so this never touches the real profile.
			SettingsManager.set_value("colorblind", true)
	var scenes: Array[String] = ["biome0", "biome1", "biome2", "biome3", "obstacles", "low", "high",
			"full", "gap", "gap_volcano", "torch", "eggs_line", "eggs_arc", "pickups", "cave_approach",
			"cave_inside", "cave_side", "bridge_approach", "bridge_inside", "transition", "vfx_egg", "vfx_crash", "menu",
			"herds", "herd_cave", "herd_climb", "herd_back", "warnings", "shield", "stampede"]
	for scene: String in scenes:
		if only.is_empty() or only.split(",").has(scene):
			await _stage(scene)
	get_tree().quit()


func _stage(scene: String) -> void:
	var style: int = 0
	if scene.begins_with("biome"):
		style = int(scene.substr(5, 1))
	elif scene == "gap_volcano":
		style = 3
	elif scene == "cave_approach" or scene == "cave_inside":
		style = 0
	elif scene == "bridge_approach" or scene == "bridge_inside":
		style = 1
	elif scene == "torch" or scene == "pickups":
		style = 2
	elif scene.begins_with("herd") or scene == "warnings" or scene == "stampede":
		style = _creature_style
	_world.biomes.reset(style - BiomeDirector.dev_offset)
	_world.track.reset(3, true)
	RenderingServer.global_shader_parameter_set(&"bend_x", 0.0035)
	# Runner height (on a ramp / a back in the herd scenes); the camera rises with it.
	var lift: float = 0.0
	_world.player.shield.deactivate()
	var c1: TrackChunk = _world.track.chunks[1]
	var c2: TrackChunk = _world.track.chunks[2]
	match scene:
		"biome0", "biome1", "biome2", "biome3":
			CoinLayout.line(c1.coins, 0.0, 0.9, -6.0, -18.0, 6)
			_obstacle(c2, &"barrier_low", 2, -8.0)
			_obstacle(c2, &"barrier_full", 0, -14.0)
		"obstacles":
			_obstacle(c1, &"barrier_low", 0, -12.0)
			_obstacle(c1, &"barrier_high", 1, -18.0)
			_obstacle(c1, &"barrier_full", 2, -24.0)
		"low":
			_obstacle(c1, &"barrier_low", 1, -9.0)
		"high":
			_obstacle(c1, &"barrier_high", 1, -9.0)
		"full":
			_obstacle(c1, &"barrier_full", 1, -9.0)
		"gap", "gap_volcano":
			_obstacle(c1, &"gap", 1, -13.0, 6.0)
			_obstacle(c1, &"gap", 0, -22.0, 3.0)
		"torch":
			_obstacle(c1, &"hazard_light", 0, -8.0)
			_obstacle(c1, &"hazard_light", 2, -15.0)
			_obstacle(c1, &"barrier_low", 1, -20.0)
		"eggs_line":
			CoinLayout.line(c1.coins, 0.0, 0.9, -3.0, -24.0, 9)
			CoinLayout.line(c1.coins, 2.0, 0.9, -12.0, -27.0, 6)
		"eggs_arc":
			_obstacle(c1, &"barrier_low", 1, -14.0)
			CoinLayout.arc(c1.coins, 0.0, 0.9, -14.0, 9.0, _cfg.jump_height * 0.8, 5)
			CoinLayout.diagonal(c2.coins, -2.0, 0.0, 0.9, 0.0, -9.0, 3)
		"pickups":
			c1.add_pickup(Factories.Pickups.create_powerup(&"magnet"), Vector3(-2.0, 1.15, -8.0))
			c1.add_pickup(Factories.Pickups.create_box(), Vector3(0.0, 1.15, -11.0))
			c1.add_pickup(Factories.Pickups.create_powerup(&"shield"), Vector3(2.0, 1.15, -14.0))
			c1.add_pickup(Factories.Pickups.create_powerup(&"jetpack"), Vector3(-2.0, 1.15, -20.0))
			c1.add_pickup(Factories.Pickups.create_powerup(&"multiplier"), Vector3(0.0, 1.15, -24.0))
			c1.add_pickup(Factories.Pickups.create_powerup(&"dash"), Vector3(2.0, 1.15, -28.0))
		"cave_approach":
			_feature(2, 4, TrackVisuals.Feature.TUNNEL)
			CoinLayout.line(c1.coins, 0.0, 0.9, -6.0, -24.0, 6)
		"cave_side":
			_feature(1, 2, TrackVisuals.Feature.TUNNEL)
		"cave_inside":
			_feature(0, 3, TrackVisuals.Feature.TUNNEL)
			_obstacle(c1, &"barrier_high", 0, -16.0)
			CoinLayout.line(c1.coins, 0.0, 0.9, -4.0, -20.0, 5)
		"bridge_approach":
			_feature(2, 4, TrackVisuals.Feature.BRIDGE)
			CoinLayout.line(c1.coins, 2.0, 0.9, -6.0, -24.0, 6)
		"bridge_inside":
			_feature(0, 3, TrackVisuals.Feature.BRIDGE)
			_obstacle(c1, &"barrier_low", 2, -16.0)
			CoinLayout.line(c1.coins, 0.0, 0.9, -4.0, -20.0, 5)
		"transition":
			_world.track.decor_set = 3
			for i in range(2, _world.track.chunks.size()):
				var chunk: TrackChunk = _world.track.chunks[i]
				chunk.prev_style = 0 if i == 2 else 3
				chunk.set_decor(3, 77 + i, SettingsManager.decor_density())
		"vfx_egg":
			CoinLayout.line(c1.coins, 0.0, 0.9, -6.0, -18.0, 5)
		"vfx_crash":
			_obstacle(c1, &"barrier_full", 1, -3.0)
		"menu":
			pass
		"herds":
			# Tail-first herd over a ramp (centre), head-first wall (right), trikes (left).
			_herd(c1, 1, -8.0, 6.0, 10.5)
			_herd(c1, 2, -16.0, 0.0, 5.25)
			_obstacle(c2, &"train_moving", 0, -6.0, 9.0)
		"herd_cave":
			# A sauropod standing inside the cave: lit like the cave wall beside it.
			_feature(1, 3, TrackVisuals.Feature.TUNNEL)
			_herd(c2, 0, -10.0, 0.0, 10.5)
			_herd(c1, 2, -4.0, 6.0, 5.25)
		"stampede":
			# Triceratops: telegraphing (pawing, head shakes, snorts) ahead, charging in the right lane.
			_obstacle(c1, &"train_moving", 1, -20.0, 9.0)
			_obstacle(c1, &"train_moving", 2, -9.0, 4.5)
		"shield":
			# The Shell Shield bubble around the runner (eggs ahead for the colour against the path).
			_world.player.shield.activate(1)
			CoinLayout.line(c1.coins, 0.0, 0.9, -4.0, -16.0, 5)
		"warnings":
			# Every warning at once (compare with --lab-colorblind).
			_obstacle(c1, &"barrier_full", 0, -9.0)
			_obstacle(c1, &"barrier_low", 1, -12.0)
			_obstacle(c1, &"gap", 2, -11.0, 4.0)
			_obstacle(c1, &"barrier_high", 1, -22.0)
			_obstacle(c1, &"barrier_full", 2, -25.0)
		"herd_climb":
			# Halfway up a tail-first herd's ramp tail (the runner is 1.5 m up the tail).
			_herd(c1, 1, 3.0, 6.0, 10.5)
			_herd(c1, 2, -12.0, 0.0, 5.25)
			lift = 1.5
		"herd_back":
			# Up on the backs: the camera rides the herd (necks to the side, the next animals).
			_herd(c1, 1, 10.0, 6.0, 21.0)
			_herd(c1, 0, -10.0, 0.0, 10.5)
			lift = 3.0
	_world.player.position.y = lift
	var cam: Camera3D = _world.camera_rig.camera
	cam.fov = _cfg.fov_min
	cam.global_transform = Transform3D(Basis.IDENTITY, EYE).looking_at(LOOK)
	if scene == "menu":
		# CameraRig's menu placement (front three-quarter view, without the slow drift).
		var yaw: float = deg_to_rad(CameraRig.MENU_YAW_DEG)
		var eye: Vector3 = Vector3(sin(yaw) * CameraRig.MENU_DISTANCE, CameraRig.MENU_EYE_HEIGHT,
				cos(yaw) * CameraRig.MENU_DISTANCE)
		cam.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(CameraRig.MENU_LOOK)
		cam.fov = CameraRig.MENU_FOV
	elif lift > 0.0:
		cam.global_transform = Transform3D(Basis.IDENTITY, EYE + Vector3(0.0, lift, 0.0)).looking_at(LOOK + Vector3(0.0, lift, 0.0))
	elif scene == "cave_side":
		# Diagnostic: the cave and its shadow from high up on the left.
		cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(-26.0, 22.0, -10.0)).looking_at(Vector3(0.0, 2.0, -40.0))
		cam.fov = 60.0
	await _frames(4)
	if scene == "stampede":
		# The world is frozen: drive the two herds by hand for a second (telegraph / charge).
		for f in range(60):
			for o: ObstacleBase in c1.obstacles:
				var train: Train = o as Train
				if train == null:
					continue
				for t: Triceratops in train.trikes:
					if t.visible:
						t.ground_drift = Vector3(0.0, 0.0, 16.0)
						t.animate(1.0 / 60.0, Triceratops.Mode.CHARGE if train.lane == 2
								else Triceratops.Mode.TELEGRAPH, 8.0)
			await get_tree().process_frame
	if scene == "vfx_egg":
		for i in range(3):
			VFXManager.play(&"coin_pickup", Vector3(0.0, 1.0, -2.0 - float(i) * 1.2))
		await get_tree().create_timer(0.12).timeout
	elif scene == "vfx_crash":
		VFXManager.crash_burst(Vector3(0.0, 1.0, -1.5))
		await get_tree().create_timer(0.16).timeout
	await _save(scene)


func _obstacle(chunk: TrackChunk, id: StringName, lane: int, z: float, run_length: float = 3.0) -> void:
	var o: ObstacleBase = Factories.Obstacles.create(id, lane, _cfg.lane_x(lane), z, run_length)
	if o != null:
		chunk.add_obstacle(o)


## A Brachiosaurus herd of `run_length` whose near end is at local z `near_z`; ramp_length > 0
## puts a paired ramp in front of it (tail-first), else it stands head-first.
func _herd(chunk: TrackChunk, lane: int, near_z: float, ramp_length: float, run_length: float) -> void:
	var ramp: Ramp = null
	var z: float = near_z
	if ramp_length > 0.0:
		ramp = Factories.Obstacles.create(&"ramp", lane, _cfg.lane_x(lane), z - ramp_length * 0.5, ramp_length) as Ramp
		chunk.add_obstacle(ramp)
		z -= ramp_length
	var train: Train = Factories.Obstacles.create(&"train_long" if run_length > 6.0 else &"train_short",
			lane, _cfg.lane_x(lane), z - run_length * 0.5, run_length) as Train
	chunk.add_obstacle(train)
	if lane == 1:
		train.set_neck_side(-1.0)
	if ramp != null:
		train.set_ramp_lead(ramp.length, ramp.def.size.y)
		ramp.set_paired(true)


func _feature(from: int, to: int, kind: TrackVisuals.Feature) -> void:
	for i in range(from, to + 1):
		_world.track.chunks[i].set_feature(kind, i == from, i == to)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _hide_ui() -> void:
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasLayer and not (node is ScreenFx):
			(node as CanvasLayer).visible = false
		for child: Node in node.get_children():
			stack.append(child)


func _save(scene: String) -> void:
	if _perf:
		var vp: RID = get_viewport().get_viewport_rid()
		var gpu: float = 0.0
		var draws: int = 0
		for i in range(90):
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		print("[env-lab] perf %s: gpu %.2f ms, draws %d" % [scene, gpu / 90.0, draws / 90])
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_dir.path_join(scene + ".png"))
	print("[env-lab] saved ", scene)

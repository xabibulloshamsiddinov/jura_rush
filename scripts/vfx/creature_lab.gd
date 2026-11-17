## Creature lab (run scenes/vfx/creature_lab.tscn): neutral late-morning daylight, a sandy floor
## with the three lanes, a runner for scale, turntables and poses for every creature, and the
## gameplay / menu camera framings.
##
## Keys: 1-6 specimen, Space next pose, Left/Right orbit, Up/Down tilt, +/- zoom,
##       G gameplay camera, M menu camera, O orbit camera, P pause animation.
## Screenshots (needs the real renderer, not --headless):
##   godot --path . --resolution 900x900 res://scenes/vfx/creature_lab.tscn -- --lab-shot=<dir>
##   optional: --lab-only=trex,trike   (specimen filter)
extends Node3D

const SPECIMENS: Array[StringName] = [&"trex", &"brachio_head", &"brachio_tail", &"herd", &"trike", &"rock"]
const POSES: Dictionary = {
	&"trex": [&"idle", &"walk", &"run", &"hunt", &"roar", &"lunge"],
	&"brachio_head": [&"idle"],
	&"brachio_tail": [&"idle"],
	&"herd": [&"idle"],
	&"trike": [&"idle", &"telegraph", &"charge"],
	&"rock": [&"idle"],
}

var camera: Camera3D = null
var specimen: StringName = &"trex"
var pose: StringName = &"idle"
var cam_mode: StringName = &"orbit"
var yaw: float = 35.0
var pitch: float = 14.0
var distance: float = 14.0
var paused: bool = false

var _roots: Dictionary = {}
var _runner: PlayerVisual = null
var _label: Label = null
var _time: float = 0.0
var _rex: TRex = null
var _trike: Node3D = null
var _ghosts: Array[MeshInstance3D] = []
var _show_ghosts: bool = OS.get_cmdline_user_args().has("--lab-ghosts")


func _ready() -> void:
	_setup_world()
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.1
	camera.far = 600.0
	add_child(camera)
	camera.current = true
	_runner = PlayerVisual.new()
	add_child(_runner)
	_label = Label.new()
	_label.position = Vector2(16.0, 12.0)
	_label.add_theme_font_size_override(&"font_size", 22)
	_label.add_theme_color_override(&"font_color", Color(0.1, 0.1, 0.1))
	var layer: CanvasLayer = CanvasLayer.new()
	layer.add_child(_label)
	add_child(layer)
	_show(&"trex")
	var shot_dir: String = ""
	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-shot="):
			shot_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--lab-only="):
			only = arg.get_slice("=", 1).split(",")
	var views_dir: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-views="):
			views_dir = arg.get_slice("=", 1)
	if not shot_dir.is_empty():
		_label.visible = false
		_shoot_all(shot_dir, only)
	elif not views_dir.is_empty():
		_label.visible = false
		_shoot_views(views_dir, only)


func _setup_world() -> void:
	var env: Environment = Environment.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.55, 0.9)
	sky_mat.sky_horizon_color = Color(0.72, 0.84, 0.95)
	sky_mat.ground_horizon_color = Color(0.72, 0.8, 0.86)
	sky_mat.ground_bottom_color = Color(0.5, 0.48, 0.42)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	add_child(sun)
	RenderingServer.global_shader_parameter_set(&"fog_start", 300.0)
	RenderingServer.global_shader_parameter_set(&"fog_end", 500.0)
	RenderingServer.global_shader_parameter_set(&"fog_color", Color(0.72, 0.84, 0.95))
	RenderingServer.global_shader_parameter_set(&"bend_x", 0.0)
	RenderingServer.global_shader_parameter_set(&"bend_y", 0.0)
	var ground: MeshInstance3D = MeshLib.mi(MeshLib.box(), Mats.lit(Color(0.86, 0.78, 0.6)),
			Vector3(0.0, -0.05, -10.0), Vector3(60.0, 0.1, 90.0))
	add_child(ground)
	for x: float in [-3.0, -1.0, 1.0, 3.0]:
		add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color(0.62, 0.5, 0.36)),
				Vector3(x, 0.005, -10.0), Vector3(0.08, 0.01, 90.0)))
	for z in range(-50, 30, 5):
		add_child(MeshLib.mi(MeshLib.box(), Mats.lit(Color(0.7, 0.62, 0.48)),
				Vector3(-4.2, 0.005, float(z)), Vector3(0.6, 0.01, 0.06)))


# --- Specimens ---------------------------------------------------------------------------------

func _build(id: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	match id:
		&"trex":
			_rex = TRex.new()
			root.add_child(_rex)
		&"brachio_head", &"brachio_tail", &"herd", &"rock", &"trike":
			var builder: Callable = Callable(self, &"_build_" + String(id))
			if builder.is_valid():
				builder.call(root)
	return root


func _show(id: StringName) -> void:
	for key: StringName in _roots.keys():
		(_roots[key] as Node3D).visible = false
	if not _roots.has(id):
		var root: Node3D = _build(id)
		add_child(root)
		_roots[id] = root
	(_roots[id] as Node3D).visible = true
	specimen = id
	var poses: Array = POSES[id]
	if not poses.has(pose):
		pose = poses[0]
	_place_runner()


func _place_runner() -> void:
	# Scale reference: the runner stands beside the creature (or in its game position).
	match specimen:
		&"trex":
			_runner.position = Vector3(2.4, 0.0, -6.0)
		&"brachio_head", &"brachio_tail", &"herd":
			_runner.position = Vector3(-2.0, 0.0, 6.0)
		&"trike":
			_runner.position = Vector3(-2.0, 0.0, 4.0)
		_:
			_runner.position = Vector3(-2.0, 0.0, 2.0)
	_runner.rotation.y = 0.0


func _process(delta: float) -> void:
	if not paused:
		_animate(delta)
	_update_camera()
	_label.text = "%s / %s / %s cam   [1-6 specimen, Space pose, G/M/O camera, arrows orbit]" % [
			specimen, pose, cam_mode]


func _animate(delta: float) -> void:
	_time += delta
	_runner.set_pose(PlayerVisual.Pose.IDLE)
	_runner.animate(delta, 9.0, 0.0)
	match specimen:
		&"trex":
			_animate_rex(delta)
		&"trike":
			var trike: Triceratops = _trike as Triceratops
			if trike != null:
				var mode: Triceratops.Mode = Triceratops.Mode.IDLE
				if pose == &"telegraph":
					mode = Triceratops.Mode.TELEGRAPH
				elif pose == &"charge":
					mode = Triceratops.Mode.CHARGE
				trike.animate(delta, mode, 9.0)


func _animate_rex(delta: float) -> void:
	_rex.hunt = 0.0
	_rex.lunge = 0.0
	_rex.auto_snap = false
	match pose:
		&"idle":
			_rex.ground_speed = 0.0
		&"walk":
			_rex.ground_speed = 5.0
		&"run":
			_rex.ground_speed = 16.0
		&"hunt":
			_rex.ground_speed = 16.0
			_rex.hunt = 1.0
			_rex.auto_snap = true
		&"roar":
			_rex.ground_speed = 0.0
			if not _rex.is_roaring():
				_rex.roar()
		&"lunge":
			_rex.ground_speed = 4.0
			_rex.hunt = 1.0
			_rex.lunge = 1.0
	_rex.animate(delta)


func _update_camera() -> void:
	var focus: Vector3 = _focus()
	match cam_mode:
		&"game":
			camera.fov = 65.0
			camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 4.2, 6.5)).looking_at(Vector3(0.0, 1.3, -7.0))
		&"death":
			# CameraRig DEATH mode right after the crash (pull = 0) ...
			camera.fov = 52.0
			camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(CameraRig.DEATH_SIDE, 2.6, 4.2)).looking_at(Vector3(0.0, 1.0, 0.0))
		&"death_far":
			# ... and fully pulled back for the results screen (pull = 1).
			camera.fov = 62.0
			camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(CameraRig.DEATH_SIDE, 4.8, 8.0)).looking_at(Vector3(0.0, 1.0, 0.0))
		&"menu":
			camera.fov = 55.0
			var eye: Vector3 = Vector3(3.4, 2.3, -7.4)
			camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(Vector3(0.0, 1.6, 2.0))
		_:
			camera.fov = 45.0
			var y: float = deg_to_rad(yaw)
			var p: float = deg_to_rad(pitch)
			var eye: Vector3 = focus + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * distance
			camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(focus)


func _focus() -> Vector3:
	match specimen:
		&"trex":
			return Vector3(0.0, 2.6, -0.5)
		&"herd":
			return Vector3(0.0, 2.5, -6.0)
		&"brachio_tail":
			return Vector3(0.0, 2.5, -1.0)
		&"trike":
			return Vector3(0.0, 1.3, 0.0)
	return Vector3(0.0, 2.5, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			var i: int = key.keycode - KEY_1
			if i < SPECIMENS.size():
				_show(SPECIMENS[i])
		KEY_SPACE:
			var poses: Array = POSES[specimen]
			pose = poses[(poses.find(pose) + 1) % poses.size()]
		KEY_LEFT:
			yaw -= 15.0
		KEY_RIGHT:
			yaw += 15.0
		KEY_UP:
			pitch = minf(pitch + 8.0, 85.0)
		KEY_DOWN:
			pitch = maxf(pitch - 8.0, -10.0)
		KEY_EQUAL, KEY_KP_ADD:
			distance = maxf(distance * 0.85, 2.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			distance *= 1.18
		KEY_G:
			cam_mode = &"game"
		KEY_M:
			cam_mode = &"menu"
		KEY_O:
			cam_mode = &"orbit"
		KEY_P:
			paused = not paused


# --- Screenshots -------------------------------------------------------------------------------

func _shoot_all(dir: String, only: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _frames(4)
	for id: StringName in SPECIMENS:
		if not only.is_empty() and not only.has(String(id)):
			continue
		_show(id)
		for p: StringName in POSES[id]:
			pose = p
			cam_mode = &"orbit"
			await _settle(1.2)
			await _sheet(dir.path_join("%s_%s.png" % [id, p]), [[35.0, 12.0], [100.0, 8.0], [215.0, 18.0], [300.0, 35.0]])
	get_tree().quit()


## Gameplay framings (run with a portrait --resolution, e.g. 540x960): the T-Rex placed with the
## Chaser's own constants under the run camera and the death camera.
func _shoot_views(dir: String, only: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _frames(4)
	if only.is_empty() or only.has("trex"):
		_show(&"trex")
		_runner.position = Vector3.ZERO
		_runner.set_pose(PlayerVisual.Pose.RUN)
		_place_rex(&"chase")
		pose = &"hunt"
		cam_mode = &"game"
		for i in range(4):
			await _settle(0.35 + 0.1 * float(i))
			await _single(dir.path_join("rex_chase%d.png" % i))
		_place_rex(&"catch")
		pose = &"lunge"
		await _settle(1.0)
		cam_mode = &"death"
		await _single(dir.path_join("rex_catch_near.png"))
		cam_mode = &"death_far"
		await _single(dir.path_join("rex_catch_far.png"))
		_place_rex(&"menu")
		pose = &"roar"
		cam_mode = &"menu"
		await _settle(0.7)
		await _single(dir.path_join("rex_menu.png"))
		_place_rex(&"origin")
	var extra: Callable = Callable(self, &"_shoot_views_extra")
	if extra.is_valid():
		await extra.call(dir, only)
	get_tree().quit()


## Puts the T-Rex where the Chaser puts it for a state (runner at the origin).
func _place_rex(where: StringName) -> void:
	match where:
		&"chase":
			_rex.position = Vector3(Chaser.CHASE_X, 0.0, Chaser.CHASE_Z)
			_rex.rotation = Vector3(0.0, Chaser.CHASE_YAW, 0.0)
			_rex.scale = Vector3.ONE * Chaser.CHASE_SCALE
		&"catch":
			_rex.position = Vector3(Chaser.CATCH_X, 0.0, Chaser.CATCH_Z)
			_rex.rotation = Vector3(0.0, atan2(Chaser.CATCH_X, Chaser.CATCH_Z), 0.0)
			_rex.scale = Vector3.ONE * Chaser.CATCH_SCALE
		&"menu":
			_rex.position = Chaser.MENU_POS
			_rex.rotation = Vector3.ZERO
			_rex.scale = Vector3.ONE * Chaser.MENU_SCALE
		_:
			_rex.position = Vector3.ZERO
			_rex.rotation = Vector3.ZERO
			_rex.scale = Vector3.ONE


## Lets the animation run for `seconds` of simulated time (fixed steps).
func _settle(seconds: float) -> void:
	paused = true
	var steps: int = int(seconds * 60.0)
	for i in range(steps):
		_animate(1.0 / 60.0)
	await _frames(2)


## Saves a 2 x 2 contact sheet of orbit views [yaw, pitch].
func _sheet(path: String, views: Array) -> void:
	var images: Array[Image] = []
	for view: Array in views:
		yaw = float(view[0])
		pitch = float(view[1])
		_update_camera()
		await _frames(3)
		images.append(get_viewport().get_texture().get_image())
	var w: int = images[0].get_width()
	var h: int = images[0].get_height()
	var sheet: Image = Image.create(w * 2, h * 2, false, images[0].get_format())
	for i in range(images.size()):
		sheet.blit_rect(images[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i >> 1) * h))
	sheet.save_png(path)


## Saves the current camera view.
func _single(path: String) -> void:
	_update_camera()
	await _frames(3)
	get_viewport().get_texture().get_image().save_png(path)


func _frames(n: int) -> void:
	for i in range(n):
		await RenderingServer.frame_post_draw


# --- Brachiosaurus / rock specimens ------------------------------------------------------------

func _build_brachio_head(root: Node3D) -> void:
	_herd(root, 0.0, 5.25, 0.0, 0.0, 1.0)


func _build_brachio_tail(root: Node3D) -> void:
	_herd(root, 0.0, 5.25, 6.0, 0.0, 1.0)


func _build_herd(root: Node3D) -> void:
	_herd(root, -2.0, 18.0, 6.0, -1.0, 1.0, -6.0)
	_herd(root, 0.0, 3.0, 0.0, 0.0, 1.0, -3.0)
	_herd(root, 2.0, 12.0, 0.0, 1.0, 1.0, -8.0)


func _build_rock(root: Node3D) -> void:
	var rock: MeshInstance3D = MeshInstance3D.new()
	rock.mesh = RockSlope.mesh(6.0, 3.0)
	rock.material_override = CreatureMats.skin(&"rock")
	root.add_child(rock)
	root.add_child(_ghost(Vector3(0.0, 1.5, 0.0), Vector3(1.7, 3.0, 6.0)))


## A herd over a run of `length` centred at z_center in lane x; ramp > 0 = tail-first.
func _herd(root: Node3D, x: float, length: float, ramp: float, outward: float, middle: float,
		z_center: float = 0.0) -> void:
	var herd: Brachiosaurus = Brachiosaurus.new()
	herd.position = Vector3(x, 0.0, z_center)
	herd.layout(length, ramp, 3.0, outward, middle, absf(x) + length)
	root.add_child(herd)
	root.add_child(_ghost(Vector3(x, 1.5, z_center), Vector3(1.7, 3.0, length)))
	if ramp > 0.0:
		root.add_child(_ghost(Vector3(x, 0.75, z_center + (length + ramp) * 0.5), Vector3(1.7, 1.5, ramp)))


## Translucent collision-box reference.
func _ghost(center: Vector3, size: Vector3) -> MeshInstance3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.0 if not _show_ghosts else 0.12)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box: MeshInstance3D = MeshLib.mi(MeshLib.box(), mat, center, size)
	_ghosts.append(box)
	return box


func _build_trike(root: Node3D) -> void:
	_trike = Triceratops.new()
	root.add_child(_trike)

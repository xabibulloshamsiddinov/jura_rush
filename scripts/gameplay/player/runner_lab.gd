## Dev lab for the caveman and the pterosaur under neutral daylight (independent of the world's
## lighting). Run: godot --path . res://scenes/vfx/runner_lab.tscn -- --lab-shots=<dir>
## Saves skin line-ups (front and back), face close-ups, a pose sheet, idle actions and the
## pterosaur ride, prints triangle budgets, then quits. Without the flag it shows a turntable.
extends Node3D

var _camera: Camera3D = null
var _visuals: Array[PlayerVisual] = []
var _dir: String = ""


func _ready() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.58, 0.76, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	ground.mesh = plane
	var gmat: StandardMaterial3D = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.52, 0.37, 0.24)
	ground.material_override = gmat
	add_child(ground)
	_camera = Camera3D.new()
	_camera.current = true
	add_child(_camera)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-shots="):
			_dir = arg.get_slice("=", 1)
	if _dir.is_empty():
		_lineup(ContentDB.CHARACTERS.size())
		_camera.look_at_from_position(Vector3(2.0, 1.6, -7.5), Vector3(0.0, 0.9, 0.0))
		return
	_run_shots()


func _process(delta: float) -> void:
	if not _dir.is_empty():
		return
	for v: PlayerVisual in _visuals:
		v.rotation.y += delta * 0.5
		v.animate(delta, 11.5, 0.0)


func _clear() -> void:
	for v: PlayerVisual in _visuals:
		v.queue_free()
	_visuals.clear()


func _lineup(count: int, spacing: float = 1.25) -> void:
	_clear()
	for i in range(count):
		var v: PlayerVisual = PlayerVisual.new()
		add_child(v)
		v.position = Vector3((float(i) - float(count - 1) * 0.5) * spacing, 0.0, 0.0)
		v.apply_character(ContentDB.CHARACTERS[i % ContentDB.CHARACTERS.size()])
		_visuals.append(v)


func _step(v: PlayerVisual, seconds: float, cadence: float = 11.5, lean: float = 0.0) -> void:
	var n: int = int(seconds * 60.0)
	for i in range(n):
		v.animate(1.0 / 60.0, cadence, lean)


func _run_shots() -> void:
	print("caveman triangles:")
	var total: int = 0
	for part: String in ["head", "lids", "beard", "chest", "hips", "skirt", "thigh", "thigh", "shin", "shin",
			"foot_l", "foot_r", "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "hair_cap_mop", "hair_locks_mop"]:
		var n: int = CavemanModel.triangles(StringName(part))
		total += n
		print("  %-16s %d" % [part, n])
	print("  body total %d" % total)
	for style: String in ["mop", "flame", "long", "short"]:
		print("  hair %-6s cap %d locks %d" % [style, CavemanModel.triangles(StringName("hair_cap_" + style)),
				CavemanModel.triangles(StringName("hair_locks_" + style))])
	for kind: StringName in [&"cap", &"visor", &"antenna", &"backpack", &"scarf"]:
		var acc: int = 0
		for part: Array in CavemanModel.accessory_parts(kind):
			acc += CavemanModel.triangles(part[0])
		print("  accessory %-8s %d" % [kind, acc])
	print("  pterosaur %d" % PterosaurRide.triangles())
	await get_tree().process_frame
	# 1. Skins front 3/4 and back.
	_lineup(6)
	for v: PlayerVisual in _visuals:
		_step(v, 0.6)
	_camera.fov = 40.0
	_camera.look_at_from_position(Vector3(1.6, 1.5, -8.6), Vector3(0.0, 0.95, 0.0))
	await _save("skins_front")
	_camera.look_at_from_position(Vector3(-1.2, 3.6, 8.5), Vector3(0.0, 0.8, 0.0))
	await _save("skins_back")
	# Turntable: every skin at four angles, seen from a slightly raised front camera.
	_camera.fov = 36.0
	_camera.look_at_from_position(Vector3(0.0, 1.7, -9.5), Vector3(0.0, 0.95, 0.0))
	for a: int in [0, 1, 2, 3]:
		for v: PlayerVisual in _visuals:
			v.rotation.y = deg_to_rad(35.0 + 90.0 * float(a))
		await _save("turntable_%d" % a)
	for v: PlayerVisual in _visuals:
		v.rotation.y = 0.0
	# 2. Faces.
	_lineup(3, 0.9)
	for i in range(3):
		_visuals[i].apply_character(ContentDB.CHARACTERS[[0, 1, 4][i]])
		_step(_visuals[i], 0.3)
	_camera.fov = 30.0
	_camera.look_at_from_position(Vector3(0.7, 1.75, -3.6), Vector3(0.0, 1.45, 0.0))
	await _save("faces")
	_lineup(3, 0.9)
	for i in range(3):
		_visuals[i].apply_character(ContentDB.CHARACTERS[[2, 3, 5][i]])
		_step(_visuals[i], 0.3)
	await _save("faces2")
	# 3. Pose sheet (side view and back view).
	var poses: Array = [[PlayerVisual.Pose.RUN, 0.25, 0.0], [PlayerVisual.Pose.RUN, 0.38, 0.0],
			[PlayerVisual.Pose.RUN, 0.25, 0.25], [PlayerVisual.Pose.READY, 0.6, 0.0],
			[PlayerVisual.Pose.JUMP, 0.05, 11.0], [PlayerVisual.Pose.JUMP, 0.2, 1.0],
			[PlayerVisual.Pose.FALL, 0.2, -10.0], [PlayerVisual.Pose.ROLL, 0.12, 0.0],
			[PlayerVisual.Pose.ROLL, 0.25, 0.0], [PlayerVisual.Pose.ROLL, 0.38, 0.0],
			[PlayerVisual.Pose.STUMBLE, 0.12, 0.0], [PlayerVisual.Pose.DEAD, 1.0, 0.0]]
	_lineup(poses.size(), 1.15)
	for i in range(poses.size()):
		var v: PlayerVisual = _visuals[i]
		v.apply_character(ContentDB.CHARACTERS[0])
		v.set_pose(PlayerVisual.Pose.RUN)
		_step(v, 0.5)
		v.vertical_speed = poses[i][2]
		v.set_pose(poses[i][0], 0.5)
		if poses[i][0] == PlayerVisual.Pose.RUN:
			_step(v, poses[i][1], 15.0, poses[i][2])
		else:
			_step(v, poses[i][1])
	_camera.fov = 34.0
	_camera.look_at_from_position(Vector3(0.0, 4.2, 14.0), Vector3(0.0, 0.9, 0.0))
	await _save("poses_back")
	# Side views: six poses per shot, lined up along Z, seen from +X.
	for half in range(2):
		for i in range(_visuals.size()):
			var k: int = i - half * 6
			_visuals[i].visible = k >= 0 and k < 6
			_visuals[i].position = Vector3(0.0, 0.0, (float(k) - 2.5) * 1.5)
		_camera.fov = 30.0
		_camera.look_at_from_position(Vector3(11.0, 1.3, 0.0), Vector3(0.0, 0.9, 0.0))
		await _save("poses_side%d" % half)
	# 4. Idle actions.
	_lineup(5, 1.4)
	for i in range(5):
		_visuals[i].apply_character(ContentDB.CHARACTERS[i])
		_step(_visuals[i], 0.2)
		_visuals[i].play_idle_action(i + 1, 0.0)
		_step(_visuals[i], 1.1)
	_camera.fov = 40.0
	_camera.look_at_from_position(Vector3(1.2, 1.5, -8.0), Vector3(0.0, 1.0, 0.0))
	await _save("idle_actions")
	# 5. Pterosaur ride: back (run camera) and side.
	_lineup(1)
	var rider: PlayerVisual = _visuals[0]
	rider.position.y = 0.6
	rider.set_pose(PlayerVisual.Pose.RUN)
	_step(rider, 0.3)
	rider.set_pose(PlayerVisual.Pose.FLY)
	_step(rider, 0.9)
	_camera.fov = 66.0
	_camera.look_at_from_position(Vector3(0.0, 4.2 + 0.6 * 0.75, 6.5), Vector3(0.0, 1.3 + 0.6 * 0.85, -7.0))
	await _save("ptero_back")
	_camera.fov = 40.0
	_camera.look_at_from_position(Vector3(5.0, 2.4, -4.5), Vector3(0.0, 1.8, 0.0))
	await _save("ptero_side")
	_step(rider, 0.1)
	await _save("ptero_side2")
	get_tree().quit()


func _save(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = _dir.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)

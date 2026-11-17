## Creature re-theme checks: the ramp -> tail-first / otherwise head-first orientation rule, herd
## splitting, that the visuals tell the truth about the walkable surfaces (sauropod backs, the
## ramp tail, the rock slope), triangle budgets, the unchanged moving-train behaviour and the
## T-Rex chaser state flow.
extends TestCase


func _grid(rows: Array[String]) -> PackedInt32Array:
	return Cell.parse_rows(PackedStringArray(rows), 3)


func test_orientation_rule() -> void:
	var roof_run: PackedInt32Array = _grid(["...", ".R.", ".R.", ".t.", ".t.", ".t.", ".t.", "...", ".c.", "..."])
	check(ChunkBuilder.ramp_leads_train(roof_run, 3, 3, 1), "a ramp in front of the run -> tail-first")
	check(not ChunkBuilder.ramp_leads_train(roof_run, 3, 4, 1), "only the run start counts")
	var side: PackedInt32Array = _grid(["...", "T..", "T..", "T..", "T..", ".c.", ".c.", "...", "...", "..."])
	check(not ChunkBuilder.ramp_leads_train(side, 3, 1, 0), "no ramp -> head-first")
	var other_lane: PackedInt32Array = _grid(["...", ".R.", ".R.", "tt.", "tt.", "...", "...", "...", "...", "..."])
	check(not ChunkBuilder.ramp_leads_train(other_lane, 3, 3, 0), "a ramp in another lane does not count")
	check(ChunkBuilder.ramp_leads_train(other_lane, 3, 3, 1), "the ramp lane itself is tail-first")
	var moving: PackedInt32Array = _grid(["...", "R..", "M..", "M..", "M..", "...", "...", "...", "...", "..."])
	check(not ChunkBuilder.ramp_leads_train(moving, 3, 2, 0), "moving trains never pair with a ramp")
	# Middle-lane necks curl toward the side without a roof next to them.
	var free_right: PackedInt32Array = _grid(["...", "TT.", "TTc", "TTc", "TTc", "...", "...", "...", "...", "..."])
	check_eq(ChunkBuilder.middle_neck_side(free_right, 3, 1, 4), 1.0, "necks go right, away from the left roof")
	check_eq(ChunkBuilder.middle_neck_side(Cell.mirror(free_right, 3), 3, 1, 4), -1.0, "mirrored -> left")


func test_herd_plan() -> void:
	var tail_first: Array[Brachiosaurus.Animal] = Brachiosaurus.plan(18.0, true, -1.0, 0.0)
	check_eq(tail_first.size(), 3, "18 m run -> 3 animals")
	check_eq(tail_first[0].tail, &"ramp", "nearest animal's tail is the ramp")
	var covered: float = 0.0
	for i in range(tail_first.size()):
		var a: Brachiosaurus.Animal = tail_first[i]
		covered += a.length
		check(not a.faces_runner, "tail-first: heads point away (%d)" % i)
		check_eq(a.neck, &"side", "tail-first: necks curl to the side (%d)" % i)
		check_eq(a.neck_side, -1.0, "left lane necks go left (%d)" % i)
		if i > 0:
			check_eq(a.tail_side, 1.0, "joint tails curl down the inner flank (%d)" % i)
			check_near(tail_first[i - 1].z - a.z, a.length, 0.001, "animals stand end to end (%d)" % i)
	check_near(covered, 18.0, 0.001, "the herd covers the whole run")
	var head_first: Array[Brachiosaurus.Animal] = Brachiosaurus.plan(12.0, false, 1.0, 0.0)
	check_eq(head_first.size(), 2, "12 m run -> 2 animals")
	check(head_first[0].faces_runner and head_first[1].faces_runner, "head-first: all face the runner")
	check_eq(head_first[0].neck, &"front", "the nearest animal is the wall, looking at the runner")
	check_eq(head_first[1].neck, &"side", "necks further back curl away from the backs")
	check_eq(head_first[1].tail, &"curl", "no ramp tail without a ramp")
	check_eq(Brachiosaurus.plan(3.0, false, 0.0, -1.0).size(), 1, "a short run is one animal")


func test_builder_pairs_ramp_and_herd() -> void:
	var cfg: GameConfig = GameConfig.current()
	Factories.register_pools(cfg.active_chunks)
	var builder: ChunkBuilder = ChunkBuilder.new(cfg)
	var chunk: TrackChunk = Factories.Chunks.create()
	var plan: SpawnStrategy.Plan = SpawnStrategy.Plan.new()
	plan.grid = _grid(["...", "R..", "R..", "tT.", "tT.", "tT.", "tT.", "...", "...", "..."])
	builder.begin(chunk, plan, 14.0).add_obstacles()
	var ramps: int = 0
	var tail_first: int = 0
	var head_first: int = 0
	for o: ObstacleBase in chunk.obstacles:
		if o is Ramp:
			ramps += 1
			check((o as Ramp).paired, "the ramp is drawn by the herd's tail")
			check_near(o.ground_height_at(o.length * 0.5), 0.0, 0.001, "ramp still starts at the ground")
			check_near(o.ground_height_at(-o.length * 0.5), 3.0, 0.001, "ramp still reaches the roof")
		elif o is Train:
			var train: Train = o as Train
			check_near(train.half_width, 0.85, 0.001, "collision width unchanged")
			check_near(train.y_max, 3.0, 0.001, "walkable top unchanged")
			check_eq(train.def.hit_type, ObstacleDef.HitType.LETHAL, "frontal hit still lethal")
			check_eq(train.def.side_hit_type, ObstacleDef.HitType.STUMBLE, "side hit still a stumble")
			# Necks / tails drawn past the box keep the herd visible until they are passed too.
			check(train.far_overhang > 0.5 and train.far_overhang < 2.0,
					"herd hide margin covers the parts beyond the box (%.2f m)" % train.far_overhang)
			print("    herd hide margin (%s): %.2f m" % ["tail-first" if train.is_tail_first() else "head-first",
					train.far_overhang])
			if train.lane == 0:
				check(train.is_tail_first(), "ramp lane herd is tail-first")
				tail_first += 1
			else:
				check(not train.is_tail_first(), "middle herd without ramp is head-first")
				head_first += 1
	check_eq([ramps, tail_first, head_first], [1, 1, 1], "one ramp, one tail-first and one head-first herd")
	chunk.clear()
	# Lone ramp: rock slope.
	plan.grid = _grid(["...", "R..", "R..", "...", "...", "...", "...", "...", "...", "..."])
	builder.begin(chunk, plan, 14.0).add_obstacles()
	for o: ObstacleBase in chunk.obstacles:
		if o is Ramp:
			check(not (o as Ramp).paired, "a ramp without a herd stays a rock slope")
	chunk.clear()
	Factories.Chunks.recycle(chunk)


## The back is the collision top along the whole walkable length; side necks leave the space
## above the back free; the ramp tail follows the ramp incline.
func test_walkable_profiles_are_truthful() -> void:
	for short: bool in [true, false]:
		var length: float = Brachiosaurus.SHORT_LEN if short else Brachiosaurus.STD_LEN
		var h: float = length * 0.5
		var worst: float = _top_deviation(_verts(Brachiosaurus.torso_mesh(short)), 0.3, -h, h,
				func(_z: float) -> float: return 3.0)
		check(worst <= 0.1, "%s back stays at 3.0 +- 0.1 over the box (worst %.3f)" % ["short" if short else "long", worst])
	var neck: PackedVector3Array = _verts(Brachiosaurus.neck_mesh(&"side"))
	var blocked: int = 0
	for v: Vector3 in neck:
		if v.y > 3.05 and v.y < 4.8 and absf(v.x) < 0.4:
			blocked += 1
	check_eq(blocked, 0, "side necks never block the space above the back")
	var ramp_len: float = 6.0
	var tail_worst: float = _top_deviation(_verts(Brachiosaurus.ramp_tail_mesh(ramp_len, 3.0)), 0.1,
			0.3, ramp_len - 0.2, func(z: float) -> float: return 3.0 * (1.0 - z / ramp_len))
	check(tail_worst <= 0.1, "the ramp tail follows the ramp incline (worst %.3f)" % tail_worst)
	var rock_worst: float = _top_deviation(_verts(RockSlope.mesh(ramp_len, 3.0)), 0.1, -1.8, 2.6,
			func(z: float) -> float: return 3.0 * (ramp_len * 0.5 - z) / ramp_len)
	check(rock_worst <= 0.12, "the rock slope follows the ramp incline (worst %.3f)" % rock_worst)


func test_triangle_budgets() -> void:
	var rex: int = OrganicMesh.mesh_triangles(TRex.mesh())
	check(rex <= 8000, "T-Rex <= 8k triangles (%d)" % rex)
	var torso: int = OrganicMesh.mesh_triangles(Brachiosaurus.torso_mesh(false))
	var neck: int = maxi(OrganicMesh.mesh_triangles(Brachiosaurus.neck_mesh(&"side")),
			OrganicMesh.mesh_triangles(Brachiosaurus.neck_mesh(&"front")))
	var tail: int = maxi(OrganicMesh.mesh_triangles(Brachiosaurus.ramp_tail_mesh(6.0, 3.0)),
			OrganicMesh.mesh_triangles(Brachiosaurus.curl_tail_mesh()))
	check(torso + neck + tail <= 6000, "Brachiosaurus <= 6k triangles (%d)" % (torso + neck + tail))
	var trike: int = OrganicMesh.mesh_triangles(Triceratops.mesh())
	check(trike <= 5000, "Triceratops <= 5k triangles (%d)" % trike)
	print("    triangles: T-Rex %d, Brachiosaurus %d (torso %d, neck %d, tail %d), Triceratops %d" % [
			rex, torso + neck + tail, torso, neck, tail, trike])
	check(TRex.mesh() == TRex.mesh() and Triceratops.mesh() == Triceratops.mesh(), "meshes are built once and shared")


## Moving trains keep their telegraph distance, activation distance and speed.
func test_stampede_keeps_moving_train_rules() -> void:
	var cfg: GameConfig = GameConfig.current()
	Factories.register_pools(cfg.active_chunks)
	var train: Train = Factories.Obstacles.create(&"train_moving", 1, 0.0, -100.0, 9.0) as Train
	check(train.needs_tick, "moving trains tick")
	check_eq(train.trikes.filter(func(t: Triceratops) -> bool: return t.visible).size(), 2, "9 m -> 2 triceratops")
	var warned: Array[int] = []
	var on_warn: Callable = func(lane: int) -> void: warned.append(lane)
	GameEvents.moving_train_warning.connect(on_warn)
	train.tick(1.0 / 60.0, 20.0, 0.0)
	check(warned.is_empty(), "no warning while far away")
	var front: float = -(cfg.moving_train_activation + 35.0) + 1.0
	train.position.z = front - train.length * 0.5
	train.tick(1.0 / 60.0, 20.0, 0.0)
	check_eq(warned, [1], "telegraph at the old distance")
	var z0: float = train.position.z
	train.tick(0.5, 20.0, 0.0)
	check_near(train.position.z, z0, 0.0001, "telegraphing animals hold position")
	train.position.z = -cfg.moving_train_activation + 1.0 - train.length * 0.5
	z0 = train.position.z
	train.tick(0.5, 20.0, 0.0)
	check_near(train.position.z - z0, 20.0 * cfg.moving_train_speed_factor * 0.5, 0.001, "charge speed unchanged")
	GameEvents.moving_train_warning.disconnect(on_warn)
	PoolManager.release(&"train_moving", train)


func test_chaser_flow() -> void:
	var chaser: Chaser = (load("res://scenes/game/chaser.tscn") as PackedScene).instantiate() as Chaser
	tree.root.add_child(chaser)
	chaser.call(&"_on_flow_changed", &"boot", &"menu")
	check(chaser.machine.is_in(Chaser.MENU), "menu: the T-Rex idles behind the runner")
	check(chaser.visible, "visible in the menu")
	check_near(chaser.position.z, Chaser.MENU_POS.z, 0.001, "menu spot")
	chaser.call(&"_on_flow_changed", &"menu", &"loading")
	check(chaser.machine.is_in(Chaser.RETREAT), "run start: roar and retreat")
	for i in range(240):
		chaser.tick(1.0 / 60.0)
	check(chaser.machine.is_in(Chaser.HIDDEN), "retreated out of view")
	check(not chaser.visible, "hidden after the retreat")
	chaser.call(&"_on_flow_changed", &"countdown", &"running")
	# Handlers are called directly: global player events would also reach VFX / audio services.
	chaser.call(&"_on_player_stumbled", &"test")
	check(chaser.machine.is_in(Chaser.CHASE), "stumble -> chase")
	for i in range(int((GameConfig.current().stumble_window + 0.5) * 60.0)):
		chaser.tick(1.0 / 60.0)
	check(chaser.machine.is_in(Chaser.HIDDEN), "chase window elapsed -> hidden")
	chaser.call(&"_on_player_crashed", &"barrier")
	check(chaser.machine.is_in(Chaser.CATCH), "crash -> catch")
	chaser.hide_now()
	check(chaser.machine.is_in(Chaser.HIDDEN) or chaser.machine.is_in(Chaser.MENU), "hide_now resets")
	chaser.queue_free()
	await tree.process_frame


## Menu -> run start, replayed with the real Chaser and CameraRig on the real flow timing
## (Loading, then the START_BLEND swing at the countdown): the camera never comes near the T-Rex's
## skinned surface, and once the run camera is in place no part of the T-Rex is in its view.
func test_run_start_swing_clears_trex() -> void:
	var runner: Node3D = Node3D.new()
	tree.root.add_child(runner)
	var rig: CameraRig = _rig(runner)
	var chaser: Chaser = _chaser()
	chaser.call(&"_on_flow_changed", &"boot", &"menu")
	var dt: float = 1.0 / 60.0
	for i in range(60):
		rig.tick(dt)
		chaser.tick(dt)
	var loading: float = 0.55
	var swing_end: float = loading + CameraRig.START_BLEND
	var closest: float = 1e9
	var seen_after_swing: int = 0
	chaser.call(&"_on_flow_changed", &"menu", &"loading")
	var t: float = 0.0
	while t < loading + 2.25 and chaser.visible:
		if t >= loading and rig.mode != CameraRig.Mode.RUN:
			rig.set_mode(CameraRig.Mode.RUN, CameraRig.START_BLEND)
		rig.tick(dt)
		chaser.tick(dt)
		t += dt
		if not chaser.visible:
			break
		var probe: Vector2 = _rex_probe(chaser, rig.camera)
		closest = minf(closest, probe.x)
		if t > swing_end:
			seen_after_swing += int(probe.y)
	print("    run-start swing: closest T-Rex surface %.2f m, T-Rex vertices in the run view after it: %d" % [
			closest, seen_after_swing])
	check(closest > 2.4, "the swing keeps clear of the T-Rex (it never even starts its near dissolve)")
	check(seen_after_swing == 0, "the retreating T-Rex is out of the run view once the swing ends")
	for n: Node in [runner, rig, chaser]:
		n.queue_free()
	await tree.process_frame


## Crash with the T-Rex on the runner's heels (CHASE) and out of sight (HIDDEN): while the run camera
## blends into the death camera the lunging T-Rex never crosses the camera's path.
func test_catch_keeps_clear_of_death_camera() -> void:
	for from_chase: bool in [true, false]:
		var runner: Node3D = Node3D.new()
		tree.root.add_child(runner)
		var rig: CameraRig = _rig(runner)
		rig.set_mode(CameraRig.Mode.RUN, 0.0)
		var chaser: Chaser = _chaser()
		chaser.call(&"_on_flow_changed", &"countdown", &"running")
		var dt: float = 1.0 / 60.0
		if from_chase:
			chaser.call(&"_on_player_stumbled", &"test")
		for i in range(60):
			rig.tick(dt)
			chaser.tick(dt)
		chaser.call(&"_on_player_crashed", &"barrier")
		rig.set_mode(CameraRig.Mode.DEATH, 0.5)
		var closest: float = 1e9
		for i in range(150):
			rig.tick(dt)
			chaser.tick(dt)
			closest = minf(closest, _rex_probe(chaser, rig.camera).x)
		var label: String = "from the chase" if from_chase else "from hiding"
		print("    catch %s: closest T-Rex surface to the camera %.2f m" % [label, closest])
		check(closest > 1.6, "catch %s: the death camera never dives into the T-Rex" % label)
		for n: Node in [runner, rig, chaser]:
			n.queue_free()
		await tree.process_frame


func _rig(target: Node3D) -> CameraRig:
	var rig: CameraRig = (load("res://scenes/game/camera_rig.tscn") as PackedScene).instantiate() as CameraRig
	rig.target = target
	tree.root.add_child(rig)
	return rig


func _chaser() -> Chaser:
	var chaser: Chaser = (load("res://scenes/game/chaser.tscn") as PackedScene).instantiate() as Chaser
	tree.root.add_child(chaser)
	return chaser


## The T-Rex's skinned surface (every 2nd vertex, posed like the GPU skins it) against a camera:
## x = closest distance to the camera (m), y = vertices inside a 9:16 portrait view.
func _rex_probe(chaser: Chaser, camera: Camera3D) -> Vector2:
	var rex: TRex = chaser.rex
	var arrays: Array = rex.mesh_instance.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skin: Skin = rex.mesh_instance.skin
	var mats: Array[Transform3D] = []
	for b in range(skin.get_bind_count()):
		mats.append(rex.skeleton.global_transform * rex.skeleton.get_bone_global_pose(skin.get_bind_bone(b))
				* skin.get_bind_pose(b))
	var cam: Transform3D = camera.global_transform
	var to_view: Transform3D = cam.affine_inverse()
	var tan_v: float = tan(deg_to_rad(camera.fov * 0.5))
	var tan_h: float = tan_v * 9.0 / 16.0
	var closest: float = 1e9
	var seen: int = 0
	for v in range(0, verts.size(), 2):
		var p: Vector3 = Vector3.ZERO
		for k in range(4):
			var w: float = weights[v * 4 + k]
			if w > 0.0:
				p += (mats[bones[v * 4 + k]] * verts[v]) * w
		closest = minf(closest, p.distance_to(cam.origin))
		var q: Vector3 = to_view * p
		if q.z < -camera.near and absf(q.x) < -q.z * tan_h and absf(q.y) < -q.z * tan_v:
			seen += 1
	return Vector2(closest, float(seen))


func _verts(mesh: Mesh) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for s in range(mesh.get_surface_count()):
		out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	return out


## Walkable-surface check: in `slice`-metre slices along z (wider than the ring spacing) (z_from..z_to) takes the highest vertex
## within |x| < half_x and returns the worst |height - expected(z)|.
func _top_deviation(verts: PackedVector3Array, half_x: float, z_from: float, z_to: float,
		expected: Callable, slice: float = 0.6) -> float:
	var bins: int = maxi(int((z_to - z_from) / slice), 1)
	var best: Array[Vector3] = []
	best.resize(bins)
	best.fill(Vector3(0.0, -100.0, 0.0))
	for v: Vector3 in verts:
		if absf(v.x) >= half_x or v.z < z_from or v.z > z_to:
			continue
		var b: int = clampi(int((v.z - z_from) / slice), 0, bins - 1)
		if v.y > best[b].y:
			best[b] = v
	var worst: float = 0.0
	for v: Vector3 in best:
		if v.y > -100.0:
			worst = maxf(worst, absf(v.y - float(expected.call(v.z))))
	return worst

## Brachiosaurus herd: the visual of a static "train" (walkable top at 3.0 m). A run becomes one
## or more sauropods standing nose-to-tail, every back flat at the collision top so the runner's
## feet stay planted. Pure visual; collision stays the box in ObstacleBase.
##
## Orientation rule (decided by ChunkBuilder from the cell data, see Train.set_ramp_lead):
##   tail-first  a ramp leads into the run: the nearest animal's TAIL is the ramp (its upper
##               surface follows the ramp incline), heads point away from the runner and every
##               neck curls up and out to the side (browsing) so the space above the backs is free.
##   head-first  no ramp: the nearest animal faces the runner, neck up, head looking down at him,
##               chewing: an unclimbable wall. Necks further back curl to the side.
## At a joint between two animals one neck rises outward and the other animal's tail curls down
## the inner flank.
##
## Meshes are built once per variant (torso: short / standard, scaled along z to the animal
## length; necks: front / side, mirrored by node scale; tails: curl / ramp per ramp length) and
## shared by every herd. Idle motion (breathing, neck sway, chewing, blinking, tail-tip sway) is
## vertex-shader only (creature.gdshader), varied per animal with the `phase` instance uniform.
class_name Brachiosaurus
extends Node3D

const BACK: Color = Color(0.45, 0.60, 0.56)
const BELLY: Color = Color(0.80, 0.78, 0.64)
const DAPPLE: Color = Color(0.33, 0.46, 0.43)
const NAIL: Color = Color(0.86, 0.82, 0.68)
const LEAF: Color = Color(0.36, 0.62, 0.2)
## Walkable top (must match ObstacleDef.size.y of the trains).
const TOP: float = 3.0
## Torso mesh lengths (collision length of one animal); other lengths scale along z.
const SHORT_LEN: float = 3.0
const STD_LEN: float = 5.25
## Herd splitting: animals are about this long.
const TARGET_LEN: float = 5.25
const MAX_ANIMALS: int = 6

## One animal of a herd plan (obstacle space: +Z toward the runner, x = lane sideways).
class Animal extends RefCounted:
	var z: float = 0.0
	var length: float = 5.25
	## True: the head points toward the runner (+Z).
	var faces_runner: bool = false
	## &"front" (head-first wall) or &"side" (up and out, browsing).
	var neck: StringName = &"side"
	## -1 = toward -X, +1 = toward +X (obstacle space). Unused for the front neck.
	var neck_side: float = 1.0
	## &"curl" (down and along the flank) or &"ramp" (the climbable tail over the ramp).
	var tail: StringName = &"curl"
	var tail_side: float = -1.0


var _slots: Array[Node3D] = []
var _torsos: Array[MeshInstance3D] = []
var _necks: Array[MeshInstance3D] = []
var _tails: Array[MeshInstance3D] = []
var _material: ShaderMaterial = null


func _init(max_animals: int = MAX_ANIMALS) -> void:
	_material = CreatureMats.skin(&"brachio")
	for i in range(max_animals):
		var slot: Node3D = Node3D.new()
		slot.visible = false
		add_child(slot)
		_slots.append(slot)
		var parts: Array[MeshInstance3D] = []
		for k in range(3):
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.material_override = _material
			# Real sun shadow (creature.gdshader bends correctly in the shadow pass).
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.extra_cull_margin = 6.0
			slot.add_child(mi)
			parts.append(mi)
		_torsos.append(parts[0])
		_necks.append(parts[1])
		_tails.append(parts[2])


## Splits a run into animals and decides every neck and tail. `tail_first` when a ramp leads into
## the run (ramp_length > 0); `outward` = the side away from the track centre for the lane
## (-1 left lane, +1 right lane, 0 middle); `middle_side` = which way middle-lane necks go.
static func plan(run_length: float, tail_first: bool, outward: float, middle_side: float) -> Array[Animal]:
	var n: int = clampi(roundi(run_length / TARGET_LEN), 1, MAX_ANIMALS)
	var a: float = run_length / float(n)
	var side: float = outward if outward != 0.0 else (middle_side if middle_side != 0.0 else 1.0)
	var out: Array[Animal] = []
	for i in range(n):
		var animal: Animal = Animal.new()
		animal.z = run_length * 0.5 - (float(i) + 0.5) * a
		animal.length = a
		animal.faces_runner = not tail_first
		animal.neck_side = side
		animal.tail_side = side
		animal.neck = &"side"
		animal.tail = &"curl"
		# The nearest animal: a ramp tail, or the head-first wall.
		if i == 0:
			if tail_first:
				animal.tail = &"ramp"
			else:
				animal.neck = &"front"
		# Tails at a joint with another animal curl down the inner flank (the neighbour's neck
		# rises outward there). Head-first: tails point away from the runner (toward i + 1).
		var tail_at_joint: bool = (i < n - 1) if not tail_first else (i > 0)
		if tail_at_joint:
			animal.tail_side = -side
		out.append(animal)
	return out


## Lays the herd out over a run (obstacle space). ramp_length > 0 = tail-first over that ramp.
func layout(run_length: float, ramp_length: float, ramp_height: float, outward: float,
		middle_side: float, phase_seed: float) -> Array[Animal]:
	var animals: Array[Animal] = plan(run_length, ramp_length > 0.0, outward, middle_side)
	for i in range(_slots.size()):
		_slots[i].visible = i < animals.size()
	for i in range(animals.size()):
		var an: Animal = animals[i]
		var slot: Node3D = _slots[i]
		slot.position = Vector3(0.0, 0.0, an.z)
		slot.rotation = Vector3(0.0, PI if an.faces_runner else 0.0, 0.0)
		# Model space faces -Z; turned around, model +X is obstacle -X.
		var flip: float = -1.0 if an.faces_runner else 1.0
		var short: bool = an.length < 4.0
		var torso: MeshInstance3D = _torsos[i]
		torso.mesh = Brachiosaurus.torso_mesh(short)
		torso.scale = Vector3(1.0, 1.0, an.length / (SHORT_LEN if short else STD_LEN))
		var neck: MeshInstance3D = _necks[i]
		neck.mesh = Brachiosaurus.neck_mesh(an.neck)
		neck.position = Vector3(0.0, 0.0, -an.length * 0.5)
		neck.scale = Vector3(an.neck_side * flip if an.neck == &"side" else 1.0, 1.0, 1.0)
		var tail: MeshInstance3D = _tails[i]
		tail.position = Vector3(0.0, 0.0, an.length * 0.5)
		if an.tail == &"ramp":
			tail.mesh = Brachiosaurus.ramp_tail_mesh(ramp_length, ramp_height)
			tail.scale = Vector3.ONE
		else:
			tail.mesh = Brachiosaurus.curl_tail_mesh()
			tail.scale = Vector3(an.tail_side * flip, 1.0, 1.0)
		var phase: float = fposmod(phase_seed * 0.618 + float(i) * 0.37, 1.0)
		for mi: MeshInstance3D in [torso, neck, tail]:
			mi.set_instance_shader_parameter(&"phase", phase)
	return animals


## Most negative z (herd space = obstacle space) reached by the visible animals' meshes: the far
## end of the drawn herd, beyond the collision box by up to ~1.1 m (rounded rump or chest, the
## last neck and head, a curled tail). Idle sway is not included.
func far_extent() -> float:
	var far: float = 0.0
	for i in range(_slots.size()):
		var slot: Node3D = _slots[i]
		if not slot.visible:
			continue
		for mi: MeshInstance3D in [_torsos[i], _necks[i], _tails[i]]:
			if mi.mesh == null:
				continue
			var box: AABB = (slot.transform * mi.transform) * mi.mesh.get_aabb()
			far = minf(far, box.position.z)
	return far


# --- Meshes (built once per variant, shared) --------------------------------------------------

## Builds every fixed variant now (boot / pool warm-up), so no mesh is ever built mid-run.
static func prewarm(ramp_lengths: Array[float] = [6.0]) -> void:
	torso_mesh(true)
	torso_mesh(false)
	neck_mesh(&"front")
	neck_mesh(&"side")
	curl_tail_mesh()
	for r: float in ramp_lengths:
		ramp_tail_mesh(r, TOP)


static func _skin(p: Vector3, n: Vector3) -> Color:
	var c: Color = OrganicMesh.countershade(n.y, BACK, BELLY, -0.25, 0.35)
	var spots: float = smoothstep(0.28, 0.45, OrganicMesh.noise3(p, 1.7, 5.0))
	c = c.lerp(DAPPLE, spots * smoothstep(-0.3, 0.4, n.y) * 0.75)
	return c.darkened(0.05 * OrganicMesh.noise3(p, 5.0, 1.0))


## Body + four pillar legs. Short = one 3 m animal, standard = 5.25 m (scaled along z).
static func torso_mesh(short: bool) -> ArrayMesh:
	return OrganicMesh.cached("brachio_torso_%s" % ("s" if short else "l"),
			Brachiosaurus._build_torso.bind(SHORT_LEN if short else STD_LEN)) as ArrayMesh


static func _build_torso(length: float) -> ArrayMesh:
	var om: OrganicMesh = OrganicMesh.new()
	var h: float = length * 0.5
	om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		var c: Color = Brachiosaurus._skin(p, n)
		# A slightly darker band down the spine reads as the path along the herd.
		return c.darkened(0.1 * (1.0 - smoothstep(0.18, 0.4, absf(p.x))) * smoothstep(0.85, 0.97, n.y))
	om.custom_fn = func(_p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		return Color(0.0, 0.0, 0.0, clampf(1.0 - absf(n.y) * 1.6, 0.0, 1.0))
	# Flat top at TOP over the whole collision length; rounded beyond it.
	var zs: PackedFloat32Array = PackedFloat32Array([h + 0.55, h + 0.2, h - 0.35, h * 0.25, -h * 0.25, -h + 0.35, -h - 0.2, -h - 0.55])
	var ys: PackedFloat32Array = PackedFloat32Array([2.46, 2.33, 2.13, 2.02, 2.02, 2.1, 2.34, 2.5])
	var rx: PackedFloat32Array = PackedFloat32Array([0.46, 0.74, 0.86, 0.9, 0.91, 0.9, 0.76, 0.5])
	var ry: PackedFloat32Array = PackedFloat32Array([0.4, 0.65, 0.87, 0.98, 0.98, 0.9, 0.65, 0.42])
	var pts: PackedVector3Array = PackedVector3Array()
	var radii: PackedVector2Array = PackedVector2Array()
	for i in range(zs.size()):
		pts.append(Vector3(0.0, ys[i], zs[i]))
		radii.append(Vector2(rx[i], ry[i]))
	om.loft(pts, radii, 20, 3, {"exps": PackedFloat32Array([2.3, 2.5, 2.7, 2.7, 2.7, 2.7, 2.5, 2.3]),
			"cap_len0": 0.8, "cap_len1": 0.8})
	om.custom_fn = Callable()
	# Stout pillar legs (front a little thicker) with flared feet and three toenails each.
	for leg in range(4):
		var front: bool = leg < 2
		var x: float = 0.5 if leg % 2 == 0 else -0.5
		var z: float = (-h + 0.6) if front else (h - 0.62)
		var r: float = 0.43 if front else 0.41
		om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
			return Brachiosaurus._skin(p, n).darkened(smoothstep(0.8, 0.0, p.y) * 0.2)
		om.limb(PackedVector3Array([Vector3(x * 0.9, 1.95, z), Vector3(x, 1.05, z + 0.05),
				Vector3(x * 1.02, 0.4, z), Vector3(x * 1.02, 0.0, z)]),
				PackedFloat32Array([r + 0.05, r - 0.03, r - 0.04, r + 0.04]), 12, 2,
				{"cap0": OrganicMesh.CAP_NONE, "cap1": OrganicMesh.CAP_FLAT})
		om.paint = Callable()
		om.color = NAIL
		for k in range(3):
			var a: float = (float(k) - 1.0) * 0.55
			om.ellipsoid(Vector3(x * 1.02 + sin(a) * (r + 0.02), 0.1, z - cos(a) * (r + 0.02)),
					Vector3(0.09, 0.09, 0.065), 4, 6)
	return om.commit()


## Neck + head: &"front" (rises at the chest, head looks down at the runner) or &"side" (up and
## out to model +X, browsing a leafy branch). Attach point: the torso end at z = 0.
static func neck_mesh(kind: StringName) -> ArrayMesh:
	return OrganicMesh.cached("brachio_neck_%s" % kind, Brachiosaurus._build_neck.bind(kind)) as ArrayMesh


static func _build_neck(kind: StringName) -> ArrayMesh:
	var om: OrganicMesh = OrganicMesh.new()
	om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		return Brachiosaurus._skin(p, n)
	om.custom_fn = func(p: Vector3, _n: Vector3, _u: float, _v: float) -> Color:
		return Color(smoothstep(2.9, 6.0, p.y), 0.0, 0.0, 0.0)
	var pts: PackedVector3Array
	var head_at: Vector3
	var head_dir: Vector3
	if kind == &"front":
		pts = PackedVector3Array([Vector3(0.0, 2.3, 0.7), Vector3(0.0, 2.65, -0.25), Vector3(0.0, 3.6, -0.68),
				Vector3(0.0, 4.6, -0.82), Vector3(0.0, 5.35, -0.78), Vector3(0.0, 5.8, -0.92)])
		head_at = Vector3(0.0, 5.92, -0.95)
		head_dir = Vector3(0.0, -0.75, -1.0)
	else:
		# The root leaves the shoulder sideways, below the back, so the walkway stays free.
		pts = PackedVector3Array([Vector3(0.3, 2.3, 0.6), Vector3(0.7, 2.4, -0.12), Vector3(1.05, 3.42, -0.3),
				Vector3(1.4, 4.5, -0.38), Vector3(1.9, 5.4, -0.34), Vector3(2.45, 5.88, -0.3)])
		head_at = Vector3(2.55, 5.98, -0.3)
		head_dir = Vector3(1.0, -0.55, -0.35)
	om.loft(pts, PackedVector2Array([Vector2(0.62, 0.62), Vector2(0.46, 0.48), Vector2(0.39, 0.41),
			Vector2(0.34, 0.35), Vector2(0.29, 0.3), Vector2(0.27, 0.28)]), 14, 4,
			{"cap0": OrganicMesh.CAP_NONE, "cap1": OrganicMesh.CAP_NONE})
	_build_head(om, Transform3D(Basis.looking_at(head_dir.normalized(), Vector3.UP), head_at), kind == &"side")
	return om.commit()


## Small sauropod head in its own frame (back of the skull at the origin, snout toward -Z):
## nasal crest, big friendly eyes, chewing lower jaw, optional leafy sprig.
static func _build_head(om: OrganicMesh, frame: Transform3D, sprig: bool) -> void:
	om.xform = frame
	om.custom = Color(1.0, 0.0, 0.0, 0.0)
	om.custom_fn = Callable()
	om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		return OrganicMesh.countershade(n.y, BACK, BELLY, -0.35, 0.3).darkened(0.04 * OrganicMesh.noise3(p, 6.0))
	om.loft(PackedVector3Array([Vector3(0.0, 0.02, 0.12), Vector3(0.0, 0.0, -0.3), Vector3(0.0, -0.1, -0.62),
			Vector3(0.0, -0.17, -0.86)]),
		PackedVector2Array([Vector2(0.27, 0.28), Vector2(0.26, 0.3), Vector2(0.2, 0.2), Vector2(0.16, 0.14)]),
		14, 3, {"exps": PackedFloat32Array([2.2, 2.3, 2.5, 2.4]), "cap_len0": 0.7, "cap_len1": 0.8})
	# Nasal crest dome.
	om.ellipsoid(Vector3(0.0, 0.2, -0.3), Vector3(0.18, 0.17, 0.25), 6, 10)
	# Lower jaw (chews).
	om.custom = Color(1.0, 0.0, 1.0, 0.0)
	om.paint = func(_p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		return OrganicMesh.countershade(n.y, BACK, BELLY, 0.3, 0.3)
	om.loft(PackedVector3Array([Vector3(0.0, -0.16, -0.12), Vector3(0.0, -0.23, -0.5), Vector3(0.0, -0.27, -0.8)]),
		PackedVector2Array([Vector2(0.19, 0.1), Vector2(0.16, 0.09), Vector2(0.12, 0.06)]), 10, 2,
		{"exps": PackedFloat32Array([2.4, 2.4, 2.4]), "cap_len1": 0.8})
	if sprig:
		om.paint = Callable()
		om.color = Color(0.42, 0.3, 0.18)
		om.limb(PackedVector3Array([Vector3(-0.32, -0.2, -0.62), Vector3(0.0, -0.2, -0.66), Vector3(0.38, -0.32, -0.62)]),
				PackedFloat32Array([0.025, 0.03, 0.022]), 5, 2)
		for k in range(6):
			var f: float = float(k) / 5.0
			om.color = LEAF.lightened(0.12 * sin(float(k) * 2.1))
			om.ellipsoid(Vector3(lerpf(-0.36, 0.42, f), -0.27 - 0.06 * sin(f * 9.0), -0.62 + 0.06 * cos(f * 7.0)),
					Vector3(0.1, 0.035, 0.07), 3, 6, Basis.from_euler(Vector3(0.4 * sin(f * 5.0), f * 2.0, 0.5)))
	# Eyes: big dark iris with a white glint (they blink).
	om.custom = Color(1.0, 0.0, 0.0, 0.0)
	om.mask2 = Vector2(1.0, 1.0)
	om.paint = Callable()
	for side: float in [-1.0, 1.0]:
		var eye: Vector3 = Vector3(side * 0.21, 0.1, -0.2)
		om.color = Color(0.12, 0.08, 0.05)
		om.ellipsoid(eye, Vector3(0.085, 0.09, 0.085), 6, 8)
		om.color = Color(1.0, 1.0, 0.96)
		om.ellipsoid(eye + Vector3(side * 0.07, 0.035, -0.035), Vector3(0.02, 0.022, 0.016), 3, 5)
		om.mask2 = Vector2.ZERO
		om.color = Color(0.2, 0.28, 0.26)
		om.ellipsoid(Vector3(side * 0.07, 0.31, -0.42), Vector3(0.035, 0.022, 0.04), 3, 5)
		om.mask2 = Vector2(1.0, 1.0)
	om.mask2 = Vector2.ZERO
	om.custom = Color(0.0, 0.0, 0.0, 0.0)
	om.xform = Transform3D.IDENTITY


## Tail that droops from the rump and curls forward along the flank to model +X, tip resting on
## the ground; stays within ~1 m of the body end. Attach point: the rump end at z = 0.
static func curl_tail_mesh() -> ArrayMesh:
	return OrganicMesh.cached("brachio_tail_curl", Brachiosaurus._build_curl_tail) as ArrayMesh


static func _build_curl_tail() -> ArrayMesh:
	var om: OrganicMesh = OrganicMesh.new()
	om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		return Brachiosaurus._skin(p, n)
	om.custom_fn = func(_p: Vector3, _n: Vector3, _u: float, v: float) -> Color:
		return Color(0.0, smoothstep(0.45, 1.0, v), 0.0, 0.0)
	om.loft(PackedVector3Array([Vector3(0.0, 2.5, -0.5), Vector3(0.0, 2.42, 0.28), Vector3(0.28, 1.95, 0.78),
			Vector3(0.72, 1.25, 0.88), Vector3(1.0, 0.58, 0.62), Vector3(1.08, 0.16, 0.02), Vector3(1.04, 0.08, -0.7)]),
		PackedVector2Array([Vector2(0.52, 0.5), Vector2(0.42, 0.42), Vector2(0.32, 0.32), Vector2(0.24, 0.24),
			Vector2(0.17, 0.17), Vector2(0.12, 0.1), Vector2(0.07, 0.055)]), 12, 3, {"cap0": OrganicMesh.CAP_NONE})
	return om.commit()


## The climbable tail over a ramp of `length` x `height`: tip on the ground at the ramp's near end
## (z = length), rising in a straight line to the back height at the body (z = 0). The upper
## surface follows the ramp's walkable incline; only the last metres sway.
static func ramp_tail_mesh(length: float, height: float) -> ArrayMesh:
	return OrganicMesh.cached("brachio_tail_ramp_%.2f_%.2f" % [length, height],
			Brachiosaurus._build_ramp_tail.bind(length, height)) as ArrayMesh


static func _build_ramp_tail(length: float, height: float) -> ArrayMesh:
	var om: OrganicMesh = OrganicMesh.new()
	om.paint = func(p: Vector3, n: Vector3, _u: float, _v: float) -> Color:
		var c: Color = Brachiosaurus._skin(p, n)
		return c.darkened(0.1 * (1.0 - smoothstep(0.12, 0.3, absf(p.x))) * smoothstep(0.8, 0.95, n.y))
	om.custom_fn = func(p: Vector3, _n: Vector3, _u: float, _v: float) -> Color:
		return Color(0.0, smoothstep(length * 0.72, length, p.z), 0.0, 0.0)
	var up: Vector3 = Vector3(0.0, length, height).normalized()
	var pts: PackedVector3Array = PackedVector3Array([Vector3(0.0, height - 0.66, -0.7)])
	var radii: PackedVector2Array = PackedVector2Array([Vector2(0.74, 0.66)])
	var ups: PackedVector3Array = PackedVector3Array([Vector3.UP])
	var steps: int = 7
	for k in range(steps + 1):
		var t: float = float(k) / float(steps)
		var ry: float = lerpf(0.64, 0.07, pow(t, 0.85))
		var rx: float = lerpf(0.72, 0.11, t)
		var top: Vector3 = Vector3(0.0, height * (1.0 - t), length * t)
		pts.append(top - up * ry)
		radii.append(Vector2(rx, ry))
		ups.append(up)
	# The very tip lies flat on the ground just past the ramp.
	pts.append(Vector3(0.0, 0.035, length + 0.35))
	radii.append(Vector2(0.06, 0.035))
	ups.append(Vector3.UP)
	var exps: PackedFloat32Array = PackedFloat32Array()
	for i in range(pts.size()):
		exps.append(2.6)
	om.loft(pts, radii, 14, 3, {"ups": ups, "exps": exps, "cap0": OrganicMesh.CAP_NONE, "cap_len1": 1.5})
	return om.commit()

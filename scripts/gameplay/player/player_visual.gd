## The runner's body, built from primitives and animated procedurally (sine swings, tweened
## poses). Skins are CharacterDef resources: colours, bulk and one accessory.
## Replace with real art by dropping assets/meshes/player.glb (see VisualProvider).
class_name PlayerVisual
extends Node3D

enum Pose { IDLE, RUN, JUMP, FALL, ROLL, STUMBLE, FLY, DEAD }

var pose: Pose = Pose.IDLE

var _root: Node3D = null
var _body: MeshInstance3D = null
var _head: MeshInstance3D = null
var _hair: MeshInstance3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null
## Elbow / knee pivots (children of the arm / leg pivots) so limbs bend while running.
var _elbow_l: Node3D = null
var _elbow_r: Node3D = null
var _knee_l: Node3D = null
var _knee_r: Node3D = null
## Meshes grouped by the skin colour they take (see apply_character).
var _sleeves: Array[MeshInstance3D] = []
var _limb_parts: Array[MeshInstance3D] = []
var _skin_parts: Array[MeshInstance3D] = []
var _shoes: Array[MeshInstance3D] = []
var _soles: Array[MeshInstance3D] = []
var _accessory: Node3D = null
var _flames: Node3D = null
var _phase: float = 0.0
var _pose_time: float = 0.0
var _custom: bool = false

## Proportions of the blocky runner from the key art (metres, feet at y = 0).
const HIP_Y: float = 0.78
const SHOULDER_Y: float = 1.38
const THIGH: float = 0.38
const SHIN: float = 0.3
const UPPER_ARM: float = 0.27
const FOREARM: float = 0.24
const SHOE_COLOR: Color = Color(0.13, 0.12, 0.17)
const SOLE_COLOR: Color = Color(0.88, 0.89, 0.95)
const EYE_COLOR: Color = Color(0.05, 0.04, 0.09)


func _ready() -> void:
	_custom = VisualProvider.has_override(&"player")
	if _custom:
		add_child(VisualProvider.build(&"player", func() -> Node3D: return Node3D.new()))
		return
	_root = Node3D.new()
	add_child(_root)
	# Torso: a block, like the key-art runner.
	_body = MeshLib.mi(MeshLib.box(), null, Vector3(0.0, 1.1, 0.0), Vector3(0.5, 0.6, 0.3))
	_root.add_child(_body)
	var neck: MeshInstance3D = MeshLib.mi(MeshLib.box(), null, Vector3(0.0, 1.44, 0.0), Vector3(0.14, 0.1, 0.14))
	_root.add_child(neck)
	_skin_parts.append(neck)
	_head = MeshLib.mi(MeshLib.sphere(), null, Vector3(0.0, 1.65, 0.0), Vector3(0.42, 0.42, 0.42))
	_root.add_child(_head)
	_skin_parts.append(_head)
	# Hair covers the back and top of the head: the camera mostly sees the runner from behind.
	_hair = MeshLib.mi(MeshLib.sphere(), null, Vector3(0.0, 1.69, 0.035), Vector3(0.44, 0.4, 0.42))
	_root.add_child(_hair)
	# Eyes (seen in the menu and the shop, where the runner faces the camera).
	for x: float in [-0.075, 0.075]:
		_root.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(EYE_COLOR), Vector3(x, 1.665, -0.196),
				Vector3(0.05, 0.075, 0.02)))
	for side: float in [-1.0, 1.0]:
		var arm: Node3D = _pivot(_root, Vector3(side * 0.31, SHOULDER_Y, 0.0))
		_sleeves.append(_part(arm, Vector3(0.0, -UPPER_ARM * 0.5, 0.0), Vector3(0.16, UPPER_ARM + 0.04, 0.17)))
		var elbow: Node3D = _pivot(arm, Vector3(0.0, -UPPER_ARM, 0.0))
		_limb_parts.append(_part(elbow, Vector3(0.0, -FOREARM * 0.5, 0.0), Vector3(0.13, FOREARM, 0.14)))
		_skin_parts.append(_part(elbow, Vector3(0.0, -FOREARM - 0.05, 0.0), Vector3(0.12, 0.11, 0.12)))
		var leg: Node3D = _pivot(_root, Vector3(side * 0.13, HIP_Y, 0.0))
		_limb_parts.append(_part(leg, Vector3(0.0, -THIGH * 0.5 + 0.02, 0.0), Vector3(0.19, THIGH + 0.04, 0.2)))
		var knee: Node3D = _pivot(leg, Vector3(0.0, -THIGH, 0.0))
		_limb_parts.append(_part(knee, Vector3(0.0, -SHIN * 0.5, 0.0), Vector3(0.17, SHIN, 0.18)))
		# Sneaker: dark upper, toe pointing forward (-Z), thick white sole.
		_shoes.append(_part(knee, Vector3(0.0, -SHIN - 0.02, -0.05), Vector3(0.2, 0.12, 0.32)))
		_soles.append(_part(knee, Vector3(0.0, -SHIN - 0.095, -0.05), Vector3(0.21, 0.04, 0.34)))
		if side < 0.0:
			_arm_l = arm
			_elbow_l = elbow
			_leg_l = leg
			_knee_l = knee
		else:
			_arm_r = arm
			_elbow_r = elbow
			_leg_r = leg
			_knee_r = knee
	_flames = Node3D.new()
	_flames.visible = false
	_root.add_child(_flames)
	for x: float in [-0.14, 0.14]:
		var flame: MeshInstance3D = MeshLib.mi(MeshLib.cone(), Mats.glow(Color(1.0, 0.6, 0.15), 3.0),
				Vector3(x, 0.72, 0.3), Vector3(0.2, 0.7, 0.2))
		flame.rotation.x = PI
		_flames.add_child(flame)
	apply_character(ContentDB.CHARACTERS[0])


## Recolours / reshapes the body for a skin.
func apply_character(def: CharacterDef) -> void:
	if _custom or _root == null:
		return
	# player_lit = lit + rim light, so the runner stays readable among coins and neon.
	var body_mat: ShaderMaterial = Mats.player_lit(def.body_color, def.glow_color, 0.12)
	var limb_mat: ShaderMaterial = Mats.player_lit(def.limb_color)
	var skin_mat: ShaderMaterial = Mats.player_lit(def.head_color)
	_body.material_override = body_mat
	_body.scale = Vector3(0.5 * def.bulk, 0.6, 0.3 * def.bulk)
	_hair.material_override = Mats.player_lit(def.hair_color)
	for arm: Node3D in [_arm_l, _arm_r]:
		arm.position.x = signf(arm.position.x) * (0.25 * def.bulk + 0.06)
	for m: MeshInstance3D in _sleeves:
		m.material_override = body_mat
	for m: MeshInstance3D in _limb_parts:
		m.material_override = limb_mat
	for m: MeshInstance3D in _skin_parts:
		m.material_override = skin_mat
	for m: MeshInstance3D in _shoes:
		m.material_override = Mats.player_lit(SHOE_COLOR)
	for m: MeshInstance3D in _soles:
		m.material_override = Mats.player_lit(SOLE_COLOR, def.glow_color, 0.15)
	if _accessory != null:
		_accessory.queue_free()
	_accessory = _build_accessory(def)
	_root.add_child(_accessory)


## Switches the animation pose.
func set_pose(new_pose: Pose) -> void:
	if pose == new_pose:
		return
	pose = new_pose
	_pose_time = 0.0
	if _flames != null:
		_flames.visible = pose == Pose.FLY


## Advances the procedural animation. cadence ~ steps per second factor, lean = lane tilt (rad).
func animate(delta: float, cadence: float, lean: float) -> void:
	if _custom or _root == null:
		return
	_pose_time += delta
	_phase += delta * cadence
	var swing: float = sin(_phase)
	var target_rot: Vector3 = Vector3(0.0, 0.0, -lean)
	var target_pos: Vector3 = Vector3.ZERO
	var arm_l: float = 0.0
	var arm_r: float = 0.0
	var leg_l: float = 0.0
	var leg_r: float = 0.0
	# Elbows bend the hand forward (+), knees bend the foot back (-).
	var elbow: float = 0.15
	var knee_l: float = 0.0
	var knee_r: float = 0.0
	match pose:
		Pose.IDLE:
			# Breathing bob, a slow weight shift from foot to foot and loose arms.
			var breath: float = sin(_pose_time * 2.0)
			var shift: float = sin(_pose_time * 0.9)
			target_pos.y = breath * 0.03
			target_rot.z += shift * 0.05
			target_rot.x = breath * 0.02
			arm_l = 0.1 + breath * 0.07
			arm_r = -0.1 + sin(_pose_time * 2.0 + 0.6) * 0.07
			leg_l = maxf(shift, 0.0) * 0.12
			leg_r = maxf(-shift, 0.0) * 0.12
		Pose.RUN:
			target_rot.x = -0.18
			target_pos.y = absf(swing) * 0.07
			leg_l = swing * 0.95
			leg_r = -swing * 0.95
			arm_l = -swing * 0.8
			arm_r = swing * 0.8
			elbow = 1.35
			# The trailing leg folds up behind the runner, the leading one stays nearly straight.
			knee_l = -(0.25 + maxf(-leg_l, 0.0) * 1.3)
			knee_r = -(0.25 + maxf(-leg_r, 0.0) * 1.3)
		Pose.JUMP, Pose.FALL:
			target_rot.x = -0.1 if pose == Pose.JUMP else 0.15
			leg_l = -0.9
			leg_r = 0.5
			arm_l = 2.4
			arm_r = 2.4
			elbow = 0.4
			knee_l = -0.4
			knee_r = -1.3
		Pose.ROLL:
			target_pos.y = -0.55
			leg_l = -1.9
			leg_r = -1.9
			arm_l = -1.2
			arm_r = -1.2
			elbow = 1.6
			knee_l = -2.2
			knee_r = -2.2
		Pose.STUMBLE:
			target_rot.x = 0.35 + sin(_pose_time * 40.0) * 0.06
			arm_l = 1.6
			arm_r = -1.2
			leg_l = swing * 0.5
			leg_r = -swing * 0.5
			elbow = 0.6
			knee_l = -0.3
			knee_r = -0.3
		Pose.FLY:
			target_rot.x = -0.95
			arm_l = 0.5
			arm_r = 0.5
			leg_l = 0.25 + swing * 0.08
			leg_r = 0.25 - swing * 0.08
			elbow = 0.5
			knee_l = -0.5
			knee_r = -0.35
		Pose.DEAD:
			var t: float = minf(_pose_time / 0.45, 1.0)
			target_rot.x = MathUtils.ease_out_cubic(t) * 1.45
			target_pos.y = -0.1 * t
			arm_l = 2.6
			arm_r = 2.2
			leg_l = 0.4
			leg_r = -0.3
	var k: float = 1.0 - exp(-delta * 18.0)
	if pose == Pose.ROLL:
		# Continuous forward tumble around the body's centre.
		_root.rotation.x -= delta * 15.0
		_root.rotation.z = lerpf(_root.rotation.z, target_rot.z, k)
		_root.scale = _root.scale.lerp(Vector3.ONE * 0.75, k)
		_root.position = Vector3(0.0, 0.45, 0.0) - _root.basis.y * 0.9
	else:
		_root.scale = _root.scale.lerp(Vector3.ONE, k)
		_root.rotation.x = lerp_angle(_root.rotation.x, target_rot.x, k)
		_root.rotation.z = lerpf(_root.rotation.z, target_rot.z, k)
		_root.position = _root.position.lerp(target_pos, k)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_l, k)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, arm_r, k)
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, leg_l, k)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, leg_r, k)
	_elbow_l.rotation.x = lerpf(_elbow_l.rotation.x, elbow, k)
	_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, elbow, k)
	_knee_l.rotation.x = lerpf(_knee_l.rotation.x, knee_l, k)
	_knee_r.rotation.x = lerpf(_knee_r.rotation.x, knee_r, k)
	if _flames.visible:
		var flicker: float = 0.6 + 0.25 * sin(_pose_time * 37.0) + 0.15 * sin(_pose_time * 61.0)
		_flames.scale = Vector3(1.0, flicker, 1.0)


## A joint: an empty node the limb parts hang from.
func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	return pivot


## A box part of the body under `parent` (material set later by apply_character).
func _part(parent: Node3D, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshLib.mi(MeshLib.box(), null, pos, size)
	parent.add_child(mesh)
	return mesh


func _build_accessory(def: CharacterDef) -> Node3D:
	var node: Node3D = Node3D.new()
	var glow_mat: ShaderMaterial = Mats.lit(Color.BLACK, def.glow_color, 2.2)
	var dark: ShaderMaterial = Mats.lit(def.limb_color)
	match def.accessory:
		&"visor":
			# Wraps around the eyes; a thin band continues round the back of the head so the
			# glow also reads from the chase camera.
			node.add_child(MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.0, 1.66, -0.17), Vector3(0.38, 0.09, 0.1)))
			node.add_child(MeshLib.mi(MeshLib.cylinder(), glow_mat, Vector3(0.0, 1.66, 0.0), Vector3(0.45, 0.035, 0.45)))
		&"cap":
			# Key-art cap: dark crown and a glowing brim at the front.
			node.add_child(MeshLib.mi(MeshLib.sphere(), dark, Vector3(0.0, 1.76, 0.02), Vector3(0.46, 0.26, 0.46)))
			node.add_child(MeshLib.mi(MeshLib.cylinder(), dark, Vector3(0.0, 1.73, 0.0), Vector3(0.46, 0.06, 0.46)))
			var brim: MeshInstance3D = MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.0, 1.72, -0.3), Vector3(0.34, 0.035, 0.24))
			brim.rotation.x = -0.12
			node.add_child(brim)
		&"backpack":
			node.add_child(MeshLib.mi(MeshLib.box(), dark, Vector3(0.0, 1.12, 0.25), Vector3(0.38, 0.46, 0.2)))
			node.add_child(MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.0, 1.2, 0.36), Vector3(0.2, 0.08, 0.02)))
		&"antenna":
			node.add_child(MeshLib.mi(MeshLib.box(), dark, Vector3(0.1, 1.98, 0.0), Vector3(0.03, 0.34, 0.03)))
			node.add_child(MeshLib.mi(MeshLib.sphere(), glow_mat, Vector3(0.1, 2.16, 0.0), Vector3(0.1, 0.1, 0.1)))
		&"scarf":
			node.add_child(MeshLib.mi(MeshLib.cylinder(), glow_mat, Vector3(0.0, 1.42, 0.0), Vector3(0.42, 0.1, 0.42)))
			var tail: MeshInstance3D = MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.12, 1.3, 0.3), Vector3(0.12, 0.05, 0.5))
			tail.rotation.x = 0.35
			node.add_child(tail)
	return node

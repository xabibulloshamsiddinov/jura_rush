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
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null
var _accessory: Node3D = null
var _flames: Node3D = null
var _phase: float = 0.0
var _pose_time: float = 0.0
var _custom: bool = false


func _ready() -> void:
	_custom = VisualProvider.has_override(&"player")
	if _custom:
		add_child(VisualProvider.build(&"player", func() -> Node3D: return Node3D.new()))
		return
	_root = Node3D.new()
	add_child(_root)
	_body = MeshLib.mi(MeshLib.capsule(), null, Vector3(0.0, 1.05, 0.0), Vector3(0.52, 0.36, 0.4))
	_head = MeshLib.mi(MeshLib.sphere(), null, Vector3(0.0, 1.58, 0.0), Vector3(0.4, 0.4, 0.4))
	_root.add_child(_body)
	_root.add_child(_head)
	_arm_l = _limb(Vector3(-0.34, 1.32, 0.0), Vector3(0.13, 0.55, 0.13))
	_arm_r = _limb(Vector3(0.34, 1.32, 0.0), Vector3(0.13, 0.55, 0.13))
	_leg_l = _limb(Vector3(-0.14, 0.74, 0.0), Vector3(0.17, 0.74, 0.17))
	_leg_r = _limb(Vector3(0.14, 0.74, 0.0), Vector3(0.17, 0.74, 0.17))
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
	var limb_mat: ShaderMaterial = Mats.player_lit(def.limb_color)
	_body.material_override = Mats.player_lit(def.body_color, def.glow_color, 0.25)
	_body.scale = Vector3(0.52 * def.bulk, 0.36, 0.4 * def.bulk)
	_head.material_override = Mats.player_lit(def.head_color)
	for pivot: Node3D in [_arm_l, _arm_r, _leg_l, _leg_r]:
		(pivot.get_child(0) as MeshInstance3D).material_override = limb_mat
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
	match pose:
		Pose.IDLE:
			target_pos.y = sin(_pose_time * 2.0) * 0.02
			arm_l = 0.08 + sin(_pose_time * 2.0) * 0.05
			arm_r = -arm_l
		Pose.RUN:
			target_rot.x = -0.18
			target_pos.y = absf(swing) * 0.07
			leg_l = swing * 0.95
			leg_r = -swing * 0.95
			arm_l = -swing * 0.8
			arm_r = swing * 0.8
		Pose.JUMP, Pose.FALL:
			target_rot.x = -0.1 if pose == Pose.JUMP else 0.15
			leg_l = -0.9
			leg_r = 0.5
			arm_l = 2.4
			arm_r = 2.4
		Pose.ROLL:
			target_pos.y = -0.55
			leg_l = -1.9
			leg_r = -1.9
			arm_l = -1.2
			arm_r = -1.2
		Pose.STUMBLE:
			target_rot.x = 0.35 + sin(_pose_time * 40.0) * 0.06
			arm_l = 1.6
			arm_r = -1.2
			leg_l = swing * 0.5
			leg_r = -swing * 0.5
		Pose.FLY:
			target_rot.x = -0.95
			arm_l = 0.5
			arm_r = 0.5
			leg_l = 0.25 + swing * 0.08
			leg_r = 0.25 - swing * 0.08
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
	if _flames.visible:
		var flicker: float = 0.6 + 0.25 * sin(_pose_time * 37.0) + 0.15 * sin(_pose_time * 61.0)
		_flames.scale = Vector3(1.0, flicker, 1.0)


## Creates a limb: a pivot node at the joint with a box hanging below it.
func _limb(joint: Vector3, size: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = joint
	pivot.add_child(MeshLib.mi(MeshLib.box(), null, Vector3(0.0, -size.y * 0.5, 0.0), size))
	_root.add_child(pivot)
	return pivot


func _build_accessory(def: CharacterDef) -> Node3D:
	var node: Node3D = Node3D.new()
	var glow_mat: ShaderMaterial = Mats.lit(Color.BLACK, def.glow_color, 2.2)
	var dark: ShaderMaterial = Mats.lit(def.limb_color)
	match def.accessory:
		&"visor":
			node.add_child(MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.0, 1.6, -0.17), Vector3(0.36, 0.09, 0.1)))
		&"cap":
			node.add_child(MeshLib.mi(MeshLib.cylinder(), dark, Vector3(0.0, 1.76, 0.0), Vector3(0.42, 0.12, 0.42)))
			node.add_child(MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.0, 1.72, -0.26), Vector3(0.3, 0.04, 0.22)))
		&"backpack":
			node.add_child(MeshLib.mi(MeshLib.box(), dark, Vector3(0.0, 1.12, 0.26), Vector3(0.38, 0.46, 0.2)))
			node.add_child(MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.0, 1.2, 0.37), Vector3(0.2, 0.08, 0.02)))
		&"antenna":
			node.add_child(MeshLib.mi(MeshLib.box(), dark, Vector3(0.1, 1.92, 0.0), Vector3(0.03, 0.34, 0.03)))
			node.add_child(MeshLib.mi(MeshLib.sphere(), glow_mat, Vector3(0.1, 2.1, 0.0), Vector3(0.1, 0.1, 0.1)))
		&"scarf":
			node.add_child(MeshLib.mi(MeshLib.cylinder(), glow_mat, Vector3(0.0, 1.38, 0.0), Vector3(0.42, 0.1, 0.42)))
			var tail: MeshInstance3D = MeshLib.mi(MeshLib.box(), glow_mat, Vector3(0.12, 1.3, 0.3), Vector3(0.12, 0.05, 0.5))
			tail.rotation.x = 0.35
			node.add_child(tail)
	return node

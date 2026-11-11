## The chaser: an original "Warden" patrol robot with a hovering scout drone, built from
## primitives. Hidden while the player runs clean, closes in after a stumble, and catches the
## player on the fatal hit. Reads speed and player events from the event bus only.
##
## States: Hidden -> Chase (player_stumbled) -> Hidden (window elapsed)
##         Chase / Hidden -> Catch (player_crashed) -> Hidden (run reset / revive)
class_name Chaser
extends Node3D

const HIDDEN: StringName = &"hidden"
const CHASE: StringName = &"chase"
const CATCH: StringName = &"catch"
const HIDDEN_Z: float = 10.5
const CHASE_Z: float = 4.6
const CATCH_Z: float = 1.5

var machine: StateMachine = null
## X the chaser steers toward (the player's lane).
var target_x: float = 0.0
var world_speed: float = 0.0

var _cfg: GameConfig = GameConfig.current()
var _body: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null
var _drone: Node3D = null
var _phase: float = 0.0
var _chase_left: float = 0.0
var _goal_z: float = HIDDEN_Z


func _ready() -> void:
	add_to_group(&"chaser")
	collision_setup()
	add_child(VisualProvider.build(&"chaser", _build_visual))
	machine = StateMachine.new()
	add_child(machine)
	machine.add_state(HIDDEN, ChaserState.new(HIDDEN_Z, false), self)
	machine.add_state(CHASE, ChaserState.new(CHASE_Z, true), self)
	machine.add_state(CATCH, ChaserState.new(CATCH_Z, true), self)
	machine.transitioned.connect(func(_from: StringName, to: StringName) -> void:
		GameEvents.chaser_state_changed.emit(to))
	machine.start(HIDDEN)
	position = Vector3(0.0, 0.0, HIDDEN_Z)
	GameEvents.speed_changed.connect(func(speed: float) -> void: world_speed = speed)
	GameEvents.player_stumbled.connect(_on_player_stumbled)
	GameEvents.player_crashed.connect(_on_player_crashed)
	GameEvents.player_revived.connect(hide_now)
	GameEvents.lane_changed.connect(func(_from: int, to: int) -> void: target_x = _cfg.lane_x(to))


## Documented layer use only: the chaser lives on layer 5 and collides with nothing.
func collision_setup() -> void:
	pass


## Sends the chaser off-screen immediately (new run, revive).
func hide_now() -> void:
	machine.transition_to(HIDDEN, true)
	position.z = HIDDEN_Z
	target_x = 0.0
	_chase_left = 0.0


## Sets where the chaser wants to be (called by its states).
func set_goal(z: float, shown: bool) -> void:
	_goal_z = z
	if shown:
		visible = true


## Animates and moves the chaser.
func tick(delta: float) -> void:
	if machine.is_in(CHASE):
		_chase_left -= delta
		if _chase_left <= 0.0:
			machine.transition_to(HIDDEN)
	var lag: float = 0.12 if machine.is_in(CATCH) else 0.45
	position.z = MathUtils.damp(position.z, _goal_z, lag, delta)
	position.x = MathUtils.damp(position.x, target_x, 0.2, delta)
	if machine.is_in(HIDDEN) and position.z > HIDDEN_Z - 0.3:
		visible = false
	if not visible or _body == null:
		return
	_phase += delta * (10.0 + world_speed * 0.2)
	var swing: float = sin(_phase)
	_leg_l.rotation.x = swing * 0.8
	_leg_r.rotation.x = -swing * 0.8
	_body.position.y = absf(swing) * 0.08
	_body.rotation.x = -0.2 if not machine.is_in(CATCH) else -0.5
	_drone.position = Vector3(1.1 + sin(_phase * 0.3) * 0.2, 1.7 + sin(_phase * 0.5) * 0.15, -0.6)
	_drone.rotate_y(delta * 6.0)


func _on_player_stumbled(_kind: StringName) -> void:
	_chase_left = _cfg.stumble_window
	machine.transition_to(CHASE, true)


func _on_player_crashed(kind: StringName) -> void:
	if kind != &"gap":
		machine.transition_to(CATCH, true)


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	_body = Node3D.new()
	root.add_child(_body)
	var armor: ShaderMaterial = Mats.lit(Color(0.16, 0.17, 0.24))
	var dark: ShaderMaterial = Mats.lit(Color(0.07, 0.07, 0.1))
	var eye: ShaderMaterial = Mats.lit(Color.BLACK, Color(1.0, 0.15, 0.15), 3.0)
	_body.add_child(MeshLib.mi(MeshLib.box(), armor, Vector3(0.0, 1.35, 0.0), Vector3(0.95, 0.9, 0.6)))
	_body.add_child(MeshLib.mi(MeshLib.box(), dark, Vector3(0.0, 2.0, 0.0), Vector3(0.6, 0.4, 0.5)))
	_body.add_child(MeshLib.mi(MeshLib.box(), eye, Vector3(0.0, 2.02, -0.26), Vector3(0.46, 0.1, 0.04)))
	_body.add_child(MeshLib.mi(MeshLib.box(), eye, Vector3(0.0, 1.5, -0.31), Vector3(0.3, 0.3, 0.03)))
	_body.add_child(MeshLib.mi(MeshLib.box(), armor, Vector3(-0.66, 1.4, -0.1), Vector3(0.24, 0.8, 0.26)))
	_body.add_child(MeshLib.mi(MeshLib.box(), armor, Vector3(0.66, 1.4, -0.1), Vector3(0.24, 0.8, 0.26)))
	_leg_l = _leg(Vector3(-0.26, 0.95, 0.0), dark)
	_leg_r = _leg(Vector3(0.26, 0.95, 0.0), dark)
	_body.add_child(_leg_l)
	_body.add_child(_leg_r)
	_drone = Node3D.new()
	_drone.add_child(MeshLib.mi(MeshLib.sphere(), armor, Vector3.ZERO, Vector3(0.5, 0.36, 0.5)))
	_drone.add_child(MeshLib.mi(MeshLib.box(), eye, Vector3(0.0, 0.0, -0.24), Vector3(0.2, 0.08, 0.04)))
	_drone.add_child(MeshLib.mi(MeshLib.box(), dark, Vector3(0.0, 0.22, 0.0), Vector3(0.9, 0.03, 0.1)))
	root.add_child(_drone)
	return root


func _leg(joint: Vector3, material: ShaderMaterial) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = joint
	pivot.add_child(MeshLib.mi(MeshLib.box(), material, Vector3(0.0, -0.47, 0.0), Vector3(0.26, 0.95, 0.3)))
	return pivot


## One class serves all three chaser states: each just declares where the chaser should be.
class ChaserState extends State:
	var _z: float = 0.0
	var _shown: bool = false

	func _init(z: float, shown: bool) -> void:
		_z = z
		_shown = shown

	func enter(_prev: StringName) -> void:
		(host as Chaser).set_goal(_z, _shown)

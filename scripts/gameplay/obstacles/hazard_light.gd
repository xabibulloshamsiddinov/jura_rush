## Blinking signal post placed at a lane edge. Harmless: it only telegraphs trouble ahead.
class_name HazardLight
extends ObstacleBase

var _lamp: MeshInstance3D = null
var _time: float = 0.0


func setup(p_def: ObstacleDef) -> void:
	super.setup(p_def)
	needs_tick = true


func configure(p_lane: int, x: float, z_center: float, run_length: float) -> void:
	super.configure(p_lane, x, z_center, run_length)
	# Stand between lanes so it never sits in the running line.
	position.x += 0.98 if p_lane <= 1 else -0.98


func blocks(_feet_y: float, _top_y: float, _dz: float, _step: float) -> bool:
	return false


func tick(delta: float, _world_speed: float, _chunk_z: float) -> void:
	_time += delta
	_lamp.visible = fmod(_time, 0.5) < 0.28


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	root.add_child(MeshLib.mi(MeshLib.box(), Mats.lit(def.color), Vector3(0.0, def.size.y * 0.5, 0.0),
			Vector3(0.1, def.size.y, 0.1)))
	_lamp = MeshLib.mi(MeshLib.sphere(), Mats.lit(Color.BLACK, def.glow, 3.0),
			Vector3(0.0, def.size.y, 0.0), Vector3(0.38, 0.38, 0.38))
	root.add_child(_lamp)
	return root

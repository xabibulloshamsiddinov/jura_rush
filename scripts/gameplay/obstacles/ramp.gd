## Ramp leading up to a sauropod's back. Running into its low end is safe (the ground just rises);
## stepping into its side while it is already tall is a stumble.
## Visual: when ChunkBuilder pairs it with a herd (set_paired) the Brachiosaurus tail IS the ramp
## and this node draws nothing; on its own it is a mossy rock slope with the same incline.
class_name Ramp
extends ObstacleBase

const PREWARM_LENGTHS: Array[float] = [3.0, 6.0, 9.0]

var paired: bool = false

var _rock: MeshInstance3D = null


func setup(p_def: ObstacleDef) -> void:
	super.setup(p_def)
	shapes_ground = true


func on_acquire() -> void:
	super.on_acquire()
	set_paired(false)


## True: a sauropod's tail forms this ramp, so the rock is hidden.
func set_paired(value: bool) -> void:
	paired = value
	if _rock != null:
		_rock.visible = not value


func ground_height_at(dz: float) -> float:
	return _height_at(dz)


func blocks(feet_y: float, _top_y: float, dz: float, step: float) -> bool:
	return feet_y < _height_at(dz) - step


## Ramp surface height: 0 at the near end, def.size.y at the far end.
func _height_at(dz: float) -> float:
	return def.size.y * clampf((length * 0.5 - dz) / maxf(length, 0.01), 0.0, 1.0)


func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	for l: float in PREWARM_LENGTHS:
		RockSlope.mesh(l, def.size.y)
	_rock = MeshInstance3D.new()
	_rock.material_override = CreatureMats.skin(&"rock")
	_rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_rock.extra_cull_margin = 4.0
	root.add_child(_rock)
	return root


func _apply_length() -> void:
	if _rock != null:
		_rock.mesh = RockSlope.mesh(length, def.size.y)

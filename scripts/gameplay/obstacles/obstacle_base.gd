## Base class of every obstacle (Template Method). Collision is a deterministic box test done by
## CollisionSystem; subclasses customise visuals, ground shaping and the hit hooks.
## The node origin sits at ground level in the middle of the obstacle's footprint.
class_name ObstacleBase
extends Node3D

## Returned by ground_height_at() when the obstacle offers no walkable surface.
const NO_GROUND: float = -1000.0

var def: ObstacleDef = null
var lane: int = 0
## Extent along the track in metres.
var length: float = 0.3
var half_width: float = 0.85
var y_min: float = 0.0
var y_max: float = 1.0
## True once it has hit (or been ghosted by) the player during this pass.
var ghost: bool = false
## Set by CollisionSystem when the player came within the near-miss margin.
var near_flag: bool = false
## Smashed by a shield or dash: invisible and non-colliding until recycled.
var disabled: bool = false
## True when tick() must be called every physics frame.
var needs_tick: bool = false
## True when it changes the ground height (roofs, ramps, gaps).
var shapes_ground: bool = false
## How far the visual reaches beyond the far end (-Z) of the collision box, in metres (necks,
## tails). TrackManager hides a passed obstacle only once this part is behind the runner too.
var far_overhang: float = 0.0

var _visual: Node3D = null


## One-time initialisation right after creation (builds the visual).
func setup(p_def: ObstacleDef) -> void:
	def = p_def
	half_width = def.size.x * 0.5
	y_min = def.y_offset
	y_max = def.y_offset + def.size.y
	shapes_ground = def.walkable_top
	needs_tick = def.moving
	_visual = VisualProvider.build(def.id, _build_visual)
	add_child(_visual)


## Places the obstacle inside its chunk. `run_length` is used when the def has no fixed depth.
func configure(p_lane: int, x: float, z_center: float, run_length: float) -> void:
	lane = p_lane
	length = def.size.z if def.size.z > 0.0 else run_length
	position = Vector3(x, 0.0, z_center)
	_apply_length()


## Pool hook: reset per-pass state.
func on_acquire() -> void:
	ghost = false
	near_flag = false
	disabled = false
	visible = true


## Pool hook.
func on_release() -> void:
	pass


## Template method: called by CollisionSystem when the player's box overlaps this obstacle.
func on_player_hit(player: Player, side: bool) -> void:
	if ghost or disabled:
		return
	ghost = true
	if player.is_invulnerable():
		return
	var type: ObstacleDef.HitType = _hit_type(side)
	_before_hit(player, side)
	if type != ObstacleDef.HitType.SOFT:
		player.take_hit(type == ObstacleDef.HitType.LETHAL, def.id, self, side)
	_after_hit(player, type)


## Visual warning before the obstacle becomes dangerous (fairness telegraph).
func telegraph() -> void:
	pass


## Per-frame update for obstacles with needs_tick (chunk_z = parent chunk's near-edge z).
func tick(_delta: float, _world_speed: float, _chunk_z: float) -> void:
	pass


## Walkable surface height under a point `dz` metres from the obstacle centre (+ = toward camera).
func ground_height_at(_dz: float) -> float:
	return y_max if def.walkable_top else NO_GROUND


## Vertical part of the collision test. Walkable tops can be stepped onto within `step`.
func blocks(feet_y: float, top_y: float, _dz: float, step: float) -> bool:
	if def.walkable_top and feet_y >= y_max - step:
		return false
	return feet_y < y_max - 0.05 and top_y > y_min + 0.05


## Destroys the obstacle for this pass (shield, dash).
func smash() -> void:
	if disabled:
		return
	disabled = true
	visible = false
	GameEvents.obstacle_smashed.emit(global_position + Vector3(0.0, (y_min + y_max) * 0.5, 0.0))


## Hook: which hit type applies.
func _hit_type(side: bool) -> ObstacleDef.HitType:
	return def.side_hit_type if side else def.hit_type


## Hook: runs before the player is told about the hit.
func _before_hit(_player: Player, _side: bool) -> void:
	pass


## Hook: runs after the hit was applied.
func _after_hit(_player: Player, _type: ObstacleDef.HitType) -> void:
	pass


## Hook: builds the primitive visual (replaced by assets/meshes/<id>.glb when present).
func _build_visual() -> Node3D:
	return Node3D.new()


## Adds the faint chevron marker painted on the rails just in front of the obstacle (toward the
## player), so the danger lane reads before the obstacle itself is clear.
## Switch off with VisualTuning.FEATURE_LANE_WARNING.
func _add_lane_warning(root: Node3D, color: Color) -> void:
	if not VisualTuning.FEATURE_LANE_WARNING:
		return
	var marker_len: float = VisualTuning.LANE_WARNING_LENGTH
	var z: float = maxf(def.size.z, 0.3) * 0.5 + VisualTuning.LANE_WARNING_GAP + marker_len * 0.5
	root.add_child(MeshLib.mi(MeshLib.plane(), Mats.lane_warning(color), Vector3(0.0, 0.015, z),
			Vector3(VisualTuning.LANE_WARNING_WIDTH, 1.0, marker_len)))


## Hook: adapts the visual to the configured length.
func _apply_length() -> void:
	pass

## Data definition of one obstacle type. The factory builds pooled nodes from these.
class_name ObstacleDef
extends Resource

enum HitType { LETHAL, STUMBLE, SOFT }

## Unique id, also the pool id and the VisualProvider key.
@export var id: StringName = &""
## Script kind used by ObstacleFactory: train, barrier_low, barrier_high, barrier_full, ramp, gap, hazard_light.
@export var kind: StringName = &""
## What a frontal hit does.
@export var hit_type: HitType = HitType.STUMBLE
## What a sideways hit (lane change into it) does.
@export var side_hit_type: HitType = HitType.STUMBLE
## Collision box: x = width, y = height, z = depth. Depth 0 means "use the run length".
@export var size: Vector3 = Vector3(1.7, 1.0, 0.3)
## Height of the box bottom above the ground.
@export var y_offset: float = 0.0
## True when the player can stand on top (train roofs).
@export var walkable_top: bool = false
## True when the obstacle drives toward the player.
@export var moving: bool = false
@export var color: Color = Color(0.2, 0.25, 0.4)
@export var glow: Color = Color(0.0, 0.9, 1.0)
## Instances pre-created at boot.
@export var pool_size: int = 6

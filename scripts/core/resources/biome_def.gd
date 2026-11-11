## Colour theme of a stretch of track. Biomes cross-fade through global shader parameters.
class_name BiomeDef
extends Resource

@export var id: StringName = &""
@export var name_key: StringName = &""
@export var sky_top: Color = Color(0.02, 0.02, 0.08)
@export var sky_horizon: Color = Color(0.2, 0.05, 0.35)
@export var fog: Color = Color(0.1, 0.04, 0.22)
@export var accent: Color = Color(0.0, 0.9, 1.0)
@export var accent2: Color = Color(1.0, 0.2, 0.8)
@export var light: Color = Color(0.8, 0.85, 1.0)
@export var fog_density_scale: float = 1.0
## Decor set index used by chunks recycled inside this biome (0 towers, 1 warehouses, 2 pylons).
@export var decor_set: int = 0

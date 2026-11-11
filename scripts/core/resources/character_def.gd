## A playable skin: colours, proportions and one accessory, all built from primitives.
class_name CharacterDef
extends Resource

@export var id: StringName = &""
@export var name_key: StringName = &""
@export var price: int = 0
@export var body_color: Color = Color(0.1, 0.75, 0.95)
@export var limb_color: Color = Color(0.12, 0.13, 0.25)
@export var head_color: Color = Color(0.95, 0.8, 0.65)
@export var glow_color: Color = Color(1.0, 0.25, 0.8)
## none, cap, visor, antenna, backpack, scarf.
@export var accessory: StringName = &"none"
## Overall body width multiplier (0.85 slim .. 1.2 bulky).
@export var bulk: float = 1.0

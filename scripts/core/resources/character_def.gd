## A playable caveman skin: colours, fur pattern, hair, build and one accessory. The body is
## built procedurally (CavemanModel); a skin only recolours and reshapes it.
## Field names are read by the shop and its thumbnails; keep them stable.
class_name CharacterDef
extends Resource

@export var id: StringName = &""
@export var name_key: StringName = &""
@export var price: int = 0
## Fur tunic, shawl and foot-wrap base colour.
@export var body_color: Color = Color(0.86, 0.56, 0.22)
## Fur markings (spots, stripes, leaf veins, patches). Also the limb colour of the shop thumbnail.
@export var limb_color: Color = Color(0.30, 0.17, 0.08)
## Skin tone.
@export var head_color: Color = Color(0.86, 0.63, 0.46)
## Hair, beard and eyebrows.
@export var hair_color: Color = Color(0.20, 0.12, 0.07)
## Accent: feathers, war paint and the shop row colour.
@export var glow_color: Color = Color(1.0, 0.8, 0.35)
## Belt knot, cords and straps.
@export var leather_color: Color = Color(0.40, 0.25, 0.13)
## Stored values kept from the first release, reinterpreted for the caveman:
##   none, cap (bone through a hair top-knot), visor (raptor-skull helmet),
##   antenna (feather headband), backpack (stone club on the back),
##   scarf (tooth necklace and fur shawl).
@export var accessory: StringName = &"none"
## Overall body width multiplier (0.85 slim .. 1.2 bulky).
@export var bulk: float = 1.0
## Whole-body size (Pip is a little smaller). Visual only, the collider does not change.
@export var height_scale: float = 1.0
## spots, stripes, leaves, patches or plain.
@export var fur_pattern: StringName = &"spots"
## Pattern size multiplier (higher = smaller marks).
@export var pattern_scale: float = 1.0
## mop, flame, long or short.
@export var hair_style: StringName = &"mop"
## 0 = clean shaven, 1 = full short beard.
@export var beard_size: float = 1.0

## The currency icon: a speckled dinosaur egg drawn with the 2D canvas (no texture, scales cleanly
## to any size). The class keeps its old name so every counter, price tag and reward row that
## shows an amount of eggs still uses `CoinIcon`; the drawing itself lives in UIIcon.
class_name CoinIcon
extends Control

## Diameter in UI pixels.
@export var diameter: float = 48.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(value, value)
		queue_redraw()
## Draws the egg greyed out (for unaffordable / disabled states).
@export var dimmed: bool = false:
	set(value):
		dimmed = value
		queue_redraw()


func _init(p_diameter: float = 48.0) -> void:
	diameter = p_diameter
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	UIIcon.paint(self, UIIcon.Kind.EGG, Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s)),
			0.0 if dimmed else 1.0)

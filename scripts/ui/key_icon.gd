## The revive currency icon: a faceted amber gem, drawn like CoinIcon so it scales cleanly. The
## class keeps its old name (revive keys are still "keys" in the save data and the code); the
## player sees amber.
class_name KeyIcon
extends Control

@export var diameter: float = 48.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(value, value)
		queue_redraw()
## Draws the gem greyed out.
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
	UIIcon.paint(self, UIIcon.Kind.AMBER, Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s)),
			0.0 if dimmed else 1.0)

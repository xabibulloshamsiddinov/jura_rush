## Pooled floating label ("+50 NEAR!", "+1" flying to the coin counter).
class_name FloatingText
extends Label

var _tween: Tween = null


func _init() -> void:
	add_theme_font_override(&"font", UIKit.font())
	add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	add_theme_constant_override(&"outline_size", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Pool hook.
func on_release() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


## Shows text at a canvas position, drifting to `target` while fading, then returns to the pool.
func launch(content: String, from: Vector2, target: Vector2, color: Color, font_size: int,
		duration: float) -> void:
	text = content
	add_theme_font_size_override(&"font_size", font_size)
	add_theme_color_override(&"font_color", color)
	reset_size()
	position = from - size * 0.5
	modulate.a = 1.0
	scale = Vector2.ONE
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", target - size * 0.5, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	_tween.chain().tween_callback(func() -> void: PoolManager.release(&"floating_text", self))

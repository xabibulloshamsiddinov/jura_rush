## Tween helpers shared by all screens (pop, slide, fade, count-up, pulse, shine).
class_name UITween
extends RefCounted


## Scales around the middle even before the first layout pass (size is 0 until then): the pivot
## follows the control whenever it is resized.
static func center_pivot(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	if not node.has_meta(&"pivot_hook"):
		node.set_meta(&"pivot_hook", true)
		node.resized.connect(func() -> void: node.pivot_offset = node.size * 0.5)


## Scale "pop" from small to full size with a little overshoot.
static func pop(node: Control, delay: float = 0.0, from: float = 0.6) -> Tween:
	center_pivot(node)
	node.scale = Vector2(from, from)
	node.modulate.a = 0.0
	var tween: Tween = node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector2.ONE, 0.32).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.18).set_delay(delay)
	return tween


## Quick scale bump (counter changed).
static func bump(node: Control, amount: float = 1.25) -> void:
	center_pivot(node)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2(amount, amount), 0.06)
	tween.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fades a node to an alpha.
static func fade(node: CanvasItem, to: float, duration: float = 0.2) -> Tween:
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate:a", to, duration)
	return tween


## Slides a full-rect control in from an offset (in pixels) while fading in.
static func slide_in(node: Control, offset: Vector2, duration: float = 0.28) -> Tween:
	node.position = offset
	node.modulate.a = 0.0
	var tween: Tween = node.create_tween().set_parallel(true)
	tween.tween_property(node, "position", Vector2.ZERO, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration * 0.7)
	return tween


## Animated number count-up on a label ("prefix 1 234").
static func count_up(label: Label, to: int, duration: float, prefix: String = "",
		delay: float = 0.0) -> Tween:
	var tween: Tween = label.create_tween()
	tween.tween_method(func(value: float) -> void:
		label.text = prefix + MathUtils.group_digits(int(value)), 0.0, float(to), duration) \
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween


## Endless gentle pulse (the PLAY button, "tap to play").
static func pulse(node: Control, amount: float = 1.06, period: float = 0.9) -> Tween:
	center_pivot(node)
	var tween: Tween = node.create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2(amount, amount), period * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, period * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


## A bright bar sweeping across a control once (reward shine).
static func shine(target: Control) -> void:
	var bar: ColorRect = ColorRect.new()
	bar.color = Color(1.0, 1.0, 1.0, 0.35)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size = Vector2(60.0, target.size.y * 1.6)
	bar.rotation = 0.35
	bar.position = Vector2(-120.0, -target.size.y * 0.3)
	target.clip_contents = true
	target.add_child(bar)
	var tween: Tween = bar.create_tween()
	tween.tween_property(bar, "position:x", target.size.x + 120.0, 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(bar.queue_free)

## "coin icon + amount" pill. `text` sets the number part, so callers that used a Label keep
## working (count-up tweens animate `text` too).
class_name CoinCounter
extends HBoxContainer

var icon: CoinIcon = null
var label: Label = null

var text: String:
	get:
		return label.text
	set(value):
		label.text = value


func _init(font_size: int = 36, color: Color = Color(1.0, 0.86, 0.1),
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	add_theme_constant_override(&"separation", int(font_size * 0.25))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		alignment = BoxContainer.ALIGNMENT_END
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		alignment = BoxContainer.ALIGNMENT_CENTER
	icon = CoinIcon.new(float(UIKit.scaled(font_size)) * 0.95)
	add_child(icon)
	label = UIKit.label("0", font_size, color, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(label)


## Shows a number with digit grouping (12 345).
func set_amount(value: int) -> void:
	label.text = MathUtils.group_digits(value)

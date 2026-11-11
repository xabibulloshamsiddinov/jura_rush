## Screen-space effects on a CanvasLayer: speed lines, vignette, white / coloured flashes, the
## red danger edge and the chromatic-aberration pulse. Driven by VFXManager.
class_name ScreenFx
extends CanvasLayer

const FX_SHADER: Shader = preload("res://assets/shaders/screen_fx.gdshader")
const CHROMA_SHADER: Shader = preload("res://assets/shaders/chroma.gdshader")

var _overlay: ColorRect = null
var _chroma: ColorRect = null
var _material: ShaderMaterial = null
var _chroma_material: ShaderMaterial = null
var _flash: float = 0.0
var _flash_decay: float = 4.0
var _edge: float = 0.0
var _chroma_amount: float = 0.0
var _speed_lines: float = 0.0
var _speed_target: float = 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_chroma_material = ShaderMaterial.new()
	_chroma_material.shader = CHROMA_SHADER
	_chroma = _full_rect(_chroma_material)
	_chroma.visible = false
	_material = ShaderMaterial.new()
	_material.shader = FX_SHADER
	_overlay = _full_rect(_material)


func _process(delta: float) -> void:
	_speed_lines = move_toward(_speed_lines, _speed_target, delta * 1.5)
	_flash = maxf(_flash - delta * _flash_decay, 0.0)
	_edge = maxf(_edge - delta * 1.8, 0.0)
	_material.set_shader_parameter(&"speed_lines", _speed_lines)
	_material.set_shader_parameter(&"flash", _flash)
	_material.set_shader_parameter(&"edge", _edge)
	if _chroma.visible:
		_chroma_amount = maxf(_chroma_amount - delta * 2.5, 0.0)
		_chroma_material.set_shader_parameter(&"amount", _chroma_amount)
		if _chroma_amount <= 0.0:
			_chroma.visible = false


## Speed-line strength 0..1 (eased toward).
func set_speed_lines(amount: float) -> void:
	_speed_target = clampf(amount, 0.0, 1.0)


## Full-screen colour flash that fades out over `duration` seconds.
func flash(color: Color, amount: float, duration: float) -> void:
	_material.set_shader_parameter(&"flash_color", color)
	_flash = amount
	_flash_decay = amount / maxf(duration, 0.02)


## Red pulse around the screen edges (stumble, crash).
func danger_edge(amount: float) -> void:
	_edge = maxf(_edge, amount)


## Chromatic aberration pulse (skipped on Low quality / reduced effects by the caller).
func chroma_pulse(amount: float) -> void:
	_chroma_amount = amount
	_chroma.visible = true


func _full_rect(material: ShaderMaterial) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	return rect

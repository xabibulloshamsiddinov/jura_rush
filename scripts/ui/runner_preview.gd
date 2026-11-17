## 3D preview for the shop: a SubViewport with its own World3D showing the selected runner on a
## slowly turning stone pedestal under a warm light, its trail as a soft rounded strip on the
## ground behind it, or a glowing amber orb for power-ups and items. Renders only while visible
## (SubViewport UPDATE_WHEN_VISIBLE), so it costs nothing outside the shop.
##
## Only built-in meshes and materials are used here (no dependency on the world's material
## library); the runner itself is a PlayerVisual and is driven through its public API.
class_name RunnerPreview
extends SubViewportContainer

const TURN_SPEED: float = 0.55
const STONE: Color = Color(0.58, 0.52, 0.44)
const STONE_DARK: Color = Color(0.40, 0.35, 0.30)
const STRIP_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	float across = 1.0 - pow(abs(UV.x * 2.0 - 1.0), 2.2);
	float along = 1.0 - smoothstep(0.0, 1.0, UV.y);
	ALBEDO = tint.rgb;
	ALPHA = clamp(across * along * 1.6, 0.0, 1.0) * tint.a;
}
"""

static var _strip_shader_cache: Shader = null

var _viewport: SubViewport = null
var _turntable: Node3D = null
var _visual: PlayerVisual = null
var _strip: MeshInstance3D = null
var _orb: MeshInstance3D = null


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 30.0
	camera.current = true
	camera.environment = _environment()
	_viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.5, 5.1), Vector3(0.0, 0.78, 0.0))
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 1.25
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	_viewport.add_child(light)
	_build_pedestal()
	_turntable = Node3D.new()
	_viewport.add_child(_turntable)
	_visual = PlayerVisual.new()
	_turntable.add_child(_visual)
	_strip = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(0.8, 1.9)
	_strip.mesh = quad
	# Lies on the ground behind the runner (forward is -Z), from its heels backwards.
	_strip.position = Vector3(0.0, 0.03, 1.05)
	_turntable.add_child(_strip)
	_orb = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 1.0
	_orb.mesh = sphere
	_orb.scale = Vector3(0.88, 1.0, 0.88)
	_orb.position = Vector3(0.0, 1.0, 0.0)
	_turntable.add_child(_orb)
	show_character(ContentDB.character(SaveSystem.equipped(&"character")))


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _turntable == null:
		return
	_turntable.rotation.y += delta * TURN_SPEED
	if _visual.visible:
		_visual.animate(delta, 9.0, 0.0)
	if _orb.visible:
		_orb.position.y = 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.08


## Shows a runner skin (instant, no reload).
func show_character(def: CharacterDef) -> void:
	if def == null or _visual == null:
		return
	_visual.visible = true
	_visual.apply_character(def)
	_visual.set_pose(PlayerVisual.Pose.IDLE)
	_strip.visible = false
	_orb.visible = false


## Shows the equipped runner with its trail: a soft rounded strip on the ground in the trail colour.
func show_trail(def: TrailDef) -> void:
	if def == null or _visual == null:
		return
	show_character(ContentDB.character(SaveSystem.equipped(&"character")))
	_visual.set_pose(PlayerVisual.Pose.RUN)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _strip_shader()
	material.set_shader_parameter(&"tint", def.color)
	_strip.material_override = material
	(_strip.mesh as QuadMesh).size = Vector2(maxf(def.width, 0.3) * 1.7, 1.9)
	_strip.visible = true


## Shows a glowing amber orb (power-up upgrades and consumable items).
func show_orb(color: Color) -> void:
	if _visual == null:
		return
	_visual.visible = false
	_strip.visible = false
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.9
	material.roughness = 0.25
	_orb.material_override = material
	_orb.visible = true


## Two stacked stone slabs with a warm pool of light on top.
func _build_pedestal() -> void:
	var base: MeshInstance3D = _slab(1.0, 0.14, STONE_DARK)
	base.position = Vector3(0.0, -0.1, 0.0)
	_viewport.add_child(base)
	var top: MeshInstance3D = _slab(0.82, 0.09, STONE)
	top.position = Vector3(0.0, -0.03, 0.0)
	_viewport.add_child(top)
	var glow: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	quad.orientation = PlaneMesh.FACE_Y
	glow.mesh = quad
	glow.position = Vector3(0.0, 0.025, 0.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = _glow_texture()
	glow.material_override = material
	_viewport.add_child(glow)


func _slab(radius: float, height: float, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.03
	mesh.height = height
	mesh.radial_segments = 40
	node.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	node.material_override = material
	return node


## Soft strip: rounded across the width, fading out along its length (the near end is the runner).
func _strip_shader() -> Shader:
	if _strip_shader_cache == null:
		_strip_shader_cache = Shader.new()
		_strip_shader_cache.code = STRIP_SHADER
	return _strip_shader_cache


## Soft warm radial gradient for the light pool.
func _glow_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 0.72, 0.3, 0.55), Color(1.0, 0.6, 0.2, 0.18), Color(1.0, 0.5, 0.1, 0.0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.56, 0.5)
	env.ambient_light_energy = 0.9
	return env

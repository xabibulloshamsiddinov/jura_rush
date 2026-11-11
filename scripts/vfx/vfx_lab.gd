## VFX lab (run scenes/vfx/vfx_lab.tscn): one button per effect, played in front of a camera.
extends Control

const ORIGIN: Vector3 = Vector3(0.0, 1.0, 0.0)


func _ready() -> void:
	VFXManager.prewarm()
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 2.2, 7.0)
	add_child(camera)
	camera.look_at(ORIGIN)
	var floor_mesh: MeshInstance3D = MeshLib.mi(MeshLib.box(), Mats.lit(Color(0.08, 0.09, 0.16)),
			Vector3(0.0, -0.1, 0.0), Vector3(14.0, 0.2, 14.0))
	add_child(floor_mesh)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.02, 0.02, 0.06)
	environment.environment.glow_enabled = true
	add_child(environment)
	RenderingServer.global_shader_parameter_set(&"fog_end", 500.0)
	RenderingServer.global_shader_parameter_set(&"fog_start", 400.0)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(24.0, 24.0)
	add_child(grid)
	for id: StringName in VfxFactory.POOL_SIZES.keys():
		_button(grid, String(id), func() -> void: VFXManager.play(id, ORIGIN))
	_button(grid, "ring", func() -> void: VFXManager.ring(ORIGIN, Color(0.4, 0.8, 1.0), 0.4, 4.0, 0.5))
	_button(grid, "streak", func() -> void: VFXManager.streak(ORIGIN, Color(0.6, 0.9, 1.0), 7.0, 0.3))
	_button(grid, "flash", func() -> void: VFXManager.screen.flash(Color.WHITE, 0.9, 0.15))
	_button(grid, "danger edge", func() -> void: VFXManager.screen.danger_edge(1.0))
	_button(grid, "chroma", func() -> void: VFXManager.screen.chroma_pulse(1.0))
	_button(grid, "speed lines on", func() -> void: VFXManager.screen.set_speed_lines(1.0))
	_button(grid, "speed lines off", func() -> void: VFXManager.screen.set_speed_lines(0.0))
	_button(grid, "confetti", func() -> void: VFXManager.play_ui(&"confetti", size * 0.5))
	_button(grid, "camera shake", func() -> void: GameEvents.camera_trauma.emit(0.8))


func _button(parent: Control, title: String, action: Callable) -> void:
	var b: Button = Button.new()
	b.text = title
	b.custom_minimum_size = Vector2(320.0, 96.0)
	b.add_theme_font_size_override(&"font_size", 30)
	b.pressed.connect(action)
	parent.add_child(b)

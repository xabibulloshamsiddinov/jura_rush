## Audio lab (run scenes/vfx/audio_lab.tscn): audition every sound, the music modes and the
## adaptive intensity slider.
extends Control

var _status: Label = null


func _ready() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(24.0, 24.0)
	add_child(column)
	_status = Label.new()
	_status.text = "Synthesising sounds..."
	_status.add_theme_font_size_override(&"font_size", 30)
	column.add_child(_status)
	await AudioManager.build_async(func(p: float) -> void: _status.text = "Synthesising %d%%" % int(p * 100.0))
	_status.text = "Ready"
	var modes: HBoxContainer = HBoxContainer.new()
	column.add_child(modes)
	for mode: StringName in [&"menu", &"game", &"off"]:
		_button(modes, "music: " + String(mode), func() -> void: AudioManager.set_music_mode(mode))
	var slider: HSlider = HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(900.0, 80.0)
	slider.value_changed.connect(func(value: float) -> void:
		AudioManager.set_intensity(value)
		_status.text = "Adaptive intensity %.2f (drums, bass and lead fade in)" % value)
	column.add_child(slider)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	column.add_child(grid)
	for id: StringName in AudioManager.sound_ids():
		var loop: bool = bool((SfxLibrary.DEFS[id] as Array)[4])
		if loop:
			_button(grid, String(id) + " (loop)", func() -> void:
				AudioManager.set_loop(id, 1.0)
				get_tree().create_timer(2.0).timeout.connect(func() -> void: AudioManager.set_loop(id, 0.0)))
		elif id == &"coin":
			_button(grid, "coin (chain)", func() -> void: AudioManager.play_coin())
		else:
			_button(grid, String(id), func() -> void: AudioManager.play(id))


func _button(parent: Control, title: String, action: Callable) -> void:
	var b: Button = Button.new()
	b.text = title
	b.custom_minimum_size = Vector2(250.0, 84.0)
	b.add_theme_font_size_override(&"font_size", 24)
	b.pressed.connect(action)
	parent.add_child(b)

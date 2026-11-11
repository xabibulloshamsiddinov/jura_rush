## Small performance readout (Settings > Show FPS, works in release builds): FPS, frame time,
## draw calls, visible objects and static memory, refreshed twice a second. With the command line
## flag `-- --perf-log` the same line is also printed every 2 s (profiling on a device / CI).
class_name PerfOverlay
extends Label

const REFRESH: float = 0.5

var _timer: float = 0.0
var _log_timer: float = 0.0
var _log: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override(&"font", UIKit.font())
	add_theme_font_size_override(&"font_size", 26)
	add_theme_color_override(&"font_color", Color(0.4, 1.0, 0.6))
	add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override(&"outline_size", 8)
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	position = Vector2(24.0, -64.0)
	_log = OS.get_cmdline_user_args().has("--perf-log")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	GameEvents.settings_changed.connect(_apply)
	_apply()


func _apply() -> void:
	visible = SettingsManager.get_bool("show_fps")
	set_process(visible or _log)


func _process(delta: float) -> void:
	_timer -= delta
	_log_timer -= delta
	if _timer > 0.0 and _log_timer > 0.0:
		return
	var vp: RID = get_viewport().get_viewport_rid()
	var line: String = "FPS %d  cpu %.1f ms  render cpu %.1f / gpu %.1f ms  draws %d  objects %d  mem %.0f MB" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(vp),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]
	if _timer <= 0.0:
		_timer = REFRESH
		text = line
	if _log and _log_timer <= 0.0:
		_log_timer = 2.0
		print("[perf] ", line)

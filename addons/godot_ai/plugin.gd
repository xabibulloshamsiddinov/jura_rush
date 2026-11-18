@tool
extends EditorPlugin

## GodotAI - AI coding assistant for Godot.
## Main EditorPlugin entry point.
## Registers the chat panel, wires providers, loads settings.

const PANEL_NAME := "AI Chat"

var _chat_panel: ChatPanel
var _provider_manager: ProviderManager
var _settings: AISettings
var _parsed_focus_chat: Dictionary = {}
var _parsed_send_code: Dictionary = {}
var _proxy_pid: int = -1

## Initialize the plugin: create ProviderManager (must be in tree for HTTP),
## create ChatPanel with injected dependencies, connect settings_saved to
## keep shortcut cache in sync, and register the dock panel.
func _enter_tree() -> void:
	_settings = AISettings.new()
	_settings.load()

	_provider_manager = ProviderManager.new()
	add_child(_provider_manager)
	_provider_manager.apply_settings(_settings)

	_chat_panel = ChatPanel.new()
	_chat_panel.setup(_provider_manager, _settings, get_editor_interface())
	_chat_panel.set_proxy_controls(start_claude_proxy, stop_claude_proxy, is_claude_proxy_running)
	_chat_panel.settings_saved.connect(_on_chat_settings_saved)

	_chat_panel.name = PANEL_NAME
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _chat_panel)

	_cache_shortcuts()
	_autostart_proxy_if_needed(_settings)

## Teardown: stop the proxy, remove the dock panel, and free all nodes.
## Settings are not re-saved here: the Settings dialog already writes them on
## Save, and re-saving would overwrite edits made to the file while the editor ran.
func _exit_tree() -> void:
	stop_claude_proxy()
	if _chat_panel:
		remove_control_from_docks(_chat_panel)
		_chat_panel.queue_free()
		_chat_panel = null

	if _provider_manager:
		_provider_manager.queue_free()
		_provider_manager = null

	_settings = null

func _cache_shortcuts() -> void:
	_parsed_focus_chat = AISettings.parse_shortcut(_settings.shortcut_focus_chat)
	_parsed_send_code = AISettings.parse_shortcut(_settings.shortcut_send_code)

func _on_chat_settings_saved(s: AISettings) -> void:
	_cache_shortcuts()
	_autostart_proxy_if_needed(s)

## Global shortcut handler. Uses _shortcut_input() instead of _input() because
## it fires before UI controls consume the event, so shortcuts work even when
## a TextEdit or other input node has focus.
func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if AISettings.matches_event(key_event, _parsed_focus_chat):
		if _chat_panel and _chat_panel._input_field:
			_chat_panel._input_field.grab_focus()
			get_viewport().set_input_as_handled()
	elif AISettings.matches_event(key_event, _parsed_send_code):
		_send_selected_code_to_chat()
		get_viewport().set_input_as_handled()

func _send_selected_code_to_chat() -> void:
	if not _chat_panel:
		return
	var selected := ContextBuilder.get_selected_code(get_editor_interface())
	if selected.is_empty():
		return
	_chat_panel.send_selected_code(selected)

const PROXY_PORT := 8082

## Launches tools/claude_proxy.py as a background process.
## Returns "" on success, or an error string on failure.
func start_claude_proxy() -> String:
	if is_claude_proxy_running():
		return ""
	var proxy_res_path: String = get_script().resource_path.get_base_dir().path_join("tools/claude_proxy.py")
	var script_path := ProjectSettings.globalize_path(proxy_res_path)
	if not FileAccess.file_exists(proxy_res_path):
		return "Proxy script not found at " + proxy_res_path
	var python_cmd := _find_python()
	if python_cmd.is_empty():
		return "Python 3 not found. Install Python 3 to use the built-in proxy."
	var pid := OS.create_process(python_cmd, PackedStringArray([script_path, "--port", str(PROXY_PORT)]))
	if pid <= 0:
		return "Failed to start proxy process."
	_proxy_pid = pid
	return ""

## Finds a real Python 3 interpreter. On Windows the "python3" command is often
## the Microsoft Store stub, which `where` finds but which cannot run scripts,
## so every candidate is actually executed and must report version 3.
## On Windows the windowless pythonw.exe is preferred so no console pops up.
func _find_python() -> String:
	var candidates: Array[String] = ["py", "python", "python3"] if OS.get_name() == "Windows" else ["python3", "python"]
	for cmd in candidates:
		var output := []
		var args := PackedStringArray(["-c", "import sys;print(sys.version_info[0]);print(sys.executable)"])
		if cmd == "py":
			args = PackedStringArray(["-3"]) + args
		var code := OS.execute(cmd, args, output, true)
		if code != 0 or output.is_empty():
			continue
		var lines := str(output[0]).strip_edges().split("\n")
		if lines.size() < 2 or lines[0].strip_edges() != "3":
			continue
		var exe := lines[1].strip_edges()
		if OS.get_name() == "Windows":
			var pythonw := exe.get_base_dir().path_join("pythonw.exe")
			if FileAccess.file_exists(pythonw):
				return pythonw
		return exe if not exe.is_empty() else cmd
	return ""

## Starts the proxy automatically when the Local provider uses the Claude Proxy preset.
func _autostart_proxy_if_needed(settings: AISettings) -> void:
	if settings and settings.active_provider == "local" and settings.local_server_preset == "claude_proxy":
		var err := start_claude_proxy()
		if not err.is_empty():
			push_warning("GodotAI: Claude Proxy could not start: " + err)

## Stops the running proxy process if one was started by the plugin.
func stop_claude_proxy() -> void:
	if _proxy_pid <= 0:
		return
	if OS.is_process_running(_proxy_pid):
		OS.kill(_proxy_pid)
	_proxy_pid = -1

## Returns true if the proxy was started by this plugin and is still alive.
func is_claude_proxy_running() -> bool:
	if _proxy_pid <= 0:
		return false
	if not OS.is_process_running(_proxy_pid):
		_proxy_pid = -1
		return false
	return true

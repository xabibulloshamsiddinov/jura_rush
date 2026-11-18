## Runs every test suite and exits with code 0 (all passed) or 1.
##   godot --headless --path . res://tests/test_runner.tscn
## Dev filter: add -- --only=<text> to run just the test methods whose name contains <text>.
extends Node

const SUITES: Array[String] = [
	"res://tests/test_core.gd",
	"res://tests/test_gameplay.gd",
	"res://tests/test_creatures.gd",
	"res://tests/test_party.gd",
]


func _ready() -> void:
	InputMapSetup.ensure()
	await get_tree().process_frame
	var total_checks: int = 0
	var total_failures: int = 0
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
	for path: String in SUITES:
		var suite: TestCase = (load(path) as GDScript).new() as TestCase
		suite.tree = get_tree()
		print("[suite] %s" % path.get_file())
		for method: Dictionary in suite.get_method_list():
			var method_name: String = str(method["name"])
			if not method_name.begins_with("test_") or (not only.is_empty() and not method_name.contains(only)):
				continue
			var before: int = suite.failures.size()
			suite.begin(method_name)
			@warning_ignore("redundant_await")
			await suite.call(method_name)
			print("  %s %s" % ["ok  " if suite.failures.size() == before else "FAIL", method_name])
		for failure: String in suite.failures:
			print("    ! " + failure)
		total_checks += suite.checks
		total_failures += suite.failures.size()
	print("=== %d checks, %d failed ===" % [total_checks, total_failures])
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().quit(0 if total_failures == 0 else 1)

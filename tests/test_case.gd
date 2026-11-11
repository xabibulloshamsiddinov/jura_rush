## Minimal unit-test base class (no addon needed). Subclasses add methods named test_*.
## Async tests may use await; the runner awaits every test.
class_name TestCase
extends RefCounted

var checks: int = 0
var failures: PackedStringArray = PackedStringArray()
## Scene tree access for tests that need nodes or frames.
var tree: SceneTree = null
var _current: String = ""


## Names the test currently running (set by the runner).
func begin(test_name: String) -> void:
	_current = test_name


## Fails the current test unless `condition` is true.
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [_current, message])


## Fails unless a == b.
func check_eq(a: Variant, b: Variant, message: String) -> void:
	check(a == b, "%s (got %s, expected %s)" % [message, a, b])


## Fails unless |a - b| <= tolerance.
func check_near(a: float, b: float, tolerance: float, message: String) -> void:
	check(absf(a - b) <= tolerance, "%s (got %f, expected %f)" % [message, a, b])

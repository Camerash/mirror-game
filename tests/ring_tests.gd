extends SceneTree

const Rings := preload("res://world/mirror_rings.gd")
const StableArcTests := preload("res://tests/stable_arc_tests.gd")

var _failed := false

func _initialize() -> void:
	_run_standalone.call_deferred()

func _run_standalone() -> void:
	var check := func(condition: bool, description: String) -> void:
		if not condition:
			_failed = true
			push_error("FAIL: " + description)
	run(check)
	await StableArcTests.run(check)
	quit(1 if _failed else 0)

static func run(check: Callable) -> void:
	check.call(is_equal_approx(Rings.angular_delta(PI * 0.9, -PI * 0.9), PI * 0.2), "Arc angles cross the signed wrap")

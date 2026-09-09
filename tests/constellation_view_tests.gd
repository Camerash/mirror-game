extends SceneTree

const PlacementGuide := preload("res://world/placement_guide.gd")

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(800, 600)
	var stage := Node3D.new()
	var camera := Camera3D.new()
	var guide := PlacementGuide.new()
	root.add_child(stage)
	stage.add_child(camera)
	stage.add_child(guide)
	camera.position = Vector3(0, 0, 5)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	camera.force_update_transform()
	await process_frame
	guide.show_guides({"dots": [{"position": Vector3.ZERO, "weight": 1.0}, {"position": Vector3(0.5, 0, 0), "weight": 0.0}], "references": PackedVector3Array([Vector3(-0.5, 0, 0)]), "target": Vector3(0, 0.5, 0)})
	guide.update_view(camera, [], Rect2(Vector2.ZERO, root.size), [])
	var marks := guide.get_visible_marks()
	_check(marks.size() == 3, "Visible data has weighted dot, reference, and target")
	_check(_has_mark(marks, "dot", 0.35), "Candidate dot uses its maximum alpha")
	_check(_has_mark(marks, "reference", 0.85), "Reference mark uses warm alpha")
	_check(_has_mark(marks, "target", 1.0), "Target mark is retained")
	guide.update_view(camera, [], Rect2(Vector2.ZERO, root.size), [Rect2(300, 200, 200, 200)])
	_check(guide.get_visible_marks().is_empty(), "Excluded UI rectangles hide marks")
	guide.update_view(camera, [{"bounds": AABB(Vector3(-0.25, -0.25, 2.0), Vector3(0.5, 0.5, 0.5))}], Rect2(Vector2.ZERO, root.size), [])
	_check(guide.get_visible_marks().is_empty(), "Displayed solids hide marks behind them")
	guide.update_view(camera, [], Rect2(Vector2.ZERO, root.size), [])
	guide.finish()
	guide.finish()
	await create_timer(0.1).timeout
	guide.update_view(camera, [], Rect2(Vector2.ZERO, root.size), [])
	_check(not guide.get_visible_marks().is_empty(), "Fade retains marks until it completes")
	await create_timer(0.2).timeout
	_check(guide.get_visible_marks().is_empty(), "Fade clears marks after its duration")
	guide.clear()
	_check(guide.get_visible_marks().is_empty(), "Clear removes retained marks")
	guide.queue_free()
	stage.queue_free()
	await process_frame
	quit(1 if _failed else 0)

func _has_mark(marks: Array[Dictionary], kind: String, alpha: float) -> bool:
	for mark: Dictionary in marks:
		if mark["kind"] == kind and is_equal_approx(float(mark["alpha"]), alpha):
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + message)

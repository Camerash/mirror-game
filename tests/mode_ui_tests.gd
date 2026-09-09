extends SceneTree

const HUD := preload("res://ui/mirror_hud.gd")
const Resize := preload("res://ui/mirror_resize.gd")

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(390, 844)
	var hud := HUD.new()
	root.add_child(hud)
	await process_frame
	_check(not hud.get_touch_control_bounds().has("mode_cycle"), "Mode cycle does not block input outside editing")
	var actions: Array[String] = []
	hud.action_requested.connect(func(action: String, _value: Variant) -> void: actions.append(action))
	hud.display_state({"editing": true, "enabled": true, "edit_mode": "move", "mode_busy": false})
	await process_frame
	var mode_bounds: Dictionary = hud.get_touch_control_bounds()
	_check(mode_bounds.has("mode_cycle") and (mode_bounds["mode_cycle"] as Rect2).size.x >= 48.0 and (mode_bounds["mode_cycle"] as Rect2).size.y >= 48.0, "Mode cycle has a 48-unit touch target")
	_check(not hud._mode_cycle.disabled and hud._mode_cycle.tooltip_text.contains("Move"), "Mode cycle exposes the current mode")
	hud._mode_cycle.pressed.emit()
	_check(actions == ["mode_cycle"], "Mode cycle emits its action")
	for key: String in mode_bounds:
		if key != "mode_cycle":
			_check(not (mode_bounds[key] as Rect2).intersects(mode_bounds["mode_cycle"]), "Mode cycle stays clear of other bottom actions")
	hud.display_state({"editing": true, "edit_mode": "rotate", "mode_busy": true})
	_check(hud._mode_cycle.disabled and hud._mode_cycle.tooltip_text.contains("Rotate"), "Mode cycle disables while a mode action is busy")
	hud.display_state({"editing": false})
	_check(not hud.get_touch_control_bounds().has("mode_cycle"), "Hidden mode cycle has no touch region")
	hud.queue_free()
	await _check_resize_modes()
	quit(1 if _failed else 0)

func _check_resize_modes() -> void:
	var stage := Node3D.new()
	var camera := Camera3D.new()
	root.add_child(stage)
	stage.add_child(camera)
	await process_frame
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position = Vector3(0, 5, 7)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	camera.force_update_transform()
	var state := {"axis": 0, "source": 1, "pivot": Vector3.ZERO, "frame_up": Vector3.UP, "enabled": true}
	var resize := Resize.new()
	resize.set_state(state, true, false, "move")
	resize.update_view(camera, Rect2(-200, -200, 2000, 2000), [], PackedVector2Array())
	_check(resize.get_control_rects().keys() == ["height_move"], "Move mode shows only the height control")
	resize.set_state(state, true, false, "resize")
	resize.update_view(camera, Rect2(-200, -200, 2000, 2000), [], PackedVector2Array())
	var resize_controls := resize.get_control_rects()
	_check(resize_controls.has("width") and resize_controls.has("height") and not resize_controls.has("height_move"), "Resize mode shows only edge pills")
	resize.pointer((resize_controls["width"] as Rect2).get_center(), true, 2)
	resize.set_state(state, true, false, "move")
	_check(resize.is_active() and resize.owns_pointer(2), "Mode changes retain an active resize gesture")
	resize.pointer(Vector2(-20, -20), false, 2)
	_check(resize.get_control_rects().keys() == ["height_move"], "Finished gestures use the current mode controls")
	resize.set_state(state, true, false, "rotate")
	resize.update_view(camera, Rect2(-200, -200, 2000, 2000), [], PackedVector2Array())
	_check(resize.get_control_rects().is_empty(), "Rotate mode has no resize controls")
	resize.free()
	stage.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + message)

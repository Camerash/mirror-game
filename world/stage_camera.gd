class_name StageCamera
extends Camera3D
## Presentation only. Camera changes never alter mirror state or navigation.
signal view_changed
signal motion_finished

var yaw := PI * 0.25
var target_yaw := PI * 0.25
var bounds := AABB()
var play_rect := Rect2()
var motion: Tween
var busy := false
var initialized := false

func fit(stage_bounds: AABB, rect: Rect2, instant := false) -> void:
	if rect.size.x < 10 or rect.size.y < 10:
		return
	var changed := not stage_bounds.is_equal_approx(bounds) or not rect.is_equal_approx(play_rect)
	if initialized and not changed and not instant:
		return
	_stop()
	bounds = stage_bounds
	play_rect = rect
	var pose := _pose(yaw)
	if instant or not initialized:
		initialized = true
		_apply(pose["position"], pose["basis"], pose["size"])
		return
	busy = true
	var start_position := position
	var start_size := size
	var start_basis := basis
	motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_method(func(weight: float) -> void:
		_apply(start_position.lerp(pose["position"], weight), start_basis.slerp(pose["basis"], weight), lerpf(start_size, pose["size"], weight)), 0.0, 1.0, 0.28)
	motion.tween_callback(_finish)

func turn(direction: int) -> void:
	if busy or not initialized:
		return
	busy = true
	var start := yaw
	var target := yaw + signi(direction) * PI * 0.5
	target_yaw = target
	motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_method(func(weight: float) -> void:
		yaw = lerpf(start, target, weight)
		var pose := _pose(yaw)
		_apply(pose["position"], pose["basis"], pose["size"]), 0.0, 1.0, 0.35)
	motion.tween_callback(_finish)

func _pose(angle: float) -> Dictionary:
	var direction := Vector3(cos(angle) * cos(PI / 6.0), sin(PI / 6.0), sin(angle) * cos(PI / 6.0))
	var centre := bounds.get_center()
	var view_basis := Basis.looking_at(-direction, Vector3.UP)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for index: int in range(8):
		var corner := view_basis.inverse() * (bounds.get_endpoint(index) - centre)
		low = low.min(Vector2(corner.x, corner.y))
		high = high.max(Vector2(corner.x, corner.y))
	var extent := (high - low).max(Vector2.ONE)
	var pixels := minf(maxf(10, play_rect.size.x - 48) / extent.x, maxf(10, play_rect.size.y - 48) / extent.y)
	var viewport_size := get_viewport().get_visible_rect().size
	var offset := play_rect.get_center() - viewport_size * 0.5
	var location := centre + direction * 40.0 - view_basis.x * offset.x / pixels + view_basis.y * offset.y / pixels
	return {"position": location, "basis": view_basis, "size": viewport_size.y / pixels}

func _apply(location: Vector3, view_basis: Basis, height: float) -> void:
	position = location
	basis = view_basis
	size = height
	view_changed.emit()

func _stop() -> void:
	if motion and motion.is_valid():
		motion.kill()
	yaw = target_yaw
	busy = false

func _finish() -> void:
	busy = false
	view_changed.emit()
	motion_finished.emit()

class_name StageCamera
extends Camera3D
## Presentation only. Camera changes never alter mirror state or navigation.
signal view_changed
signal motion_finished

var yaw := PI * 0.25
var target_yaw := PI * 0.25
var bounds := AABB()
## What the view must show. When it is not empty, the view is fitted to these
## points and not to the corners of `bounds`: one box round a whole place has
## corners where nothing stands, and fitting to them leaves the place small.
var points := PackedVector3Array()
var play_rect := Rect2()
var motion: Tween
var busy := false
var initialized := false
## The title's view: 0 is play, 1 is the stage seen from far above.
var afar := 0.0
## The title's slow sway about the stage, in radians, scaled by `afar`.
var drift := 0.0
## The verb for the next fit only, when it is not a settle: moving on between
## places travels with "transition".
var travel_verb := ""

func fit(stage_bounds: AABB, rect: Rect2, instant := false, content := PackedVector3Array()) -> void:
	if rect.size.x < 10 or rect.size.y < 10:
		return
	var changed := not stage_bounds.is_equal_approx(bounds) or not rect.is_equal_approx(play_rect) or content != points
	if initialized and not changed and not instant:
		return
	_stop()
	bounds = stage_bounds
	play_rect = rect
	points = content
	var pose := _pose(yaw)
	if instant or not initialized:
		initialized = true
		_apply(pose["position"], pose["basis"], pose["size"])
		return
	busy = true
	var start_position := position
	var start_size := size
	var start_basis := basis
	var verb := travel_verb if not travel_verb.is_empty() else "settle"
	travel_verb = ""
	motion = Motion.blend(self, func(weight: float) -> void:
		_apply(start_position.lerp(pose["position"], weight), start_basis.slerp(pose["basis"], weight), lerpf(start_size, pose["size"], weight)), verb)
	motion.tween_callback(_finish)

## True when the current view already shows all of `stage_bounds` inside
## `rect`, and is not much wider than a fresh fit would be. While this holds,
## the direct controls leave the view where it is.
func covers(stage_bounds: AABB, rect: Rect2, slack := 1.25, content := PackedVector3Array()) -> bool:
	if not initialized or busy or rect.size.x < 10 or rect.size.y < 10:
		return false
	var inner := rect.grow(-12.0)
	for point: Vector3 in _shown(stage_bounds, content):
		if not inner.has_point(unproject_position(point)):
			return false
	return size <= float(_pose(yaw, 0.0, stage_bounds, rect, content)["size"]) * slack

## The points a view of `framed` must show: `content`, or the box's corners.
func _shown(framed: AABB, content: PackedVector3Array) -> PackedVector3Array:
	if not content.is_empty():
		return content
	var corners := PackedVector3Array()
	for index: int in range(8):
		corners.append(framed.get_endpoint(index))
	return corners

func turn(direction: int) -> void:
	if busy or not initialized:
		return
	busy = true
	var start := yaw
	var target := yaw + signi(direction) * PI * 0.5
	target_yaw = target
	# One fixed world pivot. Its place on the screen and the size of the view
	# go evenly from the start to the end: no fit between the two, so the
	# place does not go up and then down in the middle of the turn.
	var pivot := bounds.get_center()
	var frame := get_viewport().get_visible_rect().size
	var end := _pose(target)
	var start_size := size
	var end_size: float = end["size"]
	var from_spot := unproject_position(pivot) - frame * 0.5
	var seen: Vector3 = (end["basis"] as Basis).inverse() * (pivot - end["position"])
	var to_spot := Vector2(seen.x, -seen.y) * frame.y / end_size
	motion = Motion.blend(self, func(weight: float) -> void:
		yaw = lerpf(start, target, weight)
		var view_basis := _view_basis(yaw)
		var height := lerpf(start_size, end_size, weight)
		var spot := from_spot.lerp(to_spot, weight) * height / frame.y
		_apply(pivot + view_basis.z * 40.0 - view_basis.x * spot.x + view_basis.y * spot.y, view_basis, height), "reveal")
	motion.tween_callback(_finish)

## Applies the current pose at once, for the title's `afar` and `drift`.
func refresh() -> void:
	if not initialized:
		return
	if busy:
		_stop()
	_apply_pose(yaw, 0.0)

func _apply_pose(angle: float, height: float) -> void:
	var pose := _pose(angle, height)
	_apply(pose["position"], pose["basis"], pose["size"])

func _pose(angle: float, fixed_size := 0.0, stage_bounds: Variant = null, area: Variant = null, content: Variant = null) -> Dictionary:
	var framed: AABB = bounds if stage_bounds == null else stage_bounds
	var shown := _shown(framed, points if content == null else content)
	var fit_rect: Rect2 = play_rect if area == null else area
	var view_basis := _view_basis(angle)
	var direction := view_basis.z
	var centre := framed.get_center()
	var viewport_size := get_viewport().get_visible_rect().size
	var pixels := viewport_size.y / fixed_size if fixed_size > 0.0 else 1.0
	# The view is centred on the middle of what it shows, as seen from this
	# angle. For a box's own corners that is the box's centre.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector3 in shown:
		var seen := view_basis.inverse() * (point - centre)
		low = low.min(Vector2(seen.x, seen.y))
		high = high.max(Vector2(seen.x, seen.y))
	centre += view_basis.x * (low.x + high.x) * 0.5 + view_basis.y * (low.y + high.y) * 0.5
	# A small screen keeps a smaller margin, so a phone shows more stage.
	var margin := minf(48.0, 0.08 * minf(fit_rect.size.x, fit_rect.size.y))
	if fixed_size <= 0.0:
		var extent := (high - low).max(Vector2.ONE)
		pixels = minf(maxf(10, fit_rect.size.x - margin) / extent.x, maxf(10, fit_rect.size.y - margin) / extent.y)
		pixels /= lerpf(1.0, 2.2, afar)
	var offset := fit_rect.get_center() - viewport_size * 0.5
	if viewport_size.y > viewport_size.x:
		# In a tall frame the mirror bar is high, for the thumb, so the middle
		# of the area above it is above the middle of the frame. The place
		# goes down toward the middle of the frame, only into free room, so it
		# stays above the bar.
		var room := (fit_rect.size.y - margin - (high.y - low.y) * pixels) * 0.5
		offset.y += clampf(viewport_size.y * 0.5 - fit_rect.get_center().y, 0.0, maxf(room, 0.0))
	var location := centre + direction * 40.0 - view_basis.x * offset.x / pixels + view_basis.y * offset.y / pixels
	return {"position": location, "basis": view_basis, "size": viewport_size.y / pixels}

## The view's axes at `angle` about the stage. Its z axis is toward the view.
func _view_basis(angle: float) -> Basis:
	angle += drift * afar
	# From afar the view looks down more steeply, and from further away.
	var lift := lerpf(PI / 6.0, 0.95, afar)
	return Basis.looking_at(-Vector3(cos(angle) * cos(lift), sin(lift), sin(angle) * cos(lift)), Vector3.UP)

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

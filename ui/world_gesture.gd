extends RefCounted
## Recognizes one world gesture. The game owns picking and state changes.
signal action_requested(action: String, value: Variant)
signal hold_progress(point: Vector2, progress: float)

const HOLD_SECONDS := 0.45
const TAP_DISTANCE := 12.0
const SWIPE_DISTANCE := 48.0
var active := false
var pointer := -1
var origin := Vector2.ZERO
var location := Vector2.ZERO
var target := ""
var editing := false
var elapsed := 0.0
var moved := false
var consumed := false
var translating := false
var allow_translation := true
## Direct controls: a hold means nothing, a drag that starts on the mirror
## slides it, and a tap anywhere walks, through the glass included.
var direct := false

func begin(point: Vector2, index: int, hit: String, is_editing: bool, can_translate := true) -> void:
	if active:
		return
	active = true
	pointer = index
	origin = point
	location = point
	target = hit
	editing = is_editing
	allow_translation = can_translate
	elapsed = 0.0
	moved = false
	consumed = false
	translating = false

func advance(delta: float) -> void:
	if not active or consumed or moved:
		return
	elapsed += delta
	if editing or direct:
		return
	if target not in ["create", "sheet"]:
		return
	hold_progress.emit(origin, minf(elapsed / HOLD_SECONDS, 1.0))
	if elapsed >= HOLD_SECONDS:
		consumed = true
		hold_progress.emit(origin, -1.0)
		action_requested.emit("create" if target == "create" else "edit", origin)

func move(point: Vector2, index: int) -> void:
	if not active or index != pointer or consumed:
		return
	location = point
	var travel := point - origin
	if travel.length() >= TAP_DISTANCE:
		moved = true
		hold_progress.emit(origin, -1.0)
	if (editing or direct) and allow_translation and target in ["sheet", "outline"] and moved:
		if not translating:
			translating = true
			action_requested.emit("drag_begin", origin)
		action_requested.emit("drag_move", point)
	elif pointer >= 0 and target in ["empty", "create"] and absf(travel.x) >= SWIPE_DISTANCE and absf(travel.x) > absf(travel.y) * 1.5:
		consumed = true
		action_requested.emit("camera_turn", -1 if travel.x < 0 else 1)

func release(point: Vector2, index: int) -> void:
	if not active or index != pointer:
		return
	move(point, index)
	var short_tap := not consumed and not moved and (direct or elapsed < HOLD_SECONDS)
	active = false
	hold_progress.emit(origin, -1.0)
	if translating:
		action_requested.emit("drag_end", null)
	elif short_tap:
		if editing and not direct and target in ["sheet", "outline"]:
			action_requested.emit("apply", null)
		elif not editing or direct:
			action_requested.emit("walk", point)

func cancel() -> void:
	active = false
	hold_progress.emit(origin, -1.0)
	if translating:
		action_requested.emit("drag_end", null)
	translating = false

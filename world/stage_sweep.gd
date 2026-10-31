class_name StageSweep
extends Node3D
## Moving on between two places, without a transition effect. The new place
## is already the real, collidable world when this runs. The place just left
## stays drawn behind her, joined at her feet (a visual-only MirrorWorldView,
## trimmed where it meets the new place), while the camera travels on to the
## new place. Then the old place drifts down and away, like the broken pieces
## of the garden. (The name is historical: this replaced the mirror sweep.)

const Geometry := preload("res://core/world_geometry.gd")

## How far the old place sinks as it drifts away.
const DRIFT_DEPTH := 9.0
## The drift away is slower than the camera's travel.
const DRIFT_TIME := 2.6

signal finished

var active := false
## The new place's bounds: the camera frames this while she moves on.
var union := AABB()

var _old_view: MirrorWorldView
var _drift: Tween
var _elapsed := 0.0
var _world_ref: MirrorWorldView
var _goal_root: Node3D
var _sheet: Node3D
var _contact: Node3D

## Starts moving on from `old_solids` (the place just left, in its own
## coordinates) to the already-loaded `world`. `shift` places the old place so
## her old goal lands on the new place's start.
func start(old_solids: Array[Dictionary], new_bounds: AABB, shift: Vector3,
		old_start: Vector3, old_goal: Vector3, _new_goal: Vector3,
		world: MirrorWorldView, goal_root: Node3D, sheet: Node3D, contact: Node3D) -> void:
	cancel()
	_world_ref = world
	_goal_root = goal_root
	_sheet = sheet
	_contact = contact
	var delta := old_goal - old_start
	var axis := 0 if absf(delta.x) >= absf(delta.z) else 2
	var direction := -1.0 if delta[axis] < 0.0 else 1.0
	_old_view = MirrorWorldView.new()
	add_child(_old_view)
	_old_view.position = shift
	_old_view.draw_world(old_solids)
	# Trim the old place where the new one begins: its goal block and anything
	# beyond it would sit inside the new place's start.
	var join: float = (old_goal + shift)[axis]
	var normal := Vector3.ZERO
	normal[axis] = direction
	_old_view.set_clip(Plane(normal, direction * join - 0.5))
	union = new_bounds
	_sheet.visible = false
	_contact.visible = false
	_goal_root.visible = false
	_elapsed = 0.0
	active = true

func cancel() -> void:
	active = false
	if _drift and _drift.is_valid():
		_drift.kill()
	if is_instance_valid(_old_view):
		_old_view.queue_free()
	_old_view = null
	if _world_ref:
		_world_ref.set_clip(Plane())
	_release()

func _release() -> void:
	if _goal_root:
		_goal_root.visible = true
	if _sheet:
		_sheet.visible = true
	if _contact:
		_contact.visible = true
	_world_ref = null
	_goal_root = null
	_sheet = null
	_contact = null

func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	if _elapsed >= Motion.duration("transition"):
		_finish()

func _finish() -> void:
	active = false
	_release()
	# The place she left drifts down into the mist, then is gone.
	var leaving := _old_view
	_old_view = null
	if is_instance_valid(leaving):
		_drift = leaving.create_tween()
		_drift.tween_property(leaving, "position:y", leaving.position.y - DRIFT_DEPTH, DRIFT_TIME / Motion.speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_drift.tween_callback(leaving.queue_free)
	finished.emit()

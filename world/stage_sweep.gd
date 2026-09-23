class_name StageSweep
extends Node3D
## The mirror sweep between two puzzle stages. Draws the old stage as a
## moved, visual-only MirrorWorldView, and moves a glass panel and a shared
## clip plane across it so the new stage (already the real, collidable
## world by the time this runs) is revealed behind the panel.

const Geometry := preload("res://core/world_geometry.gd")
const Frame := preload("res://world/mirror_frame.gd")
const TrialGlass := preload("res://world/trial_glass.gdshader")

const GROW_TIME := 0.25
const SWEEP_TIME := 1.2
const SHRINK_TIME := 0.25
const MARGIN := 1.0
## Glass opacity multiplier. The panel has no ribbons or motes to show it.
const GLASS_PRESENCE := 6.0

signal finished

var active := false
var union := AABB()

var _old_view: MirrorWorldView
var _old_ring: Node3D
var _old_ring_world := Vector3.ZERO
var _new_goal := Vector3.ZERO
var _axis := 0
var _direction := 1.0
var _ahead := 0.0
var _behind := 0.0
var _elapsed := 0.0
var _world_ref: MirrorWorldView
var _goal_root: Node3D
var _sheet: Node3D
var _contact: Node3D
var _panel_root := Node3D.new()
var _quad := MeshInstance3D.new()
var _quad_mesh := QuadMesh.new()
var _frame := Frame.new()
var _sheet_material := ShaderMaterial.new()

func _ready() -> void:
	_sheet_material.shader = TrialGlass
	_sheet_material.render_priority = 64
	_sheet_material.set_shader_parameter("presence", GLASS_PRESENCE)
	_quad.mesh = _quad_mesh
	_quad.material_override = _sheet_material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_panel_root.add_child(_quad)
	_panel_root.add_child(_frame)
	_panel_root.visible = false
	add_child(_panel_root)

## Starts a sweep from `old_solids` (the stage just left, in its own
## coordinates) to the already-loaded `world`. `shift` places the old stage
## so the traveller's old goal lands on the new stage's start.
func start(old_solids: Array[Dictionary], new_bounds: AABB, shift: Vector3,
		old_start: Vector3, old_goal: Vector3, new_goal: Vector3,
		world: MirrorWorldView, goal_root: Node3D, sheet: Node3D, contact: Node3D) -> void:
	cancel()
	_world_ref = world
	_goal_root = goal_root
	_sheet = sheet
	_contact = contact
	_new_goal = new_goal
	var delta := old_goal - old_start
	_axis = 0 if absf(delta.x) >= absf(delta.z) else 2
	_direction = -1.0 if delta[_axis] < 0.0 else 1.0
	_old_view = MirrorWorldView.new()
	add_child(_old_view)
	_old_view.position = shift
	_old_view.draw_world(old_solids)
	_old_ring = Node3D.new()
	_old_view.add_child(_old_ring)
	_old_view.add_ring(_old_ring, old_goal, Color("805534"))
	_old_ring_world = old_goal + shift
	var old_bounds := Geometry.total_bounds(old_solids)
	old_bounds.position += shift
	union = new_bounds.merge(old_bounds)
	var union_min: float = union.position[_axis]
	var union_max: float = union.position[_axis] + union.size[_axis]
	_ahead = union_max if _direction > 0.0 else union_min
	_behind = union_min if _direction > 0.0 else union_max
	_sheet.visible = false
	_contact.visible = false
	_goal_root.visible = false
	_elapsed = 0.0
	active = true
	_apply(0.0, 0.0)

func cancel() -> void:
	active = false
	if is_instance_valid(_old_view):
		_old_view.queue_free()
	_old_view = null
	_old_ring = null
	if _world_ref:
		_world_ref.set_clip(Plane())
	_panel_root.visible = false
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
	if _elapsed < GROW_TIME:
		_apply(0.0, _elapsed / GROW_TIME)
	elif _elapsed < GROW_TIME + SWEEP_TIME:
		_apply((_elapsed - GROW_TIME) / SWEEP_TIME, 1.0)
	elif _elapsed < GROW_TIME + SWEEP_TIME + SHRINK_TIME:
		_apply(1.0, 1.0 - (_elapsed - GROW_TIME - SWEEP_TIME) / SHRINK_TIME)
	else:
		_finish()

func _apply(t: float, scale: float) -> void:
	var coordinate := lerpf(_ahead, _behind, t)
	var axis_unit := Vector3.ZERO
	axis_unit[_axis] = 1.0
	_world_ref.set_clip(Plane(axis_unit * -_direction, -_direction * coordinate))
	_old_view.set_clip(Plane(axis_unit * _direction, _direction * coordinate))
	_old_ring.visible = _direction * _old_ring_world[_axis] <= _direction * coordinate
	_goal_root.visible = _direction * _new_goal[_axis] >= _direction * coordinate
	var centre := union.get_center()
	centre[_axis] = coordinate
	_panel_root.position = centre
	_panel_root.basis = _panel_basis()
	var full := _cross_section_size()
	var size := Vector2(maxf(full.x * scale, 0.01), maxf(full.y * scale, 0.01))
	_quad_mesh.size = size
	_sheet_material.set_shader_parameter("panel_size", size)
	_frame.update_frame(size, false, true)
	_panel_root.visible = scale > 0.0

func _cross_section_size() -> Vector2:
	var width := union.size.z if _axis == 0 else union.size.x
	return Vector2(width, union.size.y) + Vector2.ONE * MARGIN

func _panel_basis() -> Basis:
	if _axis == 0:
		return Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	return Basis.IDENTITY

func _finish() -> void:
	cancel()
	finished.emit()

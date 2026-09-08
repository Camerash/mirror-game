class_name MirrorSheet
extends Node3D

signal transition_finished

const SheetShader := preload("res://world/mirror_sheet.gdshader")

var sheet := MeshInstance3D.new()
var edges := MeshInstance3D.new()
var cue := MeshInstance3D.new()
var sheet_material := ShaderMaterial.new()
var edge_material := StandardMaterial3D.new()
var state: Dictionary = {}
var corners := PackedVector3Array()
var editing := false
var transitioning := false
var elapsed := 0.0
var settle_time := 0.0
var old_normal := Vector3.FORWARD
var target_normal := Vector3.FORWARD
var drawn_bounds := AABB()
var has_geometry := false

func _ready() -> void:
	sheet_material.shader = SheetShader
	sheet_material.render_priority = 64
	sheet.material_override = sheet_material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edges.material_override = edge_material
	cue.material_override = edge_material
	edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_material.render_priority = 80
	edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	edge_material.albedo_color = Color("c3f1f2")
	add_child(sheet)
	add_child(edges)
	add_child(cue)

func set_state(next_state: Dictionary, bounds: AABB, is_editing: bool) -> void:
	if has_geometry and next_state == state and bounds == drawn_bounds and editing == is_editing:
		return
	var axis := int(next_state.get("axis", 0))
	var source := int(next_state.get("source", 1))
	var normal := Vector3.ZERO
	normal[axis] = float(source)
	var changed := not state.is_empty() and (axis != int(state.get("axis", axis)) or source != int(state.get("source", source)))
	var visual_change := next_state != state or bounds != drawn_bounds or editing != is_editing
	state = next_state.duplicate()
	editing = is_editing
	var pivot: Vector3 = state.get("pivot", bounds.get_center())
	_set_geometry(axis, float(state.get("offset", 0.0)), normal, bounds, pivot)
	if changed:
		old_normal = target_normal
		target_normal = normal
		global_basis = Basis(_rotation_from_to(target_normal, old_normal))
		transitioning = true
		elapsed = 0.0
	elif not transitioning:
		target_normal = normal
		global_basis = Basis.IDENTITY
		transitioning = false
	drawn_bounds = bounds
	has_geometry = true
	settle_time = 0.18 if visual_change and not editing else 0.0
	visible = bool(state.get("enabled", false)) or editing
	sheet.visible = visible
	edges.visible = visible

func get_corners() -> PackedVector3Array:
	return corners

func is_transitioning() -> bool:
	return transitioning

func _set_geometry(axis: int, offset: float, normal: Vector3, bounds: AABB, pivot: Vector3) -> void:
	var dimensions: Array[int] = [0, 1, 2]
	dimensions.erase(axis)
	var first := Vector3.ZERO
	var second := Vector3.ZERO
	first[dimensions[0]] = 1.0
	second[dimensions[1]] = 1.0
	var centre := bounds.get_center()
	centre[axis] = offset
	var first_size := bounds.size[dimensions[0]]
	var second_size := bounds.size[dimensions[1]]
	corners = PackedVector3Array([
		centre - first * first_size * 0.5 - second * second_size * 0.5,
		centre + first * first_size * 0.5 - second * second_size * 0.5,
		centre + first * first_size * 0.5 + second * second_size * 0.5,
		centre - first * first_size * 0.5 + second * second_size * 0.5,
	])
	global_position = pivot
	sheet.mesh = QuadMesh.new()
	(sheet.mesh as QuadMesh).size = Vector2(first_size, second_size)
	sheet.position = centre - pivot
	sheet.basis = Basis(first, second, normal).orthonormalized()
	_draw_edges(first_size, second_size)
	edges.position = sheet.position
	edges.basis = sheet.basis
	var marker_centre := centre
	marker_centre.y = bounds.position.y + minf(bounds.size.y * 0.30, 0.45)
	_draw_cue(marker_centre, normal, second, maxf(first_size, second_size), pivot)

func _draw_edges(width: float, height: float) -> void:
	var points := PackedVector3Array()
	var corners_2d := [Vector2(-width, -height), Vector2(width, -height), Vector2(width, height), Vector2(-width, height)]
	for side: int in 4:
		var start: Vector2 = corners_2d[side] * 0.5
		var finish: Vector2 = corners_2d[(side + 1) % 4] * 0.5
		var steps := maxi(1, ceili(start.distance_to(finish) / 0.16)) if editing else 1
		for step: int in range(0, steps, 2 if editing else 1):
			points.append(Vector3(start.x, start.y, 0.01).lerp(Vector3(finish.x, finish.y, 0.01), float(step) / steps))
			points.append(Vector3(start.x, start.y, 0.01).lerp(Vector3(finish.x, finish.y, 0.01), float(step + 1) / steps))
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point: Vector3 in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	edges.mesh = mesh

func _draw_cue(centre: Vector3, normal: Vector3, tangent: Vector3, extent: float, pivot: Vector3) -> void:
	var start := centre - normal * (0.22 + extent * 0.06)
	var finish := centre - normal * 0.10
	var points := PackedVector3Array([
		start - pivot, finish - pivot,
		finish - pivot, finish - normal * 0.12 + tangent * 0.08 - pivot,
		finish - pivot, finish - normal * 0.12 - tangent * 0.08 - pivot,
	])
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point: Vector3 in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	cue.mesh = mesh

func _process(delta: float) -> void:
	elapsed += delta
	settle_time = maxf(0.0, settle_time - delta)
	sheet_material.set_shader_parameter("sheet_time", elapsed)
	var pulse := 0.70 + sin(elapsed * 2.2) * 0.20 if editing else 1.0
	edge_material.albedo_color = Color(0.76, 0.95, 0.95, pulse)
	sheet_material.set_shader_parameter("sheet_alpha", 0.07 if editing else 0.11 + settle_time * 0.12)
	if not transitioning:
		return
	var fraction := minf(elapsed / 0.22, 1.0)
	global_basis = Basis(_rotation_from_to(target_normal, old_normal).slerp(Quaternion.IDENTITY, fraction))
	if fraction >= 1.0:
		global_basis = Basis.IDENTITY
		transitioning = false
		transition_finished.emit()

func _rotation_from_to(from: Vector3, to: Vector3) -> Quaternion:
	if from.dot(to) < -0.999:
		var turn_axis := Vector3.UP if absf(from.y) < 0.9 else Vector3.RIGHT
		return Quaternion(turn_axis, PI)
	return Quaternion(from, to)

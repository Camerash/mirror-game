class_name MirrorSheet
extends Node3D

signal transition_finished
signal pose_changed

const Rules := preload("res://core/mirror_state.gd")
const SheetShader := preload("res://world/mirror_sheet.gdshader")
const RibbonShader := preload("res://world/mirror_ribbon.gdshader")

var guides := MeshInstance3D.new()
var guide_material := StandardMaterial3D.new()
var panel_size := Vector2(3, 3)
var rotation_motion: Tween
var sheet := MeshInstance3D.new()
var edges := MeshInstance3D.new()
var ribbons := MeshInstance3D.new()
var sheet_material := ShaderMaterial.new()
var edge_material := StandardMaterial3D.new()
var ribbon_material := ShaderMaterial.new()
var state: Dictionary = {}
var editing := false
var transitioning := false
var elapsed := 0.0
var settle_time := 0.0
var drawn_bounds := AABB()
var has_geometry := false

func _ready() -> void:
	sheet_material.shader = SheetShader
	sheet_material.render_priority = 64
	sheet.material_override = sheet_material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edges.material_override = edge_material
	edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_material.render_priority = 80
	edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	edge_material.albedo_color = Color("c3f1f2")
	edge_material.emission_enabled = true
	edge_material.emission = Color("9ee9f2")
	edge_material.emission_energy_multiplier = 1.35
	ribbon_material.shader = RibbonShader
	ribbon_material.render_priority = 72
	ribbons.material_override = ribbon_material
	guide_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guide_material.albedo_color = Color(0.65, 0.86, 0.92, 0.23)
	guides.material_override = guide_material
	guides.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(guides)
	add_child(sheet)
	add_child(edges)
	add_child(ribbons)

func set_state(next_state: Dictionary, bounds: AABB, is_editing: bool) -> void:
	if next_state == state and bounds == drawn_bounds and editing == is_editing:
		return
	var dimensions := Vector2(clampf(float(next_state.get("width", 3.0)), 1.0, 6.0), clampf(float(next_state.get("height", 3.0)), 1.0, 6.0))
	var rebuild := editing != is_editing or not has_geometry or dimensions != panel_size
	panel_size = dimensions
	state = next_state.duplicate(true)
	editing = is_editing
	drawn_bounds = bounds
	has_geometry = state.has("axis")
	visible = has_geometry
	if not has_geometry:
		cancel_transition()
		return
	global_position = state["pivot"]
	global_basis = Rules.frame(state)
	if rebuild:
		var quad := QuadMesh.new()
		quad.size = panel_size
		sheet.mesh = quad
		_draw_edges(panel_size.x, panel_size.y)
		_draw_ribbons(panel_size.x, panel_size.y)
	var enabled: bool = state.get("enabled", false)
	sheet.visible = enabled
	ribbons.visible = enabled
	edges.visible = enabled or editing
	guides.visible = editing and enabled
	if guides.visible:
		_update_guides(bounds)
	sheet_material.set_shader_parameter("panel_size", panel_size)
	sheet_material.set_shader_parameter("removal", not enabled)
	settle_time = 0.18 if not editing else 0.0

func contains_visible_point(point: Vector3, selected: Dictionary) -> bool:
	var pivot: Vector3 = selected["pivot"]
	var local := Rules.frame(selected).inverse() * (point - pivot)
	var width := clampf(float(selected.get("width", 3.0)), 1.0, 6.0)
	var height := clampf(float(selected.get("height", 3.0)), 1.0, 6.0)
	return absf(local.x) <= width * 0.5 and absf(local.y) <= height * 0.5

func animate_to(next_state: Dictionary, bounds: AABB) -> void:
	var previous := global_basis
	set_state(next_state, bounds, true)
	var target := global_basis
	global_basis = previous
	transitioning = true
	rotation_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rotation_motion.tween_method(func(weight: float) -> void:
		global_basis = previous.slerp(target, weight)
		pose_changed.emit(), 0.0, 1.0, 0.22)
	rotation_motion.tween_callback(func() -> void:
		global_basis = target
		transitioning = false
		transition_finished.emit())

func cancel_transition() -> void:
	if rotation_motion and rotation_motion.is_valid():
		rotation_motion.kill()
	transitioning = false
	# Force the next state refresh to restore its exact pose.
	state = {}

func get_corners() -> PackedVector3Array:
	var result := PackedVector3Array()
	if not has_geometry:
		return result
	for point: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		result.append(to_global(Vector3(point.x * panel_size.x, point.y * panel_size.y, 0) * 0.5))
	return result

func is_transitioning() -> bool:
	return transitioning

func _update_guides(bounds: AABB) -> void:
	var low := -2.0
	var high := 2.0
	for index: int in 8:
		var point := to_local(bounds.get_endpoint(index))
		low = minf(low, point.z - 0.5)
		high = maxf(high, point.z + 0.5)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for corner: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		var first := Vector3(corner.x * panel_size.x * 0.5, corner.y * panel_size.y * 0.5, low)
		var last := Vector3(first.x, first.y, high)
		mesh.surface_add_vertex(first)
		mesh.surface_add_vertex(last)
	mesh.surface_end()
	guides.mesh = mesh

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

func _draw_ribbons(width: float, height: float) -> void:
	const RIBBON_LENGTH := 0.45
	var corners_2d := [Vector2(-width, -height), Vector2(width, -height), Vector2(width, height), Vector2(-width, height)]
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in 4:
		var start: Vector2 = corners_2d[side] * 0.5
		var finish: Vector2 = corners_2d[(side + 1) % 4] * 0.5
		var plane_start := Vector3(start.x, start.y, 0.0)
		var plane_finish := Vector3(finish.x, finish.y, 0.0)
		var far_start := plane_start + Vector3.BACK * RIBBON_LENGTH
		var far_finish := plane_finish + Vector3.BACK * RIBBON_LENGTH
		mesh.surface_set_uv(Vector2(0.0, 0.0))
		mesh.surface_add_vertex(plane_start)
		mesh.surface_set_uv(Vector2(0.0, 1.0))
		mesh.surface_add_vertex(plane_finish)
		mesh.surface_set_uv(Vector2(1.0, 1.0))
		mesh.surface_add_vertex(far_finish)
		mesh.surface_set_uv(Vector2(0.0, 0.0))
		mesh.surface_add_vertex(plane_start)
		mesh.surface_set_uv(Vector2(1.0, 1.0))
		mesh.surface_add_vertex(far_finish)
		mesh.surface_set_uv(Vector2(1.0, 0.0))
		mesh.surface_add_vertex(far_start)
	mesh.surface_end()
	ribbons.mesh = mesh

func _process(delta: float) -> void:
	elapsed += delta
	settle_time = maxf(0.0, settle_time - delta)
	sheet_material.set_shader_parameter("sheet_time", elapsed)
	var pulse := 0.70 + sin(elapsed * 2.2) * 0.20 if editing else 1.0
	edge_material.albedo_color = Color(0.76, 0.95, 0.95, pulse)
	edge_material.emission_energy_multiplier = 1.35 if not editing else 0.75 + pulse * 0.45
	sheet_material.set_shader_parameter("sheet_alpha", 0.07 if editing else 0.11 + settle_time * 0.12)
	ribbon_material.set_shader_parameter("ribbon_time", elapsed)
	ribbon_material.set_shader_parameter("ribbon_alpha", 0.62 if editing else 1.0)

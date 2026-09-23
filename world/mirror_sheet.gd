class_name MirrorSheet
extends Node3D

signal transition_finished
signal pose_changed

const TrialGlass := preload("res://world/trial_glass.gdshader")
const Frame := preload("res://world/mirror_frame.gd")
const Rules := preload("res://core/mirror_state.gd")
const RibbonShader := preload("res://world/mirror_ribbon.gdshader")
const GuideShader := preload("res://world/mirror_guides.gdshader")
const MoteShader := preload("res://world/mirror_motes.gdshader")

var frame := Frame.new()
var panel_size := Vector2(3, 3)
var rotation_motion: Tween
var sheet := MeshInstance3D.new()
var edges := MeshInstance3D.new()
var ribbons := MeshInstance3D.new()
var guides := MeshInstance3D.new()
var motes := MeshInstance3D.new()
var sheet_material := ShaderMaterial.new()
var edge_material := StandardMaterial3D.new()
var ribbon_material := ShaderMaterial.new()
var guide_material := ShaderMaterial.new()
var mote_material := ShaderMaterial.new()
var state: Dictionary = {}
var editing := false
var transitioning := false
var elapsed := 0.0
var settle_time := 0.0
var drawn_bounds := AABB()
var has_geometry := false

func _ready() -> void:
	sheet_material.shader = TrialGlass
	sheet_material.render_priority = 64
	sheet.material_override = sheet_material
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edges.material_override = edge_material
	edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	guides.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	guide_material.shader = GuideShader
	guide_material.render_priority = 70
	guides.material_override = guide_material
	mote_material.shader = MoteShader
	mote_material.render_priority = 74
	motes.material_override = mote_material
	add_child(frame)
	add_child(sheet)
	add_child(edges)
	add_child(ribbons)
	add_child(guides)
	add_child(motes)

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
		_draw_guides(panel_size.x, panel_size.y)
		_draw_motes(panel_size.x, panel_size.y)
	var enabled: bool = state.get("enabled", false)
	frame.update_frame(panel_size, editing, enabled)
	sheet.visible = enabled
	ribbons.visible = enabled
	guides.visible = enabled or editing
	motes.visible = enabled
	edges.visible = editing
	sheet_material.set_shader_parameter("panel_size", panel_size)
	sheet_material.set_shader_parameter("removal", not enabled)
	var source_sign := float(state.get("source_sign", 1.0))
	ribbon_material.set_shader_parameter("source_sign", source_sign)
	guide_material.set_shader_parameter("source_sign", source_sign)
	guide_material.set_shader_parameter("guide_alpha", 0.35 if not enabled else 1.0)
	mote_material.set_shader_parameter("source_sign", source_sign)
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
	const RIBBON_LENGTH := 0.25
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

func _draw_guides(width: float, height: float) -> void:
	const GUIDE_LENGTH := 6.0
	const GUIDE_WIDTH := 0.025
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for corner: Vector2 in [Vector2(-width, -height), Vector2(width, -height), Vector2(width, height), Vector2(-width, height)]:
		var centre := Vector3(corner.x, corner.y, 0.0) * 0.5
		for vertex: Vector2 in [Vector2(-1,0), Vector2(1,0), Vector2(1,1), Vector2(-1,0), Vector2(1,1), Vector2(-1,1)]:
			mesh.surface_set_uv(Vector2(vertex.x * 0.5 + 0.5, vertex.y))
			mesh.surface_add_vertex(centre + Vector3(vertex.x * GUIDE_WIDTH * 0.5, 0.0, vertex.y * GUIDE_LENGTH))
	mesh.surface_end()
	guides.mesh = mesh
	guides.custom_aabb = AABB(Vector3(-width * 0.5 - GUIDE_WIDTH, -height * 0.5 - GUIDE_WIDTH, -GUIDE_LENGTH - GUIDE_WIDTH), Vector3(width + GUIDE_WIDTH * 2.0, height + GUIDE_WIDTH * 2.0, (GUIDE_LENGTH + GUIDE_WIDTH) * 2.0))

func _draw_motes(width: float, height: float) -> void:
	const MOTE_COUNT := 28
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in MOTE_COUNT:
		var side := index % 4
		var fraction := fmod(float(index) * 0.61803398875 + 0.13, 1.0)
		var size := 0.014 + fmod(float(index) * 0.173, 1.0) * 0.012
		var point := Vector2.ZERO
		if side < 2:
			point = Vector2((-0.5 if side == 0 else 0.5) * width, (fraction - 0.5) * height)
		else:
			point = Vector2((fraction - 0.5) * width, (-0.5 if side == 2 else 0.5) * height)
		var phase := fmod(float(index) * 0.371, 1.0)
		for vertex: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,-1), Vector2(1,1), Vector2(-1,1)]:
			mesh.surface_set_color(Color(phase, size / 0.03, 0.0, 1.0))
			mesh.surface_set_uv(vertex * 0.5 + Vector2(0.5, 0.5))
			mesh.surface_add_vertex(Vector3(point.x + vertex.x * size, point.y + vertex.y * size, 0.006))
	mesh.surface_end()
	motes.mesh = mesh

func _process(delta: float) -> void:
	elapsed += delta
	var camera := get_viewport().get_camera_3d()
	if camera:
		mote_material.set_shader_parameter("pixel_world_size", camera.size / maxf(1.0, get_viewport().get_visible_rect().size.y) * 1.1)
	settle_time = maxf(0.0, settle_time - delta)
	sheet_material.set_shader_parameter("sheet_time", elapsed)
	var pulse := 0.70 + sin(elapsed * 2.2) * 0.20 if editing else 1.0
	edge_material.albedo_color = Color(0.76, 0.95, 0.95, pulse)
	edge_material.emission_energy_multiplier = 1.35 if not editing else 0.75 + pulse * 0.45
	sheet_material.set_shader_parameter("sheet_alpha", 0.07 if editing else 0.11 + settle_time * 0.12)
	ribbon_material.set_shader_parameter("ribbon_time", elapsed)
	ribbon_material.set_shader_parameter("ribbon_alpha", 0.85 if editing else 1.0)
	mote_material.set_shader_parameter("mote_time", elapsed)
	mote_material.set_shader_parameter("mote_alpha", 0.85 if editing else 1.0)

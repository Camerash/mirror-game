extends Node3D

var backdrop := MeshInstance3D.new()
var material := ShaderMaterial.new()
var editing := false
var clock := 0.0
var haze_root := Node3D.new()
var haze_materials: Array[ShaderMaterial] = []
var bounds := AABB(Vector3(-3, -1, -3), Vector3(6, 3, 6))
var art_trial := false

func _ready() -> void:
	material.shader = preload("res://world/atmosphere.gdshader")
	material.render_priority = -128
	material.set_shader_parameter("art_trial", art_trial)
	backdrop.mesh = QuadMesh.new()
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.extra_cull_margin = 200.0
	add_child(backdrop)
	add_child(haze_root)
	set_bounds(bounds)

func set_art_trial(enabled: bool) -> void:
	art_trial = enabled
	material.set_shader_parameter("art_trial", art_trial)
	for haze: ShaderMaterial in haze_materials:
		haze.set_shader_parameter("art_trial", art_trial)

func update_view(camera: Camera3D, centre: Vector3) -> void:
	var dimensions := camera.get_viewport().get_visible_rect().size
	var extent := Vector2(camera.size * dimensions.x / dimensions.y, camera.size) * 1.1
	backdrop.mesh.size = extent
	backdrop.global_basis = camera.global_basis
	backdrop.global_position = camera.global_position - camera.global_basis.z * 80.0
	# Keep the background cross-section aligned with the camera's centre ray.
	var section := camera.global_position - camera.global_basis.z * (camera.global_position - centre).dot(camera.global_basis.z)
	material.set_shader_parameter("section_centre", section)
	material.set_shader_parameter("camera_right", camera.global_basis.x)
	material.set_shader_parameter("camera_up", camera.global_basis.y)
	material.set_shader_parameter("view_size", extent)

func set_mirror(mirror: Dictionary, is_editing: bool, style: int) -> void:
	editing = is_editing
	var normal := Vector3.ZERO
	normal[int(mirror["axis"])] = 1.0
	material.set_shader_parameter("plane_normal", normal)
	material.set_shader_parameter("plane_offset", float(mirror["offset"]))
	material.set_shader_parameter("source_direction", float(mirror["source"]))
	material.set_shader_parameter("mirror_enabled", mirror["enabled"])
	material.set_shader_parameter("atmosphere_enabled", style == 0)
	for haze: ShaderMaterial in haze_materials:
		haze.set_shader_parameter("plane_normal", normal)
		haze.set_shader_parameter("plane_offset", float(mirror["offset"]))
		haze.set_shader_parameter("source_direction", float(mirror["source"]))
		haze.set_shader_parameter("atmosphere_enabled", style == 0 and mirror["enabled"])

func set_bounds(next_bounds: AABB) -> void:
	bounds = next_bounds
	for child: Node in haze_root.get_children():
		child.queue_free()
	haze_materials.clear()
	for index: int in 2:
		var haze := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		var haze_depth := maxf(bounds.size.z, 4.0) if art_trial else bounds.size.z
		mesh.size = Vector2(bounds.size.x * (0.82 - index * 0.16), haze_depth * (0.72 - index * 0.12))
		haze.mesh = mesh
		haze.position = Vector3(bounds.get_center().x, bounds.position.y - 0.25 - index * 0.35, bounds.get_center().z)
		var haze_material := ShaderMaterial.new()
		haze_material.shader = preload("res://world/atmosphere.gdshader")
		haze_material.render_priority = -64
		haze_material.set_shader_parameter("haze_mode", true)
		haze_material.set_shader_parameter("art_trial", art_trial)
		haze_material.set_shader_parameter("haze_centre", haze.position)
		haze_material.set_shader_parameter("haze_extent", Vector3(bounds.size.x * 0.55, 1.0, maxf(haze_depth * 0.55, 1.0)))
		haze.material_override = haze_material
		haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		haze_root.add_child(haze)
		haze_materials.append(haze_material)

func _process(delta: float) -> void:
	clock += delta * (0.2 if editing else 1.0)
	material.set_shader_parameter("atmosphere_time", clock)
	for haze: ShaderMaterial in haze_materials:
		haze.set_shader_parameter("atmosphere_time", clock)

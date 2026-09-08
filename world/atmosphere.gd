extends Node3D

var backdrop := MeshInstance3D.new()
var material := ShaderMaterial.new()
var editing := false
var clock := 0.0

func _ready() -> void:
	material.shader = preload("res://world/atmosphere.gdshader")
	backdrop.mesh = QuadMesh.new()
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.extra_cull_margin = 200.0
	add_child(backdrop)

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

func _process(delta: float) -> void:
	clock += delta * (0.2 if editing else 1.0)
	material.set_shader_parameter("atmosphere_time", clock)

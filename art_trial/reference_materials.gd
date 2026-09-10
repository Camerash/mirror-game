class_name ReferenceMaterials
extends RefCounted

const SurfaceShader := preload("res://art_trial/reference_surface.gdshader")
const CeramicMaps := [preload("res://assets/reference/surface_ceramic_albedo.png"), preload("res://assets/reference/surface_ceramic_roughness.png"), preload("res://assets/reference/surface_ceramic_height.png")]
const JadeMaps := [preload("res://assets/reference/surface_jade_albedo.png"), preload("res://assets/reference/surface_jade_roughness.png"), preload("res://assets/reference/surface_jade_height.png")]

static func build(kind: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SurfaceShader
	var is_jade := kind == "jade" or kind == "absolute"
	var maps: Array = JadeMaps if is_jade else CeramicMaps
	material.set_shader_parameter("albedo_map", maps[0])
	material.set_shader_parameter("roughness_map", maps[1])
	material.set_shader_parameter("height_map", maps[2])
	material.set_shader_parameter("jade", is_jade)
	material.set_shader_parameter("reflected", kind == "reflected")
	material.set_shader_parameter("cut_surface", false)
	material.set_shader_parameter("tint", Vector3(0.25, 0.32, 0.30) if is_jade else Vector3(0.90, 0.94, 0.98))
	return material

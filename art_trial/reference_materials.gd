class_name ReferenceMaterials
extends RefCounted

const SurfaceShader := preload("res://art_trial/reference_surface.gdshader")
const CeramicMaps := [preload("res://assets/reference/surface_ceramic_albedo.png"), preload("res://assets/reference/surface_ceramic_roughness.png")]
const JadeMaps := [preload("res://assets/reference/surface_jade_albedo.png"), preload("res://assets/reference/surface_jade_roughness.png")]

static func build(kind: String, variation := 0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SurfaceShader
	var is_jade := kind in ["jade", "absolute", "goal"]
	var maps: Array = JadeMaps if is_jade else CeramicMaps
	material.set_shader_parameter("albedo_map", maps[0])
	material.set_shader_parameter("roughness_map", maps[1])
	var family := "jade" if is_jade else "ceramic"
	for face: String in ["side", "top"]:
		for channel: String in ["normal", "masks"]:
			material.set_shader_parameter(face + "_" + channel, load("res://assets/reference/detail_%s_%s_%s.png" % [family, face, channel]))
	material.set_shader_parameter("variation", float(variation))
	material.set_shader_parameter("jade", is_jade)
	material.set_shader_parameter("goal_socket", kind == "goal")
	material.set_shader_parameter("reflected", kind == "reflected")
	material.set_shader_parameter("tint", Vector3(0.16, 0.24, 0.22) if is_jade else Vector3(0.90, 0.94, 0.98))
	return material

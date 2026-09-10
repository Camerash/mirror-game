class_name TrialMaterials
extends RefCounted

const CeramicShader := preload("res://world/ceramic.gdshader")
const PorcelainShader := preload("res://world/porcelain.gdshader")
const TEXTURES := {
	"ceramic": [preload("res://assets/materials/ceramic_albedo.png"), preload("res://assets/materials/ceramic_roughness.png"), preload("res://assets/materials/ceramic_normal.png"), preload("res://assets/materials/ceramic_height.png")],
	"jade": [preload("res://assets/materials/jade_albedo.png"), preload("res://assets/materials/jade_roughness.png"), preload("res://assets/materials/jade_normal.png"), preload("res://assets/materials/jade_height.png")],
}

static func configure(material: ShaderMaterial, kind: String) -> void:
	var map_kind := "jade" if kind == "absolute" else "ceramic"
	var maps: Array = TEXTURES[map_kind]
	material.shader = PorcelainShader if kind == "reflected" else CeramicShader
	material.set_shader_parameter("albedo_map", maps[0])
	material.set_shader_parameter("roughness_map", maps[1])
	material.set_shader_parameter("normal_map", maps[2])
	material.set_shader_parameter("height_map", maps[3])
	material.set_shader_parameter("jade_surface", kind == "absolute")

class_name BlockSet
extends RefCounted
## The master block set. Every stage, puzzle or fixture, uses this one look:
## the ceramic and porcelain surfaces, and the goal ring. Look follows the
## kind of solid (original, reflected, absolute), never the level index.

const CeramicShader := preload("res://world/ceramic.gdshader")
const PorcelainShader := preload("res://world/porcelain.gdshader")
const TEXTURES := {
	"ceramic": [preload("res://assets/materials/ceramic_albedo.png"), preload("res://assets/materials/ceramic_roughness.png"), preload("res://assets/materials/ceramic_normal.png"), preload("res://assets/materials/ceramic_height.png")],
	"jade": [preload("res://assets/materials/jade_albedo.png"), preload("res://assets/materials/jade_roughness.png"), preload("res://assets/materials/jade_normal.png"), preload("res://assets/materials/jade_height.png")],
}
const GOAL_CARVING_COLOR := Color("f3d89b")

static func configure(material: ShaderMaterial, kind: String) -> void:
	var map_kind := "jade" if kind == "absolute" else "ceramic"
	var maps: Array = TEXTURES[map_kind]
	material.shader = PorcelainShader if kind == "reflected" else CeramicShader
	material.set_shader_parameter("albedo_map", maps[0])
	material.set_shader_parameter("roughness_map", maps[1])
	material.set_shader_parameter("normal_map", maps[2])
	material.set_shader_parameter("height_map", maps[3])
	material.set_shader_parameter("jade_surface", kind == "absolute")

static func goal_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b49a67")
	material.metallic = 0.75
	material.roughness = 0.27
	return material

static func goal_carving_points(feet: Vector3, radius: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for index: int in 8:
		var angle := TAU * float(index) / 8.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var centre := feet + Vector3.UP * 0.099 + direction * radius * 0.855
		points.append(centre - direction * radius * 0.075)
		points.append(centre + direction * radius * 0.075)
	return points

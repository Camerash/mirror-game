class_name BlockSet
extends RefCounted
## The master block set. Every stage, puzzle or fixture, uses this one look:
## garden stone under snow, and the goal ring. Look follows the kind of solid
## (original, reflected, absolute), never the level index.

const StoneShader := preload("res://world/stone.gdshader")
const KINDS := {"original": 0, "reflected": 1, "absolute": 2}
const GOAL_CARVING_COLOR := Color("f3d89b")

static func configure(material: ShaderMaterial, kind: String) -> void:
	material.shader = StoneShader
	material.set_shader_parameter("kind", KINDS.get(kind, 0))

static func goal_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c99a4a")
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
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

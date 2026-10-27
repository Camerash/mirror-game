extends PilotLook
## The current identity, polished: the game's own ceramic, porcelain and
## jade block shaders, under a dawn gradient and warm soft sunlight.

const CERAMIC := ["res://assets/materials/ceramic_albedo.png", "res://assets/materials/ceramic_normal.png"]
const JADE := ["res://assets/materials/jade_albedo.png", "res://assets/materials/jade_normal.png"]

func title() -> String:
	return "Ceramic dawn"

func environment() -> Environment:
	var settings := PilotLook.backdrop({
		"top_color": Color("b7a2b9"), "bottom_color": Color("f0cdb6"),
		"light_top": Color("cdbdbb"), "light_bottom": Color("9c8592"),
	})
	settings.ambient_light_energy = 0.3
	settings.tonemap_exposure = 0.95
	settings.glow_enabled = true
	settings.glow_intensity = 0.35
	settings.glow_bloom = 0.04
	return settings

func lights() -> Array[Light3D]:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -12, 0)
	sun.light_color = Color("ffe2c4")
	sun.light_energy = 0.85
	sun.light_angular_distance = 3.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.6
	sun.directional_shadow_max_distance = 40.0
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("c9d6ff")
	fill.light_energy = 0.18
	return [sun, fill]

func block_material(kind: String, bounds: AABB) -> Material:
	var material := ShaderMaterial.new()
	BlockSet.configure(material, kind)
	material.set_shader_parameter("box_centre", bounds.get_center())
	material.set_shader_parameter("box_size", bounds.size)
	material.set_shader_parameter("source_size", bounds.size)
	material.set_shader_parameter("world_to_material", Transform3D(Basis.IDENTITY, bounds.get_center()).affine_inverse())
	var base := Color("c9d8f0") if kind == "reflected" else Color.WHITE
	material.next_pass = PilotLook.shader("res://art_trial/look_pilot/shaders/height_shade.gdshader", {"base": base})
	material.next_pass.render_priority = 1
	return material

func model_material(role: String, source: Material) -> Material:
	match role:
		"ornament":
			return _glaze(CERAMIC, Color.WHITE, 0.3)
		"absolute":
			return _glaze(JADE, Color.WHITE, 0.28)
		"metal":
			return PilotLook.plain(Color("c99a5b"), 0.3, 1.0)
		"pot":
			return PilotLook.plain(Color("b7d0c2"), 0.25)
		"bark":
			return PilotLook.plain(Color("6a4a3a"), 0.8)
	var material := PilotLook.plain(Color.WHITE, 0.85)
	material.vertex_color_use_as_albedo = true
	return material

func frame_material() -> Material:
	return PilotLook.plain(Color("b98b4e"), 0.3, 1.0)

func glass_material() -> Material:
	return PilotLook.shader("res://art_trial/look_pilot/shaders/glass_edge.gdshader")

func goal_material() -> Material:
	return BlockSet.goal_material()

## Petals drifting through the scene, placed from a fixed seed.
func decorate(root: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var petal := QuadMesh.new()
	petal.size = Vector2(0.16, 0.1)
	var material := PilotLook.plain(Color("f2b5b9"), 0.9)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index: int in 22:
		var instance := MeshInstance3D.new()
		instance.mesh = petal
		instance.material_override = material
		instance.position = Vector3(random.randf_range(-6, 10), random.randf_range(-2, 4), random.randf_range(-4, 3))
		instance.rotation = Vector3(random.randf() * TAU, random.randf() * TAU, random.randf() * TAU)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)

func _glaze(maps: Array, color: Color, roughness: float) -> StandardMaterial3D:
	var material := PilotLook.plain(color, roughness)
	material.albedo_texture = load(maps[0])
	material.normal_enabled = true
	material.normal_texture = load(maps[1])
	material.normal_scale = 0.4
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.62
	return material

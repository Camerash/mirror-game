extends PilotLook
## Twilight and lanterns: warm sandstone under a dusk sky, lit by small
## lanterns, with the mirror's copy as luminous cyan glass. Mostly lighting:
## point lights, emission and glow, which the Mobile renderer supports.

const LANTERNS := [
	Vector3(-2.35, 0, -2.2), Vector3(-2.35, 0, 0.3), Vector3(0.6, 0, -1.2),
	Vector3(5.35, 0, -2.2), Vector3(5.35, 0, 1.2), Vector3(8.7, 1, 0.75),
]

func title() -> String:
	return "Twilight lanterns"

func environment() -> Environment:
	var settings := PilotLook.backdrop({
		"top_color": Color("161a44"), "bottom_color": Color("c8879c"), "stars": 1.0,
		"light_top": Color("525a9a"), "light_bottom": Color("9a6a82"),
	})
	settings.ambient_light_energy = 0.95
	settings.glow_enabled = true
	settings.glow_intensity = 0.9
	settings.glow_bloom = 0.12
	settings.glow_hdr_threshold = 0.9
	return settings

func lights() -> Array[Light3D]:
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 150, 0)
	moon.light_color = Color("9fb2ff")
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	moon.shadow_bias = 0.03
	moon.shadow_normal_bias = 0.6
	moon.directional_shadow_max_distance = 40.0
	var result: Array[Light3D] = [moon]
	for at: Vector3 in LANTERNS:
		var lamp := OmniLight3D.new()
		lamp.position = at + Vector3.UP * 0.25
		lamp.light_color = Color("ffad5c")
		lamp.light_energy = 2.2
		lamp.omni_range = 3.0
		lamp.omni_attenuation = 1.6
		result.append(lamp)
	return result

func block_material(kind: String, _bounds: AABB) -> Material:
	var material: BaseMaterial3D
	match kind:
		"reflected":
			material = _glass()
		"absolute":
			material = PilotLook.plain(Color("3f7a62"), 0.35)
			material.emission_enabled = true
			material.emission = Color("2f8f6f")
			material.emission_energy_multiplier = 0.35
		_:
			material = _sandstone()
	if kind != "reflected":
		material.next_pass = PilotLook.shader("res://art_trial/look_pilot/shaders/height_shade.gdshader", {"tint": Color(0.36, 0.3, 0.5)})
	return material

func model_material(role: String, _source: Material) -> Material:
	match role:
		"ornament":
			return _sandstone()
		"absolute":
			var jade := PilotLook.plain(Color("3f7a62"), 0.35)
			jade.emission_enabled = true
			jade.emission = Color("2f8f6f")
			jade.emission_energy_multiplier = 0.4
			return jade
		"metal":
			return _gold(1.0)
		"pot":
			return PilotLook.plain(Color("c9c3bd"), 0.4)
		"bark":
			return PilotLook.plain(Color("4a3428"), 0.85)
	var material := PilotLook.plain(Color.WHITE, 0.85)
	material.vertex_color_use_as_albedo = true
	return material

func frame_material() -> Material:
	return PilotLook.plain(Color("5a5f70"), 0.3, 1.0)

func glass_material() -> Material:
	return PilotLook.shader("res://art_trial/look_pilot/shaders/glass_edge.gdshader", {
		"tint": Color("a9c9ff"), "glow": Color("7fe7ff"), "glow_strength": 2.0, "clarity": 0.06,
	})

func goal_material() -> Material:
	return _gold(2.5)

func decorate(root: Node3D) -> void:
	var body := BoxMesh.new()
	body.size = Vector3(0.14, 0.2, 0.14)
	var glow := PilotLook.plain(Color("ffcf8a"), 0.5)
	glow.emission_enabled = true
	glow.emission = Color("ffa04a")
	glow.emission_energy_multiplier = 4.0
	var cap := BoxMesh.new()
	cap.size = Vector3(0.18, 0.04, 0.18)
	var dark := PilotLook.plain(Color("2b2420"), 0.6)
	for at: Vector3 in LANTERNS:
		for part: Array in [[body, glow, 0.1], [cap, dark, 0.22]]:
			var instance := MeshInstance3D.new()
			instance.mesh = part[0]
			instance.material_override = part[1]
			instance.position = at + Vector3.UP * part[2]
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(instance)
	var random := RandomNumberGenerator.new()
	random.seed = 11
	var mote := SphereMesh.new()
	mote.radius = 0.03
	mote.height = 0.06
	var firefly := PilotLook.plain(Color("e9ff9a"), 1.0)
	firefly.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	firefly.emission_enabled = true
	firefly.emission = Color("d8ff7a")
	firefly.emission_energy_multiplier = 3.0
	for index: int in 16:
		var instance := MeshInstance3D.new()
		instance.mesh = mote
		instance.material_override = firefly
		instance.position = Vector3(random.randf_range(-1, 6), random.randf_range(0.3, 2.5), random.randf_range(-2.5, 1.5))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)

func _sandstone() -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, Color("c48d62"))
	ramp.set_color(1, Color("e2b58a"))
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = ramp
	texture.seamless = true
	texture.width = 256
	texture.height = 256
	var material := PilotLook.plain(Color.WHITE, 0.9)
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.35
	return material

func _glass() -> StandardMaterial3D:
	var material := PilotLook.plain(Color(0.45, 0.9, 1.0, 0.5), 0.15)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color("41c8ff")
	material.emission_energy_multiplier = 1.3
	material.rim_enabled = true
	material.rim = 0.8
	return material

func _gold(glow: float) -> StandardMaterial3D:
	var material := PilotLook.plain(Color("e0b04f"), 0.25, 1.0)
	material.emission_enabled = true
	material.emission = Color("ffbe45")
	material.emission_energy_multiplier = glow
	return material

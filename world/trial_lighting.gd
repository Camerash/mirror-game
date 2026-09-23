extends Node3D
## Fixed light sources keep ceramic highlights stable during mirror manipulation.

var environment := WorldEnvironment.new()
var key := DirectionalLight3D.new()
var fill := DirectionalLight3D.new()

func _ready() -> void:
	environment.environment = Environment.new()
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/environment/studio.gdshader")
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.environment.sky = sky
	environment.environment.background_mode = Environment.BG_COLOR
	add_child(environment)
	key.rotation_degrees = Vector3(-55, -35, 0)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 35.0
	key.shadow_bias = 0.2
	key.shadow_normal_bias = 1.5
	add_child(key)
	fill.rotation_degrees = Vector3(-25, 135, 0)
	fill.light_color = Color("dae3ff")
	add_child(fill)
	var settings := environment.environment
	settings.background_color = Color("807887")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e8e0ea")
	settings.ambient_light_energy = 0.32
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	key.light_color = Color("fff0dc")
	key.light_energy = 0.35
	fill.light_energy = 0.16

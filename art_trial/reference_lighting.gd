extends Node3D
## Studio lighting authored for Mobile; no renderer branches.
func _ready() -> void:
 var world := WorldEnvironment.new()
 var environment := Environment.new()
 world.environment = environment
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color("b09a9d")
 environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
 environment.ambient_light_energy = 0.3
 environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
 var sky := Sky.new()
 var material := ShaderMaterial.new()
 material.shader = preload("res://assets/environment/studio.gdshader")
 sky.sky_material = material
 sky.radiance_size = Sky.RADIANCE_SIZE_512
 environment.sky = sky
 add_child(world)
 var key := DirectionalLight3D.new()
 key.rotation_degrees = Vector3(-55,-25,0)
 key.light_color = Color("fff4df")
 key.light_energy = 0.38
 key.light_angular_distance = 8.0
 key.shadow_enabled = true
 key.shadow_bias = 0.03
 key.shadow_normal_bias = 0.3
 key.directional_shadow_max_distance = 30
 add_child(key)
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(-35,145,0)
 fill.light_color = Color("dbe6ff")
 fill.light_energy = 0.15
 add_child(fill)

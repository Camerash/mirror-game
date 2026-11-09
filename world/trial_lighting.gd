extends Node3D
## The light of a place: a low warm sun from the left of the first view, cool
## light from the sky for the blue of snow shadows, and mist below the path.
## The sun is fixed in the world, so turning the view walks round the light.
## Colours follow `docs/art/STYLE.md`.

const BackdropShader := preload("res://assets/environment/backdrop.gdshader")
const SKY_TOP := Color("a9bcc8")
const MIST := Color("f4e9d8")
## The mist is the edge of the world: it gathers this far above the height
## that ends a fall, but never over the place's own ground.
const MIST_RISE := 2.2
const MIST_CLEAR := 0.3

var environment := WorldEnvironment.new()
var key := DirectionalLight3D.new()
var fill := DirectionalLight3D.new()

func _ready() -> void:
	var backdrop := ShaderMaterial.new()
	backdrop.shader = BackdropShader
	backdrop.set_shader_parameter("top_color", SKY_TOP)
	backdrop.set_shader_parameter("bottom_color", MIST)
	backdrop.set_shader_parameter("light_top", Color("8fabdc"))
	backdrop.set_shader_parameter("light_bottom", Color("a9a7ad"))
	var sky := Sky.new()
	sky.sky_material = backdrop
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_energy = 0.48
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_white = 2.4
	settings.glow_enabled = true
	settings.glow_intensity = 0.25
	settings.glow_bloom = 0.03
	settings.fog_enabled = true
	settings.fog_light_color = MIST
	settings.fog_sun_scatter = 0.0
	settings.fog_density = 0.0
	settings.fog_sky_affect = 0.0
	settings.fog_height_density = 0.9
	environment.environment = settings
	add_child(environment)
	# The sun stands low, behind the first view's left shoulder.
	key.basis = Basis.looking_at(Vector3(-0.3, -0.62, -1.0))
	key.light_color = Color("ffe6c8")
	key.light_energy = 1.6
	key.shadow_enabled = true
	key.shadow_blur = 1.6
	key.directional_shadow_max_distance = 35.0
	key.shadow_bias = 0.05
	key.shadow_normal_bias = 1.0
	add_child(key)
	# A weak cool light from the far side keeps the shaded faces in shape.
	fill.basis = Basis.looking_at(Vector3(1.0, -0.5, 0.35))
	fill.light_color = Color("b4c8f0")
	fill.light_energy = 0.14
	add_child(fill)
	set_floor(-5.0, -1.0)

## Sets the mist for a place whose falls end at `kill_y` and whose lowest
## ground has its underside at `lowest`.
func set_floor(kill_y: float, lowest: float) -> void:
	environment.environment.fog_height = minf(kill_y + MIST_RISE, lowest - MIST_CLEAR)

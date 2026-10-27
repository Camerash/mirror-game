class_name PilotLook
extends RefCounted
## One look for the look pilot: the environment, the lights and every
## material the diorama uses. The base class is the neutral grey box that the
## style boards start from; each look overrides what it changes.

const MODEL_ROLES := {
	"ivory_glaze": "ornament",
	"jade": "absolute",
	"warm_metal": "metal",
	"celadon_glaze": "pot",
	"moss": "moss",
	"bark": "bark",
	"foliage": "foliage",
}

func title() -> String:
	return "Grey box"

func environment() -> Environment:
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("b9b9bd")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.35
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return settings

func lights() -> Array[Light3D]:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 0.6
	key.directional_shadow_max_distance = 40.0
	return [key]

## `kind` is original, reflected or absolute; `bounds` is the block in world space.
func block_material(_kind: String, _bounds: AABB) -> Material:
	return plain(Color("e6e6e6"), 0.8)

## `role` comes from MODEL_ROLES; `source` is the material the model shipped with.
func model_material(role: String, source: Material) -> Material:
	var material := plain(Color("dcdcdc"), 0.8)
	var shipped := source as BaseMaterial3D
	if shipped != null and shipped.vertex_color_use_as_albedo and role in ["moss", "foliage"]:
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color(0.86, 0.86, 0.86)
	return material

func frame_material() -> Material:
	return plain(Color("b8b8b8"), 0.6)

func glass_material() -> Material:
	var material := plain(Color(0.85, 0.88, 0.9, 0.18), 0.1)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func goal_material() -> Material:
	return plain(Color("bdbdbd"), 0.5)

## Extra scenery a look adds around the diorama (backdrops, particles).
func decorate(_root: Node3D) -> void:
	pass

static func plain(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

## An environment whose background is the screen-space backdrop shader.
static func backdrop(parameters: Dictionary) -> Environment:
	var material := ShaderMaterial.new()
	material.shader = preload("res://art_trial/look_pilot/shaders/backdrop.gdshader")
	for key: String in parameters:
		material.set_shader_parameter(key, parameters[key])
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return settings

static func shader(path: String, parameters := {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(path)
	for key: String in parameters:
		material.set_shader_parameter(key, parameters[key])
	return material

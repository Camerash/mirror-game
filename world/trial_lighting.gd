extends Node3D
## The light of a place: a low sun from the left of the first view, and cool
## light from the sky for the colour of snow shadows. The sun is fixed in the
## world, so turning the view walks round the light. Each place names one
## colour script (`"light"` in its level file); the ice below takes its
## colours from the same script. See `docs/art/STYLE.md`.

const BackdropShader := preload("res://assets/environment/backdrop.gdshader")
## One entry per time of day. `sun` and `fill` are the two lights, `sky` and
## `ground` the ambient light from above and below, and the three `ice`
## colours run from the far ice (top of the screen) to the near.
const SCRIPTS := {
	"morning": {
		"sun": Color("ffe6c8"), "sun_energy": 1.6, "fill": Color("b4c8f0"), "fill_energy": 0.14,
		"sky": Color("8fabdc"), "ground": Color("a9a7ad"), "ambient": 0.48,
		"ice_far": Color("e9edf0"), "ice_mid": Color("9db0c6"), "ice_near": Color("4c627f"),
		"glow": Color("ffd596"),
	},
	"dusk": {
		"sun": Color("ffc4a2"), "sun_energy": 1.45, "fill": Color("9a9ff0"), "fill_energy": 0.18,
		"sky": Color("7c84d2"), "ground": Color("6c688f"), "ambient": 0.5,
		"ice_far": Color("eeaa9c"), "ice_mid": Color("6667a8"), "ice_near": Color("23244a"),
		"glow": Color("ffc980"),
	},
}
const DEFAULT_SCRIPT := "morning"
## The ice lies this far under the place's lowest ground, close enough that
## each stone stands over its own image.
const ICE_CLEAR := 0.35

var environment := WorldEnvironment.new()
var key := DirectionalLight3D.new()
var fill := DirectionalLight3D.new()
var backdrop := ShaderMaterial.new()
var script_name := DEFAULT_SCRIPT
## The height of the ice under the current place.
var floor_height := -2.8

func _ready() -> void:
	backdrop.shader = BackdropShader
	var sky := Sky.new()
	sky.sky_material = backdrop
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_white = 2.4
	settings.glow_enabled = true
	settings.glow_intensity = 0.25
	settings.glow_bloom = 0.03
	environment.environment = settings
	add_child(environment)
	# The sun stands low, behind the first view's left shoulder.
	key.basis = Basis.looking_at(Vector3(-0.3, -0.62, -1.0))
	key.shadow_enabled = true
	key.shadow_blur = 1.6
	key.directional_shadow_max_distance = 35.0
	key.shadow_bias = 0.05
	key.shadow_normal_bias = 1.0
	add_child(key)
	# A weak cool light from the far side keeps the shaded faces in shape.
	fill.basis = Basis.looking_at(Vector3(1.0, -0.5, 0.35))
	add_child(fill)
	set_place(DEFAULT_SCRIPT)

## The colours of the current place.
func palette() -> Dictionary:
	return SCRIPTS[script_name]

## Lights the place by the colour script `name`; an unknown name is morning.
func set_place(name: String) -> void:
	script_name = name if SCRIPTS.has(name) else DEFAULT_SCRIPT
	var colors: Dictionary = palette()
	key.light_color = colors["sun"]
	key.light_energy = colors["sun_energy"]
	fill.light_color = colors["fill"]
	fill.light_energy = colors["fill_energy"]
	environment.environment.ambient_light_energy = colors["ambient"]
	backdrop.set_shader_parameter("top_color", colors["ice_far"])
	backdrop.set_shader_parameter("bottom_color", colors["ice_near"])
	backdrop.set_shader_parameter("light_top", colors["sky"])
	backdrop.set_shader_parameter("light_bottom", colors["ground"])

## Sets the ice for a place whose lowest ground has its underside at
## `lowest`. Falls end at `kill_y`, somewhere under the ice.
func set_floor(kill_y: float, lowest: float) -> void:
	floor_height = maxf(kill_y, lowest - ICE_CLEAR)

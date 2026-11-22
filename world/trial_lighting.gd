extends Node3D
## The light of a place: a low sun ahead of the first view and to its right,
## so the place stands against the light, and cool light from the sky for the
## colour of snow shadows. The sun is fixed in the world, so turning the view
## walks round the light: one view looks into the sun, the opposite one has it
## behind. A place can name a colour script (`"light"` in its level file);
## without a name it has the default. The water below takes its colours
## from the same script. See `docs/art/STYLE.md`.

const BackdropShader := preload("res://assets/environment/backdrop.gdshader")
## One entry per colour script. `sun` and `fill` are the two lights, `sky` and
## `ground` the ambient light from above and below, and the three `ice`
## colours are the water's, from the far water (top of the screen) to the
## near. `sun_from` points from the place to the sun, `haze` is the colour
## of the air, which the pond's scenery takes on, and `lamp` is the one warm
## light: the lit window of the garden.
const SCRIPTS := {
	# Winter with almost no colour (owner, 2026-11-17): dark slate water that
	# goes into pale mist far away, and a soft high light.
	"pale": {
		"sun": Color("f3efe8"), "sun_energy": 1.5, "fill": Color("d3dade"), "fill_energy": 0.42,
		"sky": Color("b6c2c8"), "ground": Color("a6a8a4"), "ambient": 0.34,
		"ice_far": Color("ced3d2"), "ice_mid": Color("5c6f7b"), "ice_near": Color("2b3944"),
		"sun_from": Vector3(-0.17, 0.8, -0.98),
		"haze": Color("8d999e"), "lamp": Color("ffb665"),
	},
}
const DEFAULT_SCRIPT := "pale"
## A place floats this far above the water. The water is the one floor of
## the place: each stone and each copy has its shadow straight below it on
## the water, so the water shows the plan of the place, and the height of a
## thing is its distance from its shadow.
const FLOAT_GAP := 2.0

var environment := WorldEnvironment.new()
var key := DirectionalLight3D.new()
var fill := DirectionalLight3D.new()
var backdrop := ShaderMaterial.new()
var script_name := DEFAULT_SCRIPT
## The height of the water under the current place.
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
	settings.glow_intensity = 0.42
	settings.glow_bloom = 0.05
	environment.environment = settings
	add_child(environment)
	key.shadow_enabled = true
	key.shadow_blur = 1.0
	# One shadow map covers the whole view. The game sets its reach from the
	# distance of the stage camera; 80 suits a camera 40 units away.
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 80.0
	key.shadow_bias = 0.06
	key.shadow_normal_bias = 0.9
	add_child(key)
	# A weak cool light from behind the first view keeps the shaded faces in
	# shape.
	fill.basis = Basis.looking_at(Vector3(-0.85, -0.4, -0.4))
	add_child(fill)
	set_place(DEFAULT_SCRIPT)

## The colours of the current place.
func palette() -> Dictionary:
	return SCRIPTS[script_name]

## Lights the place by the colour script `name`; an unknown name is the default.
func set_place(name: String) -> void:
	script_name = name if SCRIPTS.has(name) else DEFAULT_SCRIPT
	var colors: Dictionary = palette()
	key.basis = Basis.looking_at(-(colors["sun_from"] as Vector3))
	key.light_color = colors["sun"]
	key.light_energy = colors["sun_energy"]
	fill.light_color = colors["fill"]
	fill.light_energy = colors["fill_energy"]
	environment.environment.ambient_light_energy = colors["ambient"]
	backdrop.set_shader_parameter("top_color", colors["ice_far"])
	backdrop.set_shader_parameter("bottom_color", colors["ice_near"])
	backdrop.set_shader_parameter("light_top", colors["sky"])
	backdrop.set_shader_parameter("light_bottom", colors["ground"])

## Sets the water for a place whose lowest ground has its underside at
## `lowest`. Falls end at `kill_y`, somewhere under the water.
func set_floor(kill_y: float, lowest: float) -> void:
	floor_height = maxf(kill_y, lowest - FLOAT_GAP)

extends Node3D
## The light of a place: a low sun ahead of the first view and to its right,
## so the place stands against the light, and cool light from the sky for the
## colour of snow shadows. The sun is fixed in the world, so turning the view
## walks round the light: one view looks into the sun, the opposite one has it
## behind. Each place names one
## colour script (`"light"` in its level file); the ice below takes its
## colours from the same script. See `docs/art/STYLE.md`.

const BackdropShader := preload("res://assets/environment/backdrop.gdshader")
## One entry per time of day. `sun` and `fill` are the two lights, `sky` and
## `ground` the ambient light from above and below, and the three `ice`
## colours run from the far ice (top of the screen) to the near. `sun_from`
## points from the place to the sun. `shore` is the dark of the far trees the
## ice holds, `ice_snow` the blown snow that lies on the ice, and `haze` the
## colour of the air, which the pond's scenery takes on.
const SCRIPTS := {
	"morning": {
		"sun": Color("ffe2bd"), "sun_energy": 1.9, "fill": Color("e8d2b8"), "fill_energy": 0.30,
		"sky": Color("8fb0dc"), "ground": Color("a89c94"), "ambient": 0.22,
		"ice_far": Color("efc79c"), "ice_mid": Color("2f5a78"), "ice_near": Color("08192a"),
		"glow": Color("ffb665"), "sun_from": Vector3(-0.17, 0.5, -0.98),
		"shore": Color("1d3345"), "ice_snow": Color("b4c6dc"), "shade": 0.22, "haze": Color("33485a"),
	},
	"dusk": {
		"sun": Color("ffd4bc"), "sun_energy": 2.5, "fill": Color("f0b8a0"), "fill_energy": 0.38,
		"sky": Color("a08cb8"), "ground": Color("a8807e"), "ambient": 0.24,
		"ice_far": Color("f0a48e"), "ice_mid": Color("26276a"), "ice_near": Color("06071a"),
		"glow": Color("ffad5c"), "sun_from": Vector3(-0.17, 0.44, -0.98),
		"shore": Color("1c1838"), "ice_snow": Color("a9a0d0"), "shade": 0.22, "haze": Color("372c58"),
	},
}
const DEFAULT_SCRIPT := "morning"
## The lowest ground of a place stands on the ice, so each stone joins its
## own image at the foot and the image cannot be taken for a second stone.
const ICE_CLEAR := 0.01
## The ice is alone on this render layer, so a light can leave it out.
const ICE_LAYER := 1 << 11

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
	settings.glow_intensity = 0.42
	settings.glow_bloom = 0.05
	environment.environment = settings
	add_child(environment)
	key.shadow_enabled = true
	key.shadow_blur = 1.0
	# The stage camera stands 40 units from the place; one shadow map covers
	# the whole view.
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 80.0
	key.shadow_bias = 0.06
	key.shadow_normal_bias = 0.9
	add_child(key)
	# A weak cool light from behind the first view keeps the shaded faces in
	# shape. It does not light the ice, which takes only the sun's shadow.
	fill.basis = Basis.looking_at(Vector3(-0.85, -0.4, -0.4))
	fill.light_cull_mask &= ~ICE_LAYER
	add_child(fill)
	set_place(DEFAULT_SCRIPT)

## The colours of the current place.
func palette() -> Dictionary:
	return SCRIPTS[script_name]

## Lights the place by the colour script `name`; an unknown name is morning.
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

## Sets the ice for a place whose lowest ground has its underside at
## `lowest`. Falls end at `kill_y`, somewhere under the ice.
func set_floor(kill_y: float, lowest: float) -> void:
	floor_height = maxf(kill_y, lowest - ICE_CLEAR)

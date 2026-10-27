extends PilotLook
## Paper and ink: unlit paper surfaces with banded watercolour washes, ink
## outlines from inverted hulls, the mirror's copy brushed in blue ink, and
## ink-wash mountains on a paper backdrop. One vermilion accent: the goal.

const SURFACE := "res://art_trial/look_pilot/shaders/ink_surface.gdshader"
const OUTLINE := "res://art_trial/look_pilot/shaders/ink_outline.gdshader"
const WASH := "res://art_trial/look_pilot/shaders/ink_wash.gdshader"

func title() -> String:
	return "Paper and ink"

func environment() -> Environment:
	var settings := PilotLook.backdrop({
		"top_color": Color("f1ece2"), "bottom_color": Color("ebe4d6"),
		"mountains": 1.0, "mountain_color": Color("8f9296"),
		"light_top": Color("ffffff"), "light_bottom": Color("cccccc"),
	})
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	return settings

## Surfaces are unlit, so the light only matters for the traveller.
func lights() -> Array[Light3D]:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 0.9
	return [light]

func block_material(kind: String, bounds: AABB) -> Material:
	var material: ShaderMaterial
	var box := {"box_centre": bounds.get_center(), "box_size": bounds.size}
	if kind == "reflected":
		material = PilotLook.shader(WASH)
	elif kind == "absolute":
		material = PilotLook.shader(SURFACE, box.merged({"wash": Color("4f7567"), "strength": 1.0}))
	else:
		material = PilotLook.shader(SURFACE, box.merged({"wash": Color("4c5a70"), "strength": 0.95}))
	material.next_pass = PilotLook.shader(OUTLINE)
	return material

func model_material(role: String, _source: Material) -> Material:
	var material: ShaderMaterial
	match role:
		"absolute":
			material = PilotLook.shader(SURFACE, {"wash": Color("5f8577"), "strength": 0.8})
		"metal":
			material = PilotLook.shader(SURFACE, {"paper": Color("c8442e"), "wash": Color("7d2418")})
		"bark":
			material = PilotLook.shader(SURFACE, {"paper": Color("4a4440"), "wash": Color("1e1c1b")})
		"foliage", "moss":
			material = PilotLook.shader(SURFACE, {"paper": Color("6f8a66"), "wash": Color("2f4433"), "strength": 0.8})
		"pot":
			material = PilotLook.shader(SURFACE, {"wash": Color("7b8d99")})
		_:
			material = PilotLook.shader(SURFACE, {"underside": 0.0})
	material.next_pass = PilotLook.shader(OUTLINE, {"box": false, "width": 0.012})
	return material

func frame_material() -> Material:
	var material := PilotLook.shader(SURFACE, {"paper": Color("cdb48d"), "wash": Color("8a6a43")})
	material.next_pass = PilotLook.shader(OUTLINE, {"width": 0.012})
	return material

func glass_material() -> Material:
	return PilotLook.shader("res://art_trial/look_pilot/shaders/glass_edge.gdshader", {
		"tint": Color("dfe7ee"), "glow": Color("9fb7d0"), "glow_strength": 0.0, "clarity": 0.12,
	})

func goal_material() -> Material:
	var material := PilotLook.plain(Color("d2462e"), 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

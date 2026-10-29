extends PilotLook
## Tide pool and sea glass: pale sandstone crusted with shells and
## barnacles, shallow pools with caustic light on the terraces, under a
## misty coastal sky. The mirror's copy is frosted aqua sea glass; the goal
## block is mother-of-pearl.

const STONE := "res://art_trial/look_pilot/shaders/stone.gdshader"
const POOLS := [
	[Vector3(-4.0, 0.006, -1.45), Vector2(1.6, 1.5), 0.0],
	[Vector3(5.5, 0.006, 0.6), Vector2(0.9, 1.4), 4.0],
	[Vector3(7.6, 0.006, -2.27), Vector2(1.6, 0.42), 9.0],
]
const SHELLS := [Color("e79fb4"), Color("b79ad6"), Color("f2e2cc"), Color("e8a07e"), Color("f6eee6")]

func title() -> String:
	return "Tide pool and sea glass"

func environment() -> Environment:
	var settings := PilotLook.backdrop({
		"top_color": Color("a6b7c4"), "bottom_color": Color("dde3e5"),
		"clouds": 1.0, "cloud_color": Color("f1f3f2"),
		"light_top": Color("c8ccce"), "light_bottom": Color("9a8a7a"),
	})
	settings.ambient_light_energy = 0.3
	settings.glow_enabled = true
	settings.glow_intensity = 0.35
	settings.glow_bloom = 0.06
	return settings

func lights() -> Array[Light3D]:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -125, 0)
	sun.light_color = Color("fff0dc")
	sun.light_energy = 1.55
	sun.light_angular_distance = 4.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.6
	sun.directional_shadow_max_distance = 40.0
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 45, 0)
	fill.light_color = Color("bcd4e6")
	fill.light_energy = 0.25
	return [sun, fill]

func block_material(kind: String, bounds: AABB) -> Material:
	var box := {"box_centre": bounds.get_center(), "box_size": bounds.size}
	match kind:
		"reflected":
			return PilotLook.shader("res://art_trial/look_pilot/shaders/sea_glass.gdshader", box)
		"absolute":
			return PilotLook.shader("res://art_trial/look_pilot/shaders/pearl.gdshader")
	return PilotLook.shader(STONE, box.merged(_sand()))

func model_material(role: String, _source: Material) -> Material:
	match role:
		"ornament":
			return PilotLook.shader(STONE, {"bricks": 0.0, "stone": Color("d8c9ae"), "grain": 0.1, "under_tint": Color.WHITE})
		"absolute":
			return PilotLook.shader("res://art_trial/look_pilot/shaders/pearl.gdshader")
		"metal":
			return PilotLook.plain(Color("a58c62"), 0.35, 0.85)
		"pot":
			return PilotLook.plain(Color("cfc4b3"), 0.6)
		"bark":
			return PilotLook.plain(Color("5a4636"), 0.85)
	var material := PilotLook.plain(Color.WHITE, 0.85)
	material.vertex_color_use_as_albedo = true
	return material

func frame_material() -> Material:
	return PilotLook.plain(Color("7d6238"), 0.35, 0.9)

func glass_material() -> Material:
	return PilotLook.shader("res://art_trial/look_pilot/shaders/glass_edge.gdshader", {
		"tint": Color("cfdde4"), "glow": Color("e6f2f2"), "glow_strength": 0.2, "clarity": 0.2,
	})

func goal_material() -> Material:
	return PilotLook.plain(Color("e9e9ee"), 0.15, 1.0)

## Shallow pools on the terraces, then shells and barnacles on the sand.
func decorate(root: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 33
	var clear: Array = [[Vector3(-2.7, 0, -0.5), 0.4], [Vector3(-4.1, 0, 0.6), 0.5], [Vector3(7.5, 1, -0.5), 1.2]]
	for pool: Array in POOLS:
		var plane := PlaneMesh.new()
		plane.size = pool[1]
		var instance := MeshInstance3D.new()
		instance.mesh = plane
		instance.position = pool[0]
		instance.material_override = PilotLook.shader("res://art_trial/look_pilot/shaders/pool.gdshader", {"seed": pool[2]})
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
		clear.append([pool[0], maxf(pool[1].x, pool[1].y) * 0.45])
	var shell := SphereMesh.new()
	shell.radius = 0.07
	shell.height = 0.14
	shell.radial_segments = 10
	shell.rings = 5
	var shells: Array[Transform3D] = []
	var shell_colors: Array[Color] = []
	var barnacle := CylinderMesh.new()
	barnacle.top_radius = 0.012
	barnacle.bottom_radius = 0.028
	barnacle.height = 0.03
	barnacle.radial_segments = 8
	barnacle.rings = 1
	var barnacles: Array[Transform3D] = []
	var barnacle_colors: Array[Color] = []
	for facing: String in ["top", "side"]:
		var on_top := facing == "top"
		for point: Array in PilotScatter.points(["original"], facing, 70 if on_top else 90, 17 if on_top else 19, clear):
			var basis := PilotScatter.facing(point[1], random.randf() * TAU)
			shells.append(Transform3D(basis.scaled(Vector3(random.randf_range(0.8, 1.4), 0.32, random.randf_range(0.7, 1.0))), point[0]))
			shell_colors.append(SHELLS[random.randi() % SHELLS.size()])
		for point: Array in PilotScatter.points(["original"], facing, 30 if on_top else 120, 23 if on_top else 29, clear):
			for index: int in random.randi_range(1, 4):
				var basis := PilotScatter.facing(point[1], 0.0)
				var offset := basis * Vector3(random.randf_range(-0.06, 0.06), 0, random.randf_range(-0.06, 0.06))
				barnacles.append(Transform3D(basis.scaled(Vector3.ONE * random.randf_range(0.6, 1.3)), point[0] + offset + point[1] * 0.012))
				barnacle_colors.append(Color("d8cfc0").lerp(Color("9d9488"), random.randf()))
	PilotScatter.draw(root, shell, shells, PilotScatter.tinted(0.4), shell_colors, false)
	PilotScatter.draw(root, barnacle, barnacles, PilotScatter.tinted(0.8), barnacle_colors, false)

func _sand() -> Dictionary:
	return {
		"stone": Color("ecd3a2"), "groove_color": Color("b39d77"), "under_tint": Color("c4aea0"),
		"bricks": 0.0, "grain": 0.1, "bump": 0.8, "shells": 1.0, "wet": 0.6,
	}

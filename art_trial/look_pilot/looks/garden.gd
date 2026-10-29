extends PilotLook
## Overgrown garden: pale limestone brickwork with moss, grass and ivy under
## a low warm morning sun and a hazy green sky. The mirror's copy is the
## same path in full bloom, as if from a life where the town was never left.
## The goal block is old bronze under green patina.

const STONE := "res://art_trial/look_pilot/shaders/stone.gdshader"
const KEEP_CLEAR := [
	[Vector3(-2.7, 0, -0.5), 0.45], [Vector3(-4.1, 0, 0.6), 0.55],
	[Vector3(7.5, 1, -0.5), 1.25], [Vector3(9.5, 1, -0.5), 0.5],
]
const PETALS := [Color("f08fb8"), Color("f6f1e6"), Color("f2c83e"), Color("b796e6"), Color("f39a7a")]

func title() -> String:
	return "Overgrown garden"

func environment() -> Environment:
	var settings := PilotLook.backdrop({
		"top_color": Color("bfd0a4"), "bottom_color": Color("e4e8c8"),
		"clouds": 1.0, "cloud_color": Color("f5f3df"),
		"light_top": Color("c9d1b0"), "light_bottom": Color("6f7656"),
	})
	settings.ambient_light_energy = 0.28
	settings.tonemap_exposure = 0.95
	settings.glow_enabled = true
	settings.glow_intensity = 0.3
	settings.glow_bloom = 0.05
	return settings

func lights() -> Array[Light3D]:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -125, 0)
	sun.light_color = Color("ffdcaa")
	sun.light_energy = 1.7
	sun.light_angular_distance = 2.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.6
	sun.directional_shadow_max_distance = 40.0
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 45, 0)
	fill.light_color = Color("c8dccf")
	fill.light_energy = 0.2
	return [sun, fill]

func block_material(kind: String, bounds: AABB) -> Material:
	var box := {"box_centre": bounds.get_center(), "box_size": bounds.size}
	match kind:
		"reflected":
			return PilotLook.shader("res://art_trial/look_pilot/shaders/bloom.gdshader")
		"absolute":
			return PilotLook.shader("res://art_trial/look_pilot/shaders/patina.gdshader", box)
	return PilotLook.shader(STONE, box.merged({"moss": 1.0, "stone": Color("d9cfb4"), "groove_color": Color("978d76"), "under_tint": Color("8d977a")}))

func model_material(role: String, _source: Material) -> Material:
	match role:
		"ornament":
			return PilotLook.shader(STONE, {"bricks": 0.0, "moss": 0.5, "stone": Color("e2dbc6")})
		"absolute":
			return PilotLook.shader("res://art_trial/look_pilot/shaders/patina.gdshader")
		"metal":
			return PilotLook.plain(Color("a9824a"), 0.35, 0.9)
		"pot":
			return PilotLook.plain(Color("b9ad99"), 0.7)
		"bark":
			return PilotLook.plain(Color("5a4232"), 0.85)
	var material := PilotLook.plain(Color(0.9, 1.0, 0.8), 0.85)
	material.vertex_color_use_as_albedo = true
	return material

func frame_material() -> Material:
	return PilotLook.plain(Color("5b4433"), 0.6)

func glass_material() -> Material:
	return PilotLook.shader("res://art_trial/look_pilot/shaders/glass_edge.gdshader", {
		"tint": Color("dfe8e4"), "glow": Color("f4f0dc"), "glow_strength": 0.3, "clarity": 0.16,
	})

func goal_material() -> Material:
	return PilotLook.plain(Color("d2a85e"), 0.25, 1.0)

func decorate(root: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 21
	_grass(root, random)
	_ivy(root, random)
	_blossom(root, random)
	_butterflies(root, random)

## Grass tufts and a few wildflowers on the stone tops.
func _grass(root: Node3D, random: RandomNumberGenerator) -> void:
	var blade := BoxMesh.new()
	blade.size = Vector3(0.018, 0.14, 0.01)
	var blades: Array[Transform3D] = []
	var greens: Array[Color] = []
	var heads: Array[Transform3D] = []
	var head_colors: Array[Color] = []
	for point: Array in PilotScatter.points(["original"], "top", 90, 5, KEEP_CLEAR):
		for index: int in random.randi_range(6, 14):
			var offset := Vector3(random.randf_range(-0.09, 0.09), 0, random.randf_range(-0.09, 0.09))
			var tilt := Basis(Vector3.UP, random.randf() * TAU) * Basis(Vector3.RIGHT, random.randf_range(-0.5, 0.5))
			var height := random.randf_range(0.6, 1.3)
			blades.append(Transform3D(tilt.scaled(Vector3(1, height, 1)), point[0] + offset + tilt * Vector3.UP * 0.07 * height))
			greens.append(Color("6f9a3a").lerp(Color("b7c86a"), random.randf()))
		if random.randf() < 0.45:
			heads.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * random.randf_range(0.7, 1.2)), point[0] + Vector3(0, 0.13, 0)))
			head_colors.append(PETALS[random.randi() % PETALS.size()])
	PilotScatter.draw(root, blade, blades, PilotScatter.tinted(0.9, true), greens, false)
	var head := SphereMesh.new()
	head.radius = 0.03
	head.height = 0.045
	PilotScatter.draw(root, head, heads, PilotScatter.tinted(0.8), head_colors, false)

## Ivy hanging from the top edges of the stone sides.
func _ivy(root: Node3D, random: RandomNumberGenerator) -> void:
	var leaf := SphereMesh.new()
	leaf.radius = 0.07
	leaf.height = 0.035
	leaf.radial_segments = 8
	leaf.rings = 4
	var leaves: Array[Transform3D] = []
	var colors: Array[Color] = []
	for point: Array in PilotScatter.points(["original"], "side", 70, 9, [], 0.9):
		var normal: Vector3 = point[1]
		var drop := random.randf_range(0.25, 1.5)
		var sway := random.randf_range(-0.3, 0.3)
		var along := normal.cross(Vector3.UP)
		var count := int(drop / 0.05)
		for index: int in count:
			var t := float(index) / count
			var at: Vector3 = point[0] + Vector3.DOWN * drop * t + along * (sway * t + random.randf_range(-0.05, 0.05)) + normal * random.randf_range(0.02, 0.06)
			var basis := PilotScatter.facing(normal.lerp(Vector3(random.randf_range(-0.5, 0.5), random.randf_range(-0.3, 0.6), random.randf_range(-0.5, 0.5)), 0.4).normalized(), random.randf() * TAU)
			leaves.append(Transform3D(basis.scaled(Vector3.ONE * random.randf_range(0.7, 1.25)), at))
			colors.append(Color("2c5220").lerp(Color("6d9440"), random.randf()))
	PilotScatter.draw(root, leaf, leaves, PilotScatter.tinted(0.75), colors)

## The copy's blossom: a deep meadow cover of flower heads and grass.
func _blossom(root: Node3D, random: RandomNumberGenerator) -> void:
	var flower := SphereMesh.new()
	flower.radius = 0.045
	flower.height = 0.06
	flower.radial_segments = 8
	flower.rings = 4
	var flowers: Array[Transform3D] = []
	var colors: Array[Color] = []
	for facing: String in ["top", "side"]:
		for point: Array in PilotScatter.points(["reflected"], facing, 520 if facing == "top" else 380, 13):
			var lift := random.randf_range(0.0, 0.12) if facing == "top" else random.randf_range(0.0, 0.06)
			var at: Vector3 = point[0] + point[1] * lift
			flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * random.randf_range(0.6, 1.3)), at))
			var green := random.randf() < 0.4
			colors.append(Color("5f8f34").lerp(Color("a3c25a"), random.randf()) if green else PETALS[random.randi() % PETALS.size()])
	PilotScatter.draw(root, flower, flowers, PilotScatter.tinted(0.9), colors)

func _butterflies(root: Node3D, random: RandomNumberGenerator) -> void:
	var wing := QuadMesh.new()
	wing.size = Vector2(0.16, 0.12)
	var wings: Array[Transform3D] = []
	var colors: Array[Color] = []
	for index: int in 6:
		var at := Vector3(random.randf_range(1.5, 5.5), random.randf_range(0.3, 1.6), random.randf_range(-2.0, 1.0))
		var heading := Basis(Vector3.UP, random.randf() * TAU)
		var color: Color = [Color("5b9be0"), Color("f08a2c"), Color("f2d24a")][index % 3]
		for side: float in [-1.0, 1.0]:
			var hinge := heading * Basis(Vector3.FORWARD, side * 0.6)
			wings.append(Transform3D(hinge * Basis(Vector3.RIGHT, -PI * 0.5), at + hinge * Vector3(side * 0.08, 0, 0)))
			colors.append(color)
	var material := PilotScatter.tinted(0.6, true)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	PilotScatter.draw(root, wing, wings, material, colors, false)

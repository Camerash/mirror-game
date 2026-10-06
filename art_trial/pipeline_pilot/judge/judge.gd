extends SceneTree
## Pilot judge. Renders glTF assets under the game's lighting from its four
## orthographic views (yaw 45/135/225/315 degrees, 30 degrees down), plus one
## view at in-game pixel scale, and reports mesh statistics.
## Needs a display (xvfb-run) and the Mobile renderer:
##   godot --path <judge> --rendering-method mobile -s judge.gd -- --input a.glb[,b.glb] --out <dir>
##   godot --path <judge> --rendering-method mobile -s judge.gd -- --selftest <file.glb>

const ELEVATION := PI / 6.0
const YAWS: Array[float] = [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]
const CLOSE_SIZE := Vector2i(1024, 1024)
const GAME_SIZE := Vector2i(1152, 800)
## World units shown vertically at game scale: the 0.8-unit traveller is
## about 60 pixels tall, as in the game on a 1152x800 window.
const GAME_VIEW_HEIGHT := 9.0
const TRAVELLER_RADIUS := 0.18
const TRAVELLER_HEIGHT := 0.8

var _args: Dictionary = {}

func _initialize() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	_run.call_deferred()

func _parse(list: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var index := 0
	while index < list.size():
		var key := list[index].trim_prefix("--")
		var value := "true"
		if index + 1 < list.size() and not list[index + 1].begins_with("--"):
			value = list[index + 1]
			index += 1
		result[key] = value
		index += 1
	return result

func _run() -> void:
	if _args.has("selftest"):
		quit(_write_selftest(str(_args["selftest"])))
		return
	if not _args.has("input") or not _args.has("out"):
		push_error("Usage: -- --input a.glb[,b.glb] --out <dir>")
		quit(2)
		return
	var out := str(_args["out"])
	DirAccess.make_dir_recursive_absolute(out)
	_build_lighting()
	var assets := Node3D.new()
	root.add_child(assets)
	var stats: Dictionary = {"triangles": 0, "surfaces": 0, "materials": [], "surfaces_without_normals": 0, "surfaces_without_uvs": 0, "assets": []}
	var cursor := 0.0
	for path: String in str(_args["input"]).split(","):
		var node := _load_gltf(path)
		if node == null:
			quit(1)
			return
		assets.add_child(node)
		var box := _bounds(node)
		node.position = Vector3(cursor - box.position.x, -box.position.y, -box.get_center().z)
		cursor += box.size.x + 0.8
		var before: int = stats["triangles"]
		_collect(node, stats)
		stats["assets"].append({"file": path.get_file(), "size": [snappedf(box.size.x, 0.001), snappedf(box.size.y, 0.001), snappedf(box.size.z, 0.001)], "triangles": int(stats["triangles"]) - before})
	var total := _bounds(assets)
	assets.position.x -= total.get_center().x
	var traveller := _traveller()
	traveller.position = Vector3(total.size.x * 0.5 + 0.45, TRAVELLER_HEIGHT * 0.5, 0.0)
	root.add_child(traveller)
	_build_ground(total.size.x + 3.0, maxf(total.size.z, 1.0) + 3.0)
	var framed := _bounds(assets).merge(AABB(traveller.position - Vector3(0.2, 0.4, 0.2), Vector3(0.4, 0.8, 0.4)))
	var images: Array[Image] = []
	for index: int in YAWS.size():
		var image := await _render(CLOSE_SIZE, YAWS[index], _fit(framed, YAWS[index], CLOSE_SIZE), framed.get_center())
		image.save_png(out.path_join("view_%d.png" % (index + 1)))
		images.append(image)
	var game := await _render(GAME_SIZE, YAWS[0], GAME_VIEW_HEIGHT, framed.get_center())
	game.save_png(out.path_join("game_scale.png"))
	var sheet := Image.create(CLOSE_SIZE.x, CLOSE_SIZE.y, false, Image.FORMAT_RGBA8)
	for index: int in images.size():
		var copy := images[index].duplicate() as Image
		copy.convert(Image.FORMAT_RGBA8)
		copy.resize(CLOSE_SIZE.x / 2, CLOSE_SIZE.y / 2, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), Vector2i(index % 2, index / 2) * (CLOSE_SIZE / 2))
	sheet.save_png(out.path_join("sheet.png"))
	stats["materials"] = (stats["materials"] as Array).size()
	var file := FileAccess.open(out.path_join("stats.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(stats, "  "))
	file.close()
	print(JSON.stringify(stats))
	quit(0)

func _load_gltf(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("Could not read %s (error %d)" % [path, error])
		return null
	var scene := document.generate_scene(state)
	if not scene is Node3D:
		push_error("No 3D scene in " + path)
		return null
	return scene as Node3D

func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child: Node in _meshes(node):
		var instance := child as MeshInstance3D
		var box := instance.global_transform * instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		result.append_array(_meshes(child))
	return result

func _collect(node: Node3D, stats: Dictionary) -> void:
	for instance: MeshInstance3D in _meshes(node):
		var mesh := instance.mesh
		for surface: int in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			var count: int = (indices as PackedInt32Array).size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			stats["triangles"] = int(stats["triangles"]) + count / 3
			stats["surfaces"] = int(stats["surfaces"]) + 1
			if arrays[Mesh.ARRAY_NORMAL] == null:
				stats["surfaces_without_normals"] = int(stats["surfaces_without_normals"]) + 1
			if arrays[Mesh.ARRAY_TEX_UV] == null:
				stats["surfaces_without_uvs"] = int(stats["surfaces_without_uvs"]) + 1
			var material := instance.get_active_material(surface)
			if material != null and not (stats["materials"] as Array).has(material):
				(stats["materials"] as Array).append(material)

## The game's Level 1 lighting (world/trial_lighting.gd).
func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://studio.gdshader")
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.sky = sky
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("807887")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e8e0ea")
	environment.ambient_light_energy = 0.32
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world.environment = environment
	root.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -35, 0)
	key.light_color = Color("fff0dc")
	key.light_energy = 0.35
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 35.0
	key.shadow_bias = 0.2
	key.shadow_normal_bias = 1.5
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 135, 0)
	fill.light_color = Color("dae3ff")
	fill.light_energy = 0.16
	root.add_child(fill)

## Unit floor tiles with narrow gaps, so the game grid reads at a glance.
func _build_ground(width: float, depth: float) -> void:
	var tile := BoxMesh.new()
	tile.size = Vector3(0.97, 1.0, 0.97)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9d94a0")
	material.roughness = 0.6
	tile.material = material
	var half_x := ceili(width * 0.5)
	var half_z := ceili(depth * 0.5)
	for x: int in range(-half_x, half_x):
		for z: int in range(-half_z, half_z):
			var instance := MeshInstance3D.new()
			instance.mesh = tile
			instance.position = Vector3(x + 0.5, -0.5, z + 0.5)
			root.add_child(instance)

## A blue-grey capsule with the traveller's collision size, for scale.
func _traveller() -> MeshInstance3D:
	var capsule := CapsuleMesh.new()
	capsule.radius = TRAVELLER_RADIUS
	capsule.height = TRAVELLER_HEIGHT
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6f8296")
	material.roughness = 0.6
	capsule.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = capsule
	return instance

func _direction(yaw: float) -> Vector3:
	return Vector3(cos(yaw) * cos(ELEVATION), sin(ELEVATION), sin(yaw) * cos(ELEVATION))

## Orthographic height that fits the box in the view, with a margin.
func _fit(box: AABB, yaw: float, size: Vector2i) -> float:
	var view := Basis.looking_at(-_direction(yaw), Vector3.UP)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for index: int in 8:
		var corner := view.inverse() * (box.get_endpoint(index) - box.get_center())
		low = low.min(Vector2(corner.x, corner.y))
		high = high.max(Vector2(corner.x, corner.y))
	var extent := high - low
	return maxf(extent.y, extent.x * float(size.y) / float(size.x)) * 1.15

func _render(size: Vector2i, yaw: float, height: float, centre: Vector3) -> Image:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = height
	camera.near = 0.05
	camera.far = 200.0
	viewport.add_child(camera)
	root.add_child(viewport)
	var direction := _direction(yaw)
	camera.global_transform = Transform3D(Basis.looking_at(-direction, Vector3.UP), centre + direction * 40.0)
	camera.current = true
	for frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image

## Writes a small two-part glTF to check the judge itself.
func _write_selftest(path: String) -> int:
	var scene := Node3D.new()
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	var glaze := StandardMaterial3D.new()
	glaze.albedo_color = Color("efe7da")
	glaze.roughness = 0.35
	box.material = glaze
	block.mesh = box
	block.position = Vector3(0, 0.5, 0)
	scene.add_child(block)
	var column := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.2
	cylinder.height = 2.0
	column.mesh = cylinder
	column.position = Vector3(1.2, 1.0, 0)
	scene.add_child(column)
	root.add_child(scene)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(scene, state)
	if error == OK:
		error = document.write_to_filesystem(state, path)
	print("selftest write: %d" % error)
	return 0 if error == OK else 1

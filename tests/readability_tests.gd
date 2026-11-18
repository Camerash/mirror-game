extends SceneTree
## Cues that make positions readable (playtest fix 5): a drop shadow straight
## below floating blocks, a mark where a tap asks for an unreachable place,
## and the walking path on desktop hover.

const Game := preload("res://game.gd")
const Geometry := preload("res://core/world_geometry.gd")
const Polygons := preload("res://core/display_geometry.gd")

var game: Node3D
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for index: int in count:
		await process_frame


func load_stage(name: String) -> void:
	check(game.load_level(Game.LEVEL_PATHS.find("res://levels/%s.json" % name)), "Loads " + name)
	for index: int in 300:
		if game.settle_frames == 0 and game.phase == "play" and not game.camera.busy:
			break
		await process_frame
	await frames(2)


func screen(point: Vector3) -> Vector2:
	return game.camera.unproject_position(point)


func shadow_area() -> float:
	var mesh := game.world.shadow_root.mesh as ArrayMesh
	if mesh == null:
		return 0.0
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var area := 0.0
	for index: int in range(0, points.size(), 3):
		area += (points[index + 1] - points[index]).cross(points[index + 2] - points[index]).length() * 0.5
	return area


func run() -> void:
	root.size = Vector2i(1152, 800)
	game = Game.new()
	game.direct_controls = true
	game.auto_advance = false
	root.add_child(game)
	await frames(2)

	await load_stage("13_first_steps")
	check(game.world.shadow_root.mesh == null, "First steps: nothing floats, so no drop shadow")
	await load_stage("11_aperture")
	check(game.world.shadow_root.mesh != null, "Only the ground: the floating tower casts a drop shadow onto the ledge")
	# A piece cut on a slant casts a shadow of its own shape, and a top that
	# slopes takes it on the slope, not flat in the air over it.
	var cube := AABB(Vector3(0, -1, 0), Vector3.ONE)
	var wedge := {"bounds": AABB(Vector3(0, 1, 0), Vector3.ONE),
		"faces": Polygons.clip(Polygons.box_faces(AABB(Vector3(0, 1, 0), Vector3.ONE)), Plane(Vector3(1, 0, 1).normalized(), sqrt(0.5)))}
	var on_flat: Array[Dictionary] = [{"bounds": cube}, wedge]
	game.world._draw_drop_shadows(on_flat)
	check(absf(shadow_area() - 0.5) < 0.01, "A piece cut on a slant casts a shadow of its own shape")
	var slope := Plane(Vector3(1, 1, 0).normalized(), 0.0)
	var on_slope: Array[Dictionary] = [{"bounds": cube, "faces": Polygons.clip(Polygons.box_faces(cube), slope)}, wedge]
	game.world._draw_drop_shadows(on_slope)
	var on_it := shadow_area() > 0.1
	if on_it:
		for point: Vector3 in (game.world.shadow_root.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			on_it = on_it and absf(slope.distance_to(point) - game.world.SHADOW_LIFT) < 0.001
	check(on_it, "A top that slopes takes the shadow on the slope")

	await load_stage("01_route")
	var goal := Geometry.vector(game.level["goal"])
	game._hover_at(screen(Vector3(1, 0, 0)))
	check(game.world.hover_root.get_child_count() > 0, "Route: hovering a reachable block shows the way")
	game._hover_at(screen(goal))
	check(game.world.hover_root.get_child_count() == 0, "Route: hovering the cut-off goal shows no way")
	game._walk_at(screen(goal))
	check(game.world.mark_root.get_child_count() == 1, "Route: a tap on the cut-off goal marks it as unreachable")
	check(game.walker.route.is_empty(), "Route: the traveller does not set off for the unreachable goal")
	await frames(90)
	await create_timer(1.0).timeout
	check(game.world.mark_root.get_child_count() == 0, "Route: the unreachable mark fades away")
	game._walk_at(screen(Vector3(1, 0, 0)))
	check(not game.walker.route.is_empty() and game.world.hover_root.get_child_count() == 0, "Route: a walk starts and clears the hover path")

	game.queue_free()
	await frames(2)
	print("Readability tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

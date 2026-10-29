extends SceneTree
## Cues that make positions readable (playtest fix 5): a drop shadow straight
## below floating blocks, a mark where a tap asks for an unreachable place,
## and the walking path on desktop hover.

const Game := preload("res://game.gd")
const Geometry := preload("res://core/world_geometry.gd")

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

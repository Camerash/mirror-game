extends SceneTree
## The edge of the mirror always glows: low at rest, medium while held. The
## glowing edge puts light on the water below it.

const Game := preload("res://game.gd")

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


func settled() -> void:
	for index: int in 600:
		if game.phase != "preview" and game.pending.is_empty() and game.settle_frames == 0 and not game.camera.busy and not game._manipulating() and game.sheet.body.scale == Vector3.ONE:
			break
		await process_frame
	await frames(3)


func hover(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event)
	await frames(3)


func glow() -> float:
	return game.sheet.frame.metal.emission_energy_multiplier


func strength() -> float:
	return game.sheet.light_material.get_shader_parameter("strength")


func glass_point() -> Vector2:
	var rect: Rect2 = game.hud.get_play_rect()
	var centre: Vector2 = game.camera.unproject_position(game.mirror["pivot"])
	var best := Vector2(-1, -1)
	for y: int in range(int(rect.position.y + 10), int(rect.end.y - 10), 6):
		for x: int in range(int(rect.position.x + 10), int(rect.end.x - 10), 6):
			var point := Vector2(x, y)
			if game.sheet_hit(point) and (best.x < 0 or point.distance_to(centre) < best.distance_to(centre)):
				best = point
	return best


func check_rest() -> void:
	var sheet: MirrorSheet = game.sheet
	var floor_height: float = game.trial_lighting.floor_height
	check(is_equal_approx(glow(), 0.9), "The frame glows low at rest")
	check(sheet.light.visible, "The light shows while the mirror is raised")
	check(is_equal_approx(strength(), 0.22), "The light is at rest strength")
	check(is_equal_approx(sheet.light.global_position.y, floor_height + 0.03), "The light lies just above the water")
	check(is_equal_approx(sheet.water_level, floor_height), "The sheet knows the water level")
	var corners: PackedVector3Array = sheet.light_material.get_shader_parameter("corners")
	var expected := sheet.get_corners()
	check(corners.size() == 4 and expected.size() == 4, "The light has four corners")
	for index: int in mini(corners.size(), expected.size()):
		check(corners[index].distance_to(expected[index]) < 0.001, "Corner %d is the corner of the pane" % index)


func check_held() -> void:
	game.begin_grip("lift", glass_point())
	await frames(3)
	check(is_equal_approx(glow(), 1.6), "The frame glows more while held")
	check(is_equal_approx(strength(), 0.34), "The light is stronger while held")
	check(game.sheet.light.visible, "The light shows while the mirror is held")
	check(game.sheet.frame.material_override == game.sheet.frame.metal, "A held frame is the metal that glows")
	game.end_grip("lift")
	await settled()
	check(is_equal_approx(glow(), 0.9), "The frame returns to the low glow")
	check(is_equal_approx(strength(), 0.22), "The light returns to rest strength")


func check_pointer() -> void:
	await hover(glass_point())
	check(is_equal_approx(glow(), 1.6), "The pointer on the glass holds the glow")
	await hover(Vector2(2, game.get_viewport().get_visible_rect().size.y * 0.5))
	check(is_equal_approx(glow(), 0.9), "The pointer on empty water gives the low glow")


func run() -> void:
	root.size = Vector2i(1152, 800)
	game = Game.new()
	game.direct_controls = true
	game.auto_advance = false
	root.add_child(game)
	await frames(3)
	game.load_level(Game.LEVEL_PATHS.find("res://levels/14_turn.json"))
	await frames(200)
	game.toggle_mirror()
	await settled()
	check_rest()
	# The sheet has no stored state after a transition stops. The light stays.
	game.sheet.cancel_transition()
	await frames(2)
	check(game.sheet.light.visible, "The light stays when a transition stops")
	await check_held()
	await check_pointer()
	game.toggle_mirror()
	await settled()
	check(not game.sheet.light.visible, "The light is hidden while the mirror is lowered")
	print("Mirror light tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

extends RefCounted

static func run(game: Node3D, check: Callable, tree: SceneTree) -> void:
	await _movement(game, check, tree)
	await _outcomes(game, check, tree)
	await _orientation(game, check, tree)

static func _frames(tree: SceneTree, count := 5) -> void:
	for tick: int in range(count):
		await tree.physics_frame

static func _ready_preview(game: Node3D, tree: SceneTree) -> void:
	for tick: int in range(120):
		if game.prediction["status"] != "pending":
			return
		await tree.physics_frame

static func _load(game: Node3D, tree: SceneTree, file: String) -> void:
	game.load_level(game.LEVEL_PATHS.find("res://levels/" + file + ".json"))
	await _frames(tree)

static func _movement(game: Node3D, check: Callable, tree: SceneTree) -> void:
	await _load(game, tree, "01_route")
	game.request_walk(Vector3(2, 0, 0))
	await _frames(tree, 8)
	var feet: Vector3 = game.walker.position
	var velocity: Vector3 = game.walker.velocity
	var route: PackedVector3Array = game.walker.route.duplicate()
	var history_size: int = game.history.size()
	game.begin_preview()
	check.call(game.preview["enabled"], "Enable enters an active preview directly")
	check.call(game.get_world_3d().space != game.predictor.world_3d.space, "Prediction uses a separate collision space")
	check.call(not game.apply_preview(), "Confirm rejects a pending prediction")
	await _frames(tree, 10)
	check.call(game.walker.position == feet and game.walker.velocity == velocity, "Editing freezes real position and velocity")
	check.call(Engine.time_scale == 1.0 and game.preview_view.elapsed > 0, "Presentation keeps running while gameplay is frozen")
	game.cancel_preview()
	check.call(game.walker.route == route and game.walker.velocity == velocity, "Cancel restores saved movement")
	check.call(game.history.size() == history_size, "Cancel does not add history")
	check.call(game.predictor.scene.get_child_count() == 0, "Cancel releases prediction collision bodies")
	await _frames(tree, 8)
	check.call(game.walker.position.x > feet.x, "Walking resumes after Cancel")
	game.standing_only = true
	game.begin_preview()
	check.call(game.phase == "play" and not game.can_edit(), "Standing-only mode prevents editing during walking")
	game.standing_only = false
	game.begin_preview()
	await _ready_preview(game, tree)
	check.call(game.apply_preview(), "Mid-walk edit can be confirmed")
	await _frames(tree)
	check.call(game.walker.route.is_empty() and absf(game.walker.velocity.x) < 0.001, "Confirm stops the old walking route")
	check.call(game.history.size() == history_size + 1, "Confirmation adds exactly one history entry")

static func _outcomes(game: Node3D, check: Callable, tree: SceneTree) -> void:
	var cases: Array[Dictionary] = [
		{"level": "01_route", "feet": Vector3.ZERO, "enabled": true, "status": "supported"},
		{"level": "01_route", "feet": Vector3(5, 0, 0), "enabled": true, "status": "supported"},
		{"level": "08_reveal", "feet": Vector3(5, 0, 0), "enabled": false, "status": "supported"},
		{"level": "07_horizontal", "feet": Vector3(0, 4, 0), "enabled": false, "status": "landing"},
		{"level": "07_horizontal", "feet": Vector3(1.65, 4, 0), "enabled": false, "status": ""},
		{"level": "01_route", "feet": Vector3(3.5, 0, 0), "enabled": false, "status": "failure"},
		{"level": "06_wall", "feet": Vector3(3, 0, 0), "enabled": false, "status": "blocked"},
	]
	for item: Dictionary in cases:
		await _load(game, tree, item["level"])
		game.walker.restore(item["feet"], Vector3.ZERO)
		game.begin_preview()
		game.change_preview("enabled", item["enabled"])
		await _ready_preview(game, tree)
		var predicted: Dictionary = game.prediction.duplicate(true)
		check.call(predicted["status"] == item["status"] or item["status"] == "", "Prediction classifies " + item["level"] + " at " + str(item["feet"]))
		if item["status"] == "blocked":
			check.call(not game.apply_preview(), "Blocked prediction cannot be confirmed")
			game.cancel_preview()
			continue
		check.call(game.apply_preview(), "Completed prediction can be confirmed")
		await _frames(tree, 180)
		check.call((game.phase == "failure") == (predicted["status"] == "failure"), "Predicted failure agrees with actual fall")
		check.call(game.walker.position.distance_to(predicted["position"]) < 0.05, "Predicted endpoint matches actual capsule motion")
	await _load(game, tree, "07_horizontal")
	game.walker.restore(Vector3(0, 2, 0), Vector3(0, -3, 0))
	game.standing_only = true
	game.begin_preview()
	check.call(game.phase == "play", "Standing-only mode also prevents editing during a fall")
	game.standing_only = false
	game.begin_preview()
	game.change_preview("enabled", true)
	game.change_preview("enabled", false)
	await _ready_preview(game, tree)
	check.call(game.prediction["revision"] == game.prediction_revision and game.prediction["status"] == "landing", "Only the newest preview result is shown")
	check.call(game.walker.velocity.y == -3 and game.walker.position.y == 2, "Mid-fall editing holds saved vertical velocity")
	var endpoint: Vector3 = game.prediction["position"]
	game.apply_preview()
	await _frames(tree, 100)
	check.call(game.walker.position.distance_to(endpoint) < 0.02, "Mid-fall prediction agrees with confirmation")
	check.call(game.undo(), "Mid-fall change supports Undo")
	await _frames(tree, 3)
	check.call(game.walker.position.y > 1.8 and game.walker.velocity.y < -2.9, "Undo restores the airborne state without an old route")

static func _orientation(game: Node3D, check: Callable, tree: SceneTree) -> void:
	await _load(game, tree, "02_partial_cut")
	game.begin_preview()
	game.change_preview("offset", 1.5)
	var revision: int = game.prediction_revision
	game.change_preview("offset", 1.52)
	check.call(game.prediction_revision == revision, "Motion within one snap step does not rebuild the preview")
	game.change_preview("axis", 1)
	game.change_preview("offset", 1.0)
	game.change_preview("axis", 2)
	game.change_preview("axis", 0)
	check.call(game.preview["offset"] == 1.5, "Returning to a plane restores its proposed offset")
	game.change_preview("axis", 1)
	check.call(game.preview["offset"] == 1.0, "Horizontal offset is remembered during the edit")
	game.cancel_preview()

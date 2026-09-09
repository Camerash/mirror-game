extends SceneTree
const Game := preload("res://game.gd")
const Style := preload("res://core/constellation_style.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func settle(game: Node3D) -> void:
	for tick: int in 300:
		await physics_frame
		if tick > 5 and not game._manipulating() and not game.camera.busy and game.prediction["status"] != "pending": return
	check(false,"Interaction settles")

func _run() -> void:
	check(Style.normalized({"brightness":NAN,"glow":INF,"size":"bad"}) == Style.DEFAULTS,"Invalid settings use defaults")
	root.size = Vector2i(1152,800)
	var game := Game.new()
	root.add_child(game)
	await settle(game)
	game.hud._gear.pressed.emit()
	game._action("guide_preview",true)
	check(not game.guide_preview_enabled,"Preview requires an enabled editing mirror")
	game.begin_preview()
	await settle(game)
	game._action("guide_preview",true)
	check(game.guide_preview_enabled and game.guide_kind.is_empty() and not game.placement_guide._data.is_empty(),"Debug preview works without a gesture")
	var proposal: Dictionary = game.preview.duplicate(true)
	var prediction: Dictionary = game.prediction.duplicate(true)
	var collision: Array = game.solids.duplicate(true)
	var camera_pose: Transform3D = game.camera.transform
	var size: float = game.camera.size
	game.hud._guide_sliders["brightness"].value = 0.55
	game.hud._guide_sliders["glow"].value = 0.65
	check(is_equal_approx(game.guide_style["brightness"],0.55) and is_equal_approx(game.placement_guide._style["glow"],0.65),"Sliders update controller and renderer immediately")
	check(game.preview == proposal and game.prediction == prediction and game.solids == collision and game.history.is_empty(),"Tuning leaves geometry, prediction, and history unchanged")
	check(game.camera.transform == camera_pose and game.camera.size == size and not game.camera.busy,"Tuning does not refit the camera")
	game._start_height_drag(game.camera.unproject_position(game.preview["pivot"]))
	check(game.guide_kind == "height","A captured gesture overrides debug preview")
	game._finish_drag()
	await settle(game)
	await process_frame
	check(game.guide_last["move"] == "height" and game.guide_preview_enabled,"Preview remembers the last Move control")
	for dot: Dictionary in game.placement_guide._data["dots"]:
		check(dot["position"].x == game.preview["pivot"].x and dot["position"].z == game.preview["pivot"].z,"Idle height preview uses a column")
	game.hud._gear.pressed.emit()
	check(not game.guide_preview_enabled and game.placement_guide._data.is_empty(),"Closing gear clears idle preview")
	game.hud._gear.pressed.emit()
	game._action("guide_preview",true)
	game.remove_mirror()
	check(not game.guide_preview_enabled and game.placement_guide._data.is_empty(),"Removal clears preview")
	game.cancel_preview()
	check(not game.guide_preview_enabled,"Cancel leaves debug preview off")
	await settle(game)
	game.load_level(1)
	await settle(game)
	check(is_equal_approx(game.guide_style["brightness"],0.55),"Level changes retain tuning")
	game.begin_preview()
	await settle(game)
	game._action("guide_preview",true)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.guide_preview_enabled and game.placement_guide._data.is_empty(),"Focus loss clears preview")
	game._action("guide_defaults",null)
	for key: String in Style.DEFAULTS:
		check(is_equal_approx(game.guide_style[key],Style.DEFAULTS[key]) and is_equal_approx(game.placement_guide._style[key],Style.DEFAULTS[key]),"Reset defaults updates " + key)
	var fresh := Game.new()
	root.add_child(fresh)
	check(fresh.guide_style == Style.DEFAULTS,"A fresh run uses defaults")
	fresh.queue_free()
	game.queue_free()
	await process_frame
	print("Constellation tuning: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

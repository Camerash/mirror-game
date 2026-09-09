extends SceneTree

const Game := preload("res://game.gd")
const Rules := preload("res://core/mirror_state.gd")
var game: Node3D
var failures := 0
var checks := 0
var capture := false

func _initialize() -> void:
	capture = OS.get_cmdline_user_args().has("--visual-review")
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1152,800)
	game = Game.new()
	root.add_child(game)
	await settle()
	game.begin_preview()
	await settle()
	game.set_edit_mode("move")
	await settle()
	var initial: Dictionary = game.preview.duplicate(true)
	var solids: Array = game.solids.duplicate(true)
	var haze: Node = game.atmosphere.haze_root.get_child(0)
	var absolute: Node = game.world.visual_slots["rest:absolute:0"]["instance"]
	var point: Vector2 = game.camera.unproject_position(initial["pivot"])
	var moved: Vector3 = initial["pivot"] + Vector3(0.37,0,0.67)
	game._start_drag(point)
	var camera_pose: Transform3D = game.camera.transform
	game._drag(game.camera.unproject_position(moved))
	check(game.display_target["pivot"] == initial["pivot"] + Vector3(0.5,0,0.5), "Ground drag selects half-unit X and Z targets")
	await create_timer(0.12).timeout
	check(game.display_preview["pivot"] == initial["pivot"] + Vector3(0.5,0,0.5), "Ground drag display reaches its selected target")
	check(game.camera.transform == camera_pose and game.solids == solids, "Ground drag preserves camera and committed collision")
	game._finish_drag()
	await settle()
	check(game.preview["pivot"] == initial["pivot"] + Vector3(0.5,0,0.5), "Ground drag settles both axes to half units")
	game.cancel_preview()
	game.begin_preview()
	await settle()
	game.set_edit_mode("move")
	await settle()
	var tabs: Dictionary = game.resize_controls.get_control_rects()
	check(tabs.has("height_move"), "Height control is accessible")
	if tabs.has("height_move"):
		var start: Vector2 = tabs["height_move"].get_center()
		game._pointer(start, true, 0)
		game.resize_controls.motion(start + game.drag_axis * 0.7, 0)
		check(game.height_drag and is_equal_approx(game.display_target["pivot"].y, initial["pivot"].y + 0.5), "Height control selects a half-unit Y target")
		await create_timer(0.12).timeout
		check(is_equal_approx(game.display_preview["pivot"].y, initial["pivot"].y + 0.5), "Height display reaches its selected target")
		game._pointer(Vector2(-20,-20), false, 0)
		await settle()
		check(game.preview["pivot"] == initial["pivot"] + Vector3.UP * 0.5, "Height release settles without confirming")
	game.cancel_preview()
	game.begin_preview()
	await settle()
	game.set_edit_mode("rotate")
	await settle()
	game._action("angle_snap", 0.0)
	await shot("continuous-start")
	game._start_rotation({"kind":"turn", "axis":Vector3.UP})
	for angle: float in [0.15,0.5,0.9]:
		game._set_rotation_angle(angle)
		await create_timer(0.12).timeout
		check(game.sheet.global_basis.is_equal_approx(Basis(Vector3.UP,angle) * Rules.frame(initial)), "Panel tracks pointer before a quarter turn")
		check(game.preview == initial and game.rotation_display and not game.apply_preview(), "Continuous pose stays outside committed state")
		check(game.world.drawn_solids.any(func(solid: Dictionary) -> bool: return solid.has("faces")), "Reflections use continuous polygon geometry")
		check(game.atmosphere.haze_root.get_child(0) == haze and game.world.visual_slots["rest:absolute:0"]["instance"] == absolute, "Mist and absolute nodes remain stable")
		await shot("continuous-angle-%d" % int(angle * 100))
	game._finish_rotation_drag()
	check(not game.apply_preview(), "Rotation release settles before confirmation")
	await settle()
	check(is_equal_approx(game.preview["yaw"], initial["yaw"] + 0.9), "No-snap rotation retains the legal continuous target")
	game.cancel_preview()
	game.begin_preview()
	await settle()
	game.set_edit_mode("rotate")
	await settle()
	game._action("angle_snap", 90.0)
	initial = game.preview.duplicate(true)
	game._start_rotation({"kind":"turn", "axis":Vector3.UP})
	game._set_rotation_angle(1.0)
	game._finish_rotation_drag()
	await settle()
	check(Rules.frame(game.preview).is_equal_approx(Rules.frame(Rules.turn(initial,1))), "Rotation selects the nearest 90-degree target")
	game._action("rotation_begin", {"kind":"turn", "axis":Vector3.UP})
	game._action("rotation_angle", -TAU - 0.2)
	game._action("rotation_end", null)
	await settle()
	check(Rules.frame(game.preview).is_equal_approx(Rules.frame(Rules.turn(initial,1))), "Reverse full revolution settles without drift")
	game.set_edit_mode("move")
	await settle()
	game.tilt_mirror(1)
	await settle()
	check(game.preview["axis"] == 1, "Animated pitch reaches horizontal placement")
	game.rotate_mirror(1)
	await settle()
	check(game.preview["axis"] == 1 and game.prediction["status"] != "pending", "Yaw on a horizontal panel leaves a ready preview")
	await shot("continuous-horizontal")
	game.cancel_preview()
	check(game.mirror == {"enabled":false}, "Cancel discards all continuous changes")
	if capture:
		root.size = Vector2i(390,844)
		await settle()
		game.begin_preview()
		await settle()
		await shot("continuous-portrait")
	print("Continuous controls: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func settle() -> void:
	for frame: int in 240:
		await physics_frame
		if frame > 4 and not game._manipulating() and not game.camera.busy and game.prediction["status"] != "pending":
			return
	check(false, "Preview settles")

func shot(label: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/%s.png" % label)

extends SceneTree

const Game := preload("res://game.gd")
const Display := preload("res://core/display_geometry.gd")
const Queries := preload("res://core/solid_queries.gd")
const Frame := preload("res://world/mirror_frame.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	check(game.world.art_trial and not game.atmosphere.visible, "Level 1 isolates ceramic art from fog")
	var jade: ShaderMaterial = game.world.visual_slots["rest:absolute:0"]["material"]
	check(jade.get_shader_parameter("jade_surface") == true, "Absolute binds jade maps")
	check(jade.get_shader_parameter("albedo_map").get_width() == 2048, "Jade uses the 2K source texture")
	var collider: CapsuleShape3D = game.walker.get_child(0).shape
	check(is_equal_approx(collider.radius, Queries.RADIUS) and is_equal_approx(collider.height, Queries.HEIGHT), "Art does not change character collision")
	var character = game.walker.character_visual
	var hood: Node3D = character.find_child("Hood", true, false)
	var hood_rest := hood.transform
	for tick: int in 12:
		character.update_motion(0.016, Vector3(2,0,0), true, false)
	check(character.primary_mesh.get_blend_shape_count() == 2 and character.hem_offset.length() <= character.HEM_SWAY_LIMIT, "Hem deforms within its limit")
	check(hood.transform.is_equal_approx(hood_rest), "Hem movement leaves the hood attached")
	var paused_offset: Vector2 = character.hem_offset
	character.update_motion(1.0, Vector3.ZERO, true, true)
	check(character.hem_offset == paused_offset, "Editing freezes cloth motion")
	character.reset_motion()
	check(character.hem_offset == Vector2.ZERO and character.left_foot.transform.is_equal_approx(character.left_foot_rest), "Restoration resets cloth and feet")
	var bounds := AABB(Vector3(-0.5,-0.5,-0.5), Vector3.ONE)
	var faces := Display.clip(Display.box_faces(bounds), Plane(Vector3(1,1,0).normalized(), 0.1))
	var solid := {"source_bounds": bounds, "material_to_world":Transform3D.IDENTITY}
	check(faces.any(func(face: PackedVector3Array) -> bool: return game.world._is_cut_face(face, solid)), "Angled cap is identified for opaque cross-section shading")
	check(not Display.box_faces(bounds).any(func(face: PackedVector3Array) -> bool: return game.world._is_cut_face(face, solid)), "Manufactured outer faces retain glaze decoration")
	var frame := Frame.new()
	root.add_child(frame)
	frame.update_frame(Vector2.ONE, false, true)
	var depth := frame.mesh.get_aabb().size.z
	frame.update_frame(Vector2(6, 4), false, true)
	check(is_equal_approx(frame.mesh.get_aabb().size.z, depth), "Mirror frame thickness stays fixed during resize")
	check(frame.get_child_count() == 0, "Frame adds no collision nodes")
	game.preview_view.set_art_trial(true)
	game.preview_view.show_result({"status":"failure", "path":PackedVector3Array([Vector3.ZERO, Vector3.DOWN]), "seconds":1.0}, game.world)
	check(game.preview_view._mesh_children(game.preview_view.ghost).size() > 1, "Fall ghost uses the character silhouette")
	game.load_level(1)
	check(not game.world.art_trial and game.atmosphere.visible and not game.sheet.art_trial, "Other puzzles retain their existing presentation")
	frame.queue_free()
	game.queue_free()
	await process_frame
	print("Ceramic trial: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

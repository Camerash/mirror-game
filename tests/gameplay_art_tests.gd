extends SceneTree

const Game := preload("res://game.gd")
const Display := preload("res://core/display_geometry.gd")
const Queries := preload("res://core/solid_queries.gd")
const Frame := preload("res://world/mirror_frame.gd")
const CeramicShader := preload("res://world/ceramic.gdshader")
const PorcelainShader := preload("res://world/porcelain.gdshader")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _find_solid(solids: Array[Dictionary], kind: String, id: String) -> Dictionary:
	for solid: Dictionary in solids:
		if solid.get("kind") == kind and solid.get("id") == id:
			return solid
	return {}

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	var jade: ShaderMaterial = game.world.visual_slots["rest:absolute:0"]["material"]
	check(jade.get_shader_parameter("jade_surface") == true, "Absolute binds jade maps")
	check(jade.get_shader_parameter("albedo_map").get_width() == 2048, "Jade uses the 2K source texture")
	var collider: CapsuleShape3D = game.walker.get_child(0).shape
	check(is_equal_approx(collider.radius, Queries.RADIUS) and is_equal_approx(collider.height, Queries.HEIGHT), "Art does not change character collision")
	var character = game.walker.character_visual
	# The character is the skinned traveller now. The feet are keyed in its own
	# walk cycle and the cloak carries the three deformations, so the checks
	# below ask the same questions of the asset instead of of this script.
	var head: Node3D = character.find_child("Head", true, false)
	check(head != null, "The traveller carries its own head")
	var head_rest := head.transform if head != null else Transform3D.IDENTITY
	var box := AABB()
	var measured := false
	for node: Node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var local: AABB = character.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		box = local if not measured else box.merge(local)
		measured = true
	check(measured and absf(box.size.y - Queries.HEIGHT) < 0.02, "The traveller is scaled to the walker's capsule")
	check(character.player != null and character.player.has_animation(character.WALK), "The traveller carries its own walk cycle")
	for tick: int in 12:
		character.update_motion(0.016, Vector3(2,0,0), true, false)
	var drift: Vector3 = character.drift
	check(drift.length() > 0.0 and absf(drift.x) <= 1.0 and absf(drift.y) <= 1.0
		and absf(drift.z) <= 1.0, "Cloak deforms within its limit")
	check(character.primary_mesh.find_blend_shape_by_name("HoodLowered") >= 0,
		"Hood and cloak are one skinned mesh, so the hood cannot detach")
	check(head == null or head.transform.is_equal_approx(head_rest), "Cloak movement leaves the head attached")
	var paused_drift: Vector3 = character.drift
	character.update_motion(1.0, Vector3.ZERO, true, true)
	check(character.drift == paused_drift, "Editing freezes cloth motion")
	character.reset_motion()
	check(character.drift == Vector3.ZERO, "Restoration resets the cloak")
	check(character.player != null and not character.player.is_playing(), "Restoration leaves the walk standing")
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
	game.preview_view.show_result({"status":"failure", "path":PackedVector3Array([Vector3.ZERO, Vector3.DOWN]), "seconds":1.0}, game.world)
	check(game.preview_view._mesh_children(game.preview_view.ghost).size() > 1, "Fall ghost uses the character silhouette")
	for index: int in Game.LEVEL_PATHS.size():
		var path: String = Game.LEVEL_PATHS[index]
		check(game.load_level(index), "Level loads: %s" % path)
		var block_look := true
		for slot: Dictionary in game.world.visual_slots.values():
			var material: ShaderMaterial = slot["material"]
			if material.shader != CeramicShader and material.shader != PorcelainShader:
				block_look = false
		check(block_look, "Every visual slot uses the ceramic or porcelain block set: %s" % path)
		check(game.walker.character_visual != null, "The golden traveller shows on every stage: %s" % path)
	game.load_level(Game.LEVEL_PATHS.find("res://levels/12_block_gallery.json"))
	var whole_original := _find_solid(game.solids, "original", "whole")
	check(whole_original.has("bounds") and (whole_original["bounds"] as AABB).size.is_equal_approx((whole_original["source_bounds"] as AABB).size),
		"Block gallery: an original block keeps its full source size")
	var cut_original := _find_solid(game.solids, "original", "straddle")
	check(cut_original.has("bounds") and not (cut_original["bounds"] as AABB).size.is_equal_approx((cut_original["source_bounds"] as AABB).size),
		"Block gallery: the mirror plane cuts an original down from its source size")
	var whole_reflected := _find_solid(game.solids, "reflected", "copy")
	check(whole_reflected.has("bounds") and (whole_reflected["bounds"] as AABB).size.is_equal_approx((whole_reflected["source_bounds"] as AABB).size),
		"Block gallery: a reflected block appears whole, at its full source size")
	var cut_reflected := _find_solid(game.solids, "reflected", "edge")
	check(cut_reflected.has("bounds") and not (cut_reflected["bounds"] as AABB).size.is_equal_approx((cut_reflected["source_bounds"] as AABB).size),
		"Block gallery: a reflected block is cut smaller than its source size at the aperture edge")
	var absolute_solid := _find_solid(game.solids, "absolute", "goal")
	check(absolute_solid.has("bounds"), "Block gallery: the jade goal platform is present")
	frame.queue_free()
	game.queue_free()
	await process_frame
	print("Gameplay art: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

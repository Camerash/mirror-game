extends SceneTree
## Focused checks for the two authored static hood endpoints.

const Study := preload("res://art_trial/drawing_traveller_study.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var study := Study.instantiate()
	root.add_child(study)
	check(study.face_material != null, "The drawing face has a local material")
	check(study.hood != null and study.hood_shape >= 0, "Both authored hood endpoints are available")
	if study.face_material != null and study.hood != null and study.hood_shape >= 0:
		check_asset(study)
		check_poses(study)
		check_expressions(study)
		check_controls(study)
		check_isolation(study)
		check_reset(study)
	study.free()
	print("Drawing static poses: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_asset(study: Node) -> void:
	var triangles := 0
	var materials := {}
	var textures := {}
	var mesh_names := []
	for mesh: MeshInstance3D in study.meshes:
		mesh_names.append(String(mesh.name))
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			check(material != null, "Every drawing surface has a native material")
			if material == null:
				continue
			materials[material.get_instance_id()] = true
			check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Drawing materials are opaque")
			check(material.resource_name in ["TravellerDrawingFace", "TravellerDrawingBody"], "Drawing uses the agreed materials")
			check(material.albedo_texture != null, "Every drawing surface uses the atlas")
			if material.albedo_texture != null:
				textures[material.albedo_texture.get_rid()] = true
				check(material.albedo_texture.get_size() == Vector2(1024, 1024), "Drawing atlas is 1024 square")
			if material.resource_name == "TravellerDrawingFace":
				var valid_uvs := true
				for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
					valid_uvs = valid_uvs and uv.x >= -0.0001 and uv.x <= 0.2501
				check(valid_uvs, "Drawing face UVs stay in the first expression tile")
	for mesh_name: String in ["Head", "Hair", "Body", "Boots", "Garment"]:
		check(mesh_names.count(mesh_name) == 1, "Drawing has one " + mesh_name)
	check(mesh_names.size() == 5, "Drawing uses the five agreed meshes")
	check(triangles > 0 and triangles <= 8000, "Drawing stays within 8000 triangles")
	check(materials.size() == 2, "Drawing has two source materials")
	check(textures.size() == 1, "Drawing materials share one atlas")
	check(study.model.find_children("*", "AnimationPlayer").is_empty(), "Drawing study has no animation clips")
	check(not study.is_processing(), "Drawing study has no automatic motion")
	print("Drawing asset: %d triangles, %d materials, %d textures" % [triangles, materials.size(), textures.size()])


func check_poses(study: Node) -> void:
	var camera_transform: Transform3D = study.camera.transform
	var camera_size: float = study.camera.size
	var bounds: AABB = study.bounds
	check(study.model.find_children("*", "Skeleton3D").is_empty(), "The static export does not double-deform the baked hood")
	for mesh: MeshInstance3D in study.meshes:
		var expected_shapes := 1 if mesh == study.hood else 0
		check(mesh.mesh.get_blend_shape_count() == expected_shapes, "%s has only the agreed endpoint shape" % mesh.name)
		for surface: int in mesh.mesh.get_surface_count():
			var base: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var contains_vertices := true
			for point: Vector3 in base:
				contains_vertices = contains_vertices and bounds.grow(0.0001).has_point(mesh.global_transform * point)
			check(contains_vertices, "Camera bounds contain the raised pose")
			if mesh != study.hood:
				continue
			var shape: PackedVector3Array = mesh.mesh.surface_get_blend_shape_arrays(surface)[study.hood_shape][Mesh.ARRAY_VERTEX]
			check(base.size() == shape.size(), "Hood endpoints share vertex topology")
			var maximum_shift := 0.0
			for index: int in shape.size():
				var point := shape[index]
				if mesh.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE:
					point += base[index]
				maximum_shift = maxf(maximum_shift, point.distance_to(base[index]))
				contains_vertices = contains_vertices and bounds.grow(0.0001).has_point(mesh.global_transform * point)
			check(maximum_shift > 0.1, "The exported folded hood is a distinct pose")
			check(contains_vertices, "Camera bounds contain the folded pose")
	study.set_expression(3)
	for lowered: bool in [true, false, true]:
		study.set_hood_lowered(lowered)
		check(study.hood.get_blend_shape_value(study.hood_shape) == float(lowered), "Hood selection applies an exact endpoint")
		check(study.expression == 3, "Hood selection preserves the expression")
		check(study.bounds == bounds and study.camera.transform == camera_transform and study.camera.size == camera_size, "Hood selection preserves the common camera fit")


func check_expressions(study: Node) -> void:
	for index: int in 4:
		study.set_expression(index)
		check(study.face_material.uv1_offset == Vector3(index * 0.25, 0, 0), "Drawing expression selects its aligned tile")
	study.set_expression(-1)
	check(study.expression == 0, "Negative drawing expression clamps to neutral")
	study.set_expression(4)
	check(study.expression == 3, "Drawing expression above the last tile clamps to smile")
	study.set_grey(true)
	study.set_expression(2)
	study.set_grey(false)
	check(study.face_material.uv1_offset.x == 0.5, "Grey review preserves the drawing expression")


func check_controls(study: Node) -> void:
	check(not study.arm_controls_enabled and study.reach_button == null, "Drawing review omits the arm control")
	check(study.hood_controls_enabled and study.hood_button != null, "Both static hood poses can be selected")
	var notice := study.get_node("DraftNotice/Label") as Label
	check(notice.text == "Static hood poses — animation is not yet implemented." and notice.is_visible_in_tree(), "The study clearly identifies the static review")
	study.controls.hide()
	check(notice.is_visible_in_tree(), "The draft status stays visible when controls are hidden")
	study.controls.show()
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_A
	study._unhandled_input(key)
	check(not study.arms_reaching, "The arm shortcut is disabled for the drawing study")
	study.set_hood_lowered(false)
	key.keycode = KEY_U
	study._unhandled_input(key)
	check(study.hood_lowered, "The hood shortcut selects the folded endpoint")
	key.keycode = KEY_SPACE
	study._unhandled_input(key)
	check(not study.turntable, "Space cannot start a drawing turntable")
	study.set_small_view(false)
	var close_size: float = study.camera.size
	study.set_small_view(true)
	check(is_equal_approx(study.camera.size, close_size * 4.0), "Game size uses the same camera bounds")
	study.set_view(4)
	check(study.view_index == 4, "Drawing review has an elevated view")


func check_isolation(study: Node) -> void:
	var second := Study.instantiate()
	root.add_child(second)
	check(study.face_material != second.face_material, "Drawing expression material belongs to each study")
	study.set_expression(3)
	study.set_hood_lowered(true)
	check(second.hood.get_blend_shape_value(second.hood_shape) == 0.0, "Hood selection is local to each study")
	check(second.face_material.uv1_offset == Vector3.ZERO, "Drawing expression changes do not affect another study")
	for mesh: MeshInstance3D in study.meshes:
		for surface: int in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			check(source.uv1_offset == Vector3.ZERO, "Drawing source materials stay unchanged")
			if source.resource_name == "TravellerDrawingFace":
				check(mesh.get_surface_override_material(surface) == study.face_material and source != study.face_material, "The drawing face uses its local material")
	second.free()


func check_reset(study: Node) -> void:
	study.set_grey(true)
	study.ceramic_light = true
	study._set_lighting()
	study.controls.hide()
	study.reset_study()
	check(study.expression == 0 and study.face_material.uv1_offset == Vector3.ZERO, "Reset restores the neutral drawing expression")
	check(not study.hood_lowered and study.hood.get_blend_shape_value(study.hood_shape) == 0.0, "Reset restores the raised hood")
	check(not study.small_view and study.view_index == 3 and not study.grey and not study.ceramic_light and study.controls.visible, "Reset restores the drawing review settings")

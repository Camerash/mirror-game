extends SceneTree
## Focused static full-character checks; no gameplay regression suite.

const Study := preload("res://art_trial/full_traveller_study.tscn")
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
	check(study.face_material != null, "A local face material is available")
	check(study.hood != null and study.hood_shape >= 0, "Hood endpoints are available")
	check(study.arms != null and study.reach_shape >= 0, "Arm endpoints are available")
	if study.face_material != null and study.hood_shape >= 0 and study.reach_shape >= 0:
		check_asset(study)
		check_poses(study)
		check_expressions(study)
		check_isolation(study)
		check_reset(study)
	study.free()
	print("Full traveller: %d checks, %d failures" % [checks, failures])
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
			check(material != null, "Every surface has a native material")
			if material == null:
				continue
			materials[material.get_instance_id()] = true
			check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Character materials are opaque")
			check(material.resource_name in ["TravellerFullFace", "TravellerFullBody"], "Character uses the two agreed materials")
			check(material.albedo_texture != null, "Every surface uses the atlas")
			if material.albedo_texture != null:
				textures[material.albedo_texture.get_rid()] = true
				check(material.albedo_texture.get_size() == Vector2(1024, 1024), "Atlas is 1024 square")
			if material.resource_name == "TravellerFullFace":
				var valid_uvs := true
				for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
					valid_uvs = valid_uvs and uv.x >= -0.0001 and uv.x <= 0.2501
				check(valid_uvs, "Face UVs stay in the first expression tile")
	for mesh_name: String in ["Body", "Head", "Hair", "Garment", "Hood", "Arms", "Boots"]:
		check(mesh_name in mesh_names, "Character has " + mesh_name)
	check(triangles > 0 and triangles <= 8000, "Character stays within 8000 triangles")
	check(materials.size() == 2, "Character has two source materials")
	check(textures.size() == 1, "Both materials share one atlas")
	check(study.model.find_children("*", "AnimationPlayer").is_empty(), "Static study has no animation clips")
	check(not study.is_processing(), "Static study has no automatic motion")
	print("Full asset: %d triangles, %d materials, %d textures" % [triangles, materials.size(), textures.size()])


func check_poses(study: Node) -> void:
	var camera_transform: Transform3D = study.camera.transform
	var camera_size: float = study.camera.size
	var bounds: AABB = study.bounds
	var hair := study.model.find_child("Hair", true, false) as MeshInstance3D
	check(hair != null and hair.mesh.get_blend_shape_count() == 0, "Hair remains fixed")
	for lowered: bool in [false, true]:
		for reaching: bool in [false, true]:
			study.set_hood_lowered(lowered)
			study.set_arms_reaching(reaching)
			check(study.hood.get_blend_shape_value(study.hood_shape) == float(lowered), "Hood endpoint is independent of arms")
			check(study.arms.get_blend_shape_value(study.reach_shape) == float(reaching), "Arm endpoint is independent of hood")
			check(study.bounds == bounds and study.camera.transform == camera_transform and study.camera.size == camera_size, "Pose changes preserve the common camera fit")
	for mesh: MeshInstance3D in [study.hood, study.arms]:
		var shape_index: int = study.hood_shape if mesh == study.hood else study.reach_shape
		for surface: int in mesh.mesh.get_surface_count():
			var base: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var shape: PackedVector3Array = mesh.mesh.surface_get_blend_shape_arrays(surface)[shape_index][Mesh.ARRAY_VERTEX]
			check(base.size() == shape.size(), "Pose endpoints share topology")
			var contains_endpoints := true
			for index: int in shape.size():
				var point := shape[index]
				if mesh.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE:
					point += base[index]
				contains_endpoints = contains_endpoints and bounds.grow(0.0001).has_point(mesh.global_transform * point)
			check(contains_endpoints, "Camera bounds include every pose endpoint")


func check_expressions(study: Node) -> void:
	for index: int in 4:
		study.set_expression(index)
		check(study.face_material.uv1_offset == Vector3(index * 0.25, 0, 0), "Expression selects its aligned tile")
	study.set_expression(-1)
	check(study.expression == 0, "Negative expression clamps to neutral")
	study.set_expression(4)
	check(study.expression == 3, "Expression above the last tile clamps to smile")
	study.set_grey(true)
	study.set_expression(2)
	study.set_grey(false)
	check(study.face_material.uv1_offset.x == 0.5, "Grey review preserves the selected face")


func check_isolation(study: Node) -> void:
	var second := Study.instantiate()
	root.add_child(second)
	check(study.face_material != second.face_material, "Face material belongs to each study")
	study.set_expression(3)
	study.set_hood_lowered(true)
	study.set_arms_reaching(true)
	check(second.face_material.uv1_offset == Vector3.ZERO, "Face changes do not affect another study")
	check(second.hood.get_blend_shape_value(second.hood_shape) == 0.0, "Hood changes do not affect another study")
	check(second.arms.get_blend_shape_value(second.reach_shape) == 0.0, "Arm changes do not affect another study")
	for mesh: MeshInstance3D in study.meshes:
		for surface: int in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			check(source.uv1_offset == Vector3.ZERO, "Source material stays unchanged")
			if source.resource_name == "TravellerFullFace":
				check(mesh.get_surface_override_material(surface) == study.face_material and source != study.face_material, "Only the local face material gets an offset")
	second.free()


func check_reset(study: Node) -> void:
	study.set_small_view(true)
	study.set_view(4)
	study.set_grey(true)
	study.ceramic_light = true
	study._set_lighting()
	study.controls.hide()
	study.reset_study()
	check(study.expression == 0 and study.face_material.uv1_offset == Vector3.ZERO, "Reset restores the neutral face")
	check(not study.hood_lowered and study.hood.get_blend_shape_value(study.hood_shape) == 0.0, "Reset raises the hood")
	check(not study.arms_reaching and study.arms.get_blend_shape_value(study.reach_shape) == 0.0, "Reset restores arms at rest")
	check(not study.small_view and study.view_index == 3 and not study.grey and not study.ceramic_light and study.controls.visible, "Reset restores all review settings")
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	study._unhandled_input(space)
	check(not study.turntable, "Space cannot start a turntable")

extends SceneTree
## Focused checks for the isolated painted bust; no gameplay regression suite.

const Study := preload("res://art_trial/painted_traveller_study.tscn")
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
	study.set_process(false)
	check(study.face_material != null, "A local face material is available")
	check(study.hood != null and study.hood_shape >= 0, "The hood has both poses")
	if study.face_material != null and study.hood != null:
		for index: int in study.HAIRSTYLES.size():
			study.set_hairstyle(index)
			check_asset(study)
			check_poses(study)
		check_styles(study)
		check_expressions(study)
		check_isolation(study)
	study.free()
	print("Painted traveller: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_asset(study: Node) -> void:
	var triangles := 0
	var materials := {}
	var textures := {}
	for mesh: MeshInstance3D in study.meshes:
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			check(material != null, "Native opaque material")
			if material == null:
				continue
			materials[material.get_instance_id()] = true
			check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "No transparent character pass")
			check(material.albedo_texture != null, "Every character surface uses the atlas")
			if material.albedo_texture != null:
				textures[material.albedo_texture.get_rid()] = true
				check(material.albedo_texture.get_size() == Vector2(1024, 1024), "Atlas is 1024 square")
			if material.resource_name == "TravellerFace":
				for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
					if uv.x < -0.0001 or uv.x > 0.2501:
						check(false, "Head UVs must stay inside the first expression tile")
						break
	check(triangles > 0 and triangles <= 5000, "Study stays within 5000 triangles")
	check(materials.size() <= 2, "At most two source materials")
	check(textures.size() == 1, "Both materials share one atlas")
	print("%s: %d triangles, %d materials, %d textures" % [study.HAIRSTYLES[study.hairstyle], triangles, materials.size(), textures.size()])


func check_expressions(study: Node) -> void:
	for index: int in 4:
		study.set_expression(index)
		check(study.face_material.uv1_offset == Vector3(index * 0.25, 0, 0), "Expression selects its aligned tile")
	study.set_expression(3)
	study.blink_once()
	check(study.displayed_expression == 1, "Blink starts half closed")
	study.advance_blink(0.08)
	check(study.displayed_expression == 2, "Blink closes")
	study.advance_blink(0.10)
	check(study.displayed_expression == 1, "Blink reopens")
	study.advance_blink(0.10)
	check(study.displayed_expression == 3 and study.blink_time < 0, "Blink restores the chosen face")
	study.blink_once()
	study.reset_study()
	check(study.displayed_expression == 0 and study.blink_time < 0, "Reset clears a pending blink")


func check_poses(study: Node) -> void:
	var mesh: Mesh = study.hood.mesh
	study.set_hood_lowered(true)
	check(study.hood.get_blend_shape_value(study.hood_shape) == 1.0, "Lowered hood endpoint")
	for hair: MeshInstance3D in study.tucked_hair:
		check(hair.get_blend_shape_value(study.tucked_hair[hair]) == 0.0, "Lowered hood restores natural hair")
	study.set_hood_lowered(false)
	check(study.hood.get_blend_shape_value(study.hood_shape) == 0.0, "Raised hood endpoint")
	for hair: MeshInstance3D in study.tucked_hair:
		var index: int = study.tucked_hair[hair]
		check(hair.get_blend_shape_value(index) == 1.0, "Raised hood applies tucked hair")
		for surface: int in hair.mesh.get_surface_count():
			var base: Array = hair.mesh.surface_get_arrays(surface)
			var shape: Array = hair.mesh.surface_get_blend_shape_arrays(surface)[index]
			check(base[Mesh.ARRAY_VERTEX].size() == shape[Mesh.ARRAY_VERTEX].size(), "Hair poses share topology")
	check(study.hood.mesh == mesh, "Pose changes reuse the same mesh")
	for surface: int in mesh.get_surface_count():
		var original: Array = mesh.surface_get_arrays(surface)
		var shape: Array = mesh.surface_get_blend_shape_arrays(surface)[study.hood_shape]
		check(original[Mesh.ARRAY_VERTEX].size() == shape[Mesh.ARRAY_VERTEX].size(), "Hood poses share topology")


func check_styles(study: Node) -> void:
	check(study.hair_models.size() == 3, "All three hair styles are available")
	study.set_expression(3)
	study.set_hood_lowered(true)
	study.small_view = true
	study.set_view(4)
	study.set_grey(true)
	var camera_transform: Transform3D = study.camera.transform
	var camera_size: float = study.camera.size
	var light: Node = study.lighting
	for index: int in 3:
		study.set_hairstyle(index)
		check(study.hairstyle == index, "Hair selector uses requested style")
		var visible_models := 0
		for variant: Node3D in study.hair_models:
			visible_models += int(variant.visible)
		check(visible_models == 1, "Only one model is visible")
		check(study.expression == 3 and study.face_material.uv1_offset.x == 0.75, "Style preserves painted expression")
		check(study.hood_lowered and study.hood.get_blend_shape_value(study.hood_shape) == 1.0, "Style preserves hood pose")
		check(study.camera.transform == camera_transform and study.camera.size == camera_size, "Style preserves common camera fit")
		check(study.lighting == light and study.small_view and study.view_index == 4, "Style preserves review settings")
		check(study.meshes[0].material_override == study.grey_material, "Style preserves grey review")
	study.blink_once()
	study.advance_blink(0.08)
	study.set_hairstyle(0)
	check(study.displayed_expression == 2 and study.face_material.uv1_offset.x == 0.5, "Style preserves a running blink")
	study.advance_blink(0.20)
	check(study.displayed_expression == 3, "Blink completes after changing hair")
	study.set_hairstyle(-1)
	check(study.hairstyle == 0, "Invalid style leaves selection intact")
	study.reset_study()
	check(study.hairstyle == 0 and not study.hood_lowered and study.expression == 0, "Reset restores long hair and default pose")


func check_isolation(study: Node) -> void:
	var second := Study.instantiate()
	root.add_child(second)
	second.set_process(false)
	check(study.face_material != second.face_material, "Expression material is local to each study")
	study.set_expression(3)
	check(second.face_material.uv1_offset == Vector3.ZERO, "Expressions do not change another character")
	study.set_hood_lowered(true)
	check(second.hood.get_blend_shape_value(second.hood_shape) == 0.0, "Hood pose is local to each character")
	second.free()

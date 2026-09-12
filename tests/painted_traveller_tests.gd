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
		check_asset(study)
		check_expressions(study)
		check_poses(study)
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
	print("Asset: %d triangles, %d materials, %d textures" % [triangles, materials.size(), textures.size()])


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
	study.set_hood_lowered(false)
	check(study.hood.get_blend_shape_value(study.hood_shape) == 0.0, "Raised hood endpoint")
	check(study.hood.mesh == mesh, "Pose changes reuse the same mesh")
	for surface: int in mesh.get_surface_count():
		var original: Array = mesh.surface_get_arrays(surface)
		var shape: Array = mesh.surface_get_blend_shape_arrays(surface)[study.hood_shape]
		check(original[Mesh.ARRAY_VERTEX].size() == shape[Mesh.ARRAY_VERTEX].size(), "Hood poses share topology")


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

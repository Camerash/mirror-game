extends "res://art_trial/head_study.gd"
## Static full-character shape review. Does not replace a gameplay asset.

const EXPRESSIONS := ["Neutral", "Half closed", "Closed", "Smile"]

var face_material: StandardMaterial3D
var hood: MeshInstance3D
var arms: MeshInstance3D
var hood_shape := -1
var reach_shape := -1
var hood_lowered := false
var arms_reaching := false
var expression := 0
var face_button: Button
var hood_button: Button
var reach_button: Button
var size_button: Button


func _ready() -> void:
	super._ready()
	if model == null or meshes.is_empty():
		return
	for mesh: MeshInstance3D in meshes:
		bounds = bounds.merge(mesh.global_transform * _pose_bounds(mesh.mesh))
	centre = bounds.get_center()
	_bind_model()
	reset_study()
	# This review has no animation or automatic camera movement.
	set_process(false)


func _pose_bounds(mesh: Mesh) -> AABB:
	var result := mesh.get_aabb()
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		return result
	for surface: int in mesh.get_surface_count():
		var base: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for shape: Array in mesh.surface_get_blend_shape_arrays(surface):
			var vertices: PackedVector3Array = shape[Mesh.ARRAY_VERTEX]
			for index: int in vertices.size():
				var point := vertices[index]
				if array_mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE:
					point += base[index]
				result = result.expand(point)
	return result


func _bind_model() -> void:
	for mesh: MeshInstance3D in meshes:
		if mesh.name == "Hood":
			hood = mesh
			hood_shape = hood.find_blend_shape_by_name("HoodLowered")
		if mesh.name == "Arms":
			arms = mesh
			reach_shape = arms.find_blend_shape_by_name("ArmsReach")
		for surface: int in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source != null and source.resource_name == "TravellerFullFace":
				if face_material == null:
					face_material = source.duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(surface, face_material)
	if face_material == null or hood_shape < 0 or reach_shape < 0:
		push_error("Full traveller needs TravellerFullFace, HoodLowered, and ArmsReach.")


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 16
	controls.offset_right = -16
	controls.offset_bottom = -16
	for index: int in VIEW_NAMES.size():
		_button("Elevated" if index == 4 else VIEW_NAMES[index], set_view.bind(index))
	_button("Grey / colour", func(): set_grey(not grey))
	_button("Lighting", func(): ceramic_light = not ceramic_light; _set_lighting())
	_button("Size: Close", func(): set_small_view(not small_view))
	size_button = controls.get_child(controls.get_child_count() - 1) as Button
	_button("Hood: Raised", func(): set_hood_lowered(not hood_lowered))
	hood_button = controls.get_child(controls.get_child_count() - 1) as Button
	_button("Arms: Rest", func(): set_arms_reaching(not arms_reaching))
	reach_button = controls.get_child(controls.get_child_count() - 1) as Button
	_button("Face: Neutral", func(): set_expression((expression + 1) % EXPRESSIONS.size()))
	face_button = controls.get_child(controls.get_child_count() - 1) as Button
	_button("Reset study", reset_study)
	_button("Hide", func(): controls.hide(); fit_camera())


func set_expression(index: int) -> void:
	expression = clampi(index, 0, EXPRESSIONS.size() - 1)
	if face_material != null:
		face_material.uv1_offset = Vector3(expression * 0.25, 0.0, 0.0)
	if face_button != null:
		face_button.text = "Face: " + EXPRESSIONS[expression]


func set_hood_lowered(lowered: bool) -> void:
	hood_lowered = lowered
	if hood != null and hood_shape >= 0:
		hood.set_blend_shape_value(hood_shape, 1.0 if lowered else 0.0)
	if hood_button != null:
		hood_button.text = "Hood: Folded" if lowered else "Hood: Raised"


func set_arms_reaching(reaching: bool) -> void:
	arms_reaching = reaching
	if arms != null and reach_shape >= 0:
		arms.set_blend_shape_value(reach_shape, 1.0 if reaching else 0.0)
	if reach_button != null:
		reach_button.text = "Arms: Reach" if reaching else "Arms: Rest"


func set_small_view(enabled: bool) -> void:
	small_view = enabled
	if size_button != null:
		size_button.text = "Size: Game" if enabled else "Size: Close"
	fit_camera()


func reset_study() -> void:
	set_expression(0)
	set_hood_lowered(false)
	set_arms_reaching(false)
	set_grey(false)
	ceramic_light = false
	_set_lighting()
	controls.show()
	set_small_view(false)
	set_view(3)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: set_view(posmod(view_index - 1, VIEW_NAMES.size()))
			KEY_E: set_view((view_index + 1) % VIEW_NAMES.size())
			KEY_G: set_grey(not grey)
			KEY_L: ceramic_light = not ceramic_light; _set_lighting()
			KEY_V: set_small_view(not small_view)
			KEY_H: controls.visible = not controls.visible; fit_camera()
			KEY_F: set_expression((expression + 1) % EXPRESSIONS.size())
			KEY_U: set_hood_lowered(not hood_lowered)
			KEY_A: set_arms_reaching(not arms_reaching)
			KEY_R: reset_study()
	if event is InputEventScreenTouch and event.pressed and not controls.visible:
		controls.show()
		fit_camera()

extends "res://art_trial/head_study.gd"
## Isolated painted-face and two-pose hood review. No gameplay asset replacement.

const EXPRESSIONS := ["Neutral", "Half closed", "Closed", "Smile"]
const BLINK_DURATION := 0.24
const HAIRSTYLES := ["Long", "Bob", "Low bun"]
const HAIR_MODELS := [
	"res://assets/studies/traveller_painted.glb",
	"res://assets/studies/traveller_painted_bob.glb",
	"res://assets/studies/traveller_painted_bun.glb",
]

var face_material: StandardMaterial3D
var hood: MeshInstance3D
var hood_shape := -1
var hood_lowered := false
var expression := 0
var displayed_expression := 0
var blink_time := -1.0
var face_button: Button
var hood_button: Button
var hair_button: Button
var hairstyle := 0
var hair_models: Array[Node3D] = []
var tucked_hair: Dictionary[MeshInstance3D, int] = {}


func _ready() -> void:
	super._ready()
	_load_hairstyles()
	reset_study()
	fit_camera()


func _load_hairstyles() -> void:
	hair_models.append(model)
	for path: String in HAIR_MODELS.slice(1):
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Hair study model is missing: " + path)
			continue
		var variant := packed.instantiate() as Node3D
		variant.hide()
		add_child(variant)
		hair_models.append(variant)
	# Measure all styles and pose endpoints once. Switching never refits the camera.
	for variant: Node3D in hair_models:
		for mesh: MeshInstance3D in variant.find_children("*", "MeshInstance3D"):
			bounds = bounds.merge(mesh.global_transform * _pose_bounds(mesh.mesh))
	centre = bounds.get_center()


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


func set_hairstyle(index: int) -> void:
	if index < 0 or index >= hair_models.size():
		return
	hairstyle = index
	for variant: Node3D in hair_models:
		variant.visible = variant == hair_models[index]
	model = hair_models[index]
	meshes.clear()
	_collect_meshes(model)
	_bind_model()
	set_grey(grey)
	set_hood_lowered(hood_lowered)
	_show_expression(displayed_expression)
	if hair_button != null:
		hair_button.text = "Hair: " + HAIRSTYLES[index]


func _bind_model() -> void:
	hood = null
	hood_shape = -1
	face_material = null
	tucked_hair.clear()
	for mesh: MeshInstance3D in meshes:
		if mesh.name == "Hood":
			hood = mesh
			hood_shape = hood.find_blend_shape_by_name("HoodLowered")
		var tucked_index := mesh.find_blend_shape_by_name("HairTucked")
		if tucked_index >= 0:
			tucked_hair[mesh] = tucked_index
		for surface: int in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source != null and source.resource_name == "TravellerFace":
				face_material = mesh.get_surface_override_material(surface) as StandardMaterial3D
				if face_material == null:
					face_material = source.duplicate() as StandardMaterial3D
					mesh.set_surface_override_material(surface, face_material)
	if face_material == null or hood_shape < 0:
		push_error("Painted study needs TravellerFace and HoodLowered.")


func _build_controls() -> void:
	super._build_controls()
	_button("Face: Neutral", func(): set_expression((expression + 1) % EXPRESSIONS.size()))
	face_button = controls.get_child(controls.get_child_count() - 1) as Button
	_button("Blink", blink_once)
	_button("Hood: Raised", func(): set_hood_lowered(not hood_lowered))
	hood_button = controls.get_child(controls.get_child_count() - 1) as Button
	_button("Hair: Long", func(): set_hairstyle((hairstyle + 1) % HAIRSTYLES.size()))
	hair_button = controls.get_child(controls.get_child_count() - 1) as Button
	_button("Reset study", reset_study)


func set_expression(index: int) -> void:
	expression = clampi(index, 0, EXPRESSIONS.size() - 1)
	blink_time = -1.0
	_show_expression(expression)
	if face_button != null:
		face_button.text = "Face: " + EXPRESSIONS[expression]


func _show_expression(index: int) -> void:
	displayed_expression = index
	if face_material != null:
		# The exported head UVs occupy the first 256 px tile of the shared atlas.
		face_material.uv1_offset = Vector3(index * 0.25, 0.0, 0.0)


func blink_once() -> void:
	blink_time = 0.0
	_show_expression(1)


func advance_blink(delta: float) -> void:
	if blink_time < 0.0:
		return
	blink_time += maxf(delta, 0.0)
	if blink_time >= BLINK_DURATION:
		blink_time = -1.0
		_show_expression(expression)
	else:
		_show_expression(2 if blink_time >= 0.06 and blink_time < 0.16 else 1)


func set_hood_lowered(lowered: bool) -> void:
	hood_lowered = lowered
	if hood != null and hood_shape >= 0:
		# Endpoints only. The full hand-assisted transition is later work.
		hood.set_blend_shape_value(hood_shape, 1.0 if lowered else 0.0)
	for mesh: MeshInstance3D in tucked_hair:
		mesh.set_blend_shape_value(tucked_hair[mesh], 0.0 if lowered else 1.0)
	if hood_button != null:
		hood_button.text = "Hood: Lowered" if lowered else "Hood: Raised"


func reset_study() -> void:
	set_hairstyle(0)
	set_expression(0)
	set_hood_lowered(false)
	set_grey(false)
	set_view(3)


func _process(delta: float) -> void:
	super._process(delta)
	advance_blink(delta)


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F: set_expression((expression + 1) % EXPRESSIONS.size())
			KEY_B: blink_once()
			KEY_U: set_hood_lowered(not hood_lowered)
			KEY_T: set_hairstyle((hairstyle + 1) % HAIRSTYLES.size())
			KEY_R: reset_study()

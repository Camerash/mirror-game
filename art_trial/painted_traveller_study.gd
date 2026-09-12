extends "res://art_trial/head_study.gd"
## Isolated painted-face and two-pose hood review. No gameplay asset replacement.

const EXPRESSIONS := ["Neutral", "Half closed", "Closed", "Smile"]
const BLINK_DURATION := 0.24

var face_material: StandardMaterial3D
var hood: MeshInstance3D
var hood_shape := -1
var hood_lowered := false
var expression := 0
var displayed_expression := 0
var blink_time := -1.0
var face_button: Button
var hood_button: Button


func _ready() -> void:
	super._ready()
	for mesh: MeshInstance3D in meshes:
		if mesh.name == "Hood":
			hood = mesh
			hood_shape = hood.find_blend_shape_by_name("HoodLowered")
		for surface: int in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source != null and source.resource_name == "TravellerFace":
				face_material = source.duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(surface, face_material)
	if face_material == null or hood_shape < 0:
		push_error("Painted study needs TravellerFace and HoodLowered.")
	reset_study()


func _build_controls() -> void:
	super._build_controls()
	_button("Face: Neutral", func(): set_expression((expression + 1) % EXPRESSIONS.size()))
	face_button = controls.get_child(controls.get_child_count() - 1) as Button
	_button("Blink", blink_once)
	_button("Hood: Raised", func(): set_hood_lowered(not hood_lowered))
	hood_button = controls.get_child(controls.get_child_count() - 1) as Button
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
	if hood_button != null:
		hood_button.text = "Hood: Lowered" if lowered else "Hood: Raised"


func reset_study() -> void:
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
			KEY_R: reset_study()

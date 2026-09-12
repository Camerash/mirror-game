extends Node3D
## Isolated native review of the traveller head. Does not replace the game asset.

@export_file("*.glb") var model_path := "res://assets/studies/traveller_head.glb"
const CeramicLighting := preload("res://art_trial/reference_lighting.gd")
const VIEW_NAMES := ["Front", "Side", "Back", "Three-quarter", "Game angle"]
const VIEW_ANGLES := [Vector2(0, 0), Vector2(90, 0), Vector2(180, 0), Vector2(-45, 0), Vector2(-45, 30)]

var model: Node3D
var camera := Camera3D.new()
var lighting: Node3D
var controls := HFlowContainer.new()
var meshes: Array[MeshInstance3D] = []
var centre := Vector3.ZERO
var bounds := AABB()
var view_index := 3
var ceramic_light := false
var grey := true
var turntable := false
var small_view := false
var orbit_angle := -45.0
var grey_material := StandardMaterial3D.new()


func _ready() -> void:
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_error("Head study GLB is missing: " + model_path)
		return
	model = packed.instantiate() as Node3D
	add_child(model)
	_collect_meshes(model)
	if meshes.is_empty():
		push_error("Head study has no visible mesh.")
		return
	bounds = meshes[0].global_transform * meshes[0].get_aabb()
	for mesh: MeshInstance3D in meshes:
		bounds = bounds.merge(mesh.global_transform * mesh.get_aabb())
	centre = bounds.get_center()
	grey_material.albedo_color = Color("b5b2ae")
	grey_material.roughness = 0.85
	grey_material.metallic_specular = 0.15
	set_grey(true)
	_set_lighting()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.01
	camera.far = 50.0
	camera.current = true
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_build_controls()
	get_viewport().size_changed.connect(fit_camera)
	fit_camera()


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		meshes.append(node)
	for child: Node in node.get_children():
		_collect_meshes(child)


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 16
	controls.offset_right = -16
	controls.offset_bottom = -16
	for index: int in VIEW_NAMES.size():
		_button(VIEW_NAMES[index], set_view.bind(index))
	_button("Grey / colour", func(): set_grey(not grey))
	_button("Lighting", func(): ceramic_light = not ceramic_light; _set_lighting())
	_button("Size", func(): small_view = not small_view; fit_camera())
	_button("Turntable", func(): turntable = not turntable)
	_button("Hide", func(): controls.hide())


func _button(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(112, 48)
	button.pressed.connect(action)
	controls.add_child(button)


func set_grey(enabled: bool) -> void:
	grey = enabled
	for mesh: MeshInstance3D in meshes:
		mesh.material_override = grey_material if grey else null


func set_view(index: int) -> void:
	view_index = clampi(index, 0, VIEW_NAMES.size() - 1)
	orbit_angle = VIEW_ANGLES[view_index].x
	turntable = false
	fit_camera()


func _set_lighting() -> void:
	if lighting != null:
		remove_child(lighting)
		lighting.queue_free()
	if ceramic_light:
		lighting = CeramicLighting.new()
		add_child(lighting)
		return
	lighting = Node3D.new()
	add_child(lighting)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("b9b4ae")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.65
	lighting.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 0.7
	key.shadow_enabled = true
	lighting.add_child(key)


func fit_camera() -> void:
	if model == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var columns := maxi(1, int((viewport_size.x - 32.0) / 116.0))
	var reserved := ceilf(float(controls.get_child_count()) / columns) * 52.0 + 24.0 if controls.visible else 24.0
	controls.offset_top = -reserved
	# Fit a sphere once; its radius does not change during the turntable.
	var diameter := bounds.size.length() * 1.16
	var usable_height := maxf(viewport_size.y - reserved, 1.0)
	camera.size = maxf(diameter * viewport_size.y / usable_height, diameter / viewport_size.aspect())
	if small_view:
		camera.size *= 4.0
	_position_camera()


func _position_camera() -> void:
	var yaw := deg_to_rad(orbit_angle)
	var pitch := deg_to_rad(VIEW_ANGLES[view_index].y)
	var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.position = centre + direction * 10.0
	camera.look_at(centre)


func _process(delta: float) -> void:
	if turntable and model != null:
		orbit_angle = fposmod(orbit_angle + delta * 30.0, 360.0)
		_position_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: set_view(posmod(view_index - 1, VIEW_NAMES.size()))
			KEY_E: set_view((view_index + 1) % VIEW_NAMES.size())
			KEY_G: set_grey(not grey)
			KEY_L: ceramic_light = not ceramic_light; _set_lighting()
			KEY_SPACE: turntable = not turntable
			KEY_V: small_view = not small_view; fit_camera()
			KEY_H: controls.visible = not controls.visible; fit_camera()
	if event is InputEventScreenTouch and event.pressed and not controls.visible:
		controls.show()
		fit_camera()

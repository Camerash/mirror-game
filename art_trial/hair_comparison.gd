extends Control
## A native six-view board. Each cell uses the same study camera and lighting.

const Study := preload("res://art_trial/painted_traveller_study.tscn")
@export_range(0, 4) var review_view := 3
var studies: Array[Node3D] = []


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("302c32")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	for lowered: bool in [false, true]:
		for index: int in 3:
			_add_cell(grid, index, lowered)


func _add_cell(grid: GridContainer, index: int, lowered: bool) -> void:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_child(cell)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.custom_minimum_size.y = 42
	cell.add_child(label)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var study := Study.instantiate()
	viewport.add_child(study)
	label.text = "%s · Hood %s" % [study.HAIRSTYLES[index], "down" if lowered else "up"]
	study.controls.hide()
	study.set_hairstyle(index)
	study.set_hood_lowered(lowered)
	study.ceramic_light = true
	study._set_lighting()
	study.set_view(review_view)
	study.set_process(false)
	studies.append(study)


func set_review_view(index: int) -> void:
	review_view = clampi(index, 0, 4)
	for study: Node3D in studies:
		study.set_view(review_view)

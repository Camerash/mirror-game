extends Control
## The look test for the UI style and motion system: every colour, type step,
## icon, control and motion verb on one screen. Open
## `res://ui/style/style_gallery.tscn` and watch the motion row loop.

const SWATCHES := [["Ink", UiStyle.INK], ["Snow", UiStyle.SNOW], ["Mist", UiStyle.MIST],
	["Light", UiStyle.LIGHT], ["Moss", UiStyle.MOSS], ["Ember", UiStyle.EMBER]]
const STATES := ["normal", "hover", "pressed", "disabled"]

var _chips := {}


func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color("c9d3d6"))
	gradient.set_color(1, Color("efe9df"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	sky.texture = texture
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(sky)
	var page := MarginContainer.new()
	page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		page.add_theme_constant_override("margin_" + side, 40)
	add_child(page)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	page.add_child(columns)
	var left := _column(columns)
	var right := _column(columns)

	left.add_child(UiStyle.label("Mirror", "title"))
	left.add_child(UiStyle.label("I   ·   The Garden", "chapter"))
	left.add_child(_spacer(8))
	left.add_child(_heading("Colour"))
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 14)
	for swatch: Array in SWATCHES:
		var item := VBoxContainer.new()
		var chip := ColorRect.new()
		chip.color = swatch[1]
		chip.custom_minimum_size = Vector2(56, 40)
		item.add_child(chip)
		item.add_child(UiStyle.label(swatch[0], "small"))
		swatches.add_child(item)
	left.add_child(swatches)
	left.add_child(_heading("Type"))
	for step: String in ["chapter", "body", "small"]:
		left.add_child(UiStyle.label("%s: the ice remembers the summer" % step.capitalize(), step))
	left.add_child(_heading("Icons"))
	var grid := GridContainer.new()
	grid.columns = UiIcons.NAMES.size()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for state: String in STATES:
		for icon: String in UiIcons.NAMES:
			grid.add_child(_icon_sample(icon, state))
	left.add_child(grid)
	left.add_child(UiStyle.label("Rows: normal, hover, pressed, disabled", "small", Color(UiStyle.INK, 0.6)))

	right.add_child(_heading("Controls"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var main := UiIcons.button("mirror_raised", "Lower the mirror (M)", true)
	row.add_child(main)
	row.add_child(UiIcons.button("undo", "Undo (Z)"))
	row.add_child(UiIcons.button("turn_left", "Turn left (Q)"))
	row.add_child(UiIcons.button("turn_right", "Turn right (E)"))
	var text_button := Button.new()
	text_button.text = "Continue"
	text_button.custom_minimum_size.y = UiStyle.TOUCH
	row.add_child(text_button)
	right.add_child(row)
	right.add_child(_heading("Panel"))
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300
	panel.size_flags_horizontal = SIZE_SHRINK_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiStyle.label("Music", "small"))
	var music := HSlider.new()
	music.max_value = 1.0
	music.step = 0.05
	music.value = 0.7
	music.custom_minimum_size.y = 28
	box.add_child(music)
	box.add_child(UiStyle.label("Effects", "small"))
	var effects := music.duplicate() as HSlider
	effects.value = 0.4
	box.add_child(effects)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = true
	box.add_child(fullscreen)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.add_child(UiIcons.button("restart", "Restart the stage"))
	actions.add_child(UiIcons.button("close", "Close"))
	box.add_child(actions)
	right.add_child(panel)
	right.add_child(_heading("Motion"))
	var motions := HBoxContainer.new()
	motions.add_theme_constant_override("separation", 6)
	for verb: String in ["press", "appear", "settle", "reveal", "breathe", "transition"]:
		var item := VBoxContainer.new()
		item.custom_minimum_size = Vector2(80, 110)
		var stage := Control.new()
		stage.custom_minimum_size = Vector2(80, 76)
		stage.clip_contents = false
		var chip := Panel.new()
		var round := UiStyle.frost(0.92, 22)
		round.set_border_width_all(0)
		chip.add_theme_stylebox_override("panel", round)
		chip.size = Vector2(44, 44)
		chip.position = Vector2(16, 16)
		stage.add_child(chip)
		item.add_child(stage)
		item.add_child(UiStyle.label("%s\n%.2f s" % [verb, Motion.duration(verb)], "small"))
		motions.add_child(item)
		_chips[verb] = chip
	right.add_child(motions)
	_loop.call_deferred()


func _loop() -> void:
	var press: Panel = _chips["press"]
	var appear: Panel = _chips["appear"]
	var settle: Panel = _chips["settle"]
	var reveal: Panel = _chips["reveal"]
	var transition: Panel = _chips["transition"]
	Motion.breathe(_chips["breathe"])
	while is_inside_tree():
		press.size = Vector2(44, 44)
		Motion.press(press)
		Motion.appear(appear)
		settle.position.x = 16 - 14
		Motion.tween(settle, "position:x", 16.0, "settle")
		reveal.modulate.a = 0.0
		reveal.scale = Vector2(1, 0.2)
		reveal.pivot_offset = Vector2(22, 44)
		Motion.tween(reveal, "modulate:a", 1.0, "reveal")
		Motion.tween(reveal, "scale", Vector2.ONE, "reveal")
		Motion.tween(transition, "self_modulate", UiStyle.LIGHT if transition.self_modulate == Color.WHITE else Color.WHITE, "transition")
		await get_tree().create_timer(1.8).timeout
		Motion.dismiss(appear)
		await get_tree().create_timer(0.9).timeout


func _column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(column)
	return column


func _heading(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_spacer(6))
	box.add_child(UiStyle.label(text.to_upper(), "small", Color(UiStyle.INK, 0.55)))
	return box


func _spacer(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	return gap


## An icon on the button surface of one state, drawn without input.
func _icon_sample(icon: String, state: String) -> Control:
	var sample := Control.new()
	sample.custom_minimum_size = Vector2(UiStyle.TOUCH, UiStyle.TOUCH)
	sample.draw.connect(func() -> void:
		var box := theme.get_stylebox(state, "IconButton")
		box.draw(sample.get_canvas_item(), Rect2(Vector2.ZERO, sample.size))
		var side := sample.size.x * 0.5
		UiIcons.draw(sample, icon, Rect2(sample.size * 0.5 - Vector2.ONE * side * 0.5, Vector2.ONE * side),
			Color(UiStyle.INK, 0.4 if state == "disabled" else 1.0)))
	return sample

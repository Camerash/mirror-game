extends Control
class_name MirrorHUD

signal action_requested(action: String, value: Variant)
signal play_rect_changed(rect: Rect2)

const INK := Color("342b2a")
const IVORY := Color("f4ecdd")
const IVORY_DARK := Color("e7d8c3")
const TERRACOTTA := Color("b85f4b")
const MUTED := Color("78645f")
const MIN_TOUCH_SIZE := 48.0
const HEADER_HEIGHT := 66.0
const PANEL_WIDTH := 312.0
const PANEL_GAP := 12.0

var _state: Dictionary = {}
var _syncing := false
var _last_play_rect := Rect2()
var _header: HBoxContainer
var _panel: PanelContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _level_picker: OptionButton
var _panel_title_label: Label
var _objective_label: Label
var _phase_label: Label
var _status_label: Label
var _edit_button: Button
var _action_row: HBoxContainer
var _enabled_button: CheckButton
var _offset_label: Label
var _step_down_button: Button
var _step_up_button: Button
var _axis_picker: OptionButton
var _source_label: Label
var _flip_button: Button
var _undo_button: Button
var _apply_button: Button
var _style_picker: OptionButton
var _collision_button: CheckButton
var _touch_controls: Dictionary = {}
var _preview_controls: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_responsive_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_responsive_layout()


func configure_levels(titles: Array[String], selected: int) -> void:
	if not is_instance_valid(_level_picker):
		return
	_syncing = true
	_level_picker.clear()
	for title in titles:
		_level_picker.add_item(title)
	if not titles.is_empty():
		_level_picker.select(clampi(selected, 0, titles.size() - 1))
	_syncing = false


func display_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	if not is_instance_valid(_panel_title_label):
		return
	_syncing = true
	_panel_title_label.text = str(_state.get("title", "Mirror"))
	_objective_label.text = str(_state.get("objective", ""))
	_phase_label.text = _phase_text(str(_state.get("phase", "play")))
	_status_label.text = str(_state.get("status", ""))
	_edit_button.text = "Close edit" if bool(_state.get("editing", false)) else "Edit mirror"
	var preview_active := bool(_state.get("editing", false)) or str(_state.get("phase", "play")) == "preview"
	for control in _preview_controls:
		control.visible = preview_active
	_enabled_button.set_pressed_no_signal(bool(_state.get("enabled", true)))
	_offset_label.text = "Offset  %.1f" % float(_state.get("offset", 0.0))
	_step_down_button.disabled = float(_state.get("offset", 0.0)) <= float(_state.get("min_offset", -INF))
	_step_up_button.disabled = float(_state.get("offset", 0.0)) >= float(_state.get("max_offset", INF))
	_axis_picker.select(clampi(int(_state.get("axis", 0)), 0, 2))
	var allowed_axes: Array = _state.get("allowed_axes", [0, 1, 2])
	for index in 3:
		_axis_picker.set_item_disabled(index, not allowed_axes.has(index))
	var test_editing := bool(_state.get("editing", false)) and bool(_state.get("is_test", false))
	_axis_picker.visible = test_editing
	_source_label.text = "Reflect lower coordinates" if int(_state.get("source", 1)) >= 0 else "Reflect higher coordinates"
	_source_label.visible = test_editing
	_flip_button.visible = test_editing
	_undo_button.disabled = not bool(_state.get("can_undo", false))
	_apply_button.disabled = not bool(_state.get("can_apply", false))
	_style_picker.select(clampi(int(_state.get("style", 0)), 0, 1))
	_collision_button.set_pressed_no_signal(bool(_state.get("collision", false)))
	_syncing = false
	_responsive_layout()


func get_play_rect() -> Rect2:
	return _last_play_rect


func get_touch_control_bounds() -> Dictionary:
	var bounds: Dictionary = {}
	for key: String in _touch_controls:
		var control := _touch_controls[key] as Control
		if is_instance_valid(control) and control.is_visible_in_tree():
			bounds[key] = control.get_global_rect()
	return bounds


func _build_ui() -> void:
	_header = HBoxContainer.new()
	_header.name = "Header"
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.add_theme_constant_override("separation", 10)
	add_child(_header)
	var header_title := _make_label("Mirror", 20)
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(header_title)
	_level_picker = OptionButton.new()
	_level_picker.tooltip_text = "Choose level"
	_level_picker.fit_to_longest_item = false
	_level_picker.clip_text = true
	_level_picker.custom_minimum_size = Vector2(144, MIN_TOUCH_SIZE)
	_style_control(_level_picker)
	_level_picker.item_selected.connect(_on_level_selected)
	_header.add_child(_level_picker)
	_register("level_picker", _level_picker)

	_panel = PanelContainer.new()
	_panel.name = "MirrorControls"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_add_text_block()
	_add_main_actions()
	_add_history_actions()
	_add_preview_actions()
	_add_options()


func _add_text_block() -> void:
	_panel_title_label = _make_label("Mirror", 18)
	_panel_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_panel_title_label)
	_objective_label = _make_label("", 15)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_objective_label)
	_phase_label = _make_label("Playing", 14)
	_phase_label.add_theme_color_override("font_color", TERRACOTTA)
	_content.add_child(_phase_label)
	_status_label = _make_label("", 14)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", MUTED)
	_content.add_child(_status_label)


func _add_main_actions() -> void:
	_edit_button = _make_button("Edit mirror")
	_edit_button.pressed.connect(func() -> void: _emit_action("edit"))
	_content.add_child(_edit_button)
	_register("edit", _edit_button)
	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 8)
	_apply_button = _make_button("Apply")
	_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button.pressed.connect(func() -> void: _emit_action("apply"))
	_action_row.add_child(_apply_button)
	var cancel := _make_button("Cancel")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: _emit_action("cancel"))
	_action_row.add_child(cancel)
	_content.add_child(_action_row)
	_register("apply", _apply_button)
	_register("cancel", cancel)
	_preview_controls.append(_apply_button)
	_preview_controls.append(cancel)


func _add_preview_actions() -> void:
	_enabled_button = CheckButton.new()
	_enabled_button.text = "Mirror enabled"
	_style_control(_enabled_button)
	_enabled_button.toggled.connect(func(value: bool) -> void: _emit_action("enabled", value))
	_content.add_child(_enabled_button)
	_register("enabled", _enabled_button)
	_preview_controls.append(_enabled_button)

	var step_row := HBoxContainer.new()
	step_row.add_theme_constant_override("separation", 8)
	_content.add_child(step_row)
	_step_down_button = _make_button("− 0.5")
	_step_down_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_down_button.pressed.connect(func() -> void: _emit_action("step", -0.5))
	step_row.add_child(_step_down_button)
	_offset_label = _make_label("Offset  0.0", 15)
	_offset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_row.add_child(_offset_label)
	_step_up_button = _make_button("+ 0.5")
	_step_up_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_up_button.pressed.connect(func() -> void: _emit_action("step", 0.5))
	step_row.add_child(_step_up_button)
	_register("step_down", _step_down_button)
	_register("step_up", _step_up_button)
	_preview_controls.append(step_row)

	_axis_picker = OptionButton.new()
	_axis_picker.add_item("Axis X", 0)
	_axis_picker.add_item("Axis Y", 1)
	_axis_picker.add_item("Axis Z", 2)
	_style_control(_axis_picker)
	_axis_picker.item_selected.connect(func(index: int) -> void: _emit_action("axis", index))
	_content.add_child(_axis_picker)
	_register("axis", _axis_picker)
	_preview_controls.append(_axis_picker)

	_source_label = _make_label("Reflect lower coordinates", 14)
	_source_label.add_theme_color_override("font_color", MUTED)
	_content.add_child(_source_label)
	_flip_button = _make_button("Flip source")
	_flip_button.pressed.connect(func() -> void: _emit_action("flip"))
	_content.add_child(_flip_button)
	_register("flip", _flip_button)


func _add_history_actions() -> void:
	_undo_button = _make_button("Undo")
	_undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_button.pressed.connect(func() -> void: _emit_action("undo"))
	_action_row.add_child(_undo_button)
	var reset := _make_button("Reset")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void: _emit_action("reset"))
	_action_row.add_child(reset)
	_register("undo", _undo_button)
	_register("reset", reset)


func _add_options() -> void:
	_style_picker = OptionButton.new()
	_style_picker.add_item("Outline view", 0)
	_style_picker.add_item("Translucent view", 1)
	_style_control(_style_picker)
	_style_picker.item_selected.connect(func(index: int) -> void: _emit_action("style", index))
	_content.add_child(_style_picker)
	_register("style", _style_picker)
	_collision_button = CheckButton.new()
	_collision_button.text = "Show collision"
	_style_control(_collision_button)
	_collision_button.toggled.connect(func(value: bool) -> void: _emit_action("collision", value))
	_content.add_child(_collision_button)
	_register("collision", _collision_button)


func _responsive_layout() -> void:
	if not is_instance_valid(_panel):
		return
	var safe_rect := _safe_rect()
	var side_layout := safe_rect.size.x >= 700.0 and safe_rect.size.x >= safe_rect.size.y
	_header.position = safe_rect.position + Vector2(PANEL_GAP, PANEL_GAP)
	_header.size = Vector2(safe_rect.size.x - PANEL_GAP * 2.0, HEADER_HEIGHT)
	if side_layout:
		_panel.position = Vector2(safe_rect.end.x - PANEL_WIDTH - PANEL_GAP, safe_rect.position.y + HEADER_HEIGHT + PANEL_GAP * 2.0)
		_panel.size = Vector2(PANEL_WIDTH, maxf(0.0, safe_rect.size.y - HEADER_HEIGHT - PANEL_GAP * 3.0))
		_set_play_rect(Rect2(Vector2(safe_rect.position.x, safe_rect.position.y + HEADER_HEIGHT + PANEL_GAP * 2.0), Vector2(maxf(0.0, safe_rect.size.x - PANEL_WIDTH - PANEL_GAP), maxf(0.0, safe_rect.size.y - HEADER_HEIGHT - PANEL_GAP * 2.0))))
	else:
		var panel_height := minf(maxf(300.0, safe_rect.size.y * 0.52), maxf(0.0, safe_rect.size.y - HEADER_HEIGHT - PANEL_GAP * 3.0))
		_panel.position = Vector2(safe_rect.position.x + PANEL_GAP, safe_rect.end.y - panel_height - PANEL_GAP)
		_panel.size = Vector2(maxf(0.0, safe_rect.size.x - PANEL_GAP * 2.0), panel_height)
		_set_play_rect(Rect2(Vector2(safe_rect.position.x, safe_rect.position.y + HEADER_HEIGHT + PANEL_GAP * 2.0), Vector2(safe_rect.size.x, maxf(0.0, _panel.position.y - safe_rect.position.y - HEADER_HEIGHT - PANEL_GAP * 3.0))))


func _safe_rect() -> Rect2:
	var visible_rect := get_viewport_rect()
	if OS.get_name() not in ["iOS", "Android"]:
		return visible_rect
	var safe_area := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return visible_rect
	var scale := Vector2(visible_rect.size.x / float(window_size.x), visible_rect.size.y / float(window_size.y))
	var safe_rect := Rect2(Vector2(safe_area.position) * scale, Vector2(safe_area.size) * scale)
	var clipped := safe_rect.intersection(visible_rect)
	return clipped if clipped.size.x > 0 and clipped.size.y > 0 else visible_rect


func _set_play_rect(rect: Rect2) -> void:
	if not rect.is_equal_approx(_last_play_rect):
		_last_play_rect = rect
		play_rect_changed.emit(rect)


func _emit_action(action: String, value: Variant = null) -> void:
	if not _syncing:
		action_requested.emit(action, value)


func _on_level_selected(index: int) -> void:
	_emit_action("select_level", index)


func _phase_text(phase: String) -> String:
	match phase:
		"preview": return "Preview"
		"failure": return "Try again"
		"complete": return "Goal reached"
		_: return "Playing"


func _make_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, MIN_TOUCH_SIZE)
	_style_control(button)
	return button


func _style_control(control: Control) -> void:
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, MIN_TOUCH_SIZE)
	if control is OptionButton:
		var popup: PopupMenu = (control as OptionButton).get_popup()
		popup.add_theme_font_size_override("font_size", 16)
		popup.add_theme_constant_override("v_separation", 32)
		popup.add_theme_color_override("font_color", INK)
		popup.add_theme_stylebox_override("panel", _panel_style())
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_hover_color", INK)
	control.add_theme_color_override("font_pressed_color", IVORY)
	control.add_theme_color_override("font_disabled_color", MUTED)
	control.add_theme_stylebox_override("normal", _control_style(IVORY_DARK))
	control.add_theme_stylebox_override("hover", _control_style(Color("eadcc8")))
	control.add_theme_stylebox_override("pressed", _control_style(TERRACOTTA))
	control.add_theme_stylebox_override("focus", _control_style(TERRACOTTA))
	control.add_theme_stylebox_override("disabled", _control_style(Color("d9cbb9")))


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = IVORY
	style.border_color = Color("cdbca5")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _control_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _register(key: String, control: Control) -> void:
	_touch_controls[key] = control

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
const HEADER_HEIGHT := 72.0
const FOOTER_HEIGHT := 60.0
const GAP := 12.0
const TOOLBAR_WIDTH := 288.0

var _state: Dictionary = {}
var _failure_marker: Label
var _syncing := false
var _last_play_rect := Rect2()
var _last_camera_rect := Rect2()
var _last_emitted_play_rect := Rect2()
var _mirror_anchor := Vector2.ZERO
var _avoid_points := PackedVector2Array()
var _header: PanelContainer
var _preview_border: PanelContainer
var _footer: PanelContainer
var _footer_root: Control
var _footer_actions: HBoxContainer
var _toolbar: PanelContainer
var _toolbar_scroll: ScrollContainer
var _toolbar_actions: VBoxContainer
var _toolbar_content: VBoxContainer
var _header_content: Control
var _header_text: VBoxContainer
var _navigation_row: HBoxContainer
var _level_picker: OptionButton
var _title_label: Label
var _objective_label: Label
var _phase_label: Label
var _status_label: Label
var _primary_button: Button
var _apply_button: Button
var _cancel_button: Button
var _enabled_button: Button
var _editing_label: Label
var _camera_left_button: Button
var _camera_right_button: Button
var _turn_left_button: Button
var _turn_right_button: Button
var _tilt_button: Button
var _step_row: HBoxContainer
var _offset_label: Label
var _step_down_button: Button
var _step_up_button: Button
var _undo_button: Button
var _reset_button: Button
var _next_level_button: Button
var _test_options_button: Button
var _test_panel: PanelContainer
var _test_options: VBoxContainer
var _style_picker: OptionButton
var _collision_button: CheckButton
var _flip_button: Button
var _standing_only_button: CheckButton
var _touch_controls: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_failure_marker = _make_label("↓ No landing", 16)
	_failure_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_failure_marker.add_theme_color_override("font_color", Color("ffdfa8"))
	_failure_marker.add_theme_color_override("font_outline_color", Color("342b2a"))
	_failure_marker.add_theme_constant_override("outline_size", 5)
	_failure_marker.visible = false
	add_child(_failure_marker)
	_toolbar_content.minimum_size_changed.connect(_responsive_layout.call_deferred)
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
	var editing_before := bool(_state.get("editing", false))
	_state = state.duplicate(true)
	if not is_instance_valid(_toolbar):
		return
	var editing := bool(_state.get("editing", false))
	if editing and not editing_before:
		_test_options_button.set_pressed_no_signal(false)
		_test_panel.visible = false
	_syncing = true
	if _level_picker.item_count > 0:
		var selected_level := clampi(int(_state.get("level_index", 0)), 0, _level_picker.item_count - 1)
		if _level_picker.selected != selected_level:
			_level_picker.select(selected_level)
	_title_label.text = str(_state.get("title", "Mirror"))
	_objective_label.text = str(_state.get("objective", ""))
	_objective_label.tooltip_text = _objective_label.text
	var phase := str(_state.get("phase", "play"))
	_phase_label.text = _phase_text(phase)
	_status_label.text = str(_state.get("status", ""))
	var can_edit := bool(_state.get("can_edit", true))
	var enabled := bool(_state.get("enabled", true))
	_primary_button.visible = not editing
	_primary_button.text = "Modify" if enabled else "Enable"
	_primary_button.disabled = not can_edit
	_apply_button.visible = editing
	_cancel_button.visible = editing
	_apply_button.disabled = not bool(_state.get("can_apply", false))
	_enabled_button.visible = editing
	_enabled_button.text = "Disable" if enabled else "Enable"
	_editing_label.visible = editing
	_camera_left_button.disabled = bool(_state.get("camera_busy", false))
	_camera_right_button.disabled = bool(_state.get("camera_busy", false))
	var horizontal := int(_state.get("axis", 0)) == 1
	var mirror_busy := bool(_state.get("mirror_busy", false))
	_turn_left_button.disabled = horizontal or mirror_busy
	_turn_right_button.disabled = horizontal or mirror_busy
	_tilt_button.disabled = mirror_busy
	_flip_button.disabled = mirror_busy
	_tilt_button.text = "Stand up" if horizontal else "Lay flat"
	var offset := float(_state.get("offset", 0.0))
	var min_offset := float(_state.get("min_offset", -INF))
	var max_offset := float(_state.get("max_offset", INF))
	_offset_label.text = "Offset %.1f" % offset
	_step_down_button.disabled = offset <= min_offset
	_step_up_button.disabled = offset >= max_offset
	_step_row.visible = editing and not is_equal_approx(min_offset, max_offset)
	_turn_left_button.visible = editing
	_turn_right_button.visible = editing
	_tilt_button.visible = editing
	_flip_button.visible = editing
	_test_panel.visible = _test_options_button.button_pressed
	_style_picker.select(clampi(int(_state.get("style", 0)), 0, 1))
	_collision_button.set_pressed_no_signal(bool(_state.get("collision", false)))
	_standing_only_button.set_pressed_no_signal(bool(_state.get("standing_only", false)))
	_undo_button.disabled = not bool(_state.get("can_undo", false))
	_next_level_button.visible = bool(_state.get("can_advance", false)) and phase == "complete"
	_preview_border.visible = editing
	_syncing = false
	_responsive_layout()


func set_mirror_anchor(point: Vector2, avoid_points: PackedVector2Array = PackedVector2Array()) -> void:
	_mirror_anchor = point
	_avoid_points = avoid_points


func get_play_rect() -> Rect2:
	return _last_play_rect


func get_camera_rect() -> Rect2:
	if not bool(_state.get("editing", false)) or not is_instance_valid(_toolbar):
		return _last_play_rect
	if _is_narrow_portrait(_last_play_rect):
		var bottom := maxf(_last_play_rect.position.y, _toolbar.position.y - GAP)
		return Rect2(_last_play_rect.position, Vector2(_last_play_rect.size.x, maxf(0.0, bottom - _last_play_rect.position.y)))
	var left := minf(_last_play_rect.end.x, _toolbar.get_global_rect().end.x + GAP)
	return Rect2(Vector2(left, _last_play_rect.position.y), Vector2(maxf(0.0, _last_play_rect.end.x - left), _last_play_rect.size.y))


func get_touch_control_bounds() -> Dictionary:
	var bounds: Dictionary = {}
	for key: String in _touch_controls:
		var control := _touch_controls[key] as Control
		if is_instance_valid(control) and control.is_visible_in_tree():
			bounds[key] = control.get_global_rect()
	return bounds


func blocks_world_input(point: Vector2) -> bool:
	for panel: Control in [_header, _footer, _toolbar, _test_panel]:
		if is_instance_valid(panel) and panel.is_visible_in_tree() and panel.get_global_rect().has_point(point):
			return true
	return false


func _build_ui() -> void:
	_preview_border = PanelContainer.new()
	_preview_border.name = "PreviewBorder"
	_preview_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_border.add_theme_stylebox_override("panel", _preview_border_style())
	_preview_border.visible = false
	add_child(_preview_border)

	_header = PanelContainer.new()
	_header.name = "Header"
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.add_theme_stylebox_override("panel", _panel_style())
	add_child(_header)
	_header_content = Control.new()
	_header.add_child(_header_content)
	_header_text = VBoxContainer.new()
	_header_text.add_theme_constant_override("separation", 0)
	_header_content.add_child(_header_text)
	_title_label = _make_label("Mirror", 18)
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header_text.add_child(_title_label)
	_objective_label = _make_label("", 13)
	_objective_label.clip_text = false
	_objective_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_objective_label.max_lines_visible = 2
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_text.add_child(_objective_label)
	_phase_label = _make_label("Playing", 13)
	_phase_label.add_theme_color_override("font_color", TERRACOTTA)
	_header_text.add_child(_phase_label)
	_navigation_row = HBoxContainer.new()
	_navigation_row.alignment = BoxContainer.ALIGNMENT_END
	_navigation_row.add_theme_constant_override("separation", 4)
	_header_content.add_child(_navigation_row)
	_camera_left_button = _make_button("◀")
	_camera_left_button.tooltip_text = "Turn camera left (Q)"
	_camera_left_button.custom_minimum_size.x = MIN_TOUCH_SIZE
	_camera_left_button.pressed.connect(func() -> void: _emit_action("camera_turn", -1))
	_navigation_row.add_child(_camera_left_button)
	_register("camera_left", _camera_left_button)
	_camera_right_button = _make_button("▶")
	_camera_right_button.tooltip_text = "Turn camera right (E)"
	_camera_right_button.custom_minimum_size.x = MIN_TOUCH_SIZE
	_camera_right_button.pressed.connect(func() -> void: _emit_action("camera_turn", 1))
	_navigation_row.add_child(_camera_right_button)
	_register("camera_right", _camera_right_button)
	_level_picker = OptionButton.new()
	_level_picker.tooltip_text = "Choose level"
	_level_picker.fit_to_longest_item = false
	_level_picker.clip_text = true
	_level_picker.custom_minimum_size = Vector2(120, MIN_TOUCH_SIZE)
	_style_control(_level_picker)
	_level_picker.item_selected.connect(_on_level_selected)
	_navigation_row.add_child(_level_picker)
	_register("level_picker", _level_picker)

	_footer = PanelContainer.new()
	_footer.name = "Footer"
	_footer.mouse_filter = Control.MOUSE_FILTER_STOP
	_footer.add_theme_stylebox_override("panel", _panel_style())
	add_child(_footer)
	_footer_root = Control.new()
	_footer.add_child(_footer_root)
	_status_label = _make_label("", 13)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", MUTED)
	_footer_root.add_child(_status_label)
	_footer_actions = HBoxContainer.new()
	_footer_actions.add_theme_constant_override("separation", 8)
	_footer_root.add_child(_footer_actions)
	_undo_button = _make_button("Undo")
	_undo_button.pressed.connect(func() -> void: _emit_action("undo"))
	_footer_actions.add_child(_undo_button)
	_register("undo", _undo_button)
	_reset_button = _make_button("Reset")
	_reset_button.pressed.connect(func() -> void: _emit_action("reset"))
	_footer_actions.add_child(_reset_button)
	_register("reset", _reset_button)
	_next_level_button = _make_button("Next")
	_next_level_button.visible = false
	_next_level_button.pressed.connect(func() -> void: _emit_action("next_level"))
	_footer_actions.add_child(_next_level_button)
	_register("next_level", _next_level_button)
	_test_options_button = _make_button("Test options")
	_test_options_button.toggle_mode = true
	_test_options_button.toggled.connect(func(shown: bool) -> void:
		_test_panel.visible = shown
		_responsive_layout())
	_footer_actions.add_child(_test_options_button)
	_register("test_options", _test_options_button)

	_toolbar = PanelContainer.new()
	_toolbar.name = "MirrorToolbar"
	_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	_toolbar.add_theme_stylebox_override("panel", _panel_style())
	add_child(_toolbar)
	var toolbar_root := VBoxContainer.new()
	toolbar_root.add_theme_constant_override("separation", 8)
	_toolbar.add_child(toolbar_root)
	_toolbar_actions = VBoxContainer.new()
	_toolbar_actions.add_theme_constant_override("separation", 8)
	toolbar_root.add_child(_toolbar_actions)
	_toolbar_scroll = ScrollContainer.new()
	_toolbar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_toolbar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	toolbar_root.add_child(_toolbar_scroll)
	_toolbar_content = VBoxContainer.new()
	_toolbar_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar_content.add_theme_constant_override("separation", 8)
	_toolbar_scroll.add_child(_toolbar_content)
	_add_toolbar_controls()

	_test_panel = PanelContainer.new()
	_test_panel.name = "TestOptions"
	_test_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_test_panel.add_theme_stylebox_override("panel", _panel_style())
	_test_panel.visible = false
	add_child(_test_panel)
	var test_scroll := ScrollContainer.new()
	test_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_test_panel.add_child(test_scroll)
	_test_options = VBoxContainer.new()
	_test_options.add_theme_constant_override("separation", 6)
	test_scroll.add_child(_test_options)
	_add_test_options()


func _add_toolbar_controls() -> void:
	_editing_label = _make_label("Editing mirror", 14)
	_editing_label.add_theme_color_override("font_color", TERRACOTTA)
	_toolbar_actions.add_child(_editing_label)
	_primary_button = _make_button("Modify")
	_primary_button.pressed.connect(func() -> void: _emit_action("edit"))
	_toolbar_actions.add_child(_primary_button)
	_register("edit", _primary_button)
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 8)
	_toolbar_actions.add_child(confirm_row)
	_apply_button = _make_button("Confirm")
	_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button.add_theme_stylebox_override("normal", _control_style(TERRACOTTA))
	_apply_button.add_theme_stylebox_override("hover", _control_style(Color("c96e58")))
	_apply_button.pressed.connect(func() -> void: _emit_action("apply"))
	confirm_row.add_child(_apply_button)
	_register("apply", _apply_button)
	_cancel_button = _make_button("Cancel")
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(func() -> void: _emit_action("cancel"))
	confirm_row.add_child(_cancel_button)
	_register("cancel", _cancel_button)
	_enabled_button = _make_button("Disable")
	_enabled_button.pressed.connect(_toggle_enabled)
	_toolbar_content.add_child(_enabled_button)
	_register("enabled", _enabled_button)
	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 8)
	_toolbar_content.add_child(turn_row)
	_turn_left_button = _make_button("Turn left")
	_turn_left_button.tooltip_text = "Quarter-turn mirror left"
	_turn_left_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_left_button.pressed.connect(func() -> void: _emit_action("turn", -1))
	turn_row.add_child(_turn_left_button)
	_register("turn_left", _turn_left_button)
	_turn_right_button = _make_button("Turn right")
	_turn_right_button.tooltip_text = "Quarter-turn mirror right"
	_turn_right_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_right_button.pressed.connect(func() -> void: _emit_action("turn", 1))
	turn_row.add_child(_turn_right_button)
	_register("turn_right", _turn_right_button)
	_tilt_button = _make_button("Lay flat")
	_tilt_button.pressed.connect(func() -> void: _emit_action("tilt"))
	_toolbar_content.add_child(_tilt_button)
	_register("tilt", _tilt_button)
	_flip_button = _make_button("Reverse sides")
	_flip_button.pressed.connect(func() -> void: _emit_action("flip"))
	_toolbar_content.add_child(_flip_button)
	_register("flip", _flip_button)
	_step_row = HBoxContainer.new()
	_step_row.add_theme_constant_override("separation", 8)
	_toolbar_content.add_child(_step_row)
	_step_down_button = _make_button("− 0.5")
	_step_down_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_down_button.pressed.connect(func() -> void: _emit_action("step", -0.5))
	_step_row.add_child(_step_down_button)
	_register("step_down", _step_down_button)
	_offset_label = _make_label("Offset 0.0", 14)
	_offset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_row.add_child(_offset_label)
	_step_up_button = _make_button("+ 0.5")
	_step_up_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_up_button.pressed.connect(func() -> void: _emit_action("step", 0.5))
	_step_row.add_child(_step_up_button)
	_register("step_up", _step_up_button)


func _add_test_options() -> void:
	_style_picker = OptionButton.new()
	_style_picker.add_item("World atmosphere", 0)
	_style_picker.add_item("Boundary only", 1)
	_style_control(_style_picker)
	_style_picker.item_selected.connect(func(index: int) -> void: _emit_action("style", index))
	_test_options.add_child(_style_picker)
	_register("style", _style_picker)
	_collision_button = CheckButton.new()
	_collision_button.text = "Show collision"
	_style_control(_collision_button)
	_collision_button.toggled.connect(func(value: bool) -> void: _emit_action("collision", value))
	_test_options.add_child(_collision_button)
	_register("collision", _collision_button)
	_standing_only_button = CheckButton.new()
	_standing_only_button.text = "Standing still only"
	_style_control(_standing_only_button)
	_standing_only_button.toggled.connect(func(value: bool) -> void: _emit_action("standing_only", value))
	_test_options.add_child(_standing_only_button)
	_register("standing_only", _standing_only_button)


func _responsive_layout() -> void:
	if not is_instance_valid(_toolbar):
		return
	var safe_rect := _safe_rect()
	var narrow := safe_rect.size.x < 600.0
	var header_height := 152.0 if narrow else 96.0
	var footer_height := 104.0 if narrow else FOOTER_HEIGHT
	_objective_label.custom_minimum_size.y = 32.0 if narrow else 16.0
	_header.position = safe_rect.position + Vector2(GAP, GAP)
	_header.size = Vector2(maxf(0.0, safe_rect.size.x - GAP * 2.0), header_height)
	_layout_header(narrow)
	_footer.position = Vector2(safe_rect.position.x + GAP, safe_rect.end.y - footer_height - GAP)
	_footer.size = Vector2(maxf(0.0, safe_rect.size.x - GAP * 2.0), footer_height)
	_layout_footer(narrow)
	_set_play_rect(Rect2(
		safe_rect.position + Vector2(GAP, header_height + GAP * 2.0),
		Vector2(maxf(0.0, safe_rect.size.x - GAP * 2.0), maxf(0.0, safe_rect.size.y - header_height - footer_height - GAP * 4.0))
	))
	_place_toolbar(_last_play_rect)
	_place_test_options(_last_play_rect)
	_emit_camera_rect_changed()


func _layout_header(narrow: bool) -> void:
	var content_size := _header.size - Vector2(24.0, 16.0)
	var navigation_width := _navigation_row.get_combined_minimum_size().x
	if narrow:
		_header_text.position = Vector2.ZERO
		_header_text.size = Vector2(content_size.x, 72.0)
		_navigation_row.position = Vector2(0, 80.0)
		_navigation_row.size = Vector2(content_size.x, MIN_TOUCH_SIZE)
		return
	_header_text.position = Vector2.ZERO
	_header_text.size = Vector2(maxf(0.0, content_size.x - navigation_width - 10.0), content_size.y)
	_navigation_row.position = Vector2(maxf(0.0, content_size.x - navigation_width), (content_size.y - MIN_TOUCH_SIZE) * 0.5)
	_navigation_row.size = Vector2(navigation_width, MIN_TOUCH_SIZE)


func _layout_footer(narrow: bool) -> void:
	var content_size := _footer.get_size() - Vector2(24.0, 16.0)
	if narrow:
		_status_label.position = Vector2.ZERO
		_status_label.size = Vector2(content_size.x, 32.0)
		_footer_actions.position = Vector2(0, 40)
		_footer_actions.size = Vector2(content_size.x, MIN_TOUCH_SIZE)
		return
	var actions_width := _footer_actions.get_combined_minimum_size().x
	_status_label.position = Vector2.ZERO
	_status_label.size = Vector2(maxf(0.0, content_size.x - actions_width - 8.0), content_size.y)
	_footer_actions.position = Vector2(maxf(0.0, content_size.x - actions_width), 0)
	_footer_actions.size = Vector2(actions_width, MIN_TOUCH_SIZE)


func _place_toolbar(play_rect: Rect2) -> void:
	var preferred_width := TOOLBAR_WIDTH if bool(_state.get("editing", false)) else 128.0
	var toolbar_width := minf(preferred_width, maxf(MIN_TOUCH_SIZE, play_rect.size.x))
	_toolbar.size = Vector2(toolbar_width, MIN_TOUCH_SIZE)
	var content_height := _toolbar_content.get_combined_minimum_size().y if bool(_state.get("editing", false)) else 0.0
	var desired_height := 16.0 + _toolbar_actions.get_combined_minimum_size().y + (8.0 + content_height if content_height > 0 else 0.0)
	var toolbar_height := minf(play_rect.size.y, desired_height)
	if bool(_state.get("editing", false)) and _is_narrow_portrait(play_rect):
		toolbar_height = minf(toolbar_height, 210.0)
	_toolbar.size.y = maxf(MIN_TOUCH_SIZE, toolbar_height)
	if bool(_state.get("editing", false)):
		if _is_narrow_portrait(play_rect):
			_toolbar.position = Vector2(
				clampf(play_rect.get_center().x - _toolbar.size.x * 0.5, play_rect.position.x, play_rect.end.x - _toolbar.size.x),
				play_rect.end.y - _toolbar.size.y
			)
		else:
			_toolbar.position = play_rect.position
		return
	var candidates := [
		_mirror_anchor + Vector2(20, -_toolbar.size.y - 20),
		_mirror_anchor + Vector2(20, 20),
		_mirror_anchor + Vector2(-_toolbar.size.x - 20, -_toolbar.size.y - 20),
		_mirror_anchor + Vector2(-_toolbar.size.x - 20, 20),
		play_rect.position,
		Vector2(play_rect.end.x - _toolbar.size.x, play_rect.position.y),
		Vector2(play_rect.position.x, play_rect.end.y - _toolbar.size.y),
		play_rect.end - _toolbar.size,
	]
	var best_position := _clamp_toolbar_position(candidates[0], play_rect)
	var best_penalty := INF
	for candidate in candidates:
		var position := _clamp_toolbar_position(candidate, play_rect)
		var rect := Rect2(position, _toolbar.size)
		var penalty := rect.get_center().distance_squared_to(_mirror_anchor) * 0.02
		for point in _avoid_points:
			if rect.grow(8.0).has_point(point):
				penalty += 1000000.0
			elif rect.grow(32.0).has_point(point):
				penalty += 10000.0
		if penalty < best_penalty:
			best_penalty = penalty
			best_position = position
	_toolbar.position = best_position


func _place_test_options(play_rect: Rect2) -> void:
	if not _test_panel.visible:
		return
	var panel_size := Vector2(
		minf(TOOLBAR_WIDTH, maxf(MIN_TOUCH_SIZE, play_rect.size.x)),
		minf(260.0, maxf(MIN_TOUCH_SIZE, play_rect.size.y))
	)
	_test_panel.size = panel_size
	var candidates := [play_rect.end - panel_size, play_rect.position,
		Vector2(play_rect.end.x - panel_size.x, play_rect.position.y),
		Vector2(play_rect.position.x, play_rect.end.y - panel_size.y)]
	if _is_narrow_portrait(play_rect):
		candidates.push_front(Vector2(
			clampf(_toolbar.position.x, play_rect.position.x, play_rect.end.x - panel_size.x),
			maxf(play_rect.position.y, _toolbar.position.y - panel_size.y - GAP)
		))
	var best_overlap := INF
	for candidate: Vector2 in candidates:
		var candidate_rect := Rect2(candidate, panel_size)
		var overlap := candidate_rect.intersection(_toolbar_actions.get_global_rect().grow(8.0)).get_area() * 1000.0
		overlap += candidate_rect.intersection(_toolbar.get_global_rect().grow(8.0)).get_area()
		overlap += candidate_rect.intersection(_header.get_global_rect().grow(8.0)).get_area()
		overlap += candidate_rect.intersection(_footer.get_global_rect().grow(8.0)).get_area()
		if overlap < best_overlap:
			best_overlap = overlap
			_test_panel.position = candidate


func _clamp_toolbar_position(position: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf(position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - _toolbar.size.x)),
		clampf(position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - _toolbar.size.y))
	)


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
	_last_play_rect = rect


func _emit_camera_rect_changed() -> void:
	var camera_rect := get_camera_rect()
	if _last_play_rect.is_equal_approx(_last_emitted_play_rect) and camera_rect.is_equal_approx(_last_camera_rect):
		return
	_last_emitted_play_rect = _last_play_rect
	_last_camera_rect = camera_rect
	play_rect_changed.emit(_last_play_rect)


func _is_narrow_portrait(rect: Rect2) -> bool:
	return rect.size.x < 600.0 and rect.size.y > rect.size.x


func _toggle_enabled() -> void:
	_emit_action("enabled", not bool(_state.get("enabled", true)))


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
	control.add_theme_stylebox_override("focus", _focus_style())
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
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _preview_border_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(TERRACOTTA, 0.45)
	style.set_border_width_all(2)
	return style


func _control_style(color: Color, horizontal_padding: float = 12.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	return style


func _register(key: String, control: Control) -> void:
	_touch_controls[key] = control

func set_failure_marker(point: Vector2, active: bool) -> void:
	if not is_instance_valid(_failure_marker):
		return
	_failure_marker.visible = active and not _last_play_rect.has_point(point)
	_failure_marker.position = point.clamp(_last_play_rect.position + Vector2(8, 8), _last_play_rect.end - _failure_marker.size - Vector2(8, 8))

func _focus_style(padding := 12.0) -> StyleBoxFlat:
	var style := _control_style(Color(0, 0, 0, 0), padding)
	style.border_color = TERRACOTTA
	style.set_border_width_all(2)
	return style

extends Control
class_name MirrorHUD

signal action_requested(action: String, value: Variant)
signal play_rect_changed(rect: Rect2)

const TOUCH := 48.0
const GAP := 12.0
const INK := Color("342b2a")
const IVORY := Color("f4ecdd")
const WARM := Color("b85f4b")
const ConstellationStyle := preload("res://core/constellation_style.gd")
var _state := {}
var _syncing := false
var _debug := false
var _last_play_rect := Rect2()
var _last_camera_rect := Rect2()
var _last_emitted_play_rect := Rect2()
var _bottom_reserved := TOUCH + GAP
var _touch_controls := {}
var _outline_accessible := true
var _gear: Button
var _camera_left: Button
var _camera_right: Button
var _undo: Button
var _reset: Button
var _next: Button
var _cancel: Button
var _enabled: Button
var _flip: Button
var _apply: Button
var _mode_cycle: Button
var _debug_panel: PanelContainer
var _level_picker: OptionButton
var _failure: Label
var _hint: Label
var _hold: Control
var _edit_border: Control
var _debug_controls := {}
var _guide_sliders := {}
var _guide_value_labels := {}
var _guide_preview: CheckButton
var _guide_defaults: Button
var _panel_width: SpinBox
var _panel_height: SpinBox
var _angle_snap: SpinBox
var _debug_status: Label
var _hint_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_responsive_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree(): _responsive_layout()

func configure_levels(titles: Array[String], selected: int) -> void:
	_syncing = true
	_level_picker.clear()
	for title in titles: _level_picker.add_item(title)
	if not titles.is_empty(): _level_picker.select(clampi(selected, 0, titles.size() - 1))
	_syncing = false

func display_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	_outline_accessible = bool(_state.get("outline_accessible", _outline_accessible))
	var editing := bool(_state.get("editing", false))
	var phase := str(_state.get("phase", "play"))
	var mirror_busy := bool(_state.get("mirror_busy", false))
	var mode_busy := bool(_state.get("mode_busy", false))
	var camera_busy := bool(_state.get("camera_busy", false))
	var enabled := bool(_state.get("enabled", false))
	_camera_left.visible = _desktop()
	_camera_right.visible = _desktop()
	_camera_left.disabled = camera_busy or mirror_busy
	_camera_right.disabled = camera_busy or mirror_busy
	_undo.visible = not editing and bool(_state.get("can_undo", false))
	_undo.disabled = not bool(_state.get("can_undo", false))
	_reset.visible = phase == "failure"
	_next.visible = phase == "complete" and bool(_state.get("can_advance", false))
	_cancel.visible = editing
	_enabled.visible = editing
	_enabled.text = "Remove mirror" if enabled else "Keep mirror"
	_enabled.disabled = mirror_busy
	_flip.visible = editing
	_flip.disabled = mirror_busy
	_apply.visible = editing and (not _outline_accessible or not enabled)
	_apply.disabled = not bool(_state.get("can_apply", false))
	_mode_cycle.visible = editing
	_mode_cycle.disabled = mode_busy
	_update_mode_cycle()
	_edit_border.visible = editing
	_update_debug(editing, mirror_busy)
	_responsive_layout()

func set_guide_state(settings: Dictionary, preview_enabled: bool, preview_available: bool) -> void:
	_sync_guide_controls(settings, preview_enabled, preview_available)

func set_sheet_controls(_corners: PackedVector2Array, outline_accessible: bool) -> void:
	_outline_accessible = outline_accessible
	_apply.visible = bool(_state.get("editing", false)) and (not _outline_accessible or not bool(_state.get("enabled", false)))
	_responsive_layout()

func set_hold_progress(point: Vector2, progress: float) -> void:
	_hold.position = point - _hold.size * 0.5
	_hold.visible = progress >= 0.0
	_hold.set_meta("progress", clampf(progress, 0.0, 1.0))
	_hold.queue_redraw()

func show_hint(text: String) -> void:
	if is_instance_valid(_hint_tween): _hint_tween.kill()
	_hint.text = text
	_hint.modulate.a = 1.0
	_hint.visible = not text.is_empty()
	_responsive_layout()
	if _hint.visible:
		_hint_tween = create_tween()
		_hint_tween.tween_interval(2.4)
		_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.35)
		_hint_tween.tween_callback(func() -> void: _hint.visible = false; _hint.modulate.a = 1.0)

func get_play_rect() -> Rect2: return _last_play_rect
func is_debug_visible() -> bool: return _debug
func get_camera_rect() -> Rect2:
	return Rect2(_last_play_rect.position + Vector2(GAP, TOUCH + GAP), _last_play_rect.size - Vector2(GAP * 2, _bottom_reserved + TOUCH + GAP))
func set_failure_marker(_point: Vector2, _active: bool) -> void:
	_failure.visible = false
func get_touch_control_bounds() -> Dictionary:
	var result := {}
	for key: String in _touch_controls:
		var control := _touch_controls[key] as Control
		if control.is_visible_in_tree(): result[key] = control.get_global_rect()
	return result
func blocks_world_input(point: Vector2) -> bool:
	for control: Control in _touch_controls.values():
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return _debug_panel.visible and _debug_panel.get_global_rect().has_point(point)

func _build() -> void:
	_failure = _label("↓ No landing", 16); _failure.visible = false; add_child(_failure)
	_failure.add_theme_color_override("font_color", Color("f0b86e"))
	_failure.add_theme_color_override("font_outline_color", Color("162126"))
	_failure.add_theme_constant_override("outline_size", 4)
	_edit_border = Control.new(); _edit_border.mouse_filter = MOUSE_FILTER_IGNORE; _edit_border.set_anchors_and_offsets_preset(PRESET_FULL_RECT); _edit_border.draw.connect(func() -> void: _edit_border.draw_rect(_last_play_rect, Color(WARM, .45), false, 1.5)); _edit_border.visible = false; add_child(_edit_border)
	_hold = Control.new(); _hold.size = Vector2(52, 52); _hold.mouse_filter = MOUSE_FILTER_IGNORE; _hold.visible = false; _hold.draw.connect(_draw_hold); add_child(_hold)
	_hint = _label("", 14); _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _hint.mouse_filter = MOUSE_FILTER_IGNORE; _hint.visible = false; _hint.add_theme_stylebox_override("normal", _box(Color(IVORY, .92))); add_child(_hint)
	_gear = _button("⚙"); _style_icon(_gear); _gear.tooltip_text = "Debug controls"; _gear.pressed.connect(_toggle_debug); add_child(_gear); _register("debug", _gear)
	_camera_left = _add_action("↶", "camera_turn", -1, "camera_left"); _style_icon(_camera_left); _camera_left.modulate.a = .72
	_camera_right = _add_action("↷", "camera_turn", 1, "camera_right"); _style_icon(_camera_right); _camera_right.modulate.a = .72
	_undo = _add_action("Undo", "undo", null, "undo")
	_reset = _add_action("Reset", "reset", null, "reset")
	_next = _add_action("Next", "next_level", null, "next_level")
	_cancel = _add_action("Cancel", "cancel", null, "cancel")
	_enabled = _button("Keep mirror"); _enabled.pressed.connect(func() -> void: _emit("enabled", not bool(_state.get("enabled", true)))); add_child(_enabled); _register("enabled", _enabled)
	_flip = _add_action("Reverse sides", "flip", null, "flip")
	_apply = _add_action("Confirm", "apply", null, "apply")
	_mode_cycle = _button("")
	_mode_cycle.visible = false
	_mode_cycle.tooltip_text = "Change edit mode"
	_mode_cycle.draw.connect(_draw_mode_icon)
	_mode_cycle.pressed.connect(func() -> void: _emit("mode_cycle", null))
	add_child(_mode_cycle)
	_register("mode_cycle", _mode_cycle)
	for control: Button in [_cancel, _enabled, _flip, _apply, _undo, _reset, _next]: _style_edit(control)
	_build_debug()

func _add_action(text_value: String, action: String, value: Variant, key: String) -> Button:
	var button := _button(text_value); button.pressed.connect(func() -> void: _emit(action, value)); add_child(button); _register(key, button); return button

func _build_debug() -> void:
	_debug_panel = PanelContainer.new(); _debug_panel.visible = false; _debug_panel.mouse_filter = MOUSE_FILTER_STOP; _debug_panel.add_theme_stylebox_override("panel", _box()); add_child(_debug_panel)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _debug_panel.add_child(scroll)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 6); scroll.add_child(box)
	var heading := _label("Constellation", 16); box.add_child(heading)
	_guide_preview = CheckButton.new(); _guide_preview.text = "Preview guides"; _style(_guide_preview)
	_guide_preview.toggled.connect(func(value: bool) -> void: _emit("guide_preview", value))
	box.add_child(_guide_preview)
	for key: String in ConstellationStyle.DEFAULTS: _guide_style_control(box, key)
	_guide_defaults = _button("Reset defaults"); _guide_defaults.pressed.connect(func() -> void: _emit("guide_defaults", null)); box.add_child(_guide_defaults)
	_panel_width = _size_control(box, "Width", "width")
	_panel_height = _size_control(box, "Height", "height")
	_angle_snap = SpinBox.new()
	_angle_snap.prefix = "Angle snap"
	_angle_snap.min_value = 0.0
	_angle_snap.max_value = 90.0
	_angle_snap.step = 5.0
	_angle_snap.value = 15.0
	_angle_snap.custom_minimum_size.y = TOUCH
	_angle_snap.value_changed.connect(func(value: float) -> void:
		_set_angle_snap_display(value)
		_emit("angle_snap", value)
	)
	box.add_child(_angle_snap)
	_level_picker = OptionButton.new(); _style(_level_picker); _level_picker.item_selected.connect(func(value: int) -> void: _emit("select_level", value)); box.add_child(_level_picker); _register("level_picker", _level_picker)
	for item in [["Edit/Create", "edit", null], ["Offset −", "step", -0.5], ["Offset +", "step", 0.5], ["Raise", "height_step", 0.5], ["Lower", "height_step", -0.5], ["Axis 1", "axis", 0], ["Axis 2", "axis", 1], ["Axis 3", "axis", 2], ["Turn left", "turn", -1], ["Turn right", "turn", 1], ["Tilt", "tilt", null], ["Reverse sides", "flip", null], ["Reset", "reset", null]]:
		var button := _button(str(item[0])); button.pressed.connect(func() -> void: _emit(str(item[1]), item[2])); box.add_child(button); _debug_controls[str(item[1]) + str(item[0])] = button
	for spec in [["Collision", "collision"], ["Standing only", "standing_only"]]:
		var check := CheckButton.new(); check.text = spec[0]; _style(check); check.toggled.connect(func(value: bool) -> void: _emit(spec[1], value)); box.add_child(check); _debug_controls[spec[1]] = check
	var picker := OptionButton.new(); picker.add_item("World atmosphere", 0); picker.add_item("Boundary only", 1); _style(picker); picker.item_selected.connect(func(value: int) -> void: _emit("style", value)); box.add_child(picker); _debug_controls["style"] = picker
	_debug_status = _label("", 13); _debug_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(_debug_status)

func _guide_style_control(parent: VBoxContainer, key: String) -> void:
	var label := _label(str(ConstellationStyle.LABELS[key]), 14)
	parent.add_child(label)
	var row := HBoxContainer.new()
	var slider := HSlider.new()
	var limits: Vector3 = ConstellationStyle.LIMITS[key]
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = limits.z
	slider.value = float(ConstellationStyle.DEFAULTS[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = TOUCH
	var value_label := _label("", 14)
	value_label.custom_minimum_size = Vector2(52, TOUCH)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float) -> void:
		_set_guide_value_label(key, value)
		_emit("guide_style", {"key": key, "value": value})
	)
	row.add_child(slider)
	row.add_child(value_label)
	parent.add_child(row)
	_guide_sliders[key] = slider
	_guide_value_labels[key] = value_label
	_set_guide_value_label(key, slider.value)

func _size_control(parent: VBoxContainer, label: String, key: String) -> SpinBox:
	var control := SpinBox.new()
	control.prefix = label
	control.min_value = 1.0
	control.max_value = 6.0
	control.step = 1.0
	control.value = 3.0
	control.custom_minimum_size.y = TOUCH
	control.value_changed.connect(func(value: float) -> void: _emit(key, value))
	parent.add_child(control)
	return control

func _update_debug(editing: bool, mirror_busy: bool) -> void:
	for spec: Array in [[_panel_width, "width"], [_panel_height, "height"]]:
		var control := spec[0] as SpinBox
		control.visible = true
		control.editable = editing and not mirror_busy and bool(_state.get("enabled", false))
		control.set_value_no_signal(float(_state.get(spec[1], 3.0)))
	var angle_snap := clampf(float(_state.get("angle_snap", 15.0)), 0.0, 90.0)
	_angle_snap.set_value_no_signal(snappedf(angle_snap, 5.0))
	_angle_snap.editable = not mirror_busy
	_set_angle_snap_display(_angle_snap.value)
	_sync_guide_controls(_state.get("guide_style", {}), bool(_state.get("guide_preview", false)), bool(_state.get("guide_preview_available", false)))
	if _level_picker.item_count > 0: _level_picker.select(clampi(int(_state.get("level_index", 0)), 0, _level_picker.item_count - 1))
	(_debug_controls["collision"] as CheckButton).set_pressed_no_signal(bool(_state.get("collision", false)))
	(_debug_controls["standing_only"] as CheckButton).set_pressed_no_signal(bool(_state.get("standing_only", false)))
	(_debug_controls["style"] as OptionButton).select(clampi(int(_state.get("style", 0)), 0, 1))
	_debug_status.text = "%s\nOffset %.1f" % [str(_state.get("status", "")), float(_state.get("offset", 0.0))]
	for control: Control in _debug_controls.values(): control.disabled = editing and mirror_busy

func _set_angle_snap_display(value: float) -> void:
	_angle_snap.suffix = "° (No snap)" if is_zero_approx(value) else "°"

func _set_guide_value_label(key: String, value: float) -> void:
	(_guide_value_labels[key] as Label).text = "%.2f" % value

func _sync_guide_controls(settings: Dictionary, preview_enabled: bool, preview_available: bool) -> void:
	var guide_style := ConstellationStyle.normalized(settings)
	for key: String in _guide_sliders:
		var slider := _guide_sliders[key] as HSlider
		slider.set_value_no_signal(float(guide_style[key]))
		slider.editable = true
		_set_guide_value_label(key, slider.value)
	_guide_preview.set_pressed_no_signal(preview_enabled)
	_guide_preview.disabled = not preview_available
	_guide_defaults.disabled = false

func _toggle_debug() -> void:
	_debug = not _debug
	_debug_panel.visible = _debug
	_emit("debug_visibility", _debug)
	_responsive_layout()

func _responsive_layout() -> void:
	if not is_instance_valid(_gear): return
	var safe := _safe_rect(); _last_play_rect = safe.grow(-GAP)
	_edit_border.queue_redraw()
	_gear.size = Vector2(TOUCH, TOUCH)
	_camera_left.size = Vector2(TOUCH, TOUCH)
	_camera_right.size = Vector2(TOUCH, TOUCH)
	_gear.position = Vector2(safe.end.x - TOUCH - GAP, safe.position.y + GAP)
	_camera_left.position = safe.position + Vector2(GAP, safe.size.y - TOUCH - GAP); _camera_right.position = _camera_left.position + Vector2(TOUCH + 6, 0)
	var right := Vector2(safe.end.x - GAP, safe.end.y - TOUCH - GAP)
	for control: Control in [_undo, _reset, _next]:
		control.size = control.get_combined_minimum_size()
		if control.visible:
			control.position = right - Vector2(control.size.x, 0)
			right.x -= control.size.x + 6.0
	var row := [_cancel, _enabled, _flip, _apply]; var count := 0
	for control: Control in row:
		if control.visible: count += 1
	var row_gap := 6.0
	var columns: int = 2 if _last_play_rect.size.x < 420.0 and count > 2 else maxi(1, count)
	var rows: int = ceili(float(count) / float(columns))
	var slot: float = maxf(TOUCH, minf(140.0, (_last_play_rect.size.x - row_gap * (columns - 1)) / maxf(1.0, float(columns))))
	_bottom_reserved = TOUCH + GAP + (TOUCH * rows + row_gap * maxf(0.0, rows - 1) + GAP if count > 0 else 0.0)
	var start: float = _last_play_rect.get_center().x - (slot * columns + row_gap * (columns - 1)) * .5; var index := 0
	for control: Control in row:
		if control.visible:
			control.size = Vector2(slot, TOUCH)
			control.position = Vector2(start + (index % columns) * (slot + row_gap), safe.end.y - TOUCH * 2 - GAP * 2 - (index / columns) * (TOUCH + row_gap))
			index += 1
	_mode_cycle.size = Vector2(TOUCH, TOUCH)
	_mode_cycle.position = Vector2(safe.end.x - TOUCH - GAP, safe.end.y - TOUCH - GAP)
	var debug_height := minf(420.0, safe.size.y - GAP * 2.0)
	if safe.size.x < 600.0 and safe.size.y > safe.size.x: debug_height = minf(debug_height, minf(220.0, safe.size.y * 0.28))
	_debug_panel.position = safe.position + Vector2(GAP, GAP); _debug_panel.size = Vector2(minf(260.0, safe.size.x - GAP * 2.0), debug_height)
	_hint.size = Vector2(minf(360.0, safe.size.x - TOUCH - GAP * 3.0), TOUCH); _hint.position = Vector2(safe.position.x + GAP, safe.position.y + TOUCH + GAP * 2)
	var camera_rect := get_camera_rect()
	if not _last_play_rect.is_equal_approx(_last_emitted_play_rect) or not camera_rect.is_equal_approx(_last_camera_rect):
		_last_emitted_play_rect = _last_play_rect
		_last_camera_rect = camera_rect
		play_rect_changed.emit(_last_play_rect)

func _safe_rect() -> Rect2:
	var visible := get_viewport_rect()
	if _desktop(): return visible
	var area := DisplayServer.get_display_safe_area(); var window := DisplayServer.window_get_size()
	if area.size.x <= 0 or area.size.y <= 0 or window.x <= 0 or window.y <= 0: return visible
	var result := Rect2(Vector2(area.position) * visible.size / Vector2(window), Vector2(area.size) * visible.size / Vector2(window)).intersection(visible)
	return result if result.size.x > 0 and result.size.y > 0 else visible

func _draw_hold() -> void: _hold.draw_arc(_hold.size * .5, 20.0, -PI * .5, -PI * .5 + TAU * float(_hold.get_meta("progress", 0.0)), 24, WARM, 4.0)
func _update_mode_cycle() -> void:
	var mode := _edit_mode()
	var name := mode.capitalize()
	_mode_cycle.tooltip_text = "Edit mode: %s. Change mode." % name
	_mode_cycle.accessibility_name = "Edit mode: %s" % name
	_mode_cycle.queue_redraw()
func _edit_mode() -> String:
	var mode := str(_state.get("edit_mode", "move"))
	return mode if mode in ["move", "rotate", "resize"] else "move"
func _draw_mode_icon() -> void:
	if not is_instance_valid(_mode_cycle): return
	var center := _mode_cycle.size * 0.5
	var ink := INK if not _mode_cycle.disabled else Color(INK, 0.45)
	match _edit_mode():
		"move":
			_mode_cycle.draw_line(center - Vector2(11, 0), center + Vector2(11, 0), ink, 1.5, true)
			_mode_cycle.draw_line(center - Vector2(0, 11), center + Vector2(0, 11), ink, 1.5, true)
		"rotate":
			_mode_cycle.draw_arc(center, 11.0, 0.0, TAU, 48, ink, 1.5, true)
		"resize":
			_mode_cycle.draw_rect(Rect2(center - Vector2(10, 10), Vector2(20, 20)), ink, false, 1.5, true)
func _button(text_value: String) -> Button:
	var button := Button.new(); button.text = text_value; button.custom_minimum_size = Vector2(TOUCH, TOUCH); _style(button); return button
func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new(); label.text = text_value; label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", INK); label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; return label
func _style(control: Control) -> void:
	control.add_theme_color_override("font_color", INK); control.add_theme_stylebox_override("normal", _box()); control.add_theme_stylebox_override("hover", _box(Color("eadcc8"))); control.add_theme_stylebox_override("pressed", _box(WARM)); control.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, 2)); control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, TOUCH)
func _style_icon(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_stylebox_override("normal", _box(Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("hover", _box(Color("342b2a66"), 0))
	button.add_theme_stylebox_override("pressed", _box(Color("342b2a99"), 0))
func _style_edit(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("fff4df"))
	button.add_theme_stylebox_override("normal", _box(Color("342b2ad9"), 1))
	button.add_theme_stylebox_override("hover", _box(Color("4b3a38e6"), 1))
	button.add_theme_stylebox_override("pressed", _box(WARM, 1))
func _box(color := IVORY, border := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = color; style.border_color = WARM if border == 2 else Color("cdbca5"); style.set_border_width_all(border); style.corner_radius_top_left = 10; style.corner_radius_top_right = 10; style.corner_radius_bottom_left = 10; style.corner_radius_bottom_right = 10; style.content_margin_left = 12; style.content_margin_right = 12; return style
func _register(key: String, control: Control) -> void: _touch_controls[key] = control
func _emit(action: String, value: Variant = null) -> void:
	if not _syncing: action_requested.emit(action, value)
func _desktop() -> bool: return OS.get_name() not in ["iOS", "Android"]

func get_blocking_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for bounds: Rect2 in get_touch_control_bounds().values():
		result.append(bounds)
	if _debug_panel.visible:
		result.append(_debug_panel.get_global_rect())
	return result

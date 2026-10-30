extends Control
class_name MirrorHUD

signal action_requested(action: String, value: Variant)
signal play_rect_changed(rect: Rect2)

const TOUCH := UiStyle.TOUCH
## The mirror button is the game's main action, so it is a size up.
const PRIMARY := UiStyle.PRIMARY
const GAP := UiStyle.GAP
## Below this play height, a wide screen frames the stage between side columns.
const SHORT_LANDSCAPE := 560.0
## The resting alpha of the quiet controls (settings, turn the view) until a
## pointer wakes them.
const FAINT := 0.5
## How long a stage's name stays written on the world.
const STAGE_TITLE_HOLD := 2.2
const ConstellationStyle := preload("res://core/constellation_style.gd")
const SafeArea := preload("res://core/safe_area.gd")
const UI_CLICK := preload("res://assets/audio/ui.wav")
var _state := {}
var _syncing := false
var _debug := false
## Set once, before this control enters the tree (`game.gd` sets it right
## before `add_child(hud)`). Swaps the gear's panel from debug controls to
## player settings, and hides the Reset button.
var release_mode := false
var _last_play_rect := Rect2()
var _last_camera_rect := Rect2()
var _last_emitted_play_rect := Rect2()
var _bottom_reserved := TOUCH + GAP
## On a short landscape screen, the width kept clear on each side of the stage.
var _side_reserved := 0.0
var _touch_controls := {}
var _outline_accessible := true
var _gear: Button
var _camera_left: Button
var _camera_right: Button
var _undo: Button
var _reset: Button
var _cancel: Button
var _enabled: Button
var _flip: Button
var _apply: Button
var _mode_cycle: Button
## Direct controls only: raises and lowers the mirror. It takes the corner the
## classic mode button uses; the two never show together.
var _mirror_button: Button
var _classic_check: CheckButton
var _debug_panel: PanelContainer
var _settings_panel: PanelContainer
var _settings_box: VBoxContainer
## True between `show_prompt` and `hide_prompt`. The card hides while a panel
## is open and comes back when the panel closes.
var _prompt_wanted := false
var _music_slider: HSlider
var _effects_slider: HSlider
var _fullscreen_check: CheckButton
var _title_button: Button
var _restart_button: Button
var _new_game_button: Button
## The stage's name, written on the world as it arrives.
var _stage_title: Label
var _stage_title_tween: Tween
var _level_picker: OptionButton
var _failure: Label
var _hint: Label
var _prompt: Label
var _prompt_tween: Tween
var _help: Button
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
## Plays a click for every button `_button` creates. One player, one wire-up
## point, instead of a play call in each button's own press handler.
var _click_player: AudioStreamPlayer

func _ready() -> void:
	theme = UiStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_responsive_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree(): _responsive_layout()

func configure_levels(titles: Array[String], selected: int) -> void:
	if not is_instance_valid(_level_picker):
		return
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
	var direct := bool(_state.get("direct", false))
	var classic_editing := editing and not direct
	Motion.fade(_help, bool(_state.get("has_prompts", false)))
	_camera_left.visible = _desktop()
	_camera_right.visible = _desktop()
	_camera_left.disabled = camera_busy or mirror_busy
	_camera_right.disabled = camera_busy or mirror_busy
	# A direct drag is a short preview: Undo stays in place through it, so the
	# corner does not flicker on every drag.
	Motion.fade(_undo, (direct or not editing) and bool(_state.get("can_undo", false)))
	_undo.disabled = not bool(_state.get("can_undo", false)) or (direct and editing)
	_reset.visible = phase == "failure" and not release_mode
	_cancel.visible = classic_editing
	_enabled.visible = classic_editing
	_enabled.text = "Remove mirror" if enabled else "Keep mirror"
	_enabled.disabled = mirror_busy
	_flip.visible = classic_editing
	_flip.disabled = mirror_busy
	_apply.visible = classic_editing and (not _outline_accessible or not enabled)
	_apply.disabled = not bool(_state.get("can_apply", false))
	_mode_cycle.visible = classic_editing
	_mode_cycle.disabled = mode_busy
	_update_mode_cycle()
	# The mirror button waits out the sweep between stages.
	Motion.fade(_mirror_button, direct and bool(_state.get("mirror_available", true)) and phase != "transition")
	_mirror_button.disabled = not bool(_state.get("can_toggle_mirror", false))
	var raised := bool(_state.get("mirror_raised", false))
	_mirror_button.set_meta("icon", "mirror_raised" if raised else "mirror")
	_mirror_button.tooltip_text = "Lower the mirror (M)" if raised else "Raise the mirror (M)"
	_mirror_button.accessibility_name = "Lower the mirror" if raised else "Raise the mirror"
	_mirror_button.queue_redraw()
	_edit_border.visible = classic_editing
	if not release_mode:
		_update_debug(editing, mirror_busy)
	_responsive_layout()

func set_guide_state(settings: Dictionary, preview_enabled: bool, preview_available: bool) -> void:
	# The guide controls are dev tools and exist only in the debug panel.
	if not release_mode:
		_sync_guide_controls(settings, preview_enabled, preview_available)

func set_sheet_controls(_corners: PackedVector2Array, outline_accessible: bool) -> void:
	_outline_accessible = outline_accessible
	_apply.visible = bool(_state.get("editing", false)) and not bool(_state.get("direct", false)) and (not _outline_accessible or not bool(_state.get("enabled", false)))
	_responsive_layout()

func set_hold_progress(point: Vector2, progress: float) -> void:
	_hold.position = point - _hold.size * 0.5
	_hold.visible = progress >= 0.0
	_hold.set_meta("progress", clampf(progress, 0.0, 1.0))
	_hold.queue_redraw()

func show_hint(text: String) -> void:
	# A hint is transient chatter; an active prompt is the current lesson, so
	# a hint that would land on top of it is dropped rather than queued.
	if _prompt.visible:
		return
	if is_instance_valid(_hint_tween): _hint_tween.kill()
	if text.is_empty():
		_hint.visible = false
		return
	_hint.text = text
	_responsive_layout()
	Motion.fade(_hint, true)
	_hint_tween = create_tween()
	_hint_tween.tween_interval(Motion.duration("appear") + 2.4)
	_hint_tween.tween_callback(func() -> void: Motion.fade(_hint, false))

## The stage's name, written on the world in chapter type: it appears, holds,
## and leaves.
func show_stage_title(text: String) -> void:
	if is_instance_valid(_stage_title_tween): _stage_title_tween.kill()
	_stage_title.text = text
	_responsive_layout()
	Motion.fade(_stage_title, true)
	_stage_title_tween = create_tween()
	_stage_title_tween.tween_interval(Motion.duration("appear") + STAGE_TITLE_HOLD)
	_stage_title_tween.tween_callback(func() -> void: Motion.fade(_stage_title, false))

## The tutorial prompt card. It stays until `hide_prompt`, unlike the transient
## hint above, and takes the hint's screen slot: hiding any hint in progress
## avoids the two overlapping.
func show_prompt(text: String) -> void:
	if is_instance_valid(_hint_tween): _hint_tween.kill()
	_hint.visible = false
	_prompt.text = text
	_prompt_wanted = not text.is_empty()
	# An empty prompt card must never show, and an open panel covers its slot.
	_prompt.visible = _prompt_wanted and not _debug
	if is_instance_valid(_prompt_tween): _prompt_tween.kill()
	if _prompt.visible:
		_prompt_tween = Motion.tween(_prompt, "modulate:a", 1.0, "appear")
	_responsive_layout()

func hide_prompt() -> void:
	_prompt_wanted = false
	if not _prompt.visible:
		return
	if is_instance_valid(_prompt_tween): _prompt_tween.kill()
	_prompt_tween = Motion.tween(_prompt, "modulate:a", 0.0, "dismiss")
	_prompt_tween.tween_callback(func() -> void: _prompt.visible = false)

func get_play_rect() -> Rect2: return _last_play_rect
func is_debug_visible() -> bool: return _debug
func get_camera_rect() -> Rect2:
	if _side_reserved > 0.0:
		return _last_play_rect.grow_individual(-_side_reserved, -GAP, -_side_reserved, -GAP)
	# A narrow portrait screen has controls only in its corners: the stage may
	# use the whole width.
	var side := 0.0 if _last_play_rect.size.x < 500.0 else GAP
	return Rect2(_last_play_rect.position + Vector2(side, TOUCH + GAP), _last_play_rect.size - Vector2(side * 2, _bottom_reserved + TOUCH + GAP))
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
	var panel := _active_panel()
	return is_instance_valid(panel) and panel.visible and panel.get_global_rect().has_point(point)

## The one gear-toggled panel that exists for this HUD: debug controls
## normally, player settings in `release_mode`. Only one is ever built.
func _active_panel() -> PanelContainer:
	return _settings_panel if release_mode else _debug_panel

func _build() -> void:
	_click_player = AudioStreamPlayer.new(); _click_player.stream = UI_CLICK; _click_player.bus = "Effects"; add_child(_click_player)
	_failure = _label("↓ No landing", 16); _failure.visible = false; add_child(_failure)
	_edit_border = Control.new(); _edit_border.mouse_filter = MOUSE_FILTER_IGNORE; _edit_border.set_anchors_and_offsets_preset(PRESET_FULL_RECT); _edit_border.draw.connect(func() -> void: _edit_border.draw_rect(_last_play_rect, Color(UiStyle.EMBER, .45), false, 1.5)); _edit_border.visible = false; add_child(_edit_border)
	_hold = Control.new(); _hold.size = Vector2(52, 52); _hold.mouse_filter = MOUSE_FILTER_IGNORE; _hold.visible = false; _hold.draw.connect(_draw_hold); add_child(_hold)
	_stage_title = UiStyle.label("", "chapter"); _stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _stage_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage_title.mouse_filter = MOUSE_FILTER_IGNORE; _stage_title.visible = false; add_child(_stage_title)
	# The hint and the prompt card: the one frost surface, in the one typeface.
	_hint = UiStyle.label("", "small"); _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _hint.mouse_filter = MOUSE_FILTER_IGNORE; _hint.visible = false
	_hint.add_theme_stylebox_override("normal", UiStyle.frost(0.86)); add_child(_hint)
	_prompt = UiStyle.label("", "body"); _prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; _prompt.vertical_alignment = VERTICAL_ALIGNMENT_TOP; _prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _prompt.mouse_filter = MOUSE_FILTER_IGNORE; _prompt.visible = false; _prompt.modulate.a = 0.0
	var prompt_box := UiStyle.frost(0.9); prompt_box.content_margin_top = 12; prompt_box.content_margin_bottom = 12
	_prompt.add_theme_stylebox_override("normal", prompt_box); add_child(_prompt)
	_gear = _icon_button("settings", "Settings" if release_mode else "Debug controls", "debug"); _gear.pressed.connect(_toggle_debug); _rest_faint(_gear)
	_help = _icon_button("help", "Show this stage's prompts again", "help"); _help.visible = false
	_help.pressed.connect(func() -> void: _emit("help", null))
	_camera_left = _icon_button("turn_left", "Turn left (Q)", "camera_left"); _camera_left.pressed.connect(func() -> void: _emit("camera_turn", -1))
	_camera_right = _icon_button("turn_right", "Turn right (E)", "camera_right"); _camera_right.pressed.connect(func() -> void: _emit("camera_turn", 1))
	for camera_button: Button in [_camera_left, _camera_right]:
		camera_button.accessibility_name = camera_button.tooltip_text.get_slice(" (", 0)
		_rest_faint(camera_button)
	_undo = _icon_button("undo", "Undo (Z)", "undo"); _undo.visible = false; _undo.accessibility_name = "Undo"
	_undo.pressed.connect(func() -> void: _emit("undo", null))
	_reset = _add_action("Reset", "reset", null, "reset")
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
	_mirror_button = _icon_button("mirror", "Raise the mirror (M)", "mirror", true)
	_mirror_button.visible = false
	# It is briefly disabled during every drag; it must not flicker then.
	_mirror_button.set_meta("steady", true)
	_mirror_button.add_theme_stylebox_override("disabled", UiStyle.theme().get_stylebox("normal", "PrimaryButton"))
	_mirror_button.pressed.connect(func() -> void: _emit("mirror_toggle", null))
	if release_mode:
		_build_settings()
	else:
		_build_debug()
	# The hint and the prompt card carry the tutorial's own guidance and
	# should never sit behind the gear's panel, which is wider and taller.
	move_child(_hint, get_child_count() - 1)
	move_child(_prompt, get_child_count() - 1)

## A round icon button from the style's icon set, registered as a touch control.
func _icon_button(icon: String, tooltip: String, key: String, primary := false) -> Button:
	var button := UiIcons.button(icon, tooltip, primary)
	button.pressed.connect(_play_click)
	add_child(button)
	_register(key, button)
	return button

## A quiet control rests faint and wakes while a pointer is over it.
func _rest_faint(button: Button) -> void:
	button.modulate.a = FAINT
	button.mouse_entered.connect(func() -> void: Motion.tween(button, "modulate:a", 1.0, "appear"))
	button.mouse_exited.connect(func() -> void:
		if not (button == _gear and _debug):
			Motion.tween(button, "modulate:a", FAINT, "dismiss"))

func _add_action(text_value: String, action: String, value: Variant, key: String) -> Button:
	var button := _button(text_value); button.pressed.connect(func() -> void: _emit(action, value)); add_child(button); _register(key, button); return button

## The gear's panel for a shipped build: audio and display settings, then
## the few ways to start over. No level picker, no guide sliders, no other
## debug control — those exist only in `_build_debug`. Words stay here only.
func _build_settings() -> void:
	_settings_panel = PanelContainer.new(); _settings_panel.visible = false; _settings_panel.mouse_filter = MOUSE_FILTER_STOP; add_child(_settings_panel)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _settings_panel.add_child(scroll)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 6); box.size_flags_horizontal = SIZE_EXPAND_FILL; scroll.add_child(box)
	_settings_box = box
	_music_slider = _settings_slider(box, "Music"); _music_slider.value_changed.connect(func(value: float) -> void: _emit("music_volume", value))
	_effects_slider = _settings_slider(box, "Effects"); _effects_slider.value_changed.connect(func(value: float) -> void: _emit("effects_volume", value))
	if _desktop():
		_fullscreen_check = CheckButton.new(); _fullscreen_check.text = "Fullscreen"; _fullscreen_check.focus_mode = FOCUS_NONE
		_fullscreen_check.custom_minimum_size.y = TOUCH
		_fullscreen_check.toggled.connect(func(value: bool) -> void: _emit("fullscreen", value))
		box.add_child(_fullscreen_check)
	var gap := Control.new(); gap.custom_minimum_size.y = 4; box.add_child(gap)
	# Undo walks back one step; this goes back to the stage's start at once.
	_restart_button = _settings_row(box, "restart", "Restart stage", "reset")
	_new_game_button = _settings_row(box, "again", "Start again", "new_game")
	_title_button = _settings_row(box, "title", "Return to title", "title")

## One icon-and-word row of the settings panel: it closes the panel, then acts.
func _settings_row(parent: VBoxContainer, icon: String, text: String, action: String) -> Button:
	var row := UiIcons.row(icon, text)
	row.pressed.connect(_play_click)
	row.pressed.connect(func() -> void:
		if _debug:
			_toggle_debug()
		_emit(action, null))
	parent.add_child(row)
	return row

## A named slider on one line, so the panel fits a phone on its side.
func _settings_slider(parent: VBoxContainer, label_text: String) -> HSlider:
	var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 12); parent.add_child(line)
	var name := UiStyle.label(label_text, "small"); name.custom_minimum_size.x = 64; line.add_child(name)
	var slider := HSlider.new(); slider.size_flags_horizontal = SIZE_EXPAND_FILL; slider.size_flags_vertical = SIZE_SHRINK_CENTER
	slider.min_value = 0.0; slider.max_value = 1.0; slider.step = 0.05; slider.value = 0.8
	slider.custom_minimum_size.y = 40
	slider.focus_mode = FOCUS_NONE
	line.add_child(slider)
	return slider

## Seeds the settings panel from the saved values, without emitting actions.
func set_settings_state(music_volume: float, effects_volume: float, fullscreen: bool) -> void:
	if is_instance_valid(_music_slider): _music_slider.set_value_no_signal(music_volume)
	if is_instance_valid(_effects_slider): _effects_slider.set_value_no_signal(effects_volume)
	if is_instance_valid(_fullscreen_check): _fullscreen_check.set_pressed_no_signal(fullscreen)

func _build_debug() -> void:
	_debug_panel = PanelContainer.new(); _debug_panel.visible = false; _debug_panel.mouse_filter = MOUSE_FILTER_STOP; add_child(_debug_panel)
	# Dev tools only: a smaller type keeps the many controls in a narrow panel.
	var dev_theme := Theme.new(); dev_theme.default_font_size = 14; _debug_panel.theme = dev_theme
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _debug_panel.add_child(scroll)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 6); scroll.add_child(box)
	# Compares the direct controls with the earlier Move/Rotate/Resize editor.
	_classic_check = CheckButton.new(); _classic_check.text = "Classic editor"; _style(_classic_check)
	_classic_check.toggled.connect(func(value: bool) -> void: _emit("classic_controls", value))
	box.add_child(_classic_check)
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
	_classic_check.set_pressed_no_signal(not bool(_state.get("direct", false)))
	_classic_check.disabled = mirror_busy
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
	Motion.fade(_active_panel(), _debug)
	if _debug:
		if is_instance_valid(_hint_tween): _hint_tween.kill()
		Motion.fade(_hint, false)
	Motion.tween(_gear, "modulate:a", 1.0 if _debug else FAINT, "appear" if _debug else "dismiss")
	_prompt.visible = _prompt_wanted and not _debug
	_prompt.modulate.a = 1.0
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
	_help.size = Vector2(TOUCH, TOUCH)
	_help.position = Vector2(_gear.position.x - TOUCH - 6, _gear.position.y)
	_camera_left.position = safe.position + Vector2(GAP, safe.size.y - TOUCH - GAP); _camera_right.position = _camera_left.position + Vector2(TOUCH + 6, 0)
	var right := Vector2(safe.end.x - GAP, safe.end.y - TOUCH - GAP)
	_mirror_button.size = Vector2(PRIMARY, PRIMARY)
	_mirror_button.position = Vector2(safe.end.x - PRIMARY - GAP, safe.end.y - PRIMARY - GAP)
	if _mirror_button.visible:
		right.x -= PRIMARY + 6.0
	for control: Control in [_undo, _reset]:
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
	_bottom_reserved = (PRIMARY if _mirror_button.visible else TOUCH) + GAP + (TOUCH * rows + row_gap * maxf(0.0, rows - 1) + GAP if count > 0 else 0.0)
	# A phone on its side keeps every control in a corner, so the stage takes
	# the full height between two equal side columns. Undo counts while it is
	# hidden, so its first appearance does not move the view.
	_side_reserved = 0.0
	if count == 0 and _last_play_rect.size.y < SHORT_LANDSCAPE and _last_play_rect.size.x > _last_play_rect.size.y * 1.3:
		var left := TOUCH * 2.0 + 6.0 + GAP if _camera_left.visible else 0.0
		var right_bottom := (PRIMARY + 6.0 if _mirror_button.visible else 0.0) + _shown_width(_undo) + GAP
		var right_top := TOUCH * 2.0 + 6.0 + GAP
		_side_reserved = maxf(left, maxf(right_bottom, right_top)) + GAP
	var start: float = _last_play_rect.get_center().x - (slot * columns + row_gap * (columns - 1)) * .5; var index := 0
	for control: Control in row:
		if control.visible:
			control.size = Vector2(slot, TOUCH)
			control.position = Vector2(start + (index % columns) * (slot + row_gap), safe.end.y - TOUCH * 2 - GAP * 2 - (index / columns) * (TOUCH + row_gap))
			index += 1
	_mode_cycle.size = Vector2(TOUCH, TOUCH)
	_mode_cycle.position = Vector2(safe.end.x - TOUCH - GAP, safe.end.y - TOUCH - GAP)
	var debug_height := minf(420.0, safe.size.y - GAP * 2.0)
	# The small portrait cap keeps the dev panel clear of the stage. Release
	# settings are few, so they use the full safe height.
	if not release_mode and safe.size.x < 600.0 and safe.size.y > safe.size.x: debug_height = minf(debug_height, minf(220.0, safe.size.y * 0.28))
	var panel := _active_panel()
	if is_instance_valid(panel):
		var panel_width := minf(260.0, safe.size.x - GAP * 2.0)
		var panel_height := debug_height
		if release_mode and is_instance_valid(_settings_box):
			# Content-sized, not the debug panel's fixed height: no empty
			# space below the last control, still capped and scrollable.
			panel_height = minf(debug_height, _settings_box.get_combined_minimum_size().y + panel.get_theme_stylebox("panel").get_minimum_size().y)
		panel.position = safe.position + Vector2(GAP, GAP)
		panel.size = Vector2(panel_width, panel_height)
	var card_width := minf(380.0, safe.size.x - TOUCH - GAP * 3.0)
	_hint.size = Vector2(card_width, _card_height(_hint, card_width)); _hint.position = Vector2(safe.position.x + GAP, safe.position.y + TOUCH + GAP * 2)
	_prompt.size = Vector2(card_width, _card_height(_prompt, card_width))
	_prompt.position = Vector2(safe.position.x + GAP, safe.position.y + TOUCH + GAP * 2)
	var camera_rect := get_camera_rect()
	# The stage's name is written on the world, low in the middle, clear of
	# the prompt card at the top.
	var title_width := minf(camera_rect.size.x, 640.0)
	_stage_title.size = Vector2(title_width, _card_height(_stage_title, title_width))
	_stage_title.position = Vector2(camera_rect.get_center().x - title_width * 0.5, camera_rect.end.y - _stage_title.size.y - camera_rect.size.y * 0.04)
	if not _last_play_rect.is_equal_approx(_last_emitted_play_rect) or not camera_rect.is_equal_approx(_last_camera_rect):
		_last_emitted_play_rect = _last_play_rect
		_last_camera_rect = camera_rect
		play_rect_changed.emit(_last_play_rect)

## A text button's width once shown; a hidden button's minimum size is stale.
func _shown_width(button: Button) -> float:
	var font := button.get_theme_font("font")
	var text_width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
	return maxf(button.custom_minimum_size.x, text_width + button.get_theme_stylebox("normal").get_minimum_size().x)

func _safe_rect() -> Rect2:
	return SafeArea.rect(self)

## A wrapping label's height at `width`, with its surface's margins.
func _card_height(label: Label, width: float) -> float:
	var box := label.get_theme_stylebox("normal")
	var margins := box.get_minimum_size() if box else Vector2.ZERO
	if label.text.is_empty():
		return TOUCH
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_size := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, maxf(10.0, width - margins.x), font_size)
	return maxf(TOUCH, text_size.y + margins.y)

func _draw_hold() -> void: _hold.draw_arc(_hold.size * .5, 20.0, -PI * .5, -PI * .5 + TAU * float(_hold.get_meta("progress", 0.0)), 24, UiStyle.LIGHT, 4.0)
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
	var ink := UiStyle.INK if not _mode_cycle.disabled else Color(UiStyle.INK, 0.45)
	match _edit_mode():
		"move":
			_mode_cycle.draw_line(center - Vector2(11, 0), center + Vector2(11, 0), ink, 1.5, true)
			_mode_cycle.draw_line(center - Vector2(0, 11), center + Vector2(0, 11), ink, 1.5, true)
		"rotate":
			_mode_cycle.draw_arc(center, 11.0, 0.0, TAU, 48, ink, 1.5, true)
		"resize":
			_mode_cycle.draw_rect(Rect2(center - Vector2(10, 10), Vector2(20, 20)), ink, false, 1.5, true)
func _button(text_value: String) -> Button:
	var button := Button.new(); button.text = text_value; button.custom_minimum_size = Vector2(TOUCH, TOUCH); _style(button)
	button.pressed.connect(_play_click)
	return button
func _play_click() -> void:
	if is_instance_valid(_click_player): _click_player.play()
func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new(); label.text = text_value; label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", UiStyle.INK); label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; return label
## Dev and classic-editor controls take the style's theme; this only keeps
## them at touch height.
func _style(control: Control) -> void:
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, TOUCH)
func _register(key: String, control: Control) -> void: _touch_controls[key] = control
func _emit(action: String, value: Variant = null) -> void:
	if not _syncing: action_requested.emit(action, value)
func _desktop() -> bool: return OS.get_name() not in ["iOS", "Android"]

func get_blocking_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for bounds: Rect2 in get_touch_control_bounds().values():
		result.append(bounds)
	var panel := _active_panel()
	if is_instance_valid(panel) and panel.visible:
		result.append(panel.get_global_rect())
	return result

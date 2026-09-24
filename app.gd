extends Node
class_name App
## The app shell around the game: the title screen, save and resume, the end
## card, and the switch between the dev panel and a player settings panel.
##
## `main.tscn`'s root carries this script. Tests can also build one directly
## with `App.new()`; set `progress_path` (and, if needed,
## `release_mode_override`) before `add_child`, the same way `game.gd` reads
## `start_stage` and `release_mode` before its own `_ready` runs.

const Game := preload("res://game.gd")
const TutorialProgress := preload("res://core/tutorial_progress.gd")
const SafeArea := preload("res://core/safe_area.gd")

const INK := Color("342b2a")
const IVORY := Color("f4ecdd")
const WARM := Color("b85f4b")
const END_CARD_DELAY := 1.5

## Overridable before `add_child`, so a test does not need a real save file.
var progress_path := TutorialProgress.DEFAULT_PATH
## Overridable before `add_child`, so a test does not need a release build or
## a real command line to see the release UI. Null keeps the real switch:
## `not OS.is_debug_build() or "--release-ui" in OS.get_cmdline_user_args()`.
var release_mode_override = null

var progress: TutorialProgress
var game: Game

var _title_layer: CanvasLayer
var _title_root: Control
var _title_veil: ColorRect
var _title_label: Label
var _primary_button: Button
var _new_game_button: Button

var _end_layer: CanvasLayer
var _end_root: Control
var _end_label: Label
var _play_again_button: Button
var _end_title_button: Button


func _ready() -> void:
	progress = TutorialProgress.new(progress_path)
	_apply_music_volume()
	_apply_effects_volume()
	_apply_fullscreen()
	game = Game.new()
	game.progress = progress
	game.release_mode = release_mode_override if release_mode_override != null \
		else (not OS.is_debug_build() or "--release-ui" in OS.get_cmdline_user_args())
	game.start_stage = clampi(progress.stage, 0, Game.PUZZLE_PATHS.size() - 1)
	add_child(game)
	game.stage_reached.connect(_on_stage_reached)
	game.tutorial_finished.connect(_on_tutorial_finished)
	game.hud.action_requested.connect(_on_hud_action)
	game.hud.set_settings_state(progress.music_volume, progress.effects_volume, progress.fullscreen)
	_build_title()
	_build_end_card()
	_show_title()


func _apply_music_volume() -> void:
	_apply_bus_volume("Music", progress.music_volume)


func _apply_effects_volume() -> void:
	_apply_bus_volume("Effects", progress.effects_volume)


## Skips silently if the bus does not exist yet; the audio task adds it.
func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(linear))


func _apply_fullscreen() -> void:
	if OS.get_name() in ["iOS", "Android"]:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if progress.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_stage_reached(index: int) -> void:
	progress.set_stage(index)


func _on_tutorial_finished() -> void:
	await get_tree().create_timer(END_CARD_DELAY).timeout
	_set_game_active(false)
	_end_layer.visible = true
	_layout_end()


## `input_enabled` gates what the game reacts to; `set_overlay_visible` hides
## what it draws in 2D (the HUD, its prompt card, the rings, the guide). Both
## turn off together whenever an app overlay (the title, the end card) takes
## the screen, and both turn back on together when play resumes. The game
## also pauses, so a walk in progress cannot reach a goal behind the title.
func _set_game_active(active: bool) -> void:
	game.input_enabled = active
	game.set_overlay_visible(active)
	game.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _on_hud_action(action: String, value: Variant) -> void:
	match action:
		"music_volume":
			progress.set_music_volume(float(value))
			_apply_music_volume()
		"effects_volume":
			progress.set_effects_volume(float(value))
			_apply_effects_volume()
		"fullscreen":
			progress.set_fullscreen(bool(value))
			_apply_fullscreen()
		"title":
			if game.hud.is_debug_visible():
				game.hud._toggle_debug()
			_show_title()


## --- Title -------------------------------------------------------------

func _build_title() -> void:
	_title_layer = CanvasLayer.new(); _title_layer.layer = 10; add_child(_title_layer)
	_title_root = Control.new(); _title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _title_layer.add_child(_title_root)
	_title_veil = ColorRect.new(); _title_veil.color = Color(IVORY, 0.86); _title_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _title_root.add_child(_title_veil)
	_title_veil.gui_input.connect(_on_title_veil_input)
	_title_label = _title_text("Mirror", 48); _title_root.add_child(_title_label)
	_primary_button = _styled_button("Tap to begin"); _primary_button.pressed.connect(_on_primary_pressed); _title_root.add_child(_primary_button)
	_new_game_button = _styled_button("New game"); _new_game_button.pressed.connect(_on_new_game_pressed); _title_root.add_child(_new_game_button)
	_title_root.resized.connect(_layout_title)


func _show_title() -> void:
	var has_save := progress.stage > 0
	_primary_button.text = "Continue" if has_save else "Tap to begin"
	_new_game_button.visible = has_save
	_title_layer.visible = true
	_set_game_active(false)
	_layout_title()


func _hide_title() -> void:
	_title_layer.visible = false
	_set_game_active(true)


## Tapping empty title space begins the game exactly like the primary
## button, but only while there is no save to protect ("Tap to begin", not
## "Continue"): a returning player should not resume by an accidental tap.
func _on_title_veil_input(event: InputEvent) -> void:
	if progress.stage > 0:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		_on_primary_pressed()


func _on_primary_pressed() -> void:
	_hide_title()


func _on_new_game_pressed() -> void:
	progress.reset_progress()
	game.load_level(0)
	_hide_title()


## --- End card ------------------------------------------------------------

func _build_end_card() -> void:
	_end_layer = CanvasLayer.new(); _end_layer.layer = 10; _end_layer.visible = false; add_child(_end_layer)
	_end_root = Control.new(); _end_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _end_layer.add_child(_end_root)
	var veil := ColorRect.new(); veil.color = Color(IVORY, 0.86); veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _end_root.add_child(veil)
	_end_label = _title_text("The tutorial is complete.", 32); _end_root.add_child(_end_label)
	_play_again_button = _styled_button("Play again"); _play_again_button.pressed.connect(_on_play_again_pressed); _end_root.add_child(_play_again_button)
	_end_title_button = _styled_button("Title"); _end_title_button.pressed.connect(_on_end_title_pressed); _end_root.add_child(_end_title_button)
	_end_root.resized.connect(_layout_end)


func _on_play_again_pressed() -> void:
	progress.reset_progress()
	game.load_level(0)
	_end_layer.visible = false
	_set_game_active(true)


func _on_end_title_pressed() -> void:
	_end_layer.visible = false
	_show_title()


## --- Shared look and layout -----------------------------------------------

func _title_text(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _styled_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(200, 48)
	button.add_theme_color_override("font_color", Color("fff4df"))
	var normal := StyleBoxFlat.new(); normal.bg_color = Color("342b2ad9"); normal.border_color = Color("cdbca5")
	normal.set_border_width_all(1); normal.corner_radius_top_left = 10; normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10; normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 16; normal.content_margin_right = 16
	var hover := normal.duplicate() as StyleBoxFlat; hover.bg_color = Color("4b3a38e6")
	var pressed := normal.duplicate() as StyleBoxFlat; pressed.bg_color = WARM
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	return button


func _layout_title() -> void:
	_layout_overlay(_title_root, _title_label, [_primary_button, _new_game_button])


func _layout_end() -> void:
	_layout_overlay(_end_root, _end_label, [_play_again_button, _end_title_button])


## Centres a heading and stacks its buttons under it, clear of the window
## edges at every supported aspect ratio from a phone in portrait to a
## tablet in landscape.
func _layout_overlay(root_control: Control, label: Label, buttons: Array) -> void:
	if not is_instance_valid(root_control) or root_control.size.x < 10 or root_control.size.y < 10:
		return
	var safe := SafeArea.rect(root_control)
	label.position = Vector2(safe.position.x, safe.position.y + safe.size.y * 0.32)
	label.size = Vector2(safe.size.x, 60)
	var y := safe.position.y + safe.size.y * 0.32 + 90
	for button: Button in buttons:
		if not button.visible:
			continue
		button.position = Vector2(safe.position.x + (safe.size.x - button.custom_minimum_size.x) * 0.5, y)
		button.size = button.custom_minimum_size
		y += button.custom_minimum_size.y + 24

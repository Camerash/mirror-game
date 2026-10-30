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

const END_CARD_DELAY := 1.5
## How long the title waits before the small light shows where to tap.
const TITLE_HINT_DELAY := 1.8
## The title's slow sway about the stage: radians, and radians per second.
const TITLE_SWAY := 0.45
const TITLE_SWAY_SPEED := 0.15

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
var _title_label: Label
## A small light that breathes where to tap, once the title has settled.
var _title_hint: Control
var _title_motion: Tween
var _title_time := 0.0
## True while the camera sinks from the title into the stage.
var _sinking := false

var _end_layer: CanvasLayer
var _end_root: Control
var _end_label: Label
var _play_again_button: Button
var _end_title_button: Button

## The ambient loop, on from the title onward. `ambient_loop.wav`'s import
## sets its own loop points, so one `play()` here is enough; no stage change
## touches this player again.
var _music_player: AudioStreamPlayer
## Plays a click for every row `_row` creates. One player, one
## wire-up point, instead of a play call in each button's own press handler.
var _click_player: AudioStreamPlayer


func _ready() -> void:
	progress = TutorialProgress.new(progress_path)
	_apply_music_volume()
	_apply_effects_volume()
	_apply_fullscreen()
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = preload("res://assets/audio/ambient_loop.wav")
	_music_player.bus = "Music"
	add_child(_music_player)
	_music_player.play()
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = preload("res://assets/audio/ui.wav")
	_click_player.bus = "Effects"
	add_child(_click_player)
	game = Game.new()
	game.progress = progress
	game.release_mode = release_mode_override if release_mode_override != null \
		else (not OS.is_debug_build() or "--release-ui" in OS.get_cmdline_user_args())
	game.start_stage = clampi(progress.stage, 0, Game.PUZZLE_PATHS.size() - 1)
	# The game plays with the direct mirror controls; the gear's debug panel
	# can switch back to the classic editor to compare.
	game.direct_controls = true
	add_child(game)
	game.stage_reached.connect(_on_stage_reached)
	game.tutorial_finished.connect(_on_tutorial_finished)
	game.hud.action_requested.connect(_on_hud_action)
	game.hud.set_settings_state(progress.music_volume, progress.effects_volume, progress.fullscreen)
	_build_title()
	_build_end_card()
	_show_title(false)


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
	_end_root.modulate.a = 0.0
	Motion.tween(_end_root, "modulate:a", 1.0, "transition")


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
		"new_game":
			_start_again()


## --- Title -------------------------------------------------------------

func _build_title() -> void:
	_title_layer = CanvasLayer.new(); _title_layer.layer = 10; add_child(_title_layer)
	# The whole screen is the way in: a tap anywhere, or any key, begins.
	_title_root = Control.new(); _title_root.theme = UiStyle.theme(); _title_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _title_layer.add_child(_title_root)
	_title_root.gui_input.connect(_on_title_input)
	_title_label = UiStyle.label("Mirror", "title"); _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; _title_root.add_child(_title_label)
	_title_hint = Control.new(); _title_hint.size = Vector2(UiStyle.TOUCH, UiStyle.TOUCH); _title_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_hint.draw.connect(_draw_title_hint); _title_hint.visible = false; _title_root.add_child(_title_hint)
	_title_root.resized.connect(_layout_title)


## The light after rain, small: a warm point in a soft halo.
func _draw_title_hint() -> void:
	var centre := _title_hint.size * 0.5
	for ring: int in 6:
		_title_hint.draw_circle(centre, 6.0 + ring * 3.2, Color(UiStyle.LIGHT, 0.10))
	_title_hint.draw_circle(centre, 5.0, Color(UiStyle.SNOW, 0.95))


## `rise` lifts the camera from the stage up to the far view; without it, the
## far view shows at once, as on launch.
func _show_title(rise := true) -> void:
	_set_game_active(false)
	_sinking = false
	if is_instance_valid(_title_motion):
		_title_motion.kill()
	_title_layer.visible = true
	_layout_title()
	_title_hint.visible = false
	Motion.fade(_title_label, true)
	var camera := game.camera
	if rise:
		var start := camera.afar
		_title_motion = Motion.blend(self, func(weight: float) -> void:
			camera.afar = lerpf(start, 1.0, weight)
			camera.refresh(), "transition")
	else:
		camera.afar = 1.0
		camera.refresh()
		_title_motion = create_tween()
	_title_motion.tween_interval(TITLE_HINT_DELAY)
	_title_motion.tween_callback(func() -> void:
		Motion.fade(_title_hint, true)
		_title_motion = create_tween()
		_title_motion.tween_interval(Motion.duration("appear"))
		_title_motion.tween_callback(func() -> void: _title_motion = Motion.breathe(_title_hint, 0.35)))


func _process(delta: float) -> void:
	if not _title_layer.visible or _sinking:
		return
	_title_time += delta
	game.camera.drift = sin(_title_time * TITLE_SWAY_SPEED) * TITLE_SWAY
	game.camera.refresh()


## Play begins once the camera has sunk into the stage.
func _hide_title() -> void:
	_title_layer.visible = false
	_sinking = false
	game.camera.afar = 0.0
	game.camera.refresh()
	_set_game_active(true)
	game.hud.modulate.a = 0.0
	Motion.tween(game.hud, "modulate:a", 1.0, "appear")
	game.hud.show_stage_title(str(game.level.get("title", "")))


func _on_title_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		_on_primary_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if _title_layer.visible and (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_primary_pressed()


## The tap that begins or continues: the camera sinks from the far view into
## the stage, then play starts.
func _on_primary_pressed() -> void:
	if _sinking or not _title_layer.visible:
		return
	_sinking = true
	if is_instance_valid(_title_motion):
		_title_motion.kill()
	Motion.fade(_title_label, false)
	Motion.fade(_title_hint, false)
	var camera := game.camera
	var start := camera.afar
	_title_motion = Motion.blend(self, func(weight: float) -> void:
		camera.afar = lerpf(start, 0.0, weight)
		camera.refresh(), "transition")
	_title_motion.tween_callback(_hide_title)


## Settings' "Start again": the saved stage and done prompts are cleared, and
## the first stage begins.
func _start_again() -> void:
	progress.reset_progress()
	game.load_level(0)
	game.hud.show_stage_title(str(game.level.get("title", "")))


## --- End card ------------------------------------------------------------

func _build_end_card() -> void:
	_end_layer = CanvasLayer.new(); _end_layer.layer = 10; _end_layer.visible = false; add_child(_end_layer)
	_end_root = Control.new(); _end_root.theme = UiStyle.theme(); _end_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _end_layer.add_child(_end_root)
	# A thin mist over the world, so the words read on it.
	var mist := ColorRect.new(); mist.color = Color(UiStyle.SNOW, 0.42); mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _end_root.add_child(mist)
	_end_label = UiStyle.label("The tutorial is complete.", "chapter"); _end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _end_root.add_child(_end_label)
	_play_again_button = _row("again", "Play again"); _play_again_button.pressed.connect(_on_play_again_pressed)
	_end_title_button = _row("title", "Title"); _end_title_button.pressed.connect(_on_end_title_pressed)
	_end_root.resized.connect(_layout_end)
	# A wrapped label knows its height only once shaped at its width.
	_end_label.minimum_size_changed.connect(_layout_end, CONNECT_DEFERRED)


func _row(icon: String, text: String) -> Button:
	var row := UiIcons.row(icon, text)
	row.custom_minimum_size.x = 220
	row.pressed.connect(_play_click)
	_end_root.add_child(row)
	return row


func _on_play_again_pressed() -> void:
	progress.reset_progress()
	game.load_level(0)
	_hide_end_card()
	_set_game_active(true)
	game.hud.show_stage_title(str(game.level.get("title", "")))


func _on_end_title_pressed() -> void:
	_hide_end_card()
	_show_title()


func _hide_end_card() -> void:
	var motion := Motion.tween(_end_root, "modulate:a", 0.0, "dismiss")
	motion.tween_callback(func() -> void: _end_layer.visible = false)


func _play_click() -> void:
	if is_instance_valid(_click_player):
		_click_player.play()


func _layout_title() -> void:
	if not is_instance_valid(_title_root) or _title_root.size.x < 10 or _title_root.size.y < 10:
		return
	var safe := SafeArea.rect(_title_root)
	# "Mirror" in the sky above the far stage; the light low in the middle.
	_title_label.size = Vector2(safe.size.x, _title_label.get_combined_minimum_size().y)
	_title_label.position = Vector2(safe.position.x, safe.position.y + safe.size.y * 0.12)
	_title_hint.position = Vector2(safe.get_center().x - _title_hint.size.x * 0.5, safe.end.y - safe.size.y * 0.12 - _title_hint.size.y)


## The end card: the words a little above the middle, the two rows under them,
## clear of the window edges from a phone in portrait to a tablet in landscape.
func _layout_end() -> void:
	if not is_instance_valid(_end_root) or _end_root.size.x < 10 or _end_root.size.y < 10:
		return
	var safe := SafeArea.rect(_end_root)
	var width := safe.size.x - UiStyle.GAP * 2.0
	_end_label.size = Vector2(width, 0)
	_end_label.position = Vector2(safe.position.x + UiStyle.GAP, safe.position.y + safe.size.y * 0.32)
	var y := _end_label.position.y + _end_label.size.y + 40.0
	for button: Button in [_play_again_button, _end_title_button]:
		button.size = button.custom_minimum_size
		button.position = Vector2(safe.get_center().x - button.size.x * 0.5, y)
		y += button.size.y + UiStyle.GAP

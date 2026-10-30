extends SceneTree
## The app shell: the title screen, save and resume, the end card, and the
## release settings panel. Each check uses its own throwaway progress file
## under `user://`, deleted at the end.

const App := preload("res://app.gd")
const Game := preload("res://game.gd")
const TutorialProgress := preload("res://core/tutorial_progress.gd")

var checks := 0
var failures := 0
var _progress_paths: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for index: int in count:
		await process_frame


func idle(app: App) -> void:
	for index: int in 600:
		if app.game.pending.is_empty() and not app.game.camera.busy and app.game.settle_frames == 0:
			return
		await process_frame


## A fresh save path for one check, tracked for cleanup at the end.
func fresh_path(name: String) -> String:
	var path := "user://test_progress_%s.cfg" % name
	_progress_paths.append(path)
	var files := DirAccess.open("user://")
	if files != null and files.file_exists(name_only(path)):
		files.remove(name_only(path))
	return path


func name_only(path: String) -> String:
	return path.trim_prefix("user://")


func cleanup_paths() -> void:
	var files := DirAccess.open("user://")
	if files == null:
		return
	for path: String in _progress_paths:
		var name := name_only(path)
		if files.file_exists(name):
			files.remove(name)


## Taps the title, then waits out the camera's sink into the stage.
func begin(app: App) -> void:
	app._on_primary_pressed()
	var deadline := Time.get_ticks_msec() + 5000
	while app._title_layer.visible and Time.get_ticks_msec() < deadline:
		await process_frame


func make_app(path: String, force_release := false) -> App:
	var app := App.new()
	app.progress_path = path
	if force_release:
		app.release_mode_override = true
	root.add_child(app)
	return app


func run() -> void:
	root.size = Vector2i(1152, 800)
	await check_title_and_start()
	await check_stage_saves_and_resumes()
	await check_tutorial_finished_and_play_again()
	await check_release_settings()
	await check_corrupt_progress()
	await check_layout()
	cleanup_paths()
	print("App flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_title_and_start() -> void:
	var app := make_app(fresh_path("title"))
	await frames(2)
	check(app._title_layer.visible, "Title: the title shows on a fresh app")
	check(not app.game.input_enabled, "Title: game input is off behind the title")
	check(app.game.process_mode == Node.PROCESS_MODE_DISABLED, "Title: the game is paused behind the title")
	check(app._title_label.text == "Mirror" and app._title_label.visible, "Title: the name shows in the sky")
	var buttons := app._title_root.find_children("*", "BaseButton", true, false)
	check(buttons.is_empty(), "Title: there are no buttons")
	check(app.game.camera.afar == 1.0, "Title: the stage is seen from afar")
	await create_timer(App.TITLE_HINT_DELAY + Motion.duration("appear") + 0.2).timeout
	check(app._title_hint.visible, "Title: after a moment, a small light shows where to tap")
	var tap := InputEventMouseButton.new(); tap.button_index = MOUSE_BUTTON_LEFT; tap.pressed = true
	app._on_title_input(tap)
	check(app._sinking and app._title_layer.visible and not app.game.input_enabled, "Title: a tap anywhere starts the sink; play waits for it")
	var deadline := Time.get_ticks_msec() + 5000
	while app._title_layer.visible and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not app._title_layer.visible, "Title: the sink ends on the stage and hides the title")
	check(app.game.camera.afar == 0.0, "Title: the camera is back at the play view")
	check(app.game.hud._stage_title.visible and app.game.hud._stage_title.text == str(app.game.level["title"]), "Title: the stage's name is written on the world")
	check(app.game.input_enabled, "Title: Tap to begin turns game input on")
	check(app.game.process_mode == Node.PROCESS_MODE_INHERIT, "Title: Tap to begin resumes the game")
	check(app.game.level_index == 0, "Title: a fresh app starts at stage 0")
	app.queue_free()
	await frames(1)


func check_stage_saves_and_resumes() -> void:
	var path := fresh_path("resume")
	var app := make_app(path)
	await idle(app)
	await begin(app)
	app.game.load_level(1)
	await idle(app)
	check(app.progress.stage == 1, "Resume: reaching a stage updates progress in memory")
	var reread := TutorialProgress.new(path)
	check(reread.stage == 1, "Resume: reaching a stage saves it to the file")
	app.queue_free()
	await frames(1)
	var resumed := make_app(path)
	await idle(resumed)
	check(resumed._title_layer.visible, "Resume: a saved stage still opens on the title")
	check(resumed.game.level_index == 1, "Resume: the app loads straight into the saved stage")
	await begin(resumed)
	check(resumed.game.level_index == 1 and resumed.game.input_enabled, "Resume: the tap continues the saved stage")
	resumed.queue_free()
	await frames(1)


func check_tutorial_finished_and_play_again() -> void:
	var path := fresh_path("finish")
	var app := make_app(path)
	await idle(app)
	await begin(app)
	app.game.load_level(2)
	await idle(app)
	app.progress.mark_prompt_done("probe_prompt")
	app.game.tutorial_finished.emit()
	await create_timer(App.END_CARD_DELAY + 0.2).timeout
	check(app._end_layer.visible, "End card: tutorial_finished shows the end card after the delay")
	check(not app.game.input_enabled, "End card: game input is off behind the card")
	app._on_play_again_pressed()
	await create_timer(Motion.duration("dismiss") + 0.1).timeout
	await idle(app)
	check(not app._end_layer.visible, "Play again: hides the end card")
	check(app.game.input_enabled, "Play again: turns game input back on")
	check(app.progress.stage == 0, "Play again: resets the saved stage")
	check(not app.progress.is_prompt_done("probe_prompt"), "Play again: clears done prompts")
	check(app.game.level_index == 0, "Play again: reloads stage 0")
	app.queue_free()
	await frames(1)


func check_release_settings() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if AudioServer.get_bus_index("Effects") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Effects")
	var path := fresh_path("release")
	var app := make_app(path, true)
	await idle(app)
	await begin(app)
	# The game is paused behind the title, so it settles after Begin.
	await frames(6)
	check(app.game.release_mode, "Release: release_mode_override takes effect")
	var hud := app.game.hud
	hud._gear.pressed.emit()
	await frames(1)
	check(hud._settings_panel.visible and not is_instance_valid(hud._debug_panel), "Release: the gear opens settings, not the debug panel")
	check(not hud.get_touch_control_bounds().has("level_picker"), "Release: there is no level picker")
	check(not hud.get_touch_control_bounds().has("reset"), "Release: there is no Reset button")
	check(hud._settings_panel.size.y < 400.0, "Release: the settings panel is sized to its content, not the debug panel's fixed height")
	check(not (hud._hint.visible and hud._hint.text.is_empty()), "Release: the hint is never visible with empty text")
	check(not (hud._prompt.visible and hud._prompt.text.is_empty()), "Release: the prompt card is never visible with empty text")
	check(hud._prompt_wanted and not hud._prompt.visible, "Release: the stage prompt hides while the settings panel is open")
	check(hud._new_game_button.is_visible_in_tree() and hud._restart_button.is_visible_in_tree() and hud._title_button.is_visible_in_tree(),
		"Release: settings offer Restart stage, Start again and Return to title")
	hud._gear.pressed.emit()
	await frames(1)
	check(hud._prompt.visible, "Release: the stage prompt returns when the settings panel closes")
	await create_timer(Motion.duration("dismiss") + 0.1).timeout
	check(not hud._settings_panel.visible, "Release: the settings panel leaves with the dismiss motion")
	app.game.load_level(1)
	await idle(app)
	app.progress.mark_prompt_done("probe_prompt")
	hud._gear.pressed.emit()
	await frames(1)
	hud._new_game_button.pressed.emit()
	await idle(app)
	check(app.game.level_index == 0 and app.progress.stage == 0 and not app.progress.is_prompt_done("probe_prompt"), "Release: Start again clears the save and begins the first stage")
	check(not hud.is_debug_visible(), "Release: Start again closes the panel")
	await create_timer(Motion.duration("dismiss") + 0.1).timeout
	app.game.begin_preview()
	await idle(app)
	check(app.game.edit_mode == "move", "Release: preview opens in Move")
	var mode_key := InputEventKey.new(); mode_key.keycode = KEY_2; mode_key.pressed = true
	app.game._unhandled_input(mode_key)
	check(app.game.edit_mode == "move", "Release: the mode-shortcut key 2 is ignored")
	app.game.cancel_preview()
	await idle(app)
	app.game._fail()
	check(not hud._reset.visible, "Release: Reset stays hidden on failure")
	hud.action_requested.emit("music_volume", 0.3)
	await frames(1)
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.3)), "Release: the music slider sets the bus volume")
	check(is_equal_approx(app.progress.music_volume, 0.3), "Release: the music slider updates progress")
	var reread := TutorialProgress.new(path)
	check(is_equal_approx(reread.music_volume, 0.3), "Release: the music volume persists to the file")
	app.queue_free()
	await frames(1)


func check_corrupt_progress() -> void:
	var path := fresh_path("corrupt")
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_string("not { a valid config :: file")
	handle.close()
	var app := make_app(path)
	await idle(app)
	check(app.progress.stage == 0, "Corrupt file: defaults to stage 0")
	check(is_equal_approx(app.progress.music_volume, TutorialProgress.DEFAULT_VOLUME), "Corrupt file: defaults the music volume")
	check(app._title_layer.visible, "Corrupt file: the app still boots to the title, no crash")
	app.queue_free()
	await frames(1)


func check_fits(controls: Array, dimensions: Vector2i, label: String) -> void:
	for control: Control in controls:
		var bounds := control.get_global_rect()
		check(bounds.position.x >= 0 and bounds.end.x <= dimensions.x and bounds.position.y >= 0 and bounds.end.y <= dimensions.y,
			"Layout: %s %s fits the window at %s" % [label, control.name, dimensions])


func check_button_bounds(buttons: Array, dimensions: Vector2i, label: String) -> void:
	for button: Button in buttons:
		var bounds := button.get_global_rect()
		check(bounds.size.x >= 48 and bounds.size.y >= 48, "Layout: %s button is at least 48 units at %s" % [label, dimensions])
		check(bounds.position.x >= 0 and bounds.end.x <= dimensions.x and bounds.position.y >= 0 and bounds.end.y <= dimensions.y,
			"Layout: %s button fits the window at %s" % [label, dimensions])


func check_layout() -> void:
	var app := make_app(fresh_path("layout"))
	await idle(app)
	app._show_title()
	app._title_hint.visible = true
	for dimensions: Vector2i in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1024, 768), Vector2i(1152, 800)]:
		root.size = dimensions
		await frames(2)
		check_fits([app._title_label, app._title_hint], dimensions, "title")
		check(app._title_label.get_global_rect().end.y < app._title_hint.get_global_rect().position.y, "Layout: the title's light sits below its name at %s" % dimensions)
	await begin(app)
	await idle(app)
	for dimensions: Vector2i in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1024, 768), Vector2i(1152, 800)]:
		root.size = dimensions
		await frames(2)
		app.game.tutorial_finished.emit()
		await create_timer(App.END_CARD_DELAY + 0.2).timeout
		check_button_bounds([app._play_again_button, app._end_title_button], dimensions, "end card")
		check_fits([app._end_label], dimensions, "end card")
		app._on_play_again_pressed()
		await create_timer(Motion.duration("dismiss") + 0.1).timeout
		await idle(app)
	root.size = Vector2i(1152, 800)
	app.queue_free()
	await frames(1)

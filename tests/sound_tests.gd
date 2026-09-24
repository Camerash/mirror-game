extends SceneTree
## The game's sound: the audio buses, the asset load, the tutorial-event map,
## footsteps, the stage sweep, and the app's music loop and effects volume.

const Game := preload("res://game.gd")
const App := preload("res://app.gd")
const Sounds := preload("res://world/sounds.gd")
const Walker := preload("res://world/walker.gd")

const AUDIO_NAMES: Array[String] = ["step_1", "step_2", "step_3", "ui", "create",
	"confirm", "remove", "goal", "sweep", "land", "ambient_loop"]

## `tutorial_event` name to the file `game.sounds` must play for it. `walk`
## is checked apart, since it must play nothing.
const EVENT_FILES := {
	"create": "create.wav",
	"confirm": "confirm.wav",
	"remove": "remove.wav",
	"goal": "goal.wav",
	"fall": "land.wav",
	"resize": "ui.wav",
	"turn": "ui.wav",
	"move": "ui.wav",
}

var checks := 0
var failures := 0


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


func physics_frames(count: int) -> void:
	for index: int in count:
		await physics_frame


## Waits for `load_level`'s two-frame settle to clear, the way `app_flow_tests.gd`'s
## `idle` does, so a `request_walk` right after a level load is not refused.
func idle(game: Node3D) -> void:
	for tick: int in range(600):
		if game.pending.is_empty() and not game.camera.busy and game.settle_frames == 0:
			return
		await process_frame


func walk_finished(game: Node3D) -> void:
	for tick: int in range(600):
		await physics_frame
		if game.walker.route.is_empty():
			await frames(3)
			return
	check(false, "Steps: the walk completes within ten seconds")


## Headless test runs load `default_bus_layout.tres` already, but a run that
## does not (or a future test order change) must not fail on a missing bus.
func ensure_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if AudioServer.get_bus_index("Effects") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Effects")


func run() -> void:
	root.size = Vector2i(1152, 800)
	ensure_buses()
	check(AudioServer.get_bus_index("Music") != -1, "Buses: Music exists")
	check(AudioServer.get_bus_index("Effects") != -1, "Buses: Effects exists")
	check_assets_load()
	await check_event_map()
	await check_steps()
	await check_sweep()
	await check_app_music_and_volume()
	print("Sound tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_assets_load() -> void:
	for name: String in AUDIO_NAMES:
		var stream: AudioStream = load("res://assets/audio/%s.wav" % name)
		check(stream != null, "Assets: %s.wav loads" % name)


func check_event_map() -> void:
	var game := Game.new()
	root.add_child(game)
	await frames(3)
	for event: String in EVENT_FILES:
		game.sounds.last_player = null
		game.tutorial_event.emit(event)
		var player: AudioStreamPlayer = game.sounds.last_player
		check(player != null and player.stream != null and player.stream.resource_path.ends_with(EVENT_FILES[event]),
			"Sound map: %s plays %s" % [event, EVENT_FILES[event]])
	game.sounds.last_player = null
	game.tutorial_event.emit("walk")
	check(game.sounds.last_player == null, "Sound map: walk plays nothing (footsteps cover it)")
	game.queue_free()
	await frames(1)


func check_steps() -> void:
	# A real walk: footsteps play while the traveller actually moves.
	var game := Game.new()
	root.add_child(game)
	await frames(3)
	game.load_level(Game.LEVEL_PATHS.find("res://levels/01_route.json"))
	await idle(game)
	# (2, 0, 0) sits on the start platform, so no mirror is needed first.
	check(game.request_walk(Vector3(2, 0, 0)), "Steps: the walk to (2,0,0) is accepted")
	var before := game.sounds.steps_played
	await walk_finished(game)
	check(game.sounds.steps_played > before, "Steps: footsteps play while walking a real route")
	game.queue_free()
	await frames(1)

	# An isolated walker, never added to the tree, keeps exactly the state
	# this test sets: nothing else corrects `grounded` or `paused` between
	# physics ticks, so the pause and airborne gates are unambiguous.
	var sounds := Sounds.new()
	root.add_child(sounds)
	var fake_walker := Walker.new()
	fake_walker.grounded = true
	fake_walker.paused = false
	fake_walker.velocity = Vector3(3, 0, 0)
	sounds.walker = fake_walker
	await physics_frames(60)
	check(sounds.steps_played > 0, "Steps: the gate plays footsteps while grounded, unpaused, and moving")
	fake_walker.paused = true
	var paused_count := sounds.steps_played
	await physics_frames(30)
	check(sounds.steps_played == paused_count, "Steps: no footsteps while paused")
	fake_walker.paused = false
	fake_walker.grounded = false
	var airborne_count := sounds.steps_played
	await physics_frames(30)
	check(sounds.steps_played == airborne_count, "Steps: no footsteps while airborne")
	sounds.queue_free()
	fake_walker.free()
	await frames(1)


func check_sweep() -> void:
	var game := Game.new()
	root.add_child(game)
	await frames(3)
	game.sounds.last_player = null
	game._begin_sweep()
	var player: AudioStreamPlayer = game.sounds.last_player
	check(player != null and player.stream != null and player.stream.resource_path.ends_with("sweep.wav"),
		"Sweep: starting the sweep plays sweep.wav")
	game.queue_free()
	await frames(1)


func check_app_music_and_volume() -> void:
	var path := "user://test_sound_app.cfg"
	var files := DirAccess.open("user://")
	if files != null and files.file_exists("test_sound_app.cfg"):
		files.remove("test_sound_app.cfg")
	var app := App.new()
	app.progress_path = path
	root.add_child(app)
	await frames(3)
	check(is_instance_valid(app._music_player) and app._music_player.bus == "Music",
		"App music: the loop plays on the Music bus")
	check(app._music_player.playing, "App music: the loop plays from the start, title included")
	var stream := app._music_player.stream as AudioStreamWAV
	check(stream != null and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "App music: the stream loops")
	app.game.load_level(1)
	await frames(3)
	check(app._music_player.playing, "App music: a stage change does not stop or restart the loop")
	app.game.hud.action_requested.emit("effects_volume", 0.4)
	await frames(1)
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects")), linear_to_db(0.4)),
		"Effects volume: the HUD action sets the Effects bus volume")
	app.queue_free()
	await frames(1)
	if files != null and files.file_exists("test_sound_app.cfg"):
		files.remove("test_sound_app.cfg")

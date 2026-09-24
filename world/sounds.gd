class_name GameSounds
extends Node
## Plays the game's sound effects: the tutorial events, the stage sweep, and
## footsteps while the traveller walks.
##
## `game.gd` creates one instance in `_setup_scene`, adds it as a child,
## connects `tutorial_event` to `play_event`, and points `walker` at the
## traveller so footsteps can follow it. All playback is on the "Effects"
## bus and uses `AudioStreamPlayer`, which stays silent but does not error
## when tests run under the dummy audio driver.

## How many players share one-shot effects. Footsteps use their own player
## below, so a burst of footsteps cannot steal a pool slot from an effect.
const POOL_SIZE := 4
## World units between two footsteps.
const STEP_DISTANCE := 0.42
const STEP_PITCH_MIN := 0.95
const STEP_PITCH_MAX := 1.05
const AUDIO_DIR := "res://assets/audio/"

const STEP_NAMES: Array[String] = ["step_1", "step_2", "step_3"]
const Walker := preload("res://world/walker.gd")

## `tutorial_event` name to the sound it plays. `volume_db` defaults to 0.0
## when left out. `resize`, `turn`, and `move` share a quiet "ui" click: they
## are small adjustments during an edit, not a fresh action like create or
## confirm. `camera_turn` has no entry: the arrow buttons already click, and a
## second click would double it. `walk` has no entry: footsteps already cover it, and a
## failed jump has no entry either, since the fall (or its absence) and the
## failure veil already read as the failure.
const EVENT_SOUNDS := {
	"create": {"name": "create"},
	"confirm": {"name": "confirm"},
	"remove": {"name": "remove"},
	"goal": {"name": "goal"},
	"fall": {"name": "land"},
	"resize": {"name": "ui", "volume_db": -8.0},
	"turn": {"name": "ui", "volume_db": -8.0},
	"move": {"name": "ui", "volume_db": -8.0},
}

## The traveller to follow for footsteps. Left null (the default) until
## `game.gd` sets it in `_setup_scene`; `_physics_process` then does nothing.
var walker: Walker = null

## The pool player used by the most recent `play` call, for tests: after a
## call, `last_player.stream.resource_path` names the file that played.
var last_player: AudioStreamPlayer
## How many footsteps have played, for tests.
var steps_played := 0

var _pool: Array[AudioStreamPlayer] = []
var _pool_next := 0
var _step_player: AudioStreamPlayer
var _step_streams: Array[AudioStream] = []
var _step_progress := 0.0
## Fixed, not random-seeded from the clock, so a footstep pitch sequence
## repeats the same way between runs.
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 1
	for step_name: String in STEP_NAMES:
		_step_streams.append(load(AUDIO_DIR + step_name + ".wav"))
	for index: int in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		add_child(player)
		_pool.append(player)
	_step_player = AudioStreamPlayer.new()
	_step_player.bus = "Effects"
	add_child(_step_player)

## Stops every player, so no playback is still held when the game closes.
func _exit_tree() -> void:
	for player: AudioStreamPlayer in _pool:
		player.stop()
	if _step_player:
		_step_player.stop()

## Plays `res://assets/audio/<name>.wav` on the next pool player. Missing
## bus names and a missing audio device are both silently harmless: the
## stream still "plays", it just makes no sound.
func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStream = load(AUDIO_DIR + name + ".wav")
	if stream == null:
		return
	var player := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	last_player = player

## The `tutorial_event` handler. Unlisted names, including "walk", play
## nothing.
func play_event(name: String) -> void:
	var entry: Dictionary = EVENT_SOUNDS.get(name, {})
	if entry.is_empty():
		return
	play(str(entry.get("name")), float(entry.get("volume_db", 0.0)))

func _physics_process(delta: float) -> void:
	if walker == null or not walker.grounded or walker.paused:
		return
	var horizontal := Vector3(walker.velocity.x, 0.0, walker.velocity.z)
	var speed := horizontal.length()
	if speed < 0.01:
		return
	_step_progress += speed * delta
	while _step_progress >= STEP_DISTANCE:
		_step_progress -= STEP_DISTANCE
		_play_step()

func _play_step() -> void:
	_step_player.stream = _step_streams[_rng.randi_range(0, _step_streams.size() - 1)]
	_step_player.pitch_scale = _rng.randf_range(STEP_PITCH_MIN, STEP_PITCH_MAX)
	_step_player.play()
	steps_played += 1

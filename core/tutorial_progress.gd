class_name TutorialProgress
extends RefCounted
## Saved tutorial progress: the reached stage, the tutorial prompts already
## shown, and the player's audio and display settings. Backed by a
## `ConfigFile` at a settable path, so tests can point it at a throwaway file.
##
## Duck-typed to match `game.gd`'s optional `progress` field:
##   is_prompt_done(id: String) -> bool
##   mark_prompt_done(id: String) -> void

const Game := preload("res://game.gd")
const SECTION := "progress"
const DEFAULT_PATH := "user://progress.cfg"
const DEFAULT_VOLUME := 0.8

var path: String
var stage := 0
var music_volume := DEFAULT_VOLUME
var effects_volume := DEFAULT_VOLUME
var fullscreen := false
var _done_prompts := {}


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path
	load_file()


## Loads the save file, or falls back to defaults. A missing file is the
## normal "no save yet" case and stays quiet. A file that cannot be read, or
## a field with the wrong type or an out-of-range value, defaults that field
## and reports why with `push_warning`.
func load_file() -> void:
	stage = 0
	music_volume = DEFAULT_VOLUME
	effects_volume = DEFAULT_VOLUME
	fullscreen = false
	_done_prompts.clear()
	var file := ConfigFile.new()
	var error := file.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_warning("TutorialProgress: %s could not be read (%s); using defaults." % [path, error_string(error)])
		return
	stage = _read_stage(file)
	_done_prompts = _read_done_prompts(file)
	music_volume = _read_unit(file, "music_volume", DEFAULT_VOLUME)
	effects_volume = _read_unit(file, "effects_volume", DEFAULT_VOLUME)
	fullscreen = _read_bool(file, "fullscreen", false)


func save_file() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "stage", stage)
	file.set_value(SECTION, "done_prompts", _done_prompts.keys())
	file.set_value(SECTION, "music_volume", music_volume)
	file.set_value(SECTION, "effects_volume", effects_volume)
	file.set_value(SECTION, "fullscreen", fullscreen)
	var error := file.save(path)
	if error != OK:
		push_warning("TutorialProgress: %s could not be saved (%s)." % [path, error_string(error)])


func is_prompt_done(id: String) -> bool:
	return bool(_done_prompts.get(id, false))


func mark_prompt_done(id: String) -> void:
	if _done_prompts.get(id, false):
		return
	_done_prompts[id] = true
	save_file()


func set_stage(index: int) -> void:
	var clamped := clampi(index, 0, maxi(0, Game.PUZZLE_PATHS.size() - 1))
	if clamped == stage:
		return
	stage = clamped
	save_file()


## Stage 0, no done prompts. Settings (audio, fullscreen) are not touched.
func reset_progress() -> void:
	stage = 0
	_done_prompts.clear()
	save_file()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	save_file()


func set_effects_volume(value: float) -> void:
	effects_volume = clampf(value, 0.0, 1.0)
	save_file()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	save_file()


func _read_stage(file: ConfigFile) -> int:
	var value: Variant = file.get_value(SECTION, "stage", 0)
	var limit := maxi(0, Game.PUZZLE_PATHS.size() - 1)
	if not (value is int or value is float) or int(value) != clampi(int(value), 0, limit):
		_warn_invalid(file, "stage", "0")
		return 0
	return int(value)


func _read_done_prompts(file: ConfigFile) -> Dictionary:
	var value: Variant = file.get_value(SECTION, "done_prompts", [])
	if not value is Array:
		_warn_invalid(file, "done_prompts", "none")
		return {}
	var result := {}
	for id: Variant in value:
		if id is String and not id.is_empty():
			result[id] = true
	return result


func _read_unit(file: ConfigFile, key: String, default: float) -> float:
	var value: Variant = file.get_value(SECTION, key, default)
	if not (value is int or value is float) or float(value) < 0.0 or float(value) > 1.0:
		_warn_invalid(file, key, "%.2f" % default)
		return default
	return float(value)


func _read_bool(file: ConfigFile, key: String, default: bool) -> bool:
	var value: Variant = file.get_value(SECTION, key, default)
	if not value is bool:
		_warn_invalid(file, key, str(default))
		return default
	return value


func _warn_invalid(file: ConfigFile, key: String, default_text: String) -> void:
	# A key that was never written is not corruption; only warn when the
	# save actually holds a bad value for it.
	if file.has_section_key(SECTION, key):
		push_warning("TutorialProgress: %s's %s is invalid; using %s." % [path, key, default_text])

extends "res://art_trial/full_traveller_study.gd"
## Isolated hood animation review. Native clips own the skeleton and garment.

const BOUNDS_PATH := "res://assets/studies/traveller_bounds.json"
const HOOD_DOWN := "HoodDown"
const HOOD_UP := "HoodUp"

var player: AnimationPlayer
var skeleton: Skeleton3D
var active_clip := HOOD_DOWN
var action_active := false
var animation_time := 0.0
var playback_speed := 1.0
var down_button: Button
var up_button: Button
var play_button: Button
var speed_button: Button
var seek_slider: HSlider
var time_label: Label


func _ready() -> void:
	super._ready()
	set_process(player != null)


func _bind_model() -> void:
	super._bind_model()
	for node: Node in model.find_children("*", "AnimationPlayer", true, false):
		player = node as AnimationPlayer
		break
	for node: Node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
		break
	if player == null or skeleton == null:
		push_error("Animated traveller needs an AnimationPlayer and Skeleton3D.")
		return
	for clip: String in [HOOD_DOWN, HOOD_UP]:
		if not player.has_animation(clip):
			push_error("Animated traveller needs " + clip + ".")
			return
	player.animation_finished.connect(_animation_finished)
	_load_animation_bounds()


func _load_animation_bounds() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(BOUNDS_PATH))
	if not data is Dictionary or not data.has("global") or not data.has("meshes"):
		push_error("Animated traveller needs sampled bounds: " + BOUNDS_PATH)
		return
	bounds = _read_bounds(data.global)
	centre = bounds.get_center()
	for mesh: MeshInstance3D in meshes:
		if not data.meshes.has(String(mesh.name)):
			push_error("Missing animated culling bounds for " + String(mesh.name))
			continue
		mesh.custom_aabb = _read_bounds(data.meshes[String(mesh.name)])


func _read_bounds(data: Dictionary) -> AABB:
	var position_data: Array = data.get("position", [])
	var size_data: Array = data.get("size", [])
	if position_data.size() != 3 or size_data.size() != 3:
		push_error("Animated bounds need three position and size coordinates.")
		return AABB()
	return AABB(Vector3(position_data[0], position_data[1], position_data[2]),
		Vector3(size_data[0], size_data[1], size_data[2]))


func _build_controls() -> void:
	super._build_controls()
	_button("Hood Down", start_action.bind(true))
	down_button = controls.get_child(-1) as Button
	_button("Hood Up", start_action.bind(false))
	up_button = controls.get_child(-1) as Button
	_button("Play", toggle_playback)
	play_button = controls.get_child(-1) as Button
	_button("Speed: 1x", _cycle_speed)
	speed_button = controls.get_child(-1) as Button
	seek_slider = HSlider.new()
	seek_slider.custom_minimum_size = Vector2(112, 48)
	seek_slider.step = 0.01
	seek_slider.max_value = 1.0
	seek_slider.tooltip_text = "Animation time. Seeking pauses playback."
	seek_slider.value_changed.connect(scrub_to)
	controls.add_child(seek_slider)
	time_label = Label.new()
	time_label.custom_minimum_size = Vector2(112, 48)
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(time_label)


func start_action(lowered: bool) -> void:
	if player == null or action_active or hood_lowered == lowered:
		return
	active_clip = HOOD_DOWN if lowered else HOOD_UP
	action_active = true
	animation_time = 0.0
	player.play(active_clip)
	player.advance(0.0)
	_update_playback_controls()


func toggle_playback() -> void:
	if player == null:
		return
	if player.is_playing():
		animation_time = player.current_animation_position
		player.pause()
	elif action_active:
		player.play()
	else:
		start_action(not hood_lowered)
	_update_playback_controls()


func scrub_to(seconds: float) -> void:
	if player == null or not player.has_animation(active_clip):
		return
	var duration := player.get_animation(active_clip).length
	var time := clampf(seconds, 0.0, duration)
	_sample_pose(active_clip, time)
	action_active = time < duration
	hood_lowered = (active_clip == HOOD_DOWN) if time >= duration else (active_clip == HOOD_UP)
	_update_playback_controls()


func _sample_pose(clip: String, time: float) -> void:
	animation_time = time
	player.play(clip)
	player.seek(time, true)
	player.advance(0.0)
	player.pause()
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()


func set_hood_lowered(lowered: bool) -> void:
	# The static endpoint control also cancels any active action.
	action_active = false
	active_clip = HOOD_DOWN
	if player != null and player.has_animation(active_clip):
		_sample_pose(active_clip, player.get_animation(active_clip).length if lowered else 0.0)
		player.stop(true)
	super.set_hood_lowered(lowered)
	_update_playback_controls()


func set_playback_speed(speed: float) -> void:
	playback_speed = clampf(speed, 0.25, 2.0)
	if player != null:
		player.speed_scale = playback_speed
	if speed_button != null:
		speed_button.text = "Speed: %sx" % str(playback_speed)


func _cycle_speed() -> void:
	var speeds := [0.25, 0.5, 1.0, 2.0]
	set_playback_speed(speeds[(speeds.find(playback_speed) + 1) % speeds.size()])


func _animation_finished(clip: StringName) -> void:
	if String(clip) != active_clip:
		return
	action_active = false
	hood_lowered = active_clip == HOOD_DOWN
	animation_time = player.get_animation(active_clip).length
	_update_playback_controls()


func _update_playback_controls() -> void:
	if down_button == null:
		return
	down_button.disabled = action_active or hood_lowered
	up_button.disabled = action_active or not hood_lowered
	play_button.text = "Pause" if player != null and player.is_playing() else "Play"
	if hood_button != null:
		hood_button.text = "Hood: Moving" if action_active else ("Hood: Folded" if hood_lowered else "Hood: Raised")
	var duration := player.get_animation(active_clip).length if player != null and player.has_animation(active_clip) else 1.0
	if player != null and not player.current_animation.is_empty():
		animation_time = player.current_animation_position
	seek_slider.max_value = duration
	seek_slider.set_value_no_signal(animation_time)
	time_label.text = "%.2f / %.2f s" % [animation_time, duration]


func reset_study() -> void:
	super.reset_study()
	set_playback_speed(1.0)


func _process(_delta: float) -> void:
	_update_playback_controls()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				toggle_playback()
				return
			KEY_D:
				start_action(true)
				return
			KEY_I:
				start_action(false)
				return
	super._unhandled_input(event)

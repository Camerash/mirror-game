class_name Prologue
extends Node3D
## The story on the first place: she wakes in the snow, finds the hand mirror
## on the ice, and for a moment sees her sister in the glass.
##
## `game.gd` owns one. `begin` sets it up when a level has a `keepsake` and
## the game plays with its story on (the app; tests leave it off). The game
## holds phase "transition" while a beat plays, so walking, the mirror and
## the camera are all refused, and calls `reach` each play frame. Every
## timeline is a tween on this node, so it waits while the title holds the
## game disabled. Wordless; the one sound is the game's own.

signal finished

const CharacterVisual := preload("res://world/character_visual.gd")
const Geometry := preload("res://core/world_geometry.gd")
## Saved with the done prompts, so the prologue plays once.
const DONE_ID := "prologue"
## She notices the hand mirror once she is this close to it.
const REACH := 0.3
## Seconds she lies still before she wakes, once play begins.
const LIE_TIME := 1.2
## How long her sister stays in the glass.
const GLIMPSE_TIME := 1.1
## How far the music falls while her sister is there, in dB.
const MUSIC_DIP := -18.0

var active := false
var at := Vector3.ZERO
var glimpse := Vector3.ZERO
var walker: Node3D
var keepsake: Node3D
var pane: MeshInstance3D
var twin: CharacterVisual
var _glint: Tween
var _scene: Tween
## The music bus level before the glimpse dipped it; NAN when not dipped.
var _music_db := NAN

## Sets up the place. With `wake`, she starts lying in the snow and wakes on
## her own once play begins.
func begin(level: Dictionary, her: Node3D, wake: bool) -> void:
	clear()
	walker = her
	at = Geometry.vector(level["keepsake"])
	glimpse = Geometry.vector(level.get("glimpse", level["goal"]))
	active = true
	_build_keepsake()
	if wake:
		_lie()

func clear() -> void:
	for tween: Tween in [_glint, _scene]:
		if tween != null and tween.is_valid():
			tween.kill()
	for child: Node in get_children():
		child.free()
	keepsake = null
	pane = null
	twin = null
	_set_music_dip(0.0)
	if walker != null and is_instance_valid(walker):
		var visual := _visual()
		if visual != null:
			visual.rotation.x = 0.0
	active = false

## True while a beat holds the game still.
func is_playing() -> bool:
	return _scene != null and _scene.is_valid() and _scene.is_running()

## Called by the game each play frame. Starts the find when she reaches the
## hand mirror; returns true when it did.
func reach(feet: Vector3) -> bool:
	if not active or keepsake == null or is_playing():
		return false
	if Vector2(feet.x - at.x, feet.z - at.z).length() > REACH:
		return false
	_find()
	return true

func _visual() -> CharacterVisual:
	return walker.get("character_visual") as CharacterVisual if walker != null else null

# --- Waking ------------------------------------------------------------------

func _lie() -> void:
	var visual := _visual()
	var has_wake := visual != null and visual.has_method("play_action")
	if has_wake:
		visual.call("hold_pose", "Wake", 0.0)
	elif visual != null:
		visual.rotation.x = -PI * 0.5
	_scene = create_tween()
	_scene.tween_interval(LIE_TIME)
	if has_wake:
		_scene.tween_callback(func() -> void: visual.call("play_action", "Wake"))
		_scene.tween_interval(_action_length(visual, "Wake", 2.4))
	elif visual != null:
		_scene.tween_property(visual, "rotation:x", 0.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_scene.tween_callback(finished.emit)

# --- The hand mirror -------------------------------------------------------

func _build_keepsake() -> void:
	keepsake = Node3D.new()
	keepsake.position = at + Vector3.UP * 0.012
	add_child(keepsake)
	# A small oval glass in a dark gold rim, lying on the snow.
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.085
	rim_mesh.bottom_radius = 0.085
	rim_mesh.height = 0.018
	rim.mesh = rim_mesh
	rim.scale = Vector3(1.0, 1.0, 1.3)
	rim.material_override = _material(Color("8a6a3a"), 0.0)
	keepsake.add_child(rim)
	var glass := MeshInstance3D.new()
	var glass_mesh := CylinderMesh.new()
	glass_mesh.top_radius = 0.068
	glass_mesh.bottom_radius = 0.068
	glass_mesh.height = 0.02
	glass.mesh = glass_mesh
	glass.scale = Vector3(1.0, 1.0, 1.3)
	glass.material_override = _material(Color("e9f2f8"), 1.4)
	keepsake.add_child(glass)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.026, 0.016, 0.11)
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.0, 0.15)
	handle.material_override = rim.material_override
	keepsake.add_child(handle)
	# The glint: a soft cool light that breathes, so light marks what matters.
	var light := OmniLight3D.new()
	light.light_color = Color("dfeeff")
	light.omni_range = 0.9
	light.light_energy = 0.0
	light.position = Vector3.UP * 0.25
	keepsake.add_child(light)
	var star := Sprite3D.new()
	star.texture = _star_texture()
	star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star.pixel_size = 0.0022
	star.shaded = false
	star.no_depth_test = false
	star.modulate = Color(1, 1, 1, 0)
	star.position = Vector3(0.03, 0.05, -0.02)
	keepsake.add_child(star)
	_glint = create_tween().set_loops()
	_glint.tween_property(light, "light_energy", 1.2, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glint.parallel().tween_property(star, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glint.tween_property(light, "light_energy", 0.25, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glint.parallel().tween_property(star, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _find() -> void:
	var visual := _visual()
	if _glint != null and _glint.is_valid():
		_glint.kill()
	_scene = create_tween()
	# She stops, faces the glass, and lifts it.
	if visual != null:
		var toward := at - walker.position
		if Vector2(toward.x, toward.z).length() > 0.01:
			_scene.tween_property(visual, "rotation:y", visual.rotation.y + angle_difference(visual.rotation.y, atan2(toward.x, toward.z)), 0.3)
		if visual.has_method("play_action"):
			_scene.tween_callback(func() -> void: visual.call("play_action", "Lift"))
	_scene.tween_interval(0.35)
	_scene.tween_property(keepsake, "position", walker.position + Vector3.UP * 0.42, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_scene.parallel().tween_property(keepsake, "scale", Vector3.ONE * 0.4, 0.6)
	_scene.tween_callback(func() -> void: keepsake.visible = false)
	_scene.tween_interval(0.4)
	_scene.tween_callback(_glimpse)

# --- The glimpse -------------------------------------------------------------

## A pane of frost stands up between her and where her sister was; in it,
## her mirror image waves. Then only snow.
func _glimpse() -> void:
	var feet := walker.position
	var across := glimpse - feet
	across.y = 0.0
	if across.length() < 0.01:
		across = Vector3.RIGHT
	var normal := across.normalized()
	var middle := (feet + glimpse) * 0.5
	pane = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.15)
	pane.mesh = quad
	var frost := StandardMaterial3D.new()
	frost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	frost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frost.cull_mode = BaseMaterial3D.CULL_DISABLED
	frost.albedo_color = Color(0.9, 0.95, 1.0, 0.0)
	pane.material_override = frost
	pane.position = Vector3(middle.x, feet.y + 0.575, middle.z)
	pane.basis = Basis.looking_at(normal, Vector3.UP)
	pane.scale = Vector3(1.0, 0.02, 1.0)
	add_child(pane)
	# Her sister: the same girl, reflected in the pane.
	twin = CharacterVisual.new()
	add_child(twin)
	var reflect := _reflection(normal)
	var her := _visual()
	var her_basis := her.global_basis if her != null else Basis.IDENTITY
	twin.global_transform = Transform3D(reflect * her_basis, middle + reflect * (feet - middle))
	# She is seen in the glass only: a pale, frosted likeness.
	var ghost := StandardMaterial3D.new()
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.albedo_color = Color(0.93, 0.96, 1.0, 0.0)
	for node: Node in twin.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = ghost
	var glass := Color(0.9, 0.95, 1.0, 0.3)
	_scene = create_tween()
	_scene.tween_property(pane, "scale:y", 1.0, Motion.duration("reveal")).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_scene.parallel().tween_property(frost, "albedo_color", glass, Motion.duration("reveal"))
	_scene.parallel().tween_method(_set_music_dip, 0.0, 1.0, Motion.duration("reveal"))
	_scene.tween_property(ghost, "albedo_color:a", 0.8, 0.35)
	_scene.tween_callback(func() -> void:
		if twin.has_method("play_action"):
			twin.call("play_action", "Wave"))
	_scene.tween_interval(GLIMPSE_TIME)
	_scene.tween_property(ghost, "albedo_color:a", 0.0, 0.25)
	_scene.tween_callback(twin.queue_free)
	_scene.tween_property(frost, "albedo_color", Color(glass, 0.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_scene.parallel().tween_property(pane, "scale:y", 0.02, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_scene.parallel().tween_method(_set_music_dip, 1.0, 0.0, 1.6)
	_scene.tween_callback(func() -> void:
		pane.queue_free()
		active = false
		finished.emit())

# --- Helpers -----------------------------------------------------------------

## Reflection across a plane through the origin with unit normal `n`.
static func _reflection(n: Vector3) -> Basis:
	return Basis(Vector3.RIGHT - n * 2.0 * n.x, Vector3.UP - n * 2.0 * n.y, Vector3.BACK - n * 2.0 * n.z)

func _set_music_dip(weight: float) -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus == -1:
		return
	if is_nan(_music_db):
		if weight <= 0.0:
			return
		_music_db = AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_volume_db(bus, _music_db + MUSIC_DIP * weight)
	if weight <= 0.0:
		_music_db = NAN

static func _action_length(visual: Node, action: String, fallback: float) -> float:
	var player := visual.get("player") as AnimationPlayer
	if player != null and player.has_animation(action):
		return player.get_animation(action).length
	return fallback

static func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.25
	material.metallic = 0.6
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

static func _star_texture() -> Texture2D:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var middle := (size - 1) * 0.5
	for y: int in size:
		for x: int in size:
			var dx := absf(x - middle) / middle
			var dy := absf(y - middle) / middle
			# A soft four-point star: two thin crossed rays and a round core.
			var ray := maxf(maxf(0.0, 1.0 - dx) * maxf(0.0, 1.0 - dy * 9.0), maxf(0.0, 1.0 - dy) * maxf(0.0, 1.0 - dx * 9.0))
			var core := maxf(0.0, 1.0 - Vector2(dx, dy).length() * 2.2)
			var alpha := clampf(ray * ray + core * core, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

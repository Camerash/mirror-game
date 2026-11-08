class_name Prologue
extends Node3D
## The story at the pond, before the first puzzle. She lies in the snow until
## the player touches her. Three lit things hold optional memories, shown as
## pale figures in a pane of frost. Her sister's footprints end on the ice at
## the hand mirror; she picks it up and sees her sister in the glass, and then
## her sister's footprints show the way on, where there were none.
##
## `game.gd` owns one. `begin` sets it up from the level's `story` when the
## game plays with its story on (the app; tests leave it off). The game holds
## phase "transition" while a beat plays, so walking, the mirror and the
## camera are refused, and calls `reach` each play frame and `tap` on a tap.
## Every timeline is a tween on this node, so it waits while the title holds
## the game disabled. Wordless.

## A beat has ended: she has woken, a memory has passed, or (with `active`
## now false) the whole story is done.
signal finished
## A sound the game should play: "pane", "fade" or "glimpse".
signal cue(name: String)

const CharacterVisual := preload("res://world/character_visual.gd")
const Geometry := preload("res://core/world_geometry.gd")
## Saved with the done prompts, so the story plays once.
const DONE_ID := "prologue"
## She notices a lit thing once she is this close to its spot.
const REACH := 0.35
## Seconds she lies still before a soft light shows the player where to touch.
const HINT_DELAY := 3.0
## How long a memory and her sister stay in the frost.
const MEMORY_TIME := 2.6
const GLIMPSE_TIME := 1.8
## How far the music falls while her sister is there, in dB.
const MUSIC_DIP := -18.0
## Seconds between her sister's footprints appearing, after the glimpse.
const WAY_STEP := 0.07

var active := false
var walker: Node3D
var props: Node3D
var story: Dictionary = {}
var keepsake: Node3D
## Memories not yet seen: id to their entry, plus their glint.
var _memories := {}
var _glints := {}
var _awaiting_tap := false
var _hint: OmniLight3D
var _scene: Tween
var _loops: Array[Tween] = []
## The music bus level before a dip; NAN when not dipped.
var _music_db := NAN

## Sets up the place. With `wake`, she starts lying in the snow and waits for
## the player's touch. `scenery` is the place's props, where her sister's
## footprints are drawn so they leave with the place.
func begin(level: Dictionary, her: Node3D, wake: bool, scenery: Node3D) -> void:
	clear()
	walker = her
	props = scenery
	story = level["story"]
	active = true
	for memory: Dictionary in story.get("memories", []):
		_memories[str(memory["id"])] = memory
		_glints[str(memory["id"])] = _glint(Geometry.vector(memory.get("glint", memory["at"])), Color("ffe2bd"))
	keepsake = _build_keepsake(Geometry.vector(story["keepsake"]))
	if wake:
		_lie()

func clear() -> void:
	for tween: Tween in _loops + [_scene]:
		if tween != null and tween.is_valid():
			tween.kill()
	_loops.clear()
	for child: Node in get_children():
		child.free()
	_memories.clear()
	_glints.clear()
	keepsake = null
	_hint = null
	_awaiting_tap = false
	_set_music_dip(0.0)
	active = false

## True while a beat holds the game still.
func is_playing() -> bool:
	return _awaiting_tap or (_scene != null and _scene.is_valid() and _scene.is_running())

## The player's tap. While she lies in the snow it wakes her; returns true
## when it did.
func tap() -> bool:
	if not _awaiting_tap:
		return false
	_awaiting_tap = false
	if _scene != null and _scene.is_valid():
		_scene.kill()
	if _hint != null:
		create_tween().tween_property(_hint, "light_energy", 0.0, 0.4)
	var visual := _visual()
	_scene = create_tween()
	if visual != null and visual.player != null and visual.player.has_animation("Wake"):
		visual.play_action("Wake")
		_scene.tween_interval(visual.player.get_animation("Wake").length)
	_scene.tween_callback(finished.emit)
	return true

## Called by the game each play frame. Starts a beat when she reaches a lit
## thing; returns true when it did.
func reach(feet: Vector3) -> bool:
	if not active or is_playing():
		return false
	for id: String in _memories.keys():
		if _near(feet, Geometry.vector(_memories[id]["at"])):
			_remember(id)
			return true
	if keepsake != null and _near(feet, Geometry.vector(story["keepsake"])):
		_find()
		return true
	return false

static func _near(feet: Vector3, spot: Vector3) -> bool:
	return Vector2(feet.x - spot.x, feet.z - spot.z).length() <= REACH

func _visual() -> CharacterVisual:
	return walker.get("character_visual") as CharacterVisual if walker != null else null

# --- Waking ------------------------------------------------------------------

func _lie() -> void:
	var visual := _visual()
	if visual != null:
		visual.hold_pose("Wake", 0.0)
	_awaiting_tap = true
	# After a while, a soft warm light breathes on her: touch here.
	_hint = OmniLight3D.new()
	_hint.light_color = Color("ffd9b0")
	_hint.omni_range = 1.1
	_hint.light_energy = 0.0
	_hint.position = walker.position + Vector3.UP * 0.35
	add_child(_hint)
	var breathe := create_tween()
	breathe.tween_interval(HINT_DELAY)
	breathe.tween_callback(func() -> void:
		var loop := create_tween().set_loops()
		loop.tween_property(_hint, "light_energy", 1.4, Motion.duration("breathe")).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		loop.tween_property(_hint, "light_energy", 0.3, Motion.duration("breathe")).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_loops.append(loop))
	_loops.append(breathe)

# --- Memories ----------------------------------------------------------------

## Pale figures of the two of them, remembered in a pane of frost by the thing
## she has walked to.
func _remember(id: String) -> void:
	var memory: Dictionary = _memories[id]
	_memories.erase(id)
	var glint: Node3D = _glints[id]
	_glints.erase(id)
	var figures: Array[CharacterVisual] = []
	var ghost := _ghost_material()
	var centre := Vector3.ZERO
	for entry: Dictionary in memory.get("figures", []):
		var figure := _figure(entry, ghost)
		figures.append(figure)
		centre += figure.position
	centre /= maxf(1.0, figures.size())
	var feet := walker.position
	_face(Geometry.vector(memory.get("glint", centre)))
	# The pane stands just behind the figures, seen from where she is.
	var toward := centre - feet
	toward.y = 0.0
	var normal := toward.normalized() if toward.length() > 0.01 else Vector3.BACK
	var pane := _pane(centre + normal * 0.35, normal, Vector2(1.3, 1.1))
	_scene = create_tween()
	_scene.tween_interval(0.3)
	_scene.tween_callback(cue.emit.bind("pane"))
	_scene.tween_callback(_put_out.bind(glint))
	_rise(pane, 0.35)
	_scene.parallel().tween_method(_set_music_dip, 0.0, 0.5, Motion.duration("reveal"))
	_scene.tween_property(ghost, "albedo_color:a", 0.75, 0.5)
	_scene.tween_interval(MEMORY_TIME)
	_scene.tween_callback(cue.emit.bind("fade"))
	_scene.tween_property(ghost, "albedo_color:a", 0.0, 0.5)
	_sink(pane)
	_scene.parallel().tween_method(_set_music_dip, 0.5, 0.0, 1.2)
	_scene.tween_callback(func() -> void:
		for figure: CharacterVisual in figures:
			figure.queue_free()
		pane.queue_free()
		finished.emit())

## One remembered figure: a pose and a place. `mirror` makes it her sister
## (the mitten on the other hand).
func _figure(entry: Dictionary, ghost: Material) -> CharacterVisual:
	var figure := CharacterVisual.new()
	figure.self_driven = true
	add_child(figure)
	figure.position = Geometry.vector(entry["at"])
	var face := Geometry.vector(entry.get("face", story["keepsake"])) - figure.position
	figure.rotation.y = atan2(face.x, face.z)
	if entry.get("mirror", false):
		figure.scale = Vector3(-1.0, 1.0, 1.0)
	var pose := str(entry.get("pose", "Idle"))
	if pose == "Wave":
		figure.play_action("Wave")
	elif pose != "Idle":
		figure.hold_pose(pose, float(entry.get("time", 0.0)))
	for node: Node in figure.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = ghost
	return figure

# --- The hand mirror and the glimpse ------------------------------------------

func _find() -> void:
	var visual := _visual()
	var at := Geometry.vector(story["keepsake"])
	_face(at)
	_scene = create_tween()
	_scene.tween_interval(0.3)
	if visual != null:
		_scene.tween_callback(visual.play_action.bind("Lift"))
	_scene.tween_interval(0.45)
	_scene.tween_property(keepsake, "position", walker.position + Vector3.UP * 0.42, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_scene.parallel().tween_property(keepsake, "scale", Vector3.ONE * 0.4, 0.6)
	_scene.tween_callback(func() -> void:
		_put_out(keepsake)
		keepsake = null)
	_scene.tween_interval(0.5)
	_scene.tween_callback(_glimpse)

## A pane of frost stands up between her and where her sister was; in it,
## her mirror image waves. Then her sister's footprints go on across the snow.
func _glimpse() -> void:
	var feet := walker.position
	var sister := Geometry.vector(story["glimpse"])
	var across := sister - feet
	across.y = 0.0
	var normal := across.normalized() if across.length() > 0.01 else Vector3.RIGHT
	var middle := (feet + sister) * 0.5
	var pane := _pane(Vector3(middle.x, feet.y, middle.z), normal, Vector2(1.0, 1.15))
	# Her sister: the same girl, reflected in the pane.
	var twin := CharacterVisual.new()
	twin.self_driven = true
	add_child(twin)
	var reflect := _reflection(normal)
	var her := _visual()
	var her_basis := her.global_basis if her != null else Basis.IDENTITY
	twin.global_transform = Transform3D(reflect * her_basis, middle + reflect * (feet - middle))
	var ghost := _ghost_material()
	for node: Node in twin.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = ghost
	_scene = create_tween()
	_scene.tween_callback(cue.emit.bind("glimpse"))
	_rise(pane, 0.3)
	_scene.parallel().tween_method(_set_music_dip, 0.0, 1.0, Motion.duration("reveal"))
	_scene.tween_property(ghost, "albedo_color:a", 0.8, 0.5)
	_scene.tween_callback(twin.play_action.bind("Wave"))
	_scene.tween_interval(GLIMPSE_TIME)
	_scene.tween_property(ghost, "albedo_color:a", 0.0, 0.4)
	_scene.tween_callback(twin.queue_free)
	_sink(pane)
	_scene.tween_callback(pane.queue_free)
	# Her sister's footprints, one by one, where there were none.
	var prints: Array[Node3D] = []
	if props != null and props.has_method("add_prints"):
		var way := PackedVector3Array()
		for point: Variant in story.get("way", []):
			way.append(Geometry.vector(point))
		prints = props.add_prints(way, Color(0.82, 0.92, 1.0, 0.85), 1.0)
		for step: Node3D in prints:
			step.visible = false
	for step: Node3D in prints:
		_scene.tween_interval(WAY_STEP)
		_scene.tween_callback(step.set_visible.bind(true))
	_scene.parallel().tween_method(_set_music_dip, 1.0, 0.0, 1.6)
	_scene.tween_interval(0.4)
	_scene.tween_callback(func() -> void:
		active = false
		finished.emit())

# --- Pieces ------------------------------------------------------------------

## She turns to face a point before a beat.
func _face(point: Vector3) -> void:
	var visual := _visual()
	if visual == null:
		return
	var toward := point - walker.position
	if Vector2(toward.x, toward.z).length() < 0.01:
		return
	create_tween().tween_property(visual, "rotation:y",
		visual.rotation.y + angle_difference(visual.rotation.y, atan2(toward.x, toward.z)), 0.3)

func _pane(feet: Vector3, normal: Vector3, size: Vector2) -> MeshInstance3D:
	var pane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	quad.center_offset = Vector3(0.0, size.y * 0.5, 0.0)
	pane.mesh = quad
	var frost := StandardMaterial3D.new()
	frost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	frost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frost.cull_mode = BaseMaterial3D.CULL_DISABLED
	frost.albedo_color = Color(0.9, 0.95, 1.0, 0.0)
	pane.material_override = frost
	pane.position = feet
	pane.basis = Basis.looking_at(normal, Vector3.UP)
	pane.scale = Vector3(1.0, 0.02, 1.0)
	add_child(pane)
	return pane

## The pane forms from the ground like ice.
func _rise(pane: MeshInstance3D, alpha: float) -> void:
	var frost := pane.material_override as StandardMaterial3D
	_scene.tween_property(pane, "scale:y", 1.0, Motion.duration("reveal")).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_scene.parallel().tween_property(frost, "albedo_color:a", alpha, Motion.duration("reveal"))

func _sink(pane: MeshInstance3D) -> void:
	var frost := pane.material_override as StandardMaterial3D
	_scene.tween_property(frost, "albedo_color:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_scene.parallel().tween_property(pane, "scale:y", 0.02, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Pale and frosted, but lit, so a remembered figure keeps its shape.
static func _ghost_material() -> StandardMaterial3D:
	var ghost := StandardMaterial3D.new()
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.albedo_color = Color(0.86, 0.92, 1.0, 0.0)
	ghost.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	ghost.emission_enabled = true
	ghost.emission = Color(0.6, 0.7, 0.85)
	ghost.emission_energy_multiplier = 0.55
	ghost.rim_enabled = true
	ghost.rim = 0.6
	return ghost

## A soft light that breathes on a thing that matters, with a small star.
func _glint(at: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 0.7
	light.light_energy = 0.0
	light.position = Vector3.UP * 0.3
	root.add_child(light)
	var star := Sprite3D.new()
	star.texture = _star_texture()
	star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star.pixel_size = 0.0022
	star.shaded = false
	star.modulate = Color(1, 1, 1, 0)
	star.position = Vector3(0.0, 0.12, 0.0)
	root.add_child(star)
	var loop := create_tween().set_loops()
	loop.tween_property(light, "light_energy", 0.7, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(star, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_property(light, "light_energy", 0.15, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.parallel().tween_property(star, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loops.append(loop)
	root.set_meta("loop", loop)
	return root

## Ends a glint and its breathing.
func _put_out(glint: Node3D) -> void:
	var loop: Tween = glint.get_meta("loop")
	if loop != null and loop.is_valid():
		loop.kill()
	glint.queue_free()

## The small oval hand mirror lying on the ice, glinting cool.
func _build_keepsake(at: Vector3) -> Node3D:
	var root := _glint(at + Vector3.UP * 0.012, Color("dfeeff"))
	var rim_material := _material(Color("8a6a3a"), 0.0)
	for part: Array in [[0.085, 0.018, rim_material], [0.068, 0.02, _material(Color("e9f2f8"), 1.4)]]:
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = part[0]
		mesh.bottom_radius = part[0]
		mesh.height = part[1]
		disc.mesh = mesh
		disc.scale = Vector3(1.0, 1.0, 1.3)
		disc.material_override = part[2]
		root.add_child(disc)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.026, 0.016, 0.11)
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.0, 0.15)
	handle.material_override = rim_material
	root.add_child(handle)
	return root

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

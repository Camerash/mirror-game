class_name CharacterVisual
extends Node3D
## Presentation-only motion for her: Idle, Walk and one-shot actions.
##
## The model (`assets/character/girl.glb`, built from `art_sources/girl/`)
## carries every motion as a named animation. This script picks between them:
## Walk while she moves, at the speed she is moving; Idle while she stands;
## and the one-shots the game asks for with `play_action`. The player is
## advanced by hand from `update_motion`, so pausing the game freezes her.

signal action_finished(name: String)

const Geometry := preload("res://core/world_geometry.gd")
const GirlScene := preload("res://assets/character/girl.glb")
const IDLE := "Idle"
const WALK := "Walk"
const GARMENT := "Coat"
## One-shots that end holding their last pose until `play_action("Lower")`
## or until she walks.
const HOLDS: Array[String] = ["Raise", "Lift"]
## The ground speed the Walk is authored for: `MirrorWalker.SPEED`. At this
## speed her planted foot moves with the ground, so it does not slide.
const WALK_SPEED := 1.1
## The slowest the Walk plays. Below `MirrorWalker.MIN_PACE` / `WALK_SPEED`
## (0.23) so easing in and out never clamps it and her feet do not slide.
const WALK_SCALE_MIN := 0.2
## Below this the character is standing, not walking.
const MOVING_SPEED := 0.05
## Seconds to cross-fade between motions.
const BLEND_TIME := 0.18
## The longest step the animation is advanced by. A long frame gap is cut
## rather than paid back as one lurch.
const MAX_STEP := 0.1
## The stage light is dim and tuned for near-white ceramic with a strong sky
## reflection. Her flat felt colours (sampled from the concept) would read grey
## in it, so each material is relit: matte, soft-wrapped shading, and part of
## its own colour given back as emission so the colour holds on the shadow side.
const TONE_LIFT := 0.45
const TONE_ROUGHNESS := 0.9
const TONE_SPECULAR := 0.2
const TONE_RIM := 0.25
## The model measures this tall with its feet at the origin. The walker's
## capsule is the authority on size, so the model is scaled to match it.
const MODEL_HEIGHT := 0.8

var primary_mesh: MeshInstance3D
var player: AnimationPlayer
var facing := 0.0
var turn_rate := 0.0
## The one-shot playing or holding, or "" while she idles or walks.
var action := ""
var holding := false
var frozen := false
## A figure no walker drives (her sister in the glass) runs its own clock.
var self_driven := false
## Her meshes and materials, tuned once for the game's light and shared by
## every figure of her.
static var _lit_meshes := {}
static var _tuned_materials := {}


func _ready() -> void:
	var girl := GirlScene.instantiate() as Node3D
	girl.scale = Vector3.ONE * (Geometry.HEIGHT / MODEL_HEIGHT)
	add_child(girl)
	primary_mesh = girl.find_child(GARMENT, true, false) as MeshInstance3D
	_relight(girl)
	for node: Node in girl.find_children("*", "AnimationPlayer", true, false):
		player = node as AnimationPlayer
		break
	if player != null:
		# glTF carries no loop flag, so the cycles are closed here.
		for name: String in [IDLE, WALK]:
			if player.has_animation(name):
				player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.animation_finished.connect(_on_animation_finished)
	facing = rotation.y
	_stand()


func _process(delta: float) -> void:
	if self_driven:
		update_motion(delta, Vector3.ZERO, true, false)


func update_motion(delta: float, movement: Vector3, is_grounded: bool, is_paused: bool) -> void:
	if is_paused:
		# The game holds her still while it edits or tells a story beat, but
		# an action she was given (waking, lifting, raising) plays on.
		if player != null and action != "" and not frozen:
			player.advance(minf(maxf(delta, 0.0), MAX_STEP))
		return
	var planar_speed := Vector2(movement.x, movement.z).length()
	if planar_speed > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(movement.x, movement.z), minf(delta * 8.0, 1.0))
	var step := minf(maxf(delta, 0.0), MAX_STEP)
	turn_rate = angle_difference(facing, rotation.y) / maxf(step, 0.001)
	facing = rotation.y
	if player == null:
		return
	var moving := planar_speed > MOVING_SPEED
	if moving and (frozen or action != ""):
		# Walking ends any one-shot or held pose.
		frozen = false
		action = ""
		holding = false
	if frozen or not is_grounded:
		# Off the ground there are no steps to take, so she holds where she is.
		return
	if action == "":
		var wanted := WALK if moving else IDLE
		if player.current_animation != wanted and player.has_animation(wanted):
			player.play(wanted, BLEND_TIME)
		player.speed_scale = clampf(planar_speed / WALK_SPEED, WALK_SCALE_MIN, 2.0) if moving else 1.0
	player.advance(step)


func reset_motion() -> void:
	turn_rate = 0.0
	facing = rotation.y
	action = ""
	holding = false
	frozen = false
	_stand()


## Play a one-shot: Wake, Lift, Raise, Lower or Wave. Raise and Lift end
## holding; the others return to Idle (or Walk) when they finish.
## `action_finished` is emitted when the animation reaches its end.
func play_action(name: String) -> void:
	if player == null or not player.has_animation(name):
		push_warning("CharacterVisual: no animation %s" % name)
		return
	frozen = false
	holding = false
	action = name
	player.speed_scale = 1.0
	player.play(name, BLEND_TIME)


## Freeze on one frame of an animation, for example lying before Wake. She
## stays there until `play_action`, `reset_motion`, or she walks.
func hold_pose(name: String, at := 0.0) -> void:
	if player == null or not player.has_animation(name):
		push_warning("CharacterVisual: no animation %s" % name)
		return
	action = name
	holding = true
	frozen = true
	player.speed_scale = 1.0
	player.play(name, 0.0)
	player.seek(at, true)


func _relight(root: Node) -> void:
	# Headless runs (the tests) have no lighting to tune for, and the dummy
	# renderer rejects these materials with an error per surface.
	if DisplayServer.get_name() == "headless":
		return
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		# The tuned materials live on a shared copy of the mesh, not as
		# per-instance surface overrides, so a `material_override` (the fall
		# ghost, her sister in the glass) sits on top cleanly; overrides of
		# both kinds on one instance make the renderer error when it is freed.
		if not _lit_meshes.has(mesh.mesh):
			var lit := mesh.mesh.duplicate() as Mesh
			for surface: int in lit.get_surface_count():
				var source := lit.surface_get_material(surface) as BaseMaterial3D
				if source != null:
					lit.surface_set_material(surface, _tuned(source))
			_lit_meshes[mesh.mesh] = lit
		mesh.mesh = _lit_meshes[mesh.mesh]


static func _tuned(source: BaseMaterial3D) -> StandardMaterial3D:
	if _tuned_materials.has(source):
		return _tuned_materials[source]
	var material := StandardMaterial3D.new()
	material.resource_name = source.resource_name
	material.albedo_color = source.albedo_color
	material.metallic = 0.0
	material.metallic_specular = TONE_SPECULAR
	material.roughness = TONE_ROUGHNESS
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	material.emission_enabled = true
	material.emission = source.albedo_color
	material.emission_energy_multiplier = TONE_LIFT
	material.rim_enabled = true
	material.rim = TONE_RIM
	material.rim_tint = 0.6
	_tuned_materials[source] = material
	return material


func _stand() -> void:
	if player != null and player.has_animation(IDLE):
		player.speed_scale = 1.0
		player.play(IDLE, 0.0)
		player.seek(0.0, true)


func _on_animation_finished(anim_name: StringName) -> void:
	var name := String(anim_name)
	if name != action:
		return
	if name in HOLDS:
		holding = true
	else:
		action = ""
		holding = false
	action_finished.emit(name)

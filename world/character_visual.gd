class_name CharacterVisual
extends Node3D
## Presentation-only motion for the traveller.
##
## The traveller is skinned, carries its own walk cycle, and carries the three
## cloak deformations the design asks for, so this script does two things only:
## it runs the walk at the speed the character is moving, and it damps the
## cloak against what the body is doing.

const Geometry := preload("res://core/world_geometry.gd")
const TravellerScene := preload("res://assets/character/traveller.glb")
const WALK := "Walk"
const GARMENT := "Garment"

## The three cloak deformations, authored in `build_cloak.py`. Each reads its
## own cap at a weight of 1, so clamping the weight is the whole of clamping
## the deformation and nothing here needs to know the geometry.
const DRIFT_SHAPES := ["CloakSide", "CloakForward", "CloakTwist"]
## Seconds for the cloth to close half the distance to where the body has gone.
const DRIFT_HALF_LIFE := 0.18
## The longest step the damping acts on. A long frame gap must not be paid back
## as one lurch, so time past this is dropped rather than carried.
const DRIFT_MAX_STEP := 0.1
## How hard movement and turning drive the cloth. Weights clamp to one, which is
## the design's cap.
const DRIFT_PER_SPEED := 1.0
const DRIFT_PER_TURN := 0.55
## Yaw rate, in radians a second, that counts as a full turn.
const FULL_TURN_RATE := 2.4
## The speed the cycle is authored for: `MirrorWalker.SPEED`.
const WALK_SPEED := 2.0
## Below this the character is standing, not walking.
const MOVING_SPEED := 0.05
## Where in the cycle the legs pass each other. Standing holds here rather than
## wherever the walk happened to stop, which would be mid-stride.
const STAND_TIME := 0.25
## The model measures this tall with its feet at the origin. The walker's
## capsule is the authority on size, so the model is scaled to match it.
const MODEL_HEIGHT := 3.428

var primary_mesh: MeshInstance3D
var player: AnimationPlayer
var drift := Vector3.ZERO
var drift_shapes: PackedInt32Array = PackedInt32Array()
var facing := 0.0
var turn_rate := 0.0


func _ready() -> void:
	var traveller := TravellerScene.instantiate() as Node3D
	traveller.scale = Vector3.ONE * (Geometry.HEIGHT / MODEL_HEIGHT)
	add_child(traveller)
	primary_mesh = traveller.find_child(GARMENT, true, false) as MeshInstance3D
	for node: Node in traveller.find_children("*", "AnimationPlayer", true, false):
		player = node as AnimationPlayer
		break
	if player != null and player.has_animation(WALK):
		# glTF carries no loop flag, so the cycle is closed here.
		player.get_animation(WALK).loop_mode = Animation.LOOP_LINEAR
		player.play(WALK)
		player.seek(STAND_TIME, true)
		player.pause()
	if primary_mesh != null:
		for name: String in DRIFT_SHAPES:
			drift_shapes.append(primary_mesh.find_blend_shape_by_name(name))
	facing = rotation.y
	_apply_drift()


func update_motion(delta: float, movement: Vector3, is_grounded: bool, is_paused: bool) -> void:
	if is_paused:
		return
	var planar_velocity := Vector2(movement.x, movement.z)
	var planar_speed := planar_velocity.length()
	if planar_speed > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(movement.x, movement.z), minf(delta * 12.0, 1.0))
	var step := minf(maxf(delta, 0.0), DRIFT_MAX_STEP)
	turn_rate = angle_difference(facing, rotation.y) / maxf(step, 0.001)
	facing = rotation.y
	_advance_walk(step, planar_speed, is_grounded)
	_advance_drift(step, movement, planar_speed)


func reset_motion() -> void:
	drift = Vector3.ZERO
	turn_rate = 0.0
	facing = rotation.y
	if player != null and player.has_animation(WALK):
		player.play(WALK)
		player.seek(STAND_TIME, true)
		player.pause()
	_apply_drift()


func _advance_walk(step: float, planar_speed: float, is_grounded: bool) -> void:
	## The cycle runs at the speed the character is actually moving. Off the
	## ground there are no steps to take, so it holds where it is.
	if player == null or not player.has_animation(WALK):
		return
	if not is_grounded:
		player.pause()
		return
	if planar_speed <= MOVING_SPEED:
		player.play(WALK)
		player.seek(STAND_TIME, true)
		player.pause()
		return
	player.speed_scale = clampf(planar_speed / WALK_SPEED, 0.25, 2.0)
	if not player.is_playing():
		player.play(WALK)
	player.advance(step)


func _advance_drift(step: float, movement: Vector3, planar_speed: float) -> void:
	## The cloth trails what the body has already done, so the target is where
	## the body is going and the damping is what makes the cloth late.
	var local: Vector3 = transform.basis.inverse() * movement
	var forward_share := clampf(local.z / WALK_SPEED, -1.0, 1.0)
	var turn_share := clampf(turn_rate / FULL_TURN_RATE, -1.0, 1.0)
	if planar_speed <= MOVING_SPEED:
		forward_share = 0.0
	var target := Vector3(
		clampf(-turn_share * DRIFT_PER_TURN, -1.0, 1.0),
		clampf(-forward_share * DRIFT_PER_SPEED, -1.0, 1.0),
		clampf(-turn_share * DRIFT_PER_TURN, -1.0, 1.0))
	var closed := 1.0 - pow(0.5, step / DRIFT_HALF_LIFE)
	drift = drift.lerp(target, closed)
	_apply_drift()


func _apply_drift() -> void:
	if primary_mesh == null or drift_shapes.size() != DRIFT_SHAPES.size():
		return
	var weights := [drift.x, drift.y, drift.z]
	for index: int in drift_shapes.size():
		if drift_shapes[index] >= 0:
			primary_mesh.set_blend_shape_value(drift_shapes[index],
				clampf(weights[index], -1.0, 1.0))

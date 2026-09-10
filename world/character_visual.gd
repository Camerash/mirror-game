class_name CharacterVisual
extends Node3D
## Presentation-only motion for the ceramic traveller.

const TravellerScene := preload("res://assets/character/ceramic_traveller.glb")
const STEP_RATE := 9.0
const FOOT_SWING := 0.32
const HEM_SWAY_LIMIT := 0.035

var left_foot: Node3D
var right_foot: Node3D
var primary_mesh: MeshInstance3D
var gait_phase := 0.0
var hem_offset := Vector2.ZERO
var last_planar_velocity := Vector2.ZERO
var left_foot_rest := Transform3D.IDENTITY
var right_foot_rest := Transform3D.IDENTITY

func _ready() -> void:
	var traveller := TravellerScene.instantiate() as Node3D
	add_child(traveller)
	left_foot = traveller.find_child("FootLeft", true, false) as Node3D
	right_foot = traveller.find_child("FootRight", true, false) as Node3D
	primary_mesh = traveller.find_child("Cloak", true, false) as MeshInstance3D
	if left_foot != null:
		left_foot_rest = left_foot.transform
	if right_foot != null:
		right_foot_rest = right_foot.transform

func update_motion(delta: float, movement: Vector3, is_grounded: bool, is_paused: bool) -> void:
	if is_paused:
		return
	var planar_velocity := Vector2(movement.x, movement.z)
	var planar_speed := planar_velocity.length()
	if planar_speed > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(movement.x, movement.z), minf(delta * 12.0, 1.0))
	if is_grounded:
		gait_phase += delta * STEP_RATE * minf(planar_speed / 2.0, 1.0)
	var local_velocity: Vector3 = transform.basis.inverse() * movement
	var world_acceleration := (planar_velocity - last_planar_velocity) / maxf(delta, 0.001)
	var acceleration := transform.basis.inverse() * Vector3(world_acceleration.x, 0.0, world_acceleration.y)
	var target_offset := Vector2(-local_velocity.x, -local_velocity.z) * 0.009 - Vector2(acceleration.x, acceleration.z) * 0.0015
	hem_offset = hem_offset.lerp(target_offset.limit_length(HEM_SWAY_LIMIT), minf(delta * 7.0, 1.0))
	last_planar_velocity = planar_velocity
	_apply_hem()
	var step := sin(gait_phase) * FOOT_SWING * minf(planar_speed / 2.0, 1.0)
	_set_foot_step(left_foot, step)
	_set_foot_step(right_foot, -step)

func reset_motion() -> void:
	gait_phase = 0.0
	hem_offset = Vector2.ZERO
	last_planar_velocity = Vector2.ZERO
	_apply_hem()
	_set_foot_step(left_foot, 0.0)
	_set_foot_step(right_foot, 0.0)

func _set_foot_step(foot: Node3D, step: float) -> void:
	if foot == null:
		return
	var rest := left_foot_rest if foot == left_foot else right_foot_rest
	foot.transform = rest
	foot.position.y += maxf(step, 0.0) * 0.018
	foot.rotation.x += step

func _apply_hem() -> void:
	if primary_mesh == null:
		return
	for pair: Array in [["HemX", hem_offset.x], ["HemZ", hem_offset.y]]:
		var index := primary_mesh.find_blend_shape_by_name(pair[0])
		if index >= 0:
			primary_mesh.set_blend_shape_value(index, float(pair[1]) / HEM_SWAY_LIMIT)

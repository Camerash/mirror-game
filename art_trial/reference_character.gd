class_name ReferenceCharacter
extends Node3D
## Presentation-only motion for the separate reference traveller asset.

const CharacterScene := preload("res://assets/reference/character.glb")
const STEP_RATE := 8.0
const TURN_RATE := 11.0
const FOOT_SWING := 0.26
const HEM_SWAY_LIMIT := 0.032

var left_foot: Node3D
var right_foot: Node3D
var cloak: MeshInstance3D
var gait_phase := 0.0
var hem_offset := Vector2.ZERO
var left_foot_rest := Transform3D.IDENTITY
var right_foot_rest := Transform3D.IDENTITY

func _ready() -> void:
	var traveller := CharacterScene.instantiate() as Node3D
	add_child(traveller)
	left_foot = traveller.find_child("FootLeft", true, false) as Node3D
	right_foot = traveller.find_child("FootRight", true, false) as Node3D
	cloak = traveller.find_child("Cloak", true, false) as MeshInstance3D
	if left_foot != null:
		left_foot_rest = left_foot.transform
	if right_foot != null:
		right_foot_rest = right_foot.transform

func update_motion(delta: float, velocity: Vector3, grounded := true, paused := false) -> void:
	if paused:
		return
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), minf(delta * TURN_RATE, 1.0))
	if grounded:
		gait_phase += delta * STEP_RATE * minf(planar_speed / 2.0, 1.0)
	var local_velocity := transform.basis.inverse() * velocity
	var target_hem := Vector2(-local_velocity.x, -local_velocity.z) * 0.011
	hem_offset = hem_offset.lerp(target_hem.limit_length(HEM_SWAY_LIMIT), minf(delta * 7.0, 1.0))
	_apply_hem()
	var step := sin(gait_phase) * FOOT_SWING * minf(planar_speed / 2.0, 1.0)
	_set_foot_step(left_foot, left_foot_rest, step)
	_set_foot_step(right_foot, right_foot_rest, -step)

func reset_motion() -> void:
	gait_phase = 0.0
	hem_offset = Vector2.ZERO
	_apply_hem()
	_set_foot_step(left_foot, left_foot_rest, 0.0)
	_set_foot_step(right_foot, right_foot_rest, 0.0)

func _set_foot_step(foot: Node3D, rest: Transform3D, step: float) -> void:
	if foot == null:
		return
	foot.transform = rest
	foot.position.y += maxf(step, 0.0) * 0.018
	foot.rotation.x += step

func _apply_hem() -> void:
	if cloak == null:
		return
	for pair: Array in [["HemX", hem_offset.x], ["HemZ", hem_offset.y]]:
		var index := cloak.find_blend_shape_by_name(pair[0])
		if index >= 0:
			cloak.set_blend_shape_value(index, float(pair[1]) / HEM_SWAY_LIMIT)

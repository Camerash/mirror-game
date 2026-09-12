class_name ReferenceCharacter
extends Node3D
## Presentation-only motion for the separate reference traveller asset.

const CharacterScene := preload("res://assets/reference/character.glb")
const STEP_RATE := 8.0
const TURN_RATE := 11.0
const FOOT_SWING := 0.26
const HEM_SWAY_LIMIT := 0.032
const HEM_TWIST_LIMIT := PI / 30.0
const CLOTH_RESPONSE := 12.0
const MAX_MOTION_DELTA := 1.0 / 30.0

var left_foot: Node3D
var right_foot: Node3D
var cloak: MeshInstance3D
var gait_phase := 0.0
var hem_offset := Vector2.ZERO
var hem_twist := 0.0
var cloth_velocity := Vector3.ZERO
var previous_velocity := Vector3.ZERO
var has_motion_history := false
var hem_x_index := -1
var hem_z_index := -1
var hem_twist_index := -1
var left_foot_rest := Transform3D.IDENTITY
var right_foot_rest := Transform3D.IDENTITY

func _ready() -> void:
	var traveller := CharacterScene.instantiate() as Node3D
	add_child(traveller)
	_soften_materials(traveller)
	left_foot = traveller.find_child("FootLeft", true, false) as Node3D
	right_foot = traveller.find_child("FootRight", true, false) as Node3D
	cloak = traveller.find_child("Cloak", true, false) as MeshInstance3D
	if cloak != null:
		hem_x_index = cloak.find_blend_shape_by_name("HemX")
		hem_z_index = cloak.find_blend_shape_by_name("HemZ")
		hem_twist_index = cloak.find_blend_shape_by_name("HemTwist")
	if left_foot != null:
		left_foot_rest = left_foot.transform
	if right_foot != null:
		right_foot_rest = right_foot.transform

func update_motion(delta: float, velocity: Vector3, grounded := true, paused := false) -> void:
	if paused:
		has_motion_history = false
		return
	if delta <= 0.0 or not is_finite(delta) or not velocity.is_finite():
		return
	# Discard stall time rather than applying a large cloth impulse after a pause.
	var step_delta := minf(delta, MAX_MOTION_DELTA)
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var previous_yaw := rotation.y
	if planar_speed > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), 1.0 - exp(-TURN_RATE * step_delta))
	var turn_speed := angle_difference(previous_yaw, rotation.y) / step_delta
	var acceleration := (velocity - previous_velocity) / step_delta if has_motion_history else Vector3.ZERO
	previous_velocity = velocity
	has_motion_history = true
	var gait_weight := minf(planar_speed / 0.65, 1.0) if grounded else 0.0
	if grounded:
		gait_phase = fmod(gait_phase + step_delta * STEP_RATE * minf(planar_speed / 2.0, 1.0), TAU)
	var local_velocity := transform.basis.inverse() * velocity
	var local_acceleration := transform.basis.inverse() * acceleration.limit_length(12.0)
	var sway := Vector2(sin(gait_phase) * 0.006, cos(gait_phase * 2.0) * 0.002) * gait_weight
	var trail := -Vector2(local_velocity.x, local_velocity.z) * 0.032 - Vector2(local_acceleration.x, local_acceleration.z) * 0.001
	var target := (trail + sway).limit_length(HEM_SWAY_LIMIT)
	_step_cloth(step_delta, Vector3(target.x, target.y, clampf(-turn_speed * 0.025, -HEM_TWIST_LIMIT, HEM_TWIST_LIMIT)))
	_apply_hem()
	var foot_step := sin(gait_phase) * FOOT_SWING * gait_weight
	_set_foot_step(left_foot, left_foot_rest, foot_step)
	_set_foot_step(right_foot, right_foot_rest, -foot_step)


func _step_cloth(delta: float, target: Vector3) -> void:
	# Exact critically damped spring step for a constant target; no solver nodes.
	var position := Vector3(hem_offset.x, hem_offset.y, hem_twist)
	var displacement := position - target
	var impulse := cloth_velocity + displacement * CLOTH_RESPONSE
	var decay := exp(-CLOTH_RESPONSE * delta)
	position = target + (displacement + impulse * delta) * decay
	cloth_velocity = (cloth_velocity - impulse * CLOTH_RESPONSE * delta) * decay
	hem_offset = Vector2(position.x, position.y).limit_length(HEM_SWAY_LIMIT)
	hem_twist = clampf(position.z, -HEM_TWIST_LIMIT, HEM_TWIST_LIMIT)


func reset_motion() -> void:
	gait_phase = 0.0
	hem_offset = Vector2.ZERO
	hem_twist = 0.0
	cloth_velocity = Vector3.ZERO
	previous_velocity = Vector3.ZERO
	has_motion_history = false
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
	if hem_x_index >= 0:
		cloak.set_blend_shape_value(hem_x_index, hem_offset.x / HEM_SWAY_LIMIT)
	if hem_z_index >= 0:
		cloak.set_blend_shape_value(hem_z_index, hem_offset.y / HEM_SWAY_LIMIT)
	if hem_twist_index >= 0:
		cloak.set_blend_shape_value(hem_twist_index, hem_twist / HEM_TWIST_LIMIT)


# Use local copies so imported and gameplay materials remain unchanged.
func _soften_materials(node: Node) -> void:
	if node is MeshInstance3D:
		node.mesh = node.mesh.duplicate()
		for index: int in node.mesh.get_surface_count():
			var source := node.get_active_material(index) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.roughness = maxf(material.roughness, 0.72)
			material.metallic_specular = 0.2
			node.mesh.surface_set_material(index, material)
	for child: Node in node.get_children():
		_soften_materials(child)

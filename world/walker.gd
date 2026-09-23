class_name MirrorWalker
extends CharacterBody3D

const Geometry := preload("res://core/world_geometry.gd")
const CharacterVisual := preload("res://world/character_visual.gd")
const SPEED := 2.0
const GRAVITY := 9.8
signal route_finished

var build_visuals := true
var grounded := false
var paused := false
var route := PackedVector3Array()
var character_visual: CharacterVisual

func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = Geometry.RADIUS
	shape.height = Geometry.HEIGHT
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = Geometry.HEIGHT * 0.5
	add_child(collider)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.12
	floor_max_angle = PI * 0.25
	floor_stop_on_slope = true
	floor_constant_speed = true
	safe_margin = 0.001
	if build_visuals:
		character_visual = CharacterVisual.new()
		add_child(character_visual)

func _physics_process(delta: float) -> void:
	if paused:
		if character_visual != null:
			character_visual.update_motion(delta, Vector3.ZERO, grounded, true)
		return
	advance_motion(delta)

func advance_motion(delta: float) -> void:
	# Also used by the isolated fall predictor at the same physics tick rate.
	var was_walking := not route.is_empty()
	if not grounded:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	if grounded or not route.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
	while not route.is_empty() and Vector2(position.x, position.z).distance_to(Vector2(route[0].x, route[0].z)) < 0.025:
		route.remove_at(0)
	if not route.is_empty():
		var offset := route[0] - position
		offset.y = 0.0
		var movement := offset.normalized() * minf(SPEED, offset.length() / delta)
		velocity.x = movement.x
		velocity.z = movement.z
	move_and_slide()
	grounded = is_on_floor()
	if character_visual != null:
		character_visual.update_motion(delta, velocity, grounded, false)
	if was_walking and route.is_empty():
		route_finished.emit()

func stop() -> void:
	route.clear()
	velocity.x = 0.0
	velocity.z = 0.0

func restore(feet: Vector3, saved_velocity: Vector3) -> void:
	grounded = false
	position = feet
	velocity = saved_velocity
	route.clear()
	visible = true
	scale = Vector3.ONE
	if character_visual != null:
		character_visual.reset_motion()

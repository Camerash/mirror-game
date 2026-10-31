class_name MirrorWalker
extends CharacterBody3D

const Geometry := preload("res://core/world_geometry.gd")
const CharacterVisual := preload("res://world/character_visual.gd")
## Her top pace: a child's careful walk in snow. Her Walk animation is
## authored for this speed (`CharacterVisual.WALK_SPEED`), so her feet hold.
const SPEED := 1.1
## Seconds from standing to full pace.
const EASE_IN := 0.35
## Over this last stretch of a route she slows into her final step.
const EASE_OUT := 0.4
## The slowest she goes before she stops, so the last step always arrives.
const MIN_PACE := 0.25
const GRAVITY := 9.8
signal route_finished

var build_visuals := true
var grounded := false
var paused := false
var route := PackedVector3Array()
## Her current walking speed; eased toward the pace the route allows.
var pace := 0.0
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
	if route.is_empty():
		pace = 0.0
	else:
		var offset := route[0] - position
		offset.y = 0.0
		# Ease in from a stand, and slow over the last stretch of the route.
		var wanted := SPEED * clampf(_remaining() / EASE_OUT, 0.0, 1.0)
		pace = move_toward(pace, maxf(wanted, MIN_PACE), SPEED / EASE_IN * delta)
		var movement := offset.normalized() * minf(pace, offset.length() / delta)
		velocity.x = movement.x
		velocity.z = movement.z
	move_and_slide()
	grounded = is_on_floor()
	if character_visual != null:
		character_visual.update_motion(delta, velocity, grounded, false)
	if was_walking and route.is_empty():
		route_finished.emit()

## The ground distance left along the route.
func _remaining() -> float:
	var total := 0.0
	var from := Vector2(position.x, position.z)
	for point: Vector3 in route:
		var next := Vector2(point.x, point.z)
		total += from.distance_to(next)
		from = next
	return total

func stop() -> void:
	pace = 0.0
	route.clear()
	velocity.x = 0.0
	velocity.z = 0.0

func restore(feet: Vector3, saved_velocity: Vector3) -> void:
	grounded = false
	position = feet
	velocity = saved_velocity
	pace = 0.0
	route.clear()
	visible = true
	scale = Vector3.ONE
	if character_visual != null:
		character_visual.reset_motion()

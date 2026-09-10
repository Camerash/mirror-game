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
var face: Node3D
var visual_root: Node3D
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
		_build_visual(collider.position)

func _build_visual(centre: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = Geometry.RADIUS
	capsule.height = Geometry.HEIGHT
	mesh.mesh = capsule
	mesh.position = centre
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f8f1dd")
	material.roughness = 0.9
	mesh.material_override = material
	add_child(mesh)
	visual_root = mesh
	set_meta("visual", mesh)
	face = Node3D.new()
	mesh.add_child(face)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.018
		dot.height = 0.036
		eye.mesh = dot
		eye.position = Vector3(side * 0.055, 0.14, 0.164)
		var eye_material := StandardMaterial3D.new()
		eye_material.albedo_color = Color("fff3da")
		eye.material_override = eye_material
		face.add_child(eye)
	face.visible = false

func set_art_trial(enabled: bool) -> void:
	if not build_visuals:
		return
	if enabled and character_visual == null:
		if visual_root != null:
			visual_root.queue_free()
		character_visual = CharacterVisual.new()
		character_visual.ready.connect(_set_character_visual_meta, CONNECT_ONE_SHOT)
		add_child(character_visual)
		visual_root = character_visual
		face = null
	elif not enabled and character_visual != null:
		character_visual.queue_free()
		character_visual = null
		_build_visual(Vector3.UP * Geometry.HEIGHT * 0.5)
	if face != null:
		face.visible = false

func _set_character_visual_meta() -> void:
	if character_visual != null and character_visual.primary_mesh != null:
		set_meta("visual", character_visual.primary_mesh)

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
	if face != null and Vector2(velocity.x, velocity.z).length_squared() > 0.0:
		face.rotation.y = lerp_angle(face.rotation.y, atan2(velocity.x, velocity.z), minf(delta * 12.0, 1.0))
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

class_name FallPredictor
extends SubViewport
## A collision-only world. It never changes the committed game's physics space.

signal ready_result(result: Dictionary)

const Geometry := preload("res://core/world_geometry.gd")
const Walker := preload("res://world/walker.gd")
const TICKS_PER_BATCH := 180
const MAX_TICKS := 7200

var revision := 0
var request: Dictionary = {}
var scene := Node3D.new()
var body: CharacterBody3D
var path := PackedVector3Array()
var wait_frames := 0
var ticks := 0
var result: Dictionary = {"status": "idle"}

func _ready() -> void:
	size = Vector2i(2, 2)
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	world_3d = World3D.new()
	add_child(scene)

func predict(solids: Array[Dictionary], feet: Vector3, velocity: Vector3, kill_y: float) -> int:
	revision += 1
	request = {"solids": solids, "position": feet, "velocity": Vector3(0, velocity.y, 0), "kill_y": kill_y}
	result = {"status": "pending", "revision": revision}
	wait_frames = -1
	return revision

func cancel() -> void:
	revision += 1
	request.clear()
	_clear()
	result = {"status": "idle", "revision": revision}

func _physics_process(_delta: float) -> void:
	if request.is_empty() or result["status"] != "pending":
		return
	if wait_frames == -1:
		_build()
		return
	if wait_frames > 0:
		wait_frames -= 1
		return
	var delta := 1.0 / Engine.physics_ticks_per_second
	for tick: int in range(TICKS_PER_BATCH):
		body.advance_motion(delta)
		ticks += 1
		path.append(body.position)
		if body.position.y < float(request["kill_y"]):
			_finish("failure")
			return
		if body.is_on_floor():
			_finish("supported" if body.position.distance_to(request["position"]) < 0.02 else "landing")
			return
		if ticks >= MAX_TICKS:
			_finish("unresolved")
			return

func _build() -> void:
	_clear()
	path = PackedVector3Array([request["position"]])
	ticks = 0
	if Geometry.embedded(request["position"], request["solids"]):
		_finish("blocked")
		return
	for solid: Dictionary in request["solids"]:
		var bounds: AABB = solid["bounds"]
		var floor_body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		collider.shape = shape
		floor_body.position = bounds.get_center()
		floor_body.add_child(collider)
		scene.add_child(floor_body)
	body = Walker.new()
	body.build_visuals = false
	body.paused = true
	scene.add_child(body)
	body.restore(request["position"], request["velocity"])
	wait_frames = 1

func _finish(outcome: String) -> void:
	result = {"status": outcome, "revision": revision, "path": path,
		"position": path[-1], "seconds": float(ticks) / Engine.physics_ticks_per_second}
	ready_result.emit(result)

func _clear() -> void:
	for child: Node in scene.get_children():
		child.free()
	body = null

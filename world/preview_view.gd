extends Node3D
## The ghost is presentation only; prediction is supplied by FallPredictor.

const Geometry := preload("res://core/world_geometry.gd")
var ghost := MeshInstance3D.new()
var marks := Node3D.new()
var points := PackedVector3Array()
var elapsed := 0.0
var duration := 1.0

func _ready() -> void:
	add_child(marks)
	add_child(ghost)
	var capsule := CapsuleMesh.new()
	capsule.radius = Geometry.RADIUS
	capsule.height = Geometry.HEIGHT
	ghost.mesh = capsule
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clear()

func clear() -> void:
	points.clear()
	ghost.visible = false
	for child: Node in marks.get_children():
		child.queue_free()

func show_result(result: Dictionary, view: Node3D) -> void:
	clear()
	if result["status"] not in ["supported", "landing", "failure"]:
		return
	points = result["path"]
	elapsed = 0.0
	duration = clampf(float(result["seconds"]) * 1.5, 0.8, 3.0)
	var color := Color("f2c483") if result["status"] == "failure" else Color("c0f4eb")
	var material: StandardMaterial3D = view._plain(Color(color, 0.55))
	ghost.material_override = material
	ghost.visible = result["status"] != "supported"
	var segments := PackedVector3Array()
	for index: int in range(0, points.size() - 1, 2):
		segments.append(points[index] + Vector3.UP * 0.06)
		segments.append(points[mini(index + 1, points.size() - 1)] + Vector3.UP * 0.06)
	view._lines(marks, segments, color)
	view.add_ring(marks, points[-1], color, 0.27)
	if result["status"] == "failure":
		var end := points[-1] + Vector3.UP * 0.06
		view._lines(marks, PackedVector3Array([end + Vector3(-0.2, 0, -0.2), end + Vector3(0.2, 0, 0.2), end + Vector3(-0.2, 0, 0.2), end + Vector3(0.2, 0, -0.2)]), color)

func _process(delta: float) -> void:
	if points.is_empty():
		return
	elapsed += delta
	var fraction := minf(fmod(elapsed, duration + 0.6) / duration, 1.0)
	var sample := fraction * (points.size() - 1)
	var index := mini(int(sample), points.size() - 1)
	ghost.position = points[index].lerp(points[mini(index + 1, points.size() - 1)], sample - index) + Vector3.UP * Geometry.HEIGHT * 0.5

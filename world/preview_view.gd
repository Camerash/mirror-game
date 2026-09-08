extends Node3D
## The ghost is presentation only; prediction is supplied by FallPredictor.

const Geometry := preload("res://core/world_geometry.gd")
var ghost := MeshInstance3D.new()
var marks := Node3D.new()
var points := PackedVector3Array()
var elapsed := 0.0
var duration := 1.0
var result_status := ""
var overlay := TrajectoryOverlay.new()
var ghost_inner := MeshInstance3D.new()

class TrajectoryOverlay extends Control:
	var camera: Camera3D
	var path := PackedVector3Array()
	var status := ""
	var ghost_point := Vector3.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if camera == null or path.size() < 2:
			return
		var projected := PackedVector2Array()
		for point: Vector3 in path:
			projected.append(camera.unproject_position(point + Vector3.UP * 0.10))
		var outer := Color("162126", 0.92)
		var inner := Color("f0b86e") if status == "failure" else Color("bdf8ef")
		for index: int in range(projected.size() - 1):
			draw_line(projected[index], projected[index + 1], outer, 5.0, true)
		for index: int in range(projected.size() - 1):
			draw_line(projected[index], projected[index + 1], inner, 2.0, true)
		var end := projected[-1]
		var before := projected[-2]
		var direction := (end - before).normalized()
		var wing := Vector2(-direction.y, direction.x) * 5.0
		draw_colored_polygon(PackedVector2Array([end, end - direction * 12.0 + wing, end - direction * 12.0 - wing]), inner)
		if status != "supported":
			var bottom := camera.unproject_position(ghost_point + Vector3.UP * Geometry.RADIUS)
			var top := camera.unproject_position(ghost_point + Vector3.UP * (Geometry.HEIGHT - Geometry.RADIUS))
			var radius := maxf(5.0, camera.unproject_position(ghost_point + camera.global_basis.x * Geometry.RADIUS).distance_to(camera.unproject_position(ghost_point)))
			draw_line(bottom, top, outer, radius * 2.0 + 4.0, true)
			draw_circle(bottom, radius + 2.0, outer)
			draw_circle(top, radius + 2.0, outer)
			draw_line(bottom, top, inner, radius * 2.0, true)
			draw_circle(bottom, radius, inner)
			draw_circle(top, radius, inner)
		if status != "landing":
			return
		var label := "LANDING"
		var font := ThemeDB.fallback_font
		var label_position := end + Vector2(10, -12)
		draw_string(font, label_position + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, outer)
		draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, inner)

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	layer.add_child(overlay)
	add_child(layer)
	add_child(marks)
	add_child(ghost)
	add_child(ghost_inner)
	var capsule := CapsuleMesh.new()
	capsule.radius = Geometry.RADIUS
	capsule.height = Geometry.HEIGHT
	ghost.mesh = capsule
	ghost_inner.mesh = capsule
	ghost.scale = Vector3.ONE * 1.10
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clear()

func clear() -> void:
	points.clear()
	result_status = ""
	overlay.path = PackedVector3Array()
	overlay.status = ""
	overlay.queue_redraw()
	ghost.visible = false
	ghost_inner.visible = false
	for child: Node in marks.get_children():
		child.queue_free()

func show_result(result: Dictionary, view: Node3D) -> void:
	clear()
	if result["status"] not in ["supported", "landing", "failure"]:
		return
	points = result["path"]
	result_status = result["status"]
	overlay.path = points
	overlay.status = result_status
	overlay.queue_redraw()
	elapsed = 0.0
	duration = clampf(float(result["seconds"]) * 1.5, 0.8, 3.0)
	var color := Color("f2c483") if result["status"] == "failure" else Color("c0f4eb")
	var material: StandardMaterial3D = view._plain(Color("18242a", 0.78))
	var inner_material: StandardMaterial3D = view._plain(Color(color, 0.92))
	ghost.material_override = material
	ghost_inner.material_override = inner_material
	ghost.visible = result["status"] != "supported"
	ghost_inner.visible = ghost.visible
	view.add_ring(marks, points[-1], color, 0.27)
	if result["status"] == "failure":
		var end := points[-1] + Vector3.UP * 0.06
		view._lines(marks, PackedVector3Array([end + Vector3(-0.2, 0, -0.2), end + Vector3(0.2, 0, 0.2), end + Vector3(-0.2, 0, 0.2), end + Vector3(0.2, 0, -0.2)]), color)

func update_view(camera: Camera3D) -> void:
	overlay.camera = camera
	overlay.queue_redraw()

func _process(delta: float) -> void:
	if points.is_empty():
		return
	elapsed += delta
	var fraction := minf(fmod(elapsed, duration + 0.6) / duration, 1.0)
	var sample := fraction * (points.size() - 1)
	var index := mini(int(sample), points.size() - 1)
	ghost.position = points[index].lerp(points[mini(index + 1, points.size() - 1)], sample - index) + Vector3.UP * Geometry.HEIGHT * 0.5
	ghost_inner.position = ghost.position
	overlay.ghost_point = ghost.position - Vector3.UP * Geometry.HEIGHT * 0.5
	overlay.queue_redraw()

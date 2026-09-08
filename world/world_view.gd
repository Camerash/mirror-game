class_name MirrorWorldView
extends Node3D

const Paint := preload("res://world/painted.gdshader")
var visual_root := Node3D.new()
var collision_root := Node3D.new()
var overlay_root := Node3D.new()
var path_root := Node3D.new()
var contact_root := Node3D.new()
var trace_root := Node3D.new()
var contact_signature := ""
var trace_time := 0.0
var materials: Dictionary = {}
var drawn_solids: Array[Dictionary] = []
var debug_collision := false

func _ready() -> void:
	for node: Node3D in [visual_root, collision_root, overlay_root, path_root, contact_root, trace_root]:
		add_child(node)
	for kind: String in ["original", "reflected", "absolute"]:
		var material := ShaderMaterial.new()
		material.shader = Paint
		material.set_shader_parameter("pigment", {"original": Color("c4b59b"), "reflected": Color("7099bd"), "absolute": Color("d7b579")}[kind])
		material.set_shader_parameter("absolute_surface", kind == "absolute")
		materials[kind] = material

func commit(solids: Array[Dictionary]) -> void:
	_clear(collision_root)
	for solid: Dictionary in solids:
		var bounds: AABB = solid["bounds"]
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.position = bounds.get_center()
		body.add_child(collider)
		collision_root.add_child(body)
	draw_world(solids)

func draw_world(solids: Array[Dictionary]) -> void:
	drawn_solids = solids
	_clear(visual_root)
	for solid: Dictionary in solids:
		var bounds: AABB = solid["bounds"]
		var instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = bounds.size
		instance.mesh = mesh
		instance.position = bounds.get_center()
		instance.material_override = materials[solid["kind"]]
		visual_root.add_child(instance)
	update_debug()

func update_debug() -> void:
	_clear(overlay_root)
	for solid: Dictionary in drawn_solids:
		if debug_collision or solid["kind"] == "absolute":
			_outline_box(overlay_root, solid["bounds"], Color("a44836") if debug_collision else Color("715732"))

func _outline_box(parent: Node3D, bounds: AABB, color: Color, dashed := false) -> void:
	var points := PackedVector3Array()
	for edge: Vector2i in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 4), Vector2i(1, 3),
			Vector2i(1, 5), Vector2i(2, 3), Vector2i(2, 6), Vector2i(3, 7),
			Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 7), Vector2i(6, 7)]:
		var start := bounds.get_endpoint(edge.x)
		var finish := bounds.get_endpoint(edge.y)
		var count := maxi(1, ceili(start.distance_to(finish) / 0.12)) if dashed else 1
		for index: int in range(0, count, 2 if dashed else 1):
			points.append(start.lerp(finish, float(index) / count))
			points.append(start.lerp(finish, float(index + 1) / count))
	_lines(parent, points, color)

func show_contacts(contacts: Array) -> void:
	var signature := str(contacts)
	if signature == contact_signature:
		return
	contact_signature = signature
	_clear(contact_root)
	_clear(trace_root)
	trace_time = 1.6
	trace_root.visible = true
	for contact: Dictionary in contacts:
		_outline_box(contact_root, contact["bounds"].grow(0.006), Color("fff1ac"))
		_outline_box(trace_root, contact["reflected"].grow(0.008), Color("aadbec"), true)

func _process(delta: float) -> void:
	trace_time = maxf(0.0, trace_time - delta)
	trace_root.visible = trace_time > 0.0

func draw_route(path: PackedVector3Array) -> void:
	_clear(path_root)
	var points := PackedVector3Array()
	for index: int in range(path.size() - 1):
		points.append(path[index] + Vector3.UP * 0.025)
		points.append(path[index + 1] + Vector3.UP * 0.025)
	_lines(path_root, points, Color("3d6262"))
	if not path.is_empty():
		add_ring(path_root, path[-1], Color("3d6262"), 0.16)

func add_ring(parent: Node3D, feet: Vector3, color: Color, radius := 0.3) -> void:
	var node := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.72
	ring.outer_radius = radius
	ring.rings = 24
	ring.ring_segments = 8
	node.mesh = ring
	node.position = feet + Vector3.UP * 0.055
	node.material_override = _plain(color)
	parent.add_child(node)


func _lines(parent: Node3D, points: PackedVector3Array, color: Color) -> void:
	if points.is_empty():
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point: Vector3 in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _plain(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func _plain(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

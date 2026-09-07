class_name MirrorWorldView
extends Node3D

const Paint := preload("res://world/painted.gdshader")
var visual_root := Node3D.new()
var collision_root := Node3D.new()
var overlay_root := Node3D.new()
var boundary_root := Node3D.new()
var path_root := Node3D.new()
var materials: Dictionary = {}
var drawn_solids: Array[Dictionary] = []
var debug_collision := false

func _ready() -> void:
	for node: Node3D in [visual_root, collision_root, overlay_root, boundary_root, path_root]:
		add_child(node)
	for kind: String in ["original", "reflected", "absolute"]:
		var material := ShaderMaterial.new()
		material.shader = Paint
		material.set_shader_parameter("pigment", {"original": Color("c4b59b"), "reflected": Color("809fa9"), "absolute": Color("d7b579")}[kind])
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
	if not debug_collision:
		return
	for solid: Dictionary in drawn_solids:
		var bounds: AABB = solid["bounds"]
		var points := PackedVector3Array()
		for edge: Vector2i in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 4), Vector2i(1, 3),
				Vector2i(1, 5), Vector2i(2, 3), Vector2i(2, 6), Vector2i(3, 7),
				Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 7), Vector2i(6, 7)]:
			points.append(bounds.get_endpoint(edge.x))
			points.append(bounds.get_endpoint(edge.y))
		_lines(overlay_root, points, Color("a44836"))

func show_boundary(mirror: Dictionary, bounds: AABB, style: int, editing: bool) -> void:
	_clear(boundary_root)
	if not mirror["enabled"] and not editing:
		return
	var axis: int = mirror["axis"]
	var corners := _plane_corners(axis, float(mirror["offset"]), bounds.grow(0.25))
	var color := Color("487078") if not editing else Color("b0654a")
	var outline := PackedVector3Array()
	for index: int in range(4):
		outline.append(corners[index])
		outline.append(corners[(index + 1) % 4])
	_lines(boundary_root, outline, color)
	if style == 1:
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for index: int in [0, 1, 2, 0, 2, 3]:
			mesh.surface_add_vertex(corners[index])
		mesh.surface_end()
		var face := MeshInstance3D.new()
		face.mesh = mesh
		face.material_override = _plain(Color(color, 0.13))
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		boundary_root.add_child(face)

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

func _plane_corners(axis: int, offset: float, bounds: AABB) -> PackedVector3Array:
	var dimensions: Array[int] = [0, 1, 2]
	dimensions.erase(axis)
	var result := PackedVector3Array()
	for side: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var point := bounds.position
		point[axis] = offset
		point[dimensions[0]] += bounds.size[dimensions[0]] * side.x
		point[dimensions[1]] += bounds.size[dimensions[1]] * side.y
		result.append(point)
	return result

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

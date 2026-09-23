class_name MirrorWorldView
extends Node3D

const Queries := preload("res://core/solid_queries.gd")
const BlockSet := preload("res://world/block_set.gd")
var visual_root := Node3D.new()
var collision_root := Node3D.new()
var overlay_root := Node3D.new()
var path_root := Node3D.new()
var drawn_solids: Array[Dictionary] = []
var visual_slots: Dictionary = {}
var visual_generation := 0
var debug_signature := ""
var debug_collision := false

func _ready() -> void:
	for node: Node3D in [visual_root, collision_root, overlay_root, path_root]:
		add_child(node)

func commit(solids: Array[Dictionary]) -> void:
	_clear(collision_root)
	for solid: Dictionary in solids:
		collision_root.add_child(Queries.body(solid))
	draw_world(solids)
	_discard_inactive_slots()

func draw_world(solids: Array[Dictionary]) -> void:
	drawn_solids = solids
	visual_generation += 1
	var occurrences := {}
	var visible_index := 0
	for solid: Dictionary in solids:
		var key := _fragment_key(solid, occurrences)
		var slot: Dictionary = visual_slots.get(key, {})
		if slot.is_empty():
			var instance := MeshInstance3D.new()
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			visual_root.add_child(instance)
			slot = {"instance": instance, "material": ShaderMaterial.new(), "mesh_signature": "", "style": ""}
			visual_slots[key] = slot
		var instance: MeshInstance3D = slot["instance"]
		var mesh_signature := _mesh_signature(solid)
		if slot["mesh_signature"] != mesh_signature:
			_apply_mesh(instance, solid)
			slot["mesh_signature"] = mesh_signature
		_configure_material(slot, solid)
		instance.visible = true
		visual_root.move_child(instance, visible_index)
		visible_index += 1
		slot["generation"] = visual_generation
		visual_slots[key] = slot
	for slot: Dictionary in visual_slots.values():
		if slot.get("generation", -1) != visual_generation:
			slot["instance"].visible = false
	update_debug()

func _discard_inactive_slots() -> void:
	for key: String in visual_slots.keys():
		var slot: Dictionary = visual_slots[key]
		if slot.get("generation", -1) == visual_generation:
			continue
		visual_root.remove_child(slot["instance"])
		slot["instance"].queue_free()
		visual_slots.erase(key)

func _fragment_key(solid: Dictionary, occurrences: Dictionary) -> String:
	if solid.has("fragment_key"):
		return str(solid["fragment_key"])
	var base := "%s:%s" % [solid.get("source_id", solid.get("id", "solid")), solid.get("kind", "original")]
	var count := int(occurrences.get(base, 0))
	occurrences[base] = count + 1
	return "%s:%d" % [base, count]

func _mesh_signature(solid: Dictionary) -> String:
	return str(solid.get("faces", [])) if solid.has("faces") else str(solid["bounds"])

func _apply_mesh(instance: MeshInstance3D, solid: Dictionary) -> void:
	if solid.has("faces") and not solid["faces"].is_empty():
		instance.mesh = _polygon_mesh(solid["faces"], solid)
		instance.position = Vector3.ZERO
		return
	var bounds: AABB = solid["bounds"]
	var mesh := BoxMesh.new()
	mesh.size = bounds.size
	instance.mesh = mesh
	instance.position = bounds.get_center()

func _polygon_mesh(faces: Array, solid: Dictionary = {}) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon: PackedVector3Array in faces:
		if polygon.size() < 3:
			continue
		var normal := (polygon[1] - polygon[0]).cross(polygon[2] - polygon[0]).normalized()
		var centre := Vector3.ZERO
		for point: Vector3 in polygon:
			centre += point
		centre /= polygon.size()
		var cut := 1.0 if _is_cut_face(polygon, solid) else 0.0
		var boundary_distance := _polygon_boundary_distance(centre, polygon)
		for index: int in polygon.size():
			tool.set_normal(normal)
			tool.set_color(Color(boundary_distance, cut, 0.0))
			tool.add_vertex(centre)
			tool.set_normal(normal)
			tool.set_color(Color(0.0, cut, 0.0))
			tool.add_vertex(polygon[(index + 1) % polygon.size()])
			tool.set_normal(normal)
			tool.set_color(Color(0.0, cut, 0.0))
			tool.add_vertex(polygon[index])
	return tool.commit()

func _is_cut_face(polygon: PackedVector3Array, solid: Dictionary) -> bool:
	if not solid.has("source_bounds"):
		return false
	var source: AABB = solid["source_bounds"]
	var mapping: Transform3D = solid.get("material_to_world", Transform3D(Basis.IDENTITY, source.get_center()))
	var inverse := mapping.affine_inverse()
	for axis: int in 3:
		for sign_value: float in [-1.0, 1.0]:
			var on_source := true
			for point: Vector3 in polygon:
				if absf((inverse * point)[axis] - source.size[axis] * 0.5 * sign_value) > 0.0001:
					on_source = false
					break
			if on_source:
				return false
	return true

func _polygon_boundary_distance(point: Vector3, polygon: PackedVector3Array) -> float:
	var distance := INF
	for index: int in polygon.size():
		var start := polygon[index]
		var finish := polygon[(index + 1) % polygon.size()]
		var edge := finish - start
		var fraction := clampf((point - start).dot(edge) / edge.length_squared(), 0.0, 1.0)
		distance = minf(distance, point.distance_to(start.lerp(finish, fraction)))
	return distance

func _configure_material(slot: Dictionary, solid: Dictionary) -> void:
	var bounds: AABB = solid["bounds"]
	var style: String = str(solid["kind"])
	var material: ShaderMaterial = slot["material"]
	if slot["style"] != style:
		BlockSet.configure(material, style)
		slot["style"] = style
	material.set_shader_parameter("polygon_surface", solid.has("faces") and not solid["faces"].is_empty())
	material.set_shader_parameter("box_centre", bounds.get_center())
	material.set_shader_parameter("box_size", bounds.size)
	material.set_shader_parameter("source_size", (solid.get("source_bounds", bounds) as AABB).size)
	_apply_source_mapping(material, solid, bounds)
	slot["instance"].material_override = material

func _apply_source_mapping(material: ShaderMaterial, solid: Dictionary, bounds: AABB) -> void:
	var material_to_world := Transform3D(Basis.IDENTITY, bounds.get_center())
	if solid.has("material_to_world") and solid["material_to_world"] is Transform3D:
		material_to_world = solid["material_to_world"]
	material.set_shader_parameter("world_to_material", material_to_world.affine_inverse())

func update_debug() -> void:
	var signature := str(debug_collision) + (str(drawn_solids) if debug_collision else "")
	if signature == debug_signature:
		return
	debug_signature = signature
	_clear(overlay_root)
	if not debug_collision:
		return
	for solid: Dictionary in drawn_solids:
		_outline_box(overlay_root, solid["bounds"], Color("a44836"))

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
	var is_goal := is_equal_approx(radius, 0.3)
	node.material_override = BlockSet.goal_material() if is_goal else _plain(color)
	parent.add_child(node)
	if is_goal:
		_lines(parent, BlockSet.goal_carving_points(feet, radius), BlockSet.GOAL_CARVING_COLOR)


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

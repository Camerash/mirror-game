class_name MirrorWorldView
extends Node3D

const Queries := preload("res://core/solid_queries.gd")
const BlockSet := preload("res://world/block_set.gd")
const DropShadowShader := preload("res://world/drop_shadow.gdshader")
## Gaps under a block smaller than this count as resting on the surface.
const SHADOW_GAP := 0.05
const UNREACHABLE := Color(0.82, 0.38, 0.3, 0.95)
const HIDDEN_FILL := Color(0.86, 0.9, 0.96, 0.16)
const HIDDEN_EDGE := Color(0.92, 0.95, 1.0, 0.75)
const HIDDEN_INSET := 0.985
var visual_root := Node3D.new()
var collision_root := Node3D.new()
var overlay_root := Node3D.new()
var path_root := Node3D.new()
var hidden_root := Node3D.new()
var shadow_root := MeshInstance3D.new()
var hover_root := Node3D.new()
var mark_root := Node3D.new()
var drawn_solids: Array[Dictionary] = []
var visual_slots: Dictionary = {}
var visual_generation := 0
var debug_signature := ""
var debug_collision := false
var clip_plane := Plane()
## Set by `reveal_from` for the next draw only: the mirror's plane. Copies new
## in that draw grow out of it, and fragments that leave sink into it, so the
## world changes like ice forming, never in a cut. Presentation only.
var _reveal_plane := Plane()
var _revealing := false
## The reveal grows every fragment, not only copies: a whole new place.
var _reveal_all := false
var ghost_root := Node3D.new()

func _ready() -> void:
	for node: Node3D in [visual_root, ghost_root, collision_root, overlay_root, path_root, hidden_root, shadow_root, hover_root, mark_root]:
		add_child(node)
	shadow_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shade := ShaderMaterial.new()
	shade.shader = DropShadowShader
	shadow_root.material_override = shade

func commit(solids: Array[Dictionary]) -> void:
	_clear(collision_root)
	for solid: Dictionary in solids:
		collision_root.add_child(Queries.body(solid))
	draw_world(solids)
	_discard_inactive_slots()

## The next `draw_world` reveals its changes from `plane` (the mirror). With
## `everything`, every fragment grows out of the plane: a whole new place.
func reveal_from(plane: Plane, everything := false) -> void:
	_reveal_plane = plane
	_revealing = true
	_reveal_all = everything

func cancel_reveal() -> void:
	_revealing = false

func draw_world(solids: Array[Dictionary]) -> void:
	drawn_solids = solids
	visual_generation += 1
	var occurrences := {}
	var visible_index := 0
	var revealing := _revealing
	_revealing = false
	var shown_before := {}
	var reveal_all := _reveal_all
	_reveal_all = false
	if revealing and not reveal_all:
		for key: String in visual_slots:
			if (visual_slots[key]["instance"] as MeshInstance3D).visible:
				shown_before[key] = true
	var grown: Array[MeshInstance3D] = []
	for solid: Dictionary in solids:
		var key := _fragment_key(solid, occurrences)
		var slot: Dictionary = visual_slots.get(key, {})
		var grows := revealing and (reveal_all or (not shown_before.has(key) and str(solid.get("kind", "original")) != "original"))
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
		if grows:
			grown.append(instance)
		instance.visible = true
		visual_root.move_child(instance, visible_index)
		visible_index += 1
		slot["generation"] = visual_generation
		visual_slots[key] = slot
	for key: String in visual_slots:
		var slot: Dictionary = visual_slots[key]
		if slot.get("generation", -1) != visual_generation:
			if revealing and shown_before.has(key):
				_sink(slot["instance"])
			slot["instance"].visible = false
	if revealing:
		for instance: MeshInstance3D in grown:
			_grow(instance)
	_draw_drop_shadows(solids)
	update_debug()

## A soft shadow straight below every floating block, on each surface under
## its footprint. A copy beside a path and one above it look alike from an
## isometric view; the shadow tells them apart.
func _draw_drop_shadows(solids: Array[Dictionary]) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for block: Dictionary in solids:
		var bounds: AABB = block["bounds"]
		for below: Dictionary in solids:
			var support: AABB = below["bounds"]
			if is_same(below, block) or support.end.y > bounds.position.y - SHADOW_GAP:
				continue
			var low := Vector2(maxf(bounds.position.x, support.position.x), maxf(bounds.position.z, support.position.z))
			var high := Vector2(minf(bounds.end.x, support.end.x), minf(bounds.end.z, support.end.z))
			if high.x - low.x < 0.05 or high.y - low.y < 0.05:
				continue
			var size := high - low
			var height := support.end.y + 0.012
			# Fainter the further the block floats above the surface.
			var fade := clampf(1.2 - (bounds.position.y - support.end.y) * 0.15, 0.45, 1.0)
			var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			for index: int in [0, 1, 2, 0, 2, 3]:
				var corner: Vector2 = corners[index]
				tool.set_color(Color(1, 1, 1, fade))
				tool.set_uv(corner)
				tool.set_uv2(size)
				tool.add_vertex(Vector3(low.x + size.x * corner.x, height, low.y + size.y * corner.y))
			count += 1
	shadow_root.mesh = tool.commit() if count > 0 else null

## Grows a fragment out of the mirror's plane to its full shape.
func _grow(instance: MeshInstance3D) -> void:
	var rest := instance.transform
	var plane := _reveal_plane
	_squash(instance, rest, plane, 0.0)
	var motion := Motion.blend(instance, func(weight: float) -> void: _squash(instance, rest, plane, weight), "reveal")
	motion.tween_callback(func() -> void: instance.transform = rest)

## A leaving fragment: a copy of it sinks into the mirror's plane, then goes.
func _sink(instance: MeshInstance3D) -> void:
	if instance.mesh == null:
		return
	var ghost := MeshInstance3D.new()
	ghost.mesh = instance.mesh
	ghost.material_override = instance.material_override
	ghost.transform = instance.transform
	ghost_root.add_child(ghost)
	var rest := ghost.transform
	var plane := _reveal_plane
	var motion := Motion.blend(ghost, func(weight: float) -> void: _squash(ghost, rest, plane, 1.0 - weight), "reveal")
	motion.tween_callback(ghost.queue_free)

## Scales `rest` along the plane's normal about the plane, by `amount`.
func _squash(instance: MeshInstance3D, rest: Transform3D, plane: Plane, amount: float) -> void:
	var keep := maxf(amount, 0.02)
	var normal := plane.normal
	var squash := Basis(Vector3.RIGHT - normal * normal.x * (1.0 - keep),
		Vector3.UP - normal * normal.y * (1.0 - keep),
		Vector3.BACK - normal * normal.z * (1.0 - keep))
	instance.transform = Transform3D(squash, normal * plane.d * (1.0 - keep)) * rest

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
	material.set_shader_parameter("clip_plane", _clip_vector())
	slot["instance"].material_override = material

func _apply_source_mapping(material: ShaderMaterial, solid: Dictionary, bounds: AABB) -> void:
	var material_to_world := Transform3D(Basis.IDENTITY, bounds.get_center())
	if solid.has("material_to_world") and solid["material_to_world"] is Transform3D:
		material_to_world = solid["material_to_world"]
	material.set_shader_parameter("world_to_material", (transform * material_to_world).affine_inverse())

## Hides every drawn fragment on the positive side of `plane`. The plane is in
## world space, also for a moved view. `Plane()` (all zero) clears the clip.
func set_clip(plane: Plane) -> void:
	clip_plane = plane
	var clip_value := _clip_vector()
	for slot: Dictionary in visual_slots.values():
		(slot["material"] as ShaderMaterial).set_shader_parameter("clip_plane", clip_value)

func _clip_vector() -> Vector4:
	return Vector4(clip_plane.normal.x, clip_plane.normal.y, clip_plane.normal.z, clip_plane.d)

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

## The ground a raised mirror hides: a faint fill with dashed edges, drawn
## a little inside each fragment so it never fights the blocks around it.
func draw_hidden(fragments: Array) -> void:
	_clear(hidden_root)
	if fragments.is_empty():
		return
	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := PackedVector3Array()
	for faces: Array in fragments:
		var centre := Vector3.ZERO
		var count := 0
		for polygon: PackedVector3Array in faces:
			for point: Vector3 in polygon:
				centre += point
				count += 1
		centre /= maxi(count, 1)
		for polygon: PackedVector3Array in faces:
			var inset := PackedVector3Array()
			for point: Vector3 in polygon:
				inset.append(centre + (point - centre) * HIDDEN_INSET)
			for index: int in range(1, inset.size() - 1):
				fill.add_vertex(inset[0])
				fill.add_vertex(inset[index])
				fill.add_vertex(inset[index + 1])
			for index: int in inset.size():
				var start := inset[index]
				var finish := inset[(index + 1) % inset.size()]
				var dashes := maxi(1, ceili(start.distance_to(finish) / 0.12))
				for dash: int in range(0, dashes, 2):
					edges.append(start.lerp(finish, float(dash) / dashes))
					edges.append(start.lerp(finish, float(dash + 1) / dashes))
	var surface := MeshInstance3D.new()
	surface.mesh = fill.commit()
	var material := _plain(HIDDEN_FILL)
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hidden_root.add_child(surface)
	_lines(hidden_root, edges, HIDDEN_EDGE)

## The way the traveller would walk to the pointer, drawn faintly on hover.
func draw_hover(path: PackedVector3Array) -> void:
	_clear(hover_root)
	var points := PackedVector3Array()
	for index: int in range(path.size() - 1):
		points.append(path[index] + Vector3.UP * 0.02)
		points.append(path[index + 1] + Vector3.UP * 0.02)
	_lines(hover_root, points, Color(0.24, 0.38, 0.38, 0.45))
	if not path.is_empty():
		add_ring(hover_root, path[-1], Color(0.24, 0.38, 0.38, 0.45), 0.13)

## A short-lived mark where a tap asked for a place the traveller cannot
## reach: a cross in a ring, lying on the surface, that fades out.
func flash_unreachable(feet: Vector3) -> void:
	_clear(mark_root)
	var mark := Node3D.new()
	mark.position = feet + Vector3.UP * 0.08
	mark_root.add_child(mark)
	var material := _plain(UNREACHABLE)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	var ring := TorusMesh.new()
	ring.inner_radius = 0.27
	ring.outer_radius = 0.34
	ring.rings = 32
	ring.ring_segments = 6
	var bar := BoxMesh.new()
	bar.size = Vector3(0.42, 0.02, 0.06)
	for part: Array in [[ring, 0.0], [bar, PI * 0.25], [bar, -PI * 0.25]]:
		var piece := MeshInstance3D.new()
		piece.mesh = part[0]
		piece.rotation.y = part[1]
		piece.scale = Vector3(1, 0.3, 1)
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.add_child(piece)
	var fade := mark.create_tween()
	fade.tween_interval(0.5)
	fade.tween_property(material, "albedo_color:a", 0.0, Motion.duration("dismiss")) \
		.set_trans(Motion.VERBS["dismiss"][1]).set_ease(Motion.VERBS["dismiss"][2])
	fade.tween_callback(mark.queue_free)

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

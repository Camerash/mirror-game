class_name MirrorWorldView
extends Node3D

const Queries := preload("res://core/solid_queries.gd")
const Polygons := preload("res://core/display_geometry.gd")
## The most planes that can cut one fragment out of its source: the five of
## the mirror's column, and the six of one absolute, with one to spare. It is
## the size of `cuts` in `stone.gdshader`.
const MAX_CUTS := 12
const SHRINK := 0.999
const BlockSet := preload("res://world/block_set.gd")
const DropShadowShader := preload("res://world/drop_shadow.gdshader")
## Gaps under a block smaller than this count as resting on the surface.
const SHADOW_GAP := 0.05
const UNREACHABLE := Color(0.82, 0.38, 0.3, 0.95)
const HIDDEN_FILL := Color(0.72, 0.82, 1.0, 0.0)
const HIDDEN_EDGE := Color(0.82, 0.90, 1.0, 0.0)
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
## Set by `reveal_along` for the next draw only; empty when not set.
var _sweep := {}
var ghost_root := Node3D.new()
## The stones show in the ice below; see `world/ice.gd`.
const MIRRORED_LAYER := 1 << 10
## The height of the ice. A stone's image fades with its height above it.
var ice_height := -100.0:
	set(value):
		ice_height = value
		for slot: Dictionary in visual_slots.values():
			(slot["material"] as ShaderMaterial).set_shader_parameter("ice_height", value)

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

## The next `draw_world` shows its changes in step with the pane, which rises
## (`rising`) or sinks along `up` between `low` and `high` (distances along
## `up`). The mirror's effect reaches as high as the pane's moving edge: a
## copy is there below the edge, and the ground it replaces is there above it.
## `mirror` is the pane's plane, with its normal toward the copy's side.
func reveal_along(up: Vector3, low: float, high: float, rising: bool, mirror: Plane) -> void:
	_sweep = {"up": up.normalized(), "low": low, "high": high, "rising": rising, "mirror": mirror}

func cancel_reveal() -> void:
	_revealing = false
	_sweep = {}

func draw_world(solids: Array[Dictionary]) -> void:
	drawn_solids = solids
	visual_generation += 1
	var occurrences := {}
	var visible_index := 0
	var sweep := _sweep
	_sweep = {}
	var revealing := _revealing or not sweep.is_empty()
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
		var copy := str(solid.get("kind", "original")) == "reflected"
		var grows := revealing and (reveal_all or (not shown_before.has(key) and str(solid.get("kind", "original")) != "original"))
		# With the pane: a new copy comes with the edge, and so does the ground
		# that returns when the pane sinks. Ground that only changes its
		# fragments is there at once.
		if slot.is_empty():
			var instance := MeshInstance3D.new()
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			instance.layers = 1 | MIRRORED_LAYER
			visual_root.add_child(instance)
			slot = {"instance": instance, "material": ShaderMaterial.new(), "mesh_signature": "", "style": ""}
			visual_slots[key] = slot
		var instance: MeshInstance3D = slot["instance"]
		var mesh_signature := _mesh_signature(solid)
		# With the pane, a fragment that changes its shape is an old shape that
		# leaves and a new one that comes.
		var reshaped: bool = not sweep.is_empty() and shown_before.has(key) and slot["mesh_signature"] != mesh_signature
		if reshaped:
			_sweep_ghost(instance, sweep, slot.get("copy", false))
		var swept: bool = not sweep.is_empty() and (reshaped or not shown_before.has(key)) and (copy or not sweep["rising"])
		_apply_mesh(instance, solid)
		slot["mesh_signature"] = mesh_signature
		_configure_material(slot, solid)
		if not sweep.is_empty():
			if swept:
				_sweep_clip(instance, slot["material"], sweep, copy, false)
		elif grows:
			grown.append(instance)
		slot["copy"] = copy
		instance.visible = true
		visual_root.move_child(instance, visible_index)
		visible_index += 1
		slot["generation"] = visual_generation
		visual_slots[key] = slot
	for key: String in visual_slots:
		var slot: Dictionary = visual_slots[key]
		if slot.get("generation", -1) != visual_generation:
			if not sweep.is_empty() and shown_before.has(key):
				_sweep_ghost(slot["instance"], sweep, slot.get("copy", false))
			elif revealing and shown_before.has(key):
				_sink(slot["instance"])
			slot["instance"].visible = false
	if revealing:
		for instance: MeshInstance3D in grown:
			_grow(instance)
	_draw_drop_shadows(solids)
	if not sweep.is_empty():
		# The shadows are of the new place. They come in with its second
		# half, when the blocks that carry them are there.
		var shade := shadow_root.material_override as ShaderMaterial
		if shadow_root.has_meta("sweep") and (shadow_root.get_meta("sweep") as Tween).is_valid():
			(shadow_root.get_meta("sweep") as Tween).kill()
		shade.set_shader_parameter("shown", 0.0)
		shadow_root.set_meta("sweep", Motion.blend(shadow_root, func(weight: float) -> void: shade.set_shader_parameter("shown", smoothstep(0.5, 1.0, weight)), "reveal"))
	update_debug()

## A soft shadow straight below every floating block, on each flat top under
## its footprint. A copy beside a path and one above it look alike from an
## isometric view; the shadow tells them apart. The shadow has the shape of
## the block's footprint on the top: a piece cut on a slant casts a slanted
## shadow, and a top that slopes takes none.
func _draw_drop_shadows(solids: Array[Dictionary]) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for block: Dictionary in solids:
		var bounds: AABB = block["bounds"]
		var footprint := PackedVector2Array()
		for below: Dictionary in solids:
			var support: AABB = below["bounds"]
			if is_same(below, block) or support.end.y > bounds.position.y - SHADOW_GAP:
				continue
			var low := Vector2(maxf(bounds.position.x, support.position.x), maxf(bounds.position.z, support.position.z))
			var high := Vector2(minf(bounds.end.x, support.end.x), minf(bounds.end.z, support.end.z))
			if high.x - low.x < 0.05 or high.y - low.y < 0.05:
				continue
			if footprint.is_empty():
				footprint = _footprint(block)
			# A flat top of a convex fragment is at the top of its bounds.
			for face: PackedVector3Array in Queries.faces(below):
				if face.size() < 3 or Queries.plane(face).normal.y < 0.999:
					continue
				var top := PackedVector2Array()
				for point: Vector3 in face:
					top.append(Vector2(point.x, point.z))
				# Fainter the further the block floats above the surface.
				var fade := clampf(1.2 - (bounds.position.y - face[0].y) * 0.15, 0.45, 1.0)
				for shade: PackedVector2Array in Geometry2D.intersect_polygons(footprint, top):
					if shade.size() >= 3:
						_add_shadow(tool, shade, face[0].y + 0.012, fade)
						count += 1
	shadow_root.mesh = tool.commit() if count > 0 else null

## The outline of `solid` seen from straight above, in (x, z).
func _footprint(solid: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	for face: PackedVector3Array in Queries.faces(solid):
		for point: Vector3 in face:
			points.append(Vector2(point.x, point.z))
	var hull := Geometry2D.convex_hull(points)
	# The hull ends with its first point again.
	hull.resize(maxi(hull.size() - 1, 0))
	return hull

## One convex shadow at `height`, as a fan of triangles from its middle. Each
## point carries its distance to the triangle's own rim (UV.x) and to the rims
## beside it (UV.y, UV2.x), so `drop_shadow.gdshader` feathers every rim by
## the same width.
func _add_shadow(tool: SurfaceTool, polygon: PackedVector2Array, height: float, fade: float) -> void:
	var count := polygon.size()
	var middle := Vector2.ZERO
	for point: Vector2 in polygon:
		middle += point
	middle /= count
	var inside := func(point: Vector2, rim: int) -> float:
		var start := polygon[posmod(rim, count)]
		var along := (polygon[posmod(rim + 1, count)] - start).normalized()
		if along.is_zero_approx():
			# Two points in one place: no rim to feather.
			return 1000.0
		var inward := Vector2(-along.y, along.x)
		if inward.dot(middle - start) < 0.0:
			inward = -inward
		return (point - start).dot(inward)
	for rim: int in count:
		for point: Vector2 in [middle, polygon[rim], polygon[(rim + 1) % count]]:
			tool.set_color(Color(1, 1, 1, fade))
			tool.set_uv(Vector2(inside.call(point, rim), inside.call(point, rim - 1)))
			tool.set_uv2(Vector2(inside.call(point, rim + 1), 0.0))
			tool.add_vertex(Vector3(point.x, height, point.y))

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

## Shows `material` only on one side of the pane's moving edge for the time
## of the reveal: below it (`below`, a copy) or above it (the ground a copy
## replaces). `leaving` frees the node at the end.
func _sweep_clip(node: MeshInstance3D, material: ShaderMaterial, sweep: Dictionary, below: bool, leaving: bool) -> void:
	if node.has_meta("sweep") and (node.get_meta("sweep") as Tween).is_valid():
		(node.get_meta("sweep") as Tween).kill()
	var up: Vector3 = sweep["up"]
	var step := func(weight: float) -> void:
		var edge := lerpf(sweep["low"], sweep["high"], weight if sweep["rising"] else 1.0 - weight)
		var plane := Vector4(up.x, up.y, up.z, edge)
		material.set_shader_parameter("reveal_plane", plane if below else -plane)
	step.call(0.0)
	var motion := Motion.blend(node, step, "reveal")
	if leaving:
		motion.tween_callback(node.queue_free)
	else:
		motion.tween_callback(func() -> void: material.set_shader_parameter("reveal_plane", Vector4()))
	node.set_meta("sweep", motion)

## A leaving fragment stays as a ghost while the pane's edge passes it. A copy
## goes with the edge; so does ground a rising pane replaces. Ground that
## only changes its fragments stays whole until the change is over.
func _sweep_ghost(instance: MeshInstance3D, sweep: Dictionary, copy: bool) -> void:
	if instance.mesh == null or not instance.material_override is ShaderMaterial:
		return
	var ghost := MeshInstance3D.new()
	ghost.mesh = instance.mesh
	ghost.layers = instance.layers
	var material := (instance.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter("reveal_plane", Vector4())
	ghost.material_override = material
	ghost.transform = instance.transform
	ghost_root.add_child(ghost)
	if copy or sweep["rising"]:
		if not copy and material.get_shader_parameter("clip_plane") in [null, Vector4()]:
			# Only the ground on the copy's side of the pane is replaced. The
			# rest is already drawn in its new fragments.
			var mirror: Plane = sweep["mirror"]
			material.set_shader_parameter("clip_plane", -Vector4(mirror.normal.x, mirror.normal.y, mirror.normal.z, mirror.d))
		_sweep_clip(ghost, material, sweep, copy, true)
	else:
		var wait := ghost.create_tween()
		wait.tween_interval(Motion.duration("reveal"))
		wait.tween_callback(ghost.queue_free)

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

## Each fragment is its whole source stone, drawn in the source's place (a
## copy: mirrored) and cut by the shader to the fragment (`_cuts`). So a stone
## keeps its shape and its look when the mirror cuts it, and when it is whole
## again.
func _apply_mesh(instance: MeshInstance3D, solid: Dictionary) -> void:
	var bounds: AABB = solid["bounds"]
	var source: AABB = solid.get("source_bounds", bounds)
	if StoneMesh.fits(source.size):
		instance.mesh = StoneMesh.of(source.size)
	else:
		var mesh := BoxMesh.new()
		mesh.size = source.size
		instance.mesh = mesh
	var place: Transform3D = solid.get("material_to_world", Transform3D(Basis.IDENTITY, source.get_center()))
	# A copy's place is a mirror image. A stone is the same on each side of
	# its middle, so the copy is drawn turned and not mirrored: the renderer
	# gives a mirrored instance its faces the wrong way round.
	if place.basis.determinant() < 0.0:
		place.basis *= Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	# A hair smaller than the box. Two stones that touch then have no wall in
	# one plane, so the closed cut of one (`stone.gdshader`) does not flicker
	# with the wall of the other. The gap is far below one pixel.
	place.basis = place.basis.scaled_local(Vector3.ONE * SHRINK)
	instance.transform = place

## The planes (normal, distance) that cut `solid` out of its whole source:
## one for each face of the fragment that is not a face of the source.
func _cuts(solid: Dictionary) -> PackedVector4Array:
	var cuts := PackedVector4Array()
	var faces: Array = solid["faces"] if solid.has("faces") and not solid["faces"].is_empty() else Polygons.box_faces(solid["bounds"])
	# The mean of the corners is inside a convex fragment. The centre of its
	# bounds is not always: a stone cut on a slant has it on the cut, or out
	# of the fragment, and the cut then kept the wrong part of the stone.
	var inside := Vector3.ZERO
	var corners := 0
	for polygon: PackedVector3Array in faces:
		for point: Vector3 in polygon:
			inside += point
			corners += 1
	inside /= maxi(corners, 1)
	for polygon: PackedVector3Array in faces:
		if polygon.size() < 3 or not _is_cut_face(polygon, solid):
			continue
		var plane := Plane(polygon[0], polygon[1], polygon[2])
		if plane.distance_to(inside) > 0.0:
			plane = -plane
		var cut := Vector4(plane.normal.x, plane.normal.y, plane.normal.z, plane.d)
		if not cuts.has(cut):
			cuts.append(cut)
	if cuts.size() > MAX_CUTS:
		push_warning("A fragment of %s has %d cuts; only %d are drawn." % [solid.get("id", "a solid"), cuts.size(), MAX_CUTS])
	cuts.resize(MAX_CUTS)
	return cuts

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

func _configure_material(slot: Dictionary, solid: Dictionary) -> void:
	var bounds: AABB = solid["bounds"]
	var style: String = str(solid["kind"])
	var material: ShaderMaterial = slot["material"]
	if slot["style"] != style:
		BlockSet.configure(material, style)
		slot["style"] = style
	var cuts := _cuts(solid)
	material.set_shader_parameter("cuts", cuts)
	material.set_shader_parameter("cut_count", MAX_CUTS - cuts.count(Vector4()))
	var source: AABB = solid.get("source_bounds", bounds)
	material.set_shader_parameter("source_size", source.size)
	material.set_shader_parameter("seed", source.get_center())
	_apply_source_mapping(material, solid, bounds)
	material.set_shader_parameter("clip_plane", _clip_vector())
	material.set_shader_parameter("ice_height", ice_height)
	slot["instance"].material_override = material

func _apply_source_mapping(material: ShaderMaterial, solid: Dictionary, bounds: AABB) -> void:
	var material_to_world := Transform3D(Basis.IDENTITY, bounds.get_center())
	if solid.has("material_to_world") and solid["material_to_world"] is Transform3D:
		material_to_world = solid["material_to_world"]
	# A Projection, the type of a mat4 uniform. The engine erases a Transform3D
	# here when it lists the material's properties, so a duplicate (the ghost of
	# a leaving fragment) lost its mapping and was painted as another block.
	material.set_shader_parameter("world_to_material", Projection((transform * material_to_world).affine_inverse()))

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

## The ground a raised mirror hides. The shape is built but drawn clear:
## every visible strength of it read as a block of glass to stand on (art
## reviews, 2026-11-10). Give `HIDDEN_FILL` and `HIDDEN_EDGE` an alpha to
## bring the cue back.
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
				edges.append(start)
				edges.append(finish)
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
		# The ring is the other warm thing of a place: it lights the snow
		# round it a little, so the eye goes from the copy to the goal.
		var warmth := OmniLight3D.new()
		warmth.light_color = Color("ffcf8a")
		warmth.light_energy = 0.8
		warmth.omni_range = 1.3
		warmth.omni_attenuation = 1.6
		warmth.position = Vector3.UP * 0.3
		node.add_child(warmth)
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

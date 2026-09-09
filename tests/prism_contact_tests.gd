extends SceneTree

const Contact := preload("res://world/mirror_contact.gd")
const Display := preload("res://core/display_geometry.gd")
const Rules := preload("res://core/mirror_state.gd")
var checks := 0
var failures := 0
var contact: Node3D
var state := {"axis": 2, "pivot": Vector3.ZERO, "width": 3.0, "height": 3.0, "source_sign": 1.0, "enabled": true}

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func contours(bounds: AABB, selected: Dictionary = state, frame: Basis = Basis.IDENTITY) -> Array:
	var solids: Array[Dictionary] = [{"bounds": bounds, "kind": "absolute"}]
	return contact._contours(solids, selected, frame)

func _run() -> void:
	contact = Contact.new()
	root.add_child(contact)
	var remote := AABB(Vector3(1.0, -0.5, 8.0), Vector3(1.0, 1.0, 1.0))
	var seams := contours(remote)
	check(seams.size() == 4, "Side contact has four face contours beyond the six-unit guide")
	for seam: Dictionary in seams:
		check(is_equal_approx(seam["a"].x, 1.5) and is_equal_approx(seam["b"].x, 1.5), "Contact follows the side boundary")
		check(seam["a"].z >= 8.0 and seam["b"].z >= 8.0, "Remote contact does not move to the panel")
	check(contours(AABB(Vector3(2.0, -0.5, 8.0), Vector3.ONE)).is_empty(), "Outside volume has no contact")
	check(contours(AABB(Vector3(1.0, -0.5, -9.0), Vector3.ONE)).is_empty(), "Source side has no side contact")
	var reverse := state.duplicate()
	reverse["source_sign"] = -1.0
	check(contours(remote, reverse).is_empty(), "Reversal clears old side contact")
	check(contours(AABB(Vector3(1.0, -0.5, -9.0), Vector3.ONE), reverse).size() == 4, "Reversal moves the prism")
	var wide := state.duplicate()
	wide["width"] = 5.0
	check(contours(remote, wide).is_empty(), "Resize moves boundary away from the block")
	var moved := state.duplicate()
	moved["pivot"] = Vector3(0.5, 0, 0)
	check(not contours(remote, moved).is_empty(), "Translated boundary still contacts its new face")
	_check_frames(remote)
	_check_fragments()
	_check_internal_edges()
	_check_corner_bands()
	_check_reflections()
	_check_adjacent_surfaces()
	contact.queue_free()
	await process_frame
	print("Prism contacts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_frames(bounds: AABB) -> void:
	for frame: Basis in [Basis(Vector3.UP, 0.37) * Basis(Vector3.RIGHT, 0.23), Basis(Vector3.RIGHT, PI * 0.5)]:
		var faces: Array = []
		for face: PackedVector3Array in Display.box_faces(bounds):
			var transformed := PackedVector3Array()
			for point: Vector3 in face:
				transformed.append(frame * point)
			faces.append(transformed)
		var solids: Array[Dictionary] = [{"faces": faces, "kind": "absolute"}]
		var seams: Array = contact._contours(solids, state, frame)
		check(seams.size() == 4, "Angled/horizontal prism preserves contact count")
		for seam: Dictionary in seams:
			check(absf((frame.inverse() * seam["a"]).x - 1.5) < 0.001, "Angled/horizontal seam follows frame")

func _check_fragments() -> void:
	var level := {"originals": [{"id":"cross", "center":[0,0,3], "size":[6,1,1]}], "absolutes": []}
	var solids := Display.generate(level, state, Basis.IDENTITY)
	var seams: Array = contact._contours(solids, state, Basis.IDENTITY)
	check(not seams.is_empty(), "Real generated cut fragments have side seams")
	for seam: Dictionary in seams:
		check(absf(absf(seam["a"].x) - 1.5) < 0.001, "Generated cut seam is on a prism side")
	contact.set_contacts(solids, state, Basis.IDENTITY)
	var first_mesh: Mesh = contact.seam.mesh
	contact.set_contacts(solids, state, Basis.IDENTITY)
	check(contact.seam.mesh == first_mesh, "Contact mesh is reused")
	contact.set_contacts(solids, state, Basis.IDENTITY, true)
	check(contact.material.get_shader_parameter("removal"), "Removal dims the existing contacts")
	var empty: Array[Dictionary] = []
	contact.set_contacts(empty, {"enabled":false}, Basis.IDENTITY)
	check(not contact.seam.visible, "Absent mirror hides contacts")

func _check_internal_edges() -> void:
	# Two coplanar triangles must form one outer contour, with no diagonal seam.
	var faces: Array = [PackedVector3Array([Vector3(-1,-1,0),Vector3(1,-1,0),Vector3(1,1,0)]), PackedVector3Array([Vector3(-1,-1,0),Vector3(1,1,0),Vector3(-1,1,0)])]
	var solids: Array[Dictionary] = [{"faces":faces,"kind":"absolute"}]
	var seams: Array = contact._contours(solids, state, Basis.IDENTITY)
	check(seams.size() == 4, "Internal coplanar diagonal is removed")
	for seam: Dictionary in seams:
		var direction: Vector3 = seam["b"] - seam["a"]
		check(absf(direction.x) < 0.001 or absf(direction.y) < 0.001, "Only outer triangle-union edges remain")

func _check_corner_bands() -> void:
	var seams := contours(AABB(Vector3(-2,-1,-1), Vector3(4,1,4)))
	var tops: Array[PackedVector2Array] = []
	for seam: Dictionary in seams:
		if seam["normal"].y < 0.9:
			continue
		var polygon := PackedVector2Array()
		for point: Vector3 in contact._band_polygon(seam, seams):
			polygon.append(Vector2(point.x, point.z))
		if polygon.size() >= 3:
			tops.append(polygon)
	check(tops.size() >= 3, "Corner fixture has panel and side bands on the top")
	for left: int in tops.size():
		for right: int in range(left + 1, tops.size()):
			var area := 0.0
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(tops[left], tops[right]):
				var signed_area := 0.0
				for index: int in polygon.size():
					signed_area += polygon[index].cross(polygon[(index + 1) % polygon.size()]) * 0.5
				area += absf(signed_area)
			check(area < 0.0001, "Contact bands do not overlap and brighten prism corners")

func _check_reflections() -> void:
	var level := {"originals": [{"id":"source", "center":[0,0,-3], "size":[6,1,1]}], "absolutes": []}
	var solids := Display.generate(level, state, Basis.IDENTITY)
	var seams: Array = contact._contours(solids, state, Basis.IDENTITY)
	check(not seams.is_empty(), "Reflected fragments receive side contact glow")
	for seam: Dictionary in seams:
		check(seam["a"].z > 0.0 and seam["b"].z > 0.0, "Reflected seams stay on the destination side")

func _check_adjacent_surfaces() -> void:
	var solids: Array[Dictionary] = []
	for edges: Vector2 in [Vector2(1,1.5), Vector2(1.5,2)]:
		var face := PackedVector3Array([Vector3(edges.x,0,2), Vector3(edges.x,0,3), Vector3(edges.y,0,3), Vector3(edges.y,0,2)])
		solids.append({"faces":[face], "kind":"original"})
	var seams: Array = contact._contours(solids, state, Basis.IDENTITY)
	check(seams.size() == 2, "Adjacent surfaces retain the glow on both sides of a shared seam")
	for seam: Dictionary in seams:
		var band: Array = contact._band_polygon(seam, seams)
		check(band.size() >= 3, "Each adjacent surface has a nonempty clipped glow band")

extends SceneTree

const Rules := preload("res://core/mirror_state.gd")
const Sheet := preload("res://world/mirror_sheet.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var mirror := Sheet.new()
	root.add_child(mirror)
	await process_frame
	var state := Rules.sync({"enabled":true, "pivot":Vector3(1, 2, 3), "yaw":0.47, "pitch":-0.31, "source_sign":-1, "width":3.0, "height":4.0})
	mirror.set_state(state, AABB(), true)
	var mesh := mirror.guides.mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	check(mesh.get_surface_count() == 1 and vertices.size() == 24, "Guides use four six-vertex ribbons")
	var origins := PackedVector3Array()
	var bounded := true
	for index: int in vertices.size():
		var centre := vertices[index] - Vector3((uvs[index].x - 0.5) * 0.025, 0, 0)
		var known := false
		for origin: Vector3 in origins:
			known = known or origin.is_equal_approx(centre)
		if is_zero_approx(centre.z) and not known:
			origins.append(centre)
		bounded = bounded and vertices[index].z >= 0 and vertices[index].z <= 6
	check(origins.size() == 4 and bounded, "Guides start at all corners and extend six local units")
	check(mirror.global_basis.is_equal_approx(Rules.frame(state)) and mirror.guide_material.get_shader_parameter("source_sign") == -1.0, "Continuous frame and source sign reach the guides")
	var moved := Rules.sync(state.merged({"pivot":Vector3(-2, 1, 4), "yaw":0.83}, true))
	mirror.set_state(moved, AABB(), true)
	check(mirror.guides.mesh == mesh, "Pose changes reuse the guide mesh")
	var resized := Rules.sync(moved.merged({"width":5.0, "height":2.0}, true))
	mirror.set_state(resized, AABB(), true)
	check(mirror.guides.mesh != mesh and is_equal_approx(mirror.guides.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0].y, -1.0), "Resize rebuilds guide origins")
	mirror.set_state(resized.merged({"enabled":false}, true), AABB(), true)
	check(mirror.guides.visible and is_equal_approx(mirror.guide_material.get_shader_parameter("guide_alpha"), 0.35), "Removal preview dims but keeps guides")
	mirror.set_state({"enabled":false}, AABB(), true)
	check(not mirror.visible and mirror.guides.get_children().is_empty(), "Absent mirrors hide guides without collision")
	mirror.queue_free()
	print("Prism guide checks: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

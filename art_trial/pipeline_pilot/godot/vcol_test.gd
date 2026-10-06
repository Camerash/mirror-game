extends SceneTree
## Experiment: which imported materials get vertex-colour-as-albedo for a
## mesh whose primitives have COLOR_0 in a given pattern.
func _initialize() -> void:
	for pattern: String in ["0101", "1111", "0111", "1000", "0001", "1", "0", "10", "01"]:
		var mesh := ArrayMesh.new()
		for k in pattern.length():
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			var o := Vector3(k, 0, 0)
			arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([o, o + Vector3(0, 0, 1), o + Vector3(1, 0, 0)])
			arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
			if pattern[k] == "1":
				arr[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.RED, Color.RED])
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var m := StandardMaterial3D.new()
			m.resource_name = "m%d" % k
			m.vertex_color_use_as_albedo = pattern[k] == "1"
			mesh.surface_set_material(k, m)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var sc := Node3D.new()
		sc.add_child(mi)
		root.add_child(sc)
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		doc.append_from_scene(sc, st)
		var buf := doc.generate_buffer(st)
		var doc2 := GLTFDocument.new()
		var st2 := GLTFState.new()
		doc2.append_from_buffer(buf, "", st2)
		var out := doc2.generate_scene(st2)
		var mi2: MeshInstance3D = out.get_child(0)
		var flags := ""
		for k in mi2.mesh.get_surface_count():
			var mat := mi2.get_active_material(k) as BaseMaterial3D
			flags += "%s:%s " % [mat.resource_name, "1" if mat.vertex_color_use_as_albedo else "0"]
		print("colours ", pattern, " -> imported flags ", flags)
		sc.queue_free()
	quit()

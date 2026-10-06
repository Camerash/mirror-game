extends SceneTree
## Usage: godot --headless --path gen -s gen.gd -- <gate|bonsai> <out.glb>
const Gate = preload("res://gate.gd")
const Bonsai = preload("res://bonsai.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <gate|bonsai> <out.glb>")
		quit(2)
		return
	var scene: Node3D = Gate.build() if args[0] == "gate" else Bonsai.build()
	root.add_child(scene)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(scene, state)
	if err == OK:
		err = doc.write_to_filesystem(state, args[1])
	var tris := 0
	for child in scene.get_children():
		if child is MeshInstance3D:
			for i in (child as MeshInstance3D).mesh.get_surface_count():
				tris += ((child as MeshInstance3D).mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("export %s: err=%d tris=%d" % [args[1], err, tris])
	quit(0 if err == OK else 1)

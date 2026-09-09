extends SceneTree

const Contact := preload("res://world/mirror_contact.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var contact := Contact.new()
	root.add_child(contact)
	var solids: Array[Dictionary] = [{"bounds": AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2)), "kind": "original"}]
	var state := {"axis": 2, "pivot": Vector3.ZERO, "width": 3.0, "height": 3.0}
	contact.set_contacts(solids, state, Basis.IDENTITY)
	var first_mesh: Mesh = contact.seam.mesh
	var has_finite_seam := first_mesh != null and first_mesh.get_aabb().size.length() > 0.1
	var band_bounds := first_mesh.get_aabb()
	var has_soft_band := is_equal_approx(band_bounds.size.z, 0.36)
	var stays_on_faces := band_bounds.position.x >= -1.003 and band_bounds.end.x <= 1.003 and band_bounds.position.y >= -1.003 and band_bounds.end.y <= 1.003
	contact.set_contacts(solids, state, Basis.IDENTITY)
	var reuses_mesh := contact.seam.mesh == first_mesh
	contact.set_contacts(solids, state, Basis(Vector3.UP, 0.37))
	var has_angled_seam := contact.seam.mesh != null and contact.seam.mesh.get_aabb().size.length() > 0.1
	var coplanar: Array[Dictionary] = [{"faces": [PackedVector3Array([Vector3(-2, -2, 0), Vector3(2, -2, 0), Vector3(2, 2, 0), Vector3(-2, 2, 0)])], "kind": "absolute"}]
	contact.set_contacts(coplanar, state, Basis.IDENTITY)
	var has_coplanar_seam := contact.seam.mesh != null and contact.seam.mesh.get_aabb().size.length() > 0.1
	var coplanar_mesh := contact.seam.mesh
	var reverse_coplanar: Array[Dictionary] = [{"faces": [PackedVector3Array([Vector3(-2, 2, 0), Vector3(2, 2, 0), Vector3(2, -2, 0), Vector3(-2, -2, 0)])], "kind": "absolute"}]
	contact.set_contacts(reverse_coplanar, state, Basis.IDENTITY)
	var refreshes_normal := contact.seam.mesh != coplanar_mesh
	contact.set_contacts([], state, Basis.IDENTITY)
	var has_safe_empty_mesh := contact.seam.mesh != null and contact.seam.mesh.get_surface_count() == 0
	print("Mirror contact: finite=%s reused=%s angled=%s coplanar=%s normal=%s empty=%s soft_band=%s face_clip=%s" % [has_finite_seam, reuses_mesh, has_angled_seam, has_coplanar_seam, refreshes_normal, has_safe_empty_mesh, has_soft_band, stays_on_faces])
	quit(0 if has_finite_seam and reuses_mesh and has_angled_seam and has_coplanar_seam and refreshes_normal and has_safe_empty_mesh and has_soft_band and stays_on_faces else 1)

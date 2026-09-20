extends SceneTree
## Focused native animation and asset checks. No gameplay regression suite.

const Study := preload("res://art_trial/animated_traveller_study.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var study := Study.instantiate()
	root.add_child(study)
	check(study.player != null and study.skeleton != null, "Native animation player and skeleton exist")
	check(study.face_material != null and study.hood_shape >= 0, "Face material and hood endpoint exist")
	if study.player != null and study.skeleton != null and study.hood_shape >= 0:
		check_asset(study)
		check_clips(study)
		await check_playback(study)
		check_bounds(study)
		check_walk(study)
		check_drift(study)
		check_isolation_and_reset(study)
	study.free()
	print("Animated traveller: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_asset(study: Node) -> void:
	var triangles := 0
	var materials := {}
	var textures := {}
	var names := []
	var weighted_vertices := 0
	for mesh: MeshInstance3D in study.meshes:
		names.append(String(mesh.name))
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			check(material != null, "Every surface uses a native material")
			if material == null:
				continue
			materials[material.get_instance_id()] = true
			check(material.resource_name in ["TravellerDrawingFace", "TravellerDrawingBody"], "Only the agreed face and body materials exist")
			check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Materials are opaque")
			check(material.albedo_texture != null, "Every surface uses the atlas")
			if material.albedo_texture != null:
				textures[material.albedo_texture.get_rid()] = true
				check(material.albedo_texture.get_size() == Vector2(1024, 1024), "The atlas is 1024 square")
			weighted_vertices += check_skin(mesh, arrays, study.skeleton)
	names.sort()
	check(names == ["Body", "Boots", "Garment", "Hair", "Head"], "The asset has the five agreed meshes")
	check(triangles > 0 and triangles <= 8000, "The asset stays within 8000 triangles")
	check(materials.size() == 2 and textures.size() == 1, "Two materials share one atlas")
	check(weighted_vertices > 0, "The animation has skinned vertices")
	print("Animated asset: %d triangles, %d materials, %d textures" % [triangles, materials.size(), textures.size()])


func check_skin(mesh: MeshInstance3D, arrays: Array, skeleton: Skeleton3D) -> int:
	if arrays[Mesh.ARRAY_WEIGHTS] == null or arrays[Mesh.ARRAY_WEIGHTS].is_empty():
		return 0
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var stride := weights.size() / vertices.size()
	var valid := mesh.skin != null and bones.size() == weights.size() and stride in [4, 8]
	if not valid:
		check(false, "Skin arrays and bind data are valid for " + String(mesh.name))
		return 0
	for vertex: int in vertices.size():
		var total := 0.0
		for slot: int in stride:
			var index := vertex * stride + slot
			valid = valid and weights[index] >= 0.0 and is_finite(weights[index])
			total += weights[index]
			if weights[index] > 0.0:
				valid = valid and bones[index] >= 0 and bones[index] < mesh.skin.get_bind_count()
		# Imported mesh weights use 16-bit values; each slot can lose one unit.
		valid = valid and absf(total - 1.0) <= float(stride) / 65535.0
	for bind: int in mesh.skin.get_bind_count():
		valid = valid and _bind_bone(mesh.skin, bind, skeleton) >= 0
	check(valid, "Bone indices and normalized weights are valid for " + String(mesh.name))
	return vertices.size()


func _bind_bone(skin: Skin, bind: int, skeleton: Skeleton3D) -> int:
	var bone := skin.get_bind_bone(bind)
	return bone if bone >= 0 else skeleton.find_bone(skin.get_bind_name(bind))


func check_clips(study: Node) -> void:
	for name: String in [study.HOOD_DOWN, study.HOOD_UP]:
		check(study.player.has_animation(name), "The asset has " + name)
		if not study.player.has_animation(name):
			continue
		var clip: Animation = study.player.get_animation(name)
		check(is_equal_approx(clip.length, 1.0) and clip.loop_mode == Animation.LOOP_NONE, name + " is a one-second nonlooping clip")
		var has_bones := false
		var has_shapes := false
		var lower_body_fixed := true
		for track: int in clip.get_track_count():
			var path := String(clip.track_get_path(track))
			has_bones = has_bones or clip.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
			has_shapes = has_shapes or clip.track_get_type(track) == Animation.TYPE_BLEND_SHAPE
			if _names_lower_body(path):
				lower_body_fixed = lower_body_fixed and _track_is_still(clip, track)
		check(has_bones and has_shapes, name + " has bone and garment shape tracks")
		check(lower_body_fixed, name + " keeps the root, pelvis, legs, and feet fixed")
		for time: float in [0.0, clip.length]:
			study.active_clip = name
			study.scrub_to(time)
			for index: int in study.hood.mesh.get_blend_shape_count():
				var shape: String = study.hood.mesh.get_blend_shape_name(index)
				if shape != "HoodLowered":
					check(is_zero_approx(study.hood.get_blend_shape_value(index)), name + " clears " + shape + " at endpoints")


func check_playback(study: Node) -> void:
	study.reset_study()
	study.start_action(true)
	check(study.player.is_playing() and study.action_active, "Hood Down starts native playback")
	study.player.advance(0.5)
	var position: float = study.player.current_animation_position
	study.start_action(false)
	check(study.active_clip == study.HOOD_DOWN and study.player.current_animation_position == position, "The opposite action is ignored without a queue")
	study.toggle_playback()
	# AnimationPlayer.advance() explicitly samples even while paused.
	# Let normal frames run to check the real pause contract.
	await process_frame
	await process_frame
	check(not study.player.is_playing() and study.player.current_animation_position == position, "Pause freezes animation time")
	check(study.seek_slider.value == position, "Pause shows the exact stopped time")
	study.start_action(false)
	check(study.active_clip == study.HOOD_DOWN, "Pause preserves the reverse-action block")
	study.scrub_to(0.0)
	study.start_action(false)
	check(study.active_clip == study.HOOD_DOWN and study.action_active, "Seeking to the start keeps the action locked until completion")
	study.scrub_to(0.5)
	check(not study.player.is_playing() and study.action_active and study.player.current_animation_position == 0.5, "Scrub pauses at the chosen time")
	study.set_playback_speed(0.5)
	check(study.speed_button.text == "Speed: 0.5x", "The speed control shows the selected speed")
	study.toggle_playback()
	study.player.advance(0.25)
	check(is_equal_approx(study.player.current_animation_position, 0.625), "Playback speed controls the native time step")
	study.player.advance(2.0)
	check(study.hood_lowered and not study.action_active and not study.player.is_playing(), "Hood Down completes and stays folded")
	study.start_action(false)
	check(study.active_clip == study.HOOD_UP and study.action_active, "Hood Up starts after completion")
	study.player.advance(5.0)
	check(not study.hood_lowered and not study.action_active, "Hood Up finishes at the raised endpoint")
	study.start_action(true)
	study.player.advance(0.5)
	study.set_hood_lowered(true)
	check(not study.player.is_playing() and not study.action_active and study.hood.get_blend_shape_value(study.hood_shape) == 1.0, "The endpoint switch stops motion immediately")


func check_walk(study: Node) -> void:
	var name: String = study.WALK
	check(study.player.has_animation(name), "The asset has " + name)
	if not study.player.has_animation(name):
		return
	var clip: Animation = study.player.get_animation(name)
	check(is_equal_approx(clip.length, 1.0), name + " is one second long")
	check(clip.loop_mode == Animation.LOOP_LINEAR, name + " loops")
	# The walk is the one clip that must move the lower body.
	var legs_move := false
	var shoulders_pinned := true
	for track: int in clip.get_track_count():
		var path := String(clip.track_get_path(track))
		if _names_lower_body(path):
			legs_move = legs_move or not _track_is_still(clip, track)
		if "clavicle" in path.to_lower():
			shoulders_pinned = shoulders_pinned and _track_is_still(clip, track)
	check(legs_move, name + " drives the legs")
	check(shoulders_pinned, name + " keeps the shoulders pinned")
	# It has to start and end on the same pose, or the loop shows a seam.
	for track: int in clip.get_track_count():
		var keys := clip.track_get_key_count(track)
		if keys < 2:
			continue
		var first: Variant = clip.track_get_key_value(track, 0)
		var last: Variant = clip.track_get_key_value(track, keys - 1)
		if first is Quaternion and last is Quaternion:
			check(absf((first as Quaternion).dot(last as Quaternion)) > 0.999,
				name + " loops without a seam on " + String(clip.track_get_path(track)))
		elif first is Vector3 and last is Vector3:
			check((first as Vector3).distance_to(last as Vector3) < 0.0005,
				name + " loops without a seam on " + String(clip.track_get_path(track)))


func check_drift(study: Node) -> void:
	## The three cloak deformations are driven here, not keyed, so what is
	## checked is the driver: that it damps, freezes, clamps, clears, and does
	## not pay back a long frame gap as one jump.
	study.reset_study()
	check(study.drift == Vector3.ZERO, "Reset clears the cloak deformation")
	for name: String in study.DRIFT_SHAPES:
		check(study.hood.find_blend_shape_by_name(name) >= 0,
			"The garment has the " + name + " shape")
	study.set_walking(true)
	study.advance_drift(0.016)
	var first: Vector3 = study.drift
	check(first.length() > 0.0, "Walking starts the cloak moving")
	study.advance_drift(0.016)
	var second: Vector3 = study.drift
	check(second.length() > first.length(), "The cloak keeps closing on its target")
	# A long gap must be cut to the cap, not paid back in full.
	var before: Vector3 = study.drift
	study.advance_drift(5.0)
	var after_gap: Vector3 = study.drift
	var jumped := (after_gap - before).length()
	study.drift = before
	study.advance_drift(study.DRIFT_MAX_STEP)
	var after_step: Vector3 = study.drift
	var capped := (after_step - before).length()
	check(is_equal_approx(jumped, capped),
		"A long frame gap moves the cloak no further than one capped step")
	# Settled, every weight stays inside the design's cap of one.
	for step: int in 200:
		study.advance_drift(0.016)
	var settled: Vector3 = study.drift
	check(absf(settled.x) <= 1.0 and absf(settled.y) <= 1.0
		and absf(settled.z) <= 1.0, "The cloak weights stay inside their cap")
	for index: int in study.drift_shapes.size():
		var value: float = study.hood.get_blend_shape_value(study.drift_shapes[index])
		check(absf(value) <= 1.0, "The driven " + study.DRIFT_SHAPES[index] + " stays inside its cap")
	# Turning drives the twist the other way from a straight walk.
	var straight: float = study.drift.z
	study.turn_index = 2
	for step: int in 200:
		study.advance_drift(0.016)
	var turned: Vector3 = study.drift
	check(absf(turned.z - straight) > 0.05, "Turning drives the cloak twist")
	study.set_walking(false)
	study.reset_study()
	check(study.drift == Vector3.ZERO, "Reset clears the cloak deformation again")


func _names_lower_body(path: String) -> bool:
	for part: String in ["leg", "foot", "toe", "boot", "pelvis", "hip", "thigh", "shin", "root"]:
		if part in path.to_lower():
			return true
	return false


func _track_is_still(clip: Animation, track: int) -> bool:
	## The hood clips must not move the lower body. They used to be checked by
	## banning these bones from a track path at all, which stopped being the
	## same question once the walk was added: Godot's glTF import gives every
	## clip a track for every bone any clip animates, so the hood clips now
	## carry lower-body tracks that hold the rest pose. Holding still is the
	## property that was always meant, so it is the one measured here.
	var keys := clip.track_get_key_count(track)
	if keys < 2:
		return true
	var first: Variant = clip.track_get_key_value(track, 0)
	for key: int in range(1, keys):
		var value: Variant = clip.track_get_key_value(track, key)
		if first is Quaternion and value is Quaternion:
			if absf((first as Quaternion).dot(value as Quaternion)) < 0.999999:
				return false
		elif first is Vector3 and value is Vector3:
			if (first as Vector3).distance_to(value as Vector3) > 0.000001:
				return false
		elif first != value:
			return false
	return true


func check_bounds(study: Node) -> void:
	study.reset_study()
	var bounds: AABB = study.bounds
	var camera_size: float = study.camera.size
	var camera_transform: Transform3D = study.camera.transform
	for clip: String in [study.HOOD_DOWN, study.HOOD_UP]:
		study.active_clip = clip
		for sample: int in 9:
			study.scrub_to(sample * 0.125)
			check(study.bounds == bounds and study.camera.size == camera_size and study.camera.transform == camera_transform, "Animation preserves the common camera fit")
			for mesh: MeshInstance3D in study.meshes:
				check(_sample_fits(mesh, study.skeleton, bounds), "Animated vertices fit camera and culling bounds: %s %.3f %s" % [clip, sample * 0.125, mesh.name])


func _sample_fits(mesh: MeshInstance3D, skeleton: Skeleton3D, bounds: AABB) -> bool:
	var local_bounds := mesh.custom_aabb.grow(0.001)
	for surface: int in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var shapes: Array = mesh.mesh.surface_get_blend_shape_arrays(surface)
		for vertex: int in vertices.size():
			var point := vertices[vertex]
			for shape: int in shapes.size():
				var target: Vector3 = shapes[shape][Mesh.ARRAY_VERTEX][vertex]
				if mesh.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
					target -= vertices[vertex]
				point += target * mesh.get_blend_shape_value(shape)
			point = _skin_point(mesh, skeleton, arrays, vertex, point)
			if not local_bounds.has_point(point) or not bounds.grow(0.001).has_point(mesh.global_transform * point):
				return false
	return true


func _skin_point(mesh: MeshInstance3D, skeleton: Skeleton3D, arrays: Array, vertex: int, point: Vector3) -> Vector3:
	if mesh.skin == null or arrays[Mesh.ARRAY_WEIGHTS] == null or arrays[Mesh.ARRAY_WEIGHTS].is_empty():
		return point
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var stride: int = weights.size() / arrays[Mesh.ARRAY_VERTEX].size()
	var result := Vector3.ZERO
	for slot: int in stride:
		var index := vertex * stride + slot
		if weights[index] <= 0.0:
			continue
		var bind := bones[index]
		var bone := _bind_bone(mesh.skin, bind, skeleton)
		result += (skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * point) * weights[index]
	return mesh.global_transform.affine_inverse() * skeleton.global_transform * result


func check_isolation_and_reset(study: Node) -> void:
	var second := Study.instantiate()
	root.add_child(second)
	for expression: int in 4:
		study.set_expression(expression)
		check(study.face_material.uv1_offset == Vector3(expression * 0.25, 0, 0), "Expression selects its atlas tile")
	check(study.face_material != second.face_material and second.face_material.uv1_offset == Vector3.ZERO, "Face materials belong to each view")
	study.set_grey(true)
	study.set_grey(false)
	check(study.face_material.uv1_offset.x == 0.75, "Grey review preserves the expression")
	study.set_hood_lowered(true)
	check(is_zero_approx(second.hood.get_blend_shape_value(second.hood_shape)), "Hood deformation belongs to each view")
	for mesh: MeshInstance3D in study.meshes:
		for surface: int in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			check(source.uv1_offset == Vector3.ZERO, "Source material tiles stay unchanged")
	study.start_action(false)
	study.scrub_to(0.8)
	study.set_small_view(true)
	study.set_view(4)
	study.set_grey(true)
	study.controls.hide()
	study.reset_study()
	check(not study.player.is_playing() and not study.action_active and not study.hood_lowered, "Reset stops playback at the raised endpoint")
	check(study.playback_speed == 1.0 and study.expression == 0 and not study.small_view and study.view_index == 3 and not study.grey and study.controls.visible, "Reset restores all view and playback settings")
	for bone: int in study.skeleton.get_bone_count():
		check(study.skeleton.get_bone_pose(bone).is_equal_approx(second.skeleton.get_bone_pose(bone)), "Reset returns each bone to the raised endpoint: " + study.skeleton.get_bone_name(bone))
	second.free()

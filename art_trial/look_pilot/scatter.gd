class_name PilotScatter
extends RefCounted
## Scatters small props over the diorama's exposed block faces from a fixed
## seed, and draws them as one MultiMesh per prop.

## Random points on exposed faces of the blocks of the given kinds. `facing`
## is "top" or "side". Each result is [position, outward normal, height
## fraction up the face]. Points within a keep-clear circle [centre, radius]
## on the ground plane are skipped.
static func points(kinds: Array, facing: String, count: int, seed: int, keep_clear: Array = [], min_height := 0.0) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var boxes: Array[AABB] = []
	for solid: Array in PilotDiorama.SOLIDS:
		boxes.append(AABB(solid[1], solid[2]))
	var faces: Array = []
	var total := 0.0
	for index: int in boxes.size():
		if not PilotDiorama.SOLIDS[index][0] in kinds:
			continue
		var low := boxes[index].position
		var size := boxes[index].size
		var sides: Array = []
		if facing == "top":
			sides.append([low + Vector3(0, size.y, 0), Vector3(size.x, 0, 0), Vector3(0, 0, size.z), Vector3.UP])
		else:
			sides.append([low, Vector3(size.x, 0, 0), Vector3(0, size.y, 0), Vector3.FORWARD])
			sides.append([low + Vector3(0, 0, size.z), Vector3(size.x, 0, 0), Vector3(0, size.y, 0), Vector3.BACK])
			sides.append([low, Vector3(0, 0, size.z), Vector3(0, size.y, 0), Vector3.LEFT])
			sides.append([low + Vector3(size.x, 0, 0), Vector3(0, 0, size.z), Vector3(0, size.y, 0), Vector3.RIGHT])
		for face: Array in sides:
			total += face[1].length() * face[2].length()
			faces.append(face + [total])
	var result: Array = []
	var tries := 0
	while result.size() < count and tries < count * 40 and total > 0.0:
		tries += 1
		var pick := random.randf() * total
		var face: Array = faces[faces.size() - 1]
		for candidate: Array in faces:
			if pick <= candidate[4]:
				face = candidate
				break
		var across := random.randf()
		var up := lerpf(min_height, 1.0, random.randf()) if facing == "side" else random.randf()
		var at: Vector3 = face[0] + face[1] * across + face[2] * up
		var probe: Vector3 = at + face[3] * 0.03
		var hidden := false
		for box: AABB in boxes:
			if box.has_point(probe):
				hidden = true
				break
		for clear: Array in keep_clear:
			if Vector2(at.x - clear[0].x, at.z - clear[0].z).length() < clear[1] and absf(at.y - clear[0].y) < 1.5:
				hidden = true
		if not hidden:
			result.append([at, face[3], up])
	return result

## One MultiMesh of `mesh`, coloured per instance when `colors` is given.
static func draw(root: Node3D, mesh: Mesh, transforms: Array[Transform3D], material: Material, colors: Array[Color] = [], shadows := true) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		if multimesh.use_colors:
			multimesh.set_instance_color(index, colors[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	return instance

## A basis that turns +Y toward `normal`, spun about it by `spin`.
static func facing(normal: Vector3, spin: float) -> Basis:
	var side := Vector3.RIGHT if absf(normal.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var tangent := side.cross(normal).normalized()
	return Basis(tangent, normal, tangent.cross(normal)).orthonormalized() * Basis(Vector3.UP, spin)

## A material that takes its colour from the MultiMesh instance colours.
static func tinted(roughness: float, two_sided := false) -> StandardMaterial3D:
	var material := PilotLook.plain(Color.WHITE, roughness)
	material.vertex_color_use_as_albedo = true
	if two_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

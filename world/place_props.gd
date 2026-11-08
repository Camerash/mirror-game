class_name PlaceProps
extends Node3D
## The scenery of a place: things to look at, not to stand on. A level lists
## them under `props`; the blocks underneath stay the ground she walks on.
##
## Grey-box shapes for now: a frozen pond, snowmen, a bench, a tree with a
## swing, and footprints in the snow. When she moves on, `game.gd` hands this
## node to the old place so the scenery leaves with it.

const Geometry := preload("res://core/world_geometry.gd")
## Footprints: the gap between steps, and how far each sits off the line.
const PRINT_STEP := 0.13
const PRINT_SIDE := 0.035

static var _materials := {}

func build(props: Array) -> void:
	for prop: Dictionary in props:
		match str(prop.get("kind", "")):
			"pond": _pond(prop)
			"snowman": _snowman(prop)
			"bench": _bench(prop)
			"tree": _tree(prop)
			"prints": add_prints(_points(prop["path"]), Color(0.52, 0.56, 0.64, 0.55))

## A line of small footprints along `path`, left and right in turn. Returns the
## prints in walking order, so a caller can reveal them one by one.
func add_prints(path: PackedVector3Array, color: Color, glow := 0.0) -> Array[Node3D]:
	var prints: Array[Node3D] = []
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = 1.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.026
	mesh.bottom_radius = 0.026
	mesh.height = 0.004
	mesh.radial_segments = 10
	mesh.rings = 1
	var left := true
	for index: int in path.size() - 1:
		var from := path[index]
		var to := path[index + 1]
		var along := to - from
		along.y = 0.0
		var length := along.length()
		if length < 0.001:
			continue
		var forward := along / length
		var side := Vector3(-forward.z, 0.0, forward.x)
		var travelled := 0.0
		while travelled < length:
			var step := MeshInstance3D.new()
			step.mesh = mesh
			step.material_override = material
			step.position = from + forward * travelled + side * (PRINT_SIDE if left else -PRINT_SIDE) + Vector3.UP * 0.004
			step.basis = Basis(Vector3.UP, atan2(forward.x, forward.z)).scaled(Vector3(1.0, 1.0, 1.7))
			add_child(step)
			prints.append(step)
			left = not left
			travelled += PRINT_STEP
	return prints

func _pond(prop: Dictionary) -> void:
	var radius := float(prop.get("radius", 1.0))
	var at := Geometry.vector(prop["at"])
	var ice := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 48
	ice.mesh = disc
	ice.position = at + Vector3.UP * 0.008
	ice.material_override = _material("ice", Color(0.74, 0.83, 0.9), 0.12, 0.25)
	add_child(ice)
	# A soft bank of snow round the edge.
	var bank := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.03
	ring.outer_radius = radius + 0.07
	ring.rings = 48
	ring.ring_segments = 8
	bank.mesh = ring
	bank.position = at + Vector3.UP * 0.01
	bank.scale = Vector3(1.0, 0.5, 1.0)
	bank.material_override = _material("snow", Color(0.95, 0.95, 0.97), 0.9, 0.2)
	add_child(bank)

func _snowman(prop: Dictionary) -> void:
	var size := float(prop.get("size", 1.0))
	var at := Geometry.vector(prop["at"])
	var height := 0.0
	for radius: float in [0.15, 0.11, 0.08]:
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = radius * size
		sphere.height = radius * size * 2.0
		ball.mesh = sphere
		ball.position = at + Vector3.UP * (height + radius * size * 0.9)
		ball.material_override = _material("snow", Color(0.95, 0.95, 0.97), 0.9, 0.2)
		add_child(ball)
		height += radius * size * 1.7

func _bench(prop: Dictionary) -> void:
	var root := Node3D.new()
	root.position = Geometry.vector(prop["at"])
	root.rotation.y = deg_to_rad(float(prop.get("yaw", 0.0)))
	add_child(root)
	var wood := _material("wood", Color(0.36, 0.3, 0.27), 0.85, 0.15)
	for part: Array in [
			[Vector3(0.72, 0.04, 0.22), Vector3(0.0, 0.22, 0.0)],
			[Vector3(0.72, 0.16, 0.03), Vector3(0.0, 0.36, -0.1)],
			[Vector3(0.04, 0.22, 0.2), Vector3(-0.3, 0.11, 0.0)],
			[Vector3(0.04, 0.22, 0.2), Vector3(0.3, 0.11, 0.0)]]:
		_box(root, part[0], part[1], wood)

func _tree(prop: Dictionary) -> void:
	var root := Node3D.new()
	root.position = Geometry.vector(prop["at"])
	root.rotation.y = deg_to_rad(float(prop.get("yaw", 0.0)))
	add_child(root)
	var bark := _material("bark", Color(0.26, 0.23, 0.24), 0.9, 0.12)
	_limb(root, Vector3.ZERO, Vector3(0.0, 1.5, 0.0), 0.07, bark)
	# A low branch for the swing, and a few bare ones above.
	_limb(root, Vector3(0.0, 1.05, 0.0), Vector3(0.55, 1.2, 0.0), 0.035, bark)
	_limb(root, Vector3(0.0, 1.25, 0.0), Vector3(-0.4, 1.6, 0.15), 0.03, bark)
	_limb(root, Vector3(0.0, 1.4, 0.0), Vector3(0.2, 1.75, -0.25), 0.025, bark)
	var rope := _material("rope", Color(0.55, 0.5, 0.44), 0.9, 0.1)
	_limb(root, Vector3(0.3, 1.13, -0.08), Vector3(0.3, 0.32, -0.08), 0.006, rope)
	_limb(root, Vector3(0.3, 1.13, 0.08), Vector3(0.3, 0.32, 0.08), 0.006, rope)
	_box(root, Vector3(0.1, 0.02, 0.22), Vector3(0.3, 0.31, 0.0), _material("wood", Color(0.36, 0.3, 0.27), 0.85, 0.15))

func _limb(root: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var limb := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.7
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 8
	limb.mesh = mesh
	limb.material_override = material
	var up := (to - from).normalized()
	var across := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	limb.basis = Basis(across, up, across.cross(up))
	limb.position = (from + to) * 0.5
	root.add_child(limb)

func _box(root: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = at
	box.material_override = material
	root.add_child(box)

static func _points(path: Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	for point: Variant in path:
		points.append(Geometry.vector(point))
	return points

## One soft, shared material per look; the tone lift keeps the shadow side
## from going grey under the game's dim light, as for her.
static func _material(id: String, color: Color, roughness: float, lift: float) -> StandardMaterial3D:
	if _materials.has(id):
		return _materials[id]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = lift
	_materials[id] = material
	return material

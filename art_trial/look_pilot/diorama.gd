class_name PilotDiorama
extends Node3D
## A small level-like diorama for the look pilot: a start terrace, a path, a
## mirror whose porcelain copy crosses the gap, and a goal terrace with the
## pilot's shrine gate, a jade goal and a bonsai. Geometry stays fixed; only
## the look changes.

const CharacterVisual := preload("res://world/character_visual.gd")
const GateScene := preload("res://art_trial/look_pilot/models/gate.glb")
const BonsaiScene := preload("res://art_trial/look_pilot/models/bonsai.glb")

## kind, minimum corner, size. Tops sit on whole or half units.
const SOLIDS := [
	["original", Vector3(-5, -1, -2.5), Vector3(3, 1, 4)],
	["original", Vector3(-4.5, -2, -2), Vector3(2, 1, 3)],
	["original", Vector3(-4, -3, -1.5), Vector3(1, 1, 2)],
	["original", Vector3(-2, -1, -1), Vector3(3, 1, 1)],
	["reflected", Vector3(2, -1, -1), Vector3(3, 1, 1)],
	["original", Vector3(5, -1, -2.5), Vector3(4, 1, 4)],
	["original", Vector3(5, 0, -1), Vector3(1, 0.5, 1)],
	["original", Vector3(6, 0, -2), Vector3(3, 1, 3)],
	["original", Vector3(5.5, -2, -2), Vector3(3, 1, 3)],
	["original", Vector3(6.5, -3, -1.5), Vector3(1, 1, 2)],
	["absolute", Vector3(9, 0, -1), Vector3(1, 1, 1)],
]
const MIRROR_CENTRE := Vector3(1.5, 0.0, -0.5)
const MIRROR_SIZE := Vector2(3, 3)
const GATE_POSITION := Vector3(7.5, 1, -0.5)
const BONSAI_POSITION := Vector3(-4.1, 0, 0.6)
const TRAVELLER_POSITION := Vector3(-2.7, 0, -0.5)
const GOAL_POSITION := Vector3(9.5, 1, -0.5)

func build(look: PilotLook) -> void:
	for child: Node in get_children():
		child.free()
	var world := WorldEnvironment.new()
	world.environment = look.environment()
	add_child(world)
	for light: Light3D in look.lights():
		add_child(light)
	for solid: Array in SOLIDS:
		var bounds := AABB(solid[1], solid[2])
		var box := BoxMesh.new()
		box.size = bounds.size
		var instance := MeshInstance3D.new()
		instance.mesh = box
		instance.position = bounds.get_center()
		instance.material_override = look.block_material(solid[0], bounds)
		add_child(instance)
	_add_model(GateScene, GATE_POSITION, PI * 0.5, look)
	_add_model(BonsaiScene, BONSAI_POSITION, 0.4, look)
	_add_mirror(look)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.28
	ring.mesh = torus
	ring.position = GOAL_POSITION + Vector3.UP * 0.04
	ring.material_override = look.goal_material()
	add_child(ring)
	var traveller := CharacterVisual.new()
	traveller.position = TRAVELLER_POSITION
	traveller.rotation.y = PI * 0.5
	add_child(traveller)
	look.decorate(self)

## Corners of every block and of the gate, for framing.
func outline() -> PackedVector3Array:
	var boxes: Array[AABB] = [AABB(GATE_POSITION - Vector3(1, 0, 1.5), Vector3(2, 3.6, 3))]
	for solid: Array in SOLIDS:
		boxes.append(AABB(solid[1], solid[2]))
	var points := PackedVector3Array()
	for box: AABB in boxes:
		for index: int in 8:
			points.append(box.get_endpoint(index))
	return points

func _add_model(scene: PackedScene, at: Vector3, yaw: float, look: PilotLook) -> void:
	var model := scene.instantiate() as Node3D
	model.position = at
	model.rotation.y = yaw
	add_child(model)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface: int in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(surface)
			var role: String = PilotLook.MODEL_ROLES.get(source.resource_name if source != null else "", "ornament")
			instance.set_surface_override_material(surface, look.model_material(role, source))

func _add_mirror(look: PilotLook) -> void:
	var mirror := Node3D.new()
	mirror.position = MIRROR_CENTRE
	add_child(mirror)
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = MIRROR_SIZE
	glass.mesh = quad
	glass.rotation.y = PI * 0.5
	glass.material_override = look.glass_material()
	mirror.add_child(glass)
	var thickness := 0.06
	var half := MIRROR_SIZE * 0.5
	for edge: Array in [[Vector3(0, half.y, 0), Vector3(thickness, thickness, MIRROR_SIZE.x + thickness)], [Vector3(0, -half.y, 0), Vector3(thickness, thickness, MIRROR_SIZE.x + thickness)], [Vector3(0, 0, half.x), Vector3(thickness, MIRROR_SIZE.y, thickness)], [Vector3(0, 0, -half.x), Vector3(thickness, MIRROR_SIZE.y, thickness)]]:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = edge[1]
		bar.mesh = box
		bar.position = edge[0]
		bar.material_override = look.frame_material()
		mirror.add_child(bar)

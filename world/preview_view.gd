extends Node3D
## The ghost is presentation only; prediction is supplied by FallPredictor.

const CharacterVisual := preload("res://world/character_visual.gd")
const FallGhostShader := preload("res://world/fall_ghost.gdshader")
const LANDING_PAUSE := 0.32
const FADE_TIME := 0.34
const LOOP_PAUSE := 0.18

var ghost := Node3D.new()
var marks := Node3D.new()
var points := PackedVector3Array()
var elapsed := 0.0
var duration := 1.0
var result_status := ""
var afterimages: Array[Node3D] = []

func _ready() -> void:
	add_child(marks)
	_setup_ghost(ghost, 1.06)
	for scale: float in [1.11, 1.16]:
		var afterimage := Node3D.new()
		_setup_ghost(afterimage, scale)
		afterimages.append(afterimage)
	clear()

func _setup_ghost(instance: Node3D, size: float) -> void:
	for child: Node in instance.get_children():
		child.free()
	var character := CharacterVisual.new()
	character.ready.connect(_apply_ghost_materials.bind(character), CONNECT_ONE_SHOT)
	instance.add_child(character)
	instance.scale = Vector3.ONE * size
	_apply_ghost_materials(instance)
	if instance.get_parent() == null:
		add_child(instance)

func _apply_ghost_materials(root: Node) -> void:
	for mesh: MeshInstance3D in _mesh_children(root):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = FallGhostShader
		mesh.material_override = material

func _mesh_children(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root)
	for child: Node in root.get_children():
		meshes.append_array(_mesh_children(child))
	return meshes

func clear() -> void:
	points.clear()
	result_status = ""
	ghost.visible = false
	for afterimage: Node3D in afterimages:
		afterimage.visible = false
	for child: Node in marks.get_children():
		child.queue_free()

func set_facing(angle: float) -> void:
	ghost.rotation.y = angle
	for afterimage: Node3D in afterimages:
		afterimage.rotation.y = angle

func show_result(result: Dictionary, _view: Node3D) -> void:
	clear()
	if result.get("status", "") not in ["supported", "landing", "failure"]:
		return
	points = result.get("path", PackedVector3Array())
	result_status = result["status"]
	if points.is_empty() or result_status == "supported":
		return
	elapsed = 0.0
	duration = clampf(float(result.get("seconds", 1.0)) * 1.5, 0.8, 3.0)
	ghost.visible = true
	for afterimage: Node3D in afterimages:
		afterimage.visible = true

func update_view(_camera: Camera3D) -> void:
	pass

func _process(delta: float) -> void:
	if points.is_empty() or result_status == "supported":
		return
	elapsed += delta
	var cycle := duration + LANDING_PAUSE + FADE_TIME + LOOP_PAUSE
	var phase := fmod(elapsed, cycle)
	var travel := minf(phase / duration, 1.0)
	var fade := _fade_for_phase(phase, travel)
	_update_ghost(ghost, travel, fade, elapsed)
	for index: int in afterimages.size():
		var delayed_phase := maxf(phase - (index + 1) * 0.11, 0.0)
		var delayed_travel := minf(delayed_phase / duration, 1.0)
		_update_ghost(afterimages[index], delayed_travel, fade * (0.30 - index * 0.10), elapsed - (index + 1) * 0.11)

func _fade_for_phase(phase: float, travel: float) -> float:
	if result_status == "failure":
		return 1.0 - smoothstep(0.76, 1.0, travel)
	if phase <= duration + LANDING_PAUSE:
		return 1.0
	return 1.0 - clampf((phase - duration - LANDING_PAUSE) / FADE_TIME, 0.0, 1.0)

func _update_ghost(instance: Node3D, travel: float, opacity: float, flow_time: float) -> void:
	var sample := travel * (points.size() - 1)
	var index := mini(int(sample), points.size() - 1)
	instance.position = points[index].lerp(points[mini(index + 1, points.size() - 1)], sample - index)
	instance.visible = opacity > 0.01
	for mesh: MeshInstance3D in _mesh_children(instance):
		var material := mesh.material_override as ShaderMaterial
		material.set_shader_parameter("ghost_opacity", opacity)
		material.set_shader_parameter("flow_time", flow_time)

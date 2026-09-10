extends MeshInstance3D
## Rounded metal tube. Cross-section dimensions stay fixed when the panel resizes.
const THICKNESS := 0.022
const CORNER := 0.065
var dimensions := Vector2.ZERO
var metal := StandardMaterial3D.new()
var ghost := StandardMaterial3D.new()

func _init() -> void:
	metal.albedo_color = Color("b8a787")
	metal.metallic = 0.8
	metal.roughness = 0.24
	ghost.albedo_color = Color(0.72, 0.8, 0.83, 0.24)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.roughness = 0.32
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_frame(size: Vector2, editing: bool, enabled: bool) -> void:
	material_override = ghost if editing else metal
	visible = enabled
	if size == dimensions:
		return
	dimensions = size
	var path := PackedVector3Array()
	for corner: int in 4:
		var angle := float(corner) * PI * 0.5
		var centre := Vector2(1 if corner in [0, 3] else -1, 1 if corner < 2 else -1) * (size * 0.5 - Vector2.ONE * CORNER)
		for step: int in 9:
			var phase := angle + float(step) / 8.0 * PI * 0.5
			path.append(Vector3(centre.x + cos(phase) * CORNER, centre.y + sin(phase) * CORNER, 0))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in path.size():
		var next := (index + 1) % path.size()
		for side: int in 8:
			for vertex: Vector2i in [Vector2i(index, side), Vector2i(next, side + 1), Vector2i(next, side), Vector2i(index, side), Vector2i(index, side + 1), Vector2i(next, side + 1)]:
				var tangent := (path[(vertex.x + 1) % path.size()] - path[posmod(vertex.x - 1, path.size())]).normalized()
				var radial := Vector3(tangent.y, -tangent.x, 0)
				var phase := float(vertex.y) * TAU / 8.0
				var normal := radial * cos(phase) + Vector3.BACK * sin(phase)
				tool.set_normal(normal)
				tool.add_vertex(path[vertex.x] + normal * THICKNESS)
	mesh = tool.commit()

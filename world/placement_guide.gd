class_name PlacementGuide
extends Node3D

const GRID_SPACING := 0.5
const RADIUS := 2.0
const GRID_COLOR := Color(0.36, 0.70, 0.76, 0.20)
const MARKER_COLOR := Color(0.88, 0.67, 0.34, 0.62)
const LINK_COLOR := Color(0.88, 0.67, 0.34, 0.34)

var reference_y := 0.0
var _grid := MeshInstance3D.new()
var _marker := MeshInstance3D.new()
var _link := MeshInstance3D.new()
var _grid_mesh := ImmediateMesh.new()
var _marker_mesh := ImmediateMesh.new()
var _link_mesh := ImmediateMesh.new()
var _grid_material := _material(GRID_COLOR)
var _marker_material := _material(MARKER_COLOR)
var _link_material := _material(LINK_COLOR)
var _fade: Tween
var _opacity := 1.0
var _grid_origin := Vector2(INF, INF)

func _ready() -> void:
	_grid.mesh = _grid_mesh
	_marker.mesh = _marker_mesh
	_link.mesh = _link_mesh
	_grid.material_override = _grid_material
	_marker.material_override = _marker_material
	_link.material_override = _link_material
	for node: MeshInstance3D in [_grid, _marker, _link]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	visible = false

func configure(next_reference_y: float) -> void:
	_cancel_fade()
	reference_y = next_reference_y
	_grid_origin = Vector2(INF, INF)
	_set_opacity(1.0)
	visible = false

func show_position(pivot: Vector3, active: bool) -> void:
	if active:
		_cancel_fade()
		visible = true
		_set_opacity(1.0)
		_update_grid(pivot)
		_update_marker(pivot)
		_update_link(pivot)
		return
	if not visible or _is_fading():
		return
	_fade = create_tween()
	_fade.tween_method(_set_opacity, _opacity, 0.0, 0.22)
	_fade.tween_callback(func() -> void:
		visible = false
		_fade = null
	)

func _update_grid(pivot: Vector3) -> void:
	var origin := Vector2(snappedf(pivot.x, GRID_SPACING), snappedf(pivot.z, GRID_SPACING))
	if origin == _grid_origin:
		return
	_grid_origin = origin
	_grid_mesh.clear_surfaces()
	_grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var steps := roundi(RADIUS * 2.0 / GRID_SPACING)
	for index: int in range(steps + 1):
		var offset := -RADIUS + float(index) * GRID_SPACING
		var fade := clampf(1.0 - absf(offset) / RADIUS, 0.0, 1.0)
		_faded_line(_grid_mesh, Vector3(origin.x + offset, reference_y + 0.012, origin.y - RADIUS), Vector3(origin.x + offset, reference_y + 0.012, origin.y), Vector3(origin.x + offset, reference_y + 0.012, origin.y + RADIUS), fade)
		_faded_line(_grid_mesh, Vector3(origin.x - RADIUS, reference_y + 0.012, origin.y + offset), Vector3(origin.x, reference_y + 0.012, origin.y + offset), Vector3(origin.x + RADIUS, reference_y + 0.012, origin.y + offset), fade)
	_grid_mesh.surface_end()

func _update_marker(pivot: Vector3) -> void:
	_marker_mesh.clear_surfaces()
	_marker_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var centre := Vector3(pivot.x, reference_y + 0.025, pivot.z)
	var radius := 0.16
	for index: int in 12:
		var start := TAU * float(index) / 12.0
		var finish := TAU * float(index + 1) / 12.0
		_solid_line(_marker_mesh, centre + Vector3(cos(start), 0.0, sin(start)) * radius, centre + Vector3(cos(finish), 0.0, sin(finish)) * radius)
	_marker_mesh.surface_end()

func _update_link(pivot: Vector3) -> void:
	_link_mesh.clear_surfaces()
	_link_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_solid_line(_link_mesh, pivot, Vector3(pivot.x, reference_y + 0.03, pivot.z))
	_link_mesh.surface_end()

func _faded_line(mesh: ImmediateMesh, start: Vector3, middle: Vector3, finish: Vector3, opacity: float) -> void:
	mesh.surface_set_color(Color(1.0, 1.0, 1.0, 0.0))
	mesh.surface_add_vertex(start)
	mesh.surface_set_color(Color(1.0, 1.0, 1.0, opacity))
	mesh.surface_add_vertex(middle)
	mesh.surface_set_color(Color(1.0, 1.0, 1.0, opacity))
	mesh.surface_add_vertex(middle)
	mesh.surface_set_color(Color(1.0, 1.0, 1.0, 0.0))
	mesh.surface_add_vertex(finish)

func _solid_line(mesh: ImmediateMesh, start: Vector3, finish: Vector3) -> void:
	mesh.surface_set_color(Color.WHITE)
	mesh.surface_add_vertex(start)
	mesh.surface_set_color(Color.WHITE)
	mesh.surface_add_vertex(finish)

func _cancel_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null

func _is_fading() -> bool:
	return _fade != null and _fade.is_valid() and _fade.is_running()

func _set_opacity(value: float) -> void:
	_opacity = value
	_grid_material.albedo_color = Color(GRID_COLOR, GRID_COLOR.a * value)
	_marker_material.albedo_color = Color(MARKER_COLOR, MARKER_COLOR.a * value)
	_link_material.albedo_color = Color(LINK_COLOR, LINK_COLOR.a * value)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

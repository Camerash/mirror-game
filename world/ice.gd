extends Node3D
## The pond's ice below a place, and the place mirrored in it. A second
## camera, the stage camera mirrored through the ice, draws the mirror image
## at half size; the ice shows it. Presentation only.

const IceShader := preload("res://world/ice.gdshader")
## Only what is on this render layer shows in the ice: the stones. The
## mirror, its guides, outlines, figures and the snow are not mirrored, so an
## image in the ice is never taken for something to stand on or to move.
const MIRRORED_LAYER := 1 << 10
const IMAGE_SCALE := 0.5
const MAX_POOLS := 6
const EXTENT := 600.0

## The stage camera to mirror.
var camera: Camera3D
## Returns the copies' lights as an array of Vector4 (place, strength).
var glows := Callable()
var height := -2.8
var plane := MeshInstance3D.new()
var material := ShaderMaterial.new()
var view := SubViewport.new()
var eye := Camera3D.new()
var _time := 0.0

func _ready() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(EXTENT, EXTENT)
	plane.mesh = quad
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.shader = IceShader
	plane.material_override = material
	add_child(plane)
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.cull_mask = MIRRORED_LAYER
	view.add_child(eye)
	eye.current = true
	material.set_shader_parameter("reflection", view.get_texture())
	# The stage camera moves on tweens, which step after `_process`; following
	# its signal keeps the mirror image on the same frame.
	if camera != null and camera.has_signal("view_changed"):
		camera.connect("view_changed", follow)

func set_palette(colors: Dictionary) -> void:
	material.set_shader_parameter("near_color", colors["ice_near"])
	material.set_shader_parameter("mid_color", colors["ice_mid"])
	material.set_shader_parameter("far_color", colors["ice_far"])
	material.set_shader_parameter("pool_color", colors["glow"])

func _process(delta: float) -> void:
	_time += delta
	material.set_shader_parameter("ice_time", _time)
	follow()
	var pools := PackedVector4Array()
	if glows.is_valid():
		for glow: Vector4 in glows.call():
			if pools.size() < MAX_POOLS:
				pools.append(glow)
	material.set_shader_parameter("pool_count", pools.size())
	pools.resize(MAX_POOLS)
	material.set_shader_parameter("pools", pools)

## Puts the mirror camera where the stage camera's image in the ice is.
func follow() -> void:
	if camera == null or not is_inside_tree():
		return
	var size := Vector2i((Vector2(get_tree().root.size) * IMAGE_SCALE).ceil()).max(Vector2i(8, 8))
	if view.size != size:
		view.size = size
	var pose := camera.global_transform
	var origin := pose.origin
	origin.y = 2.0 * height - origin.y
	var forward := -pose.basis.z
	forward.y = -forward.y
	# Mirroring turns the view upside down; the ice shader reads it flipped.
	var up := pose.basis.y
	up = Vector3(-up.x, up.y, -up.z)
	eye.global_transform = Transform3D(Basis.looking_at(forward, up), origin)
	eye.size = camera.size
	eye.near = camera.near
	eye.far = camera.far
	# The ice stays under the view, wherever the place is.
	var sight := -pose.basis.z
	var reach := (height - pose.origin.y) / sight.y if absf(sight.y) > 0.001 else 0.0
	var centre := pose.origin + sight * reach
	plane.global_position = Vector3(centre.x, height, centre.z)

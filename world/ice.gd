extends Node3D
## The still water that lies on the pond's ice below a place, and the place
## mirrored in it. A second camera, the stage camera mirrored through the
## water, draws the mirror image at half size; the water shows it.
## Presentation only.

const IceShader := preload("res://world/ice.gdshader")
## Only what is on this render layer shows in the water: the stones, the
## girl, the mirror's pane and the reeds. The mirror's frame, guides and
## outlines and the snow are not mirrored. The image is soft and is gone with
## height (`stone.gdshader`), so it is never taken for something to stand on.
const MIRRORED_LAYER := 1 << 10
const IMAGE_SCALE := 0.5
const MAX_POOLS := 6
const MAX_RINGS := 4
## A thing this far above the water does not disturb it.
const RING_HEIGHT := 2.5
const EXTENT := 600.0
## The water is alone on this render layer (`ICE_LAYER` in the lighting).
const ICE_LAYER := 1 << 11

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
## The last rings something made: place (x, z), start time, strength.
var _rings := PackedVector4Array()
var _next_ring := 0
## The direction from the place to the sun, from the colour script.
var _sun_from := Vector3(0.0, 0.5, -1.0)

func _ready() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(EXTENT, EXTENT)
	plane.mesh = quad
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.layers = ICE_LAYER
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
	material.set_shader_parameter("sun_color", colors["sun"])
	material.set_shader_parameter("shade", colors["shade"])
	_sun_from = colors["sun_from"]

## Something at `at` disturbs the water: a ring spreads from the point below
## it. The higher the thing is above the water, the weaker the ring.
func ring(at: Vector3) -> void:
	var strength := clampf(1.0 - (at.y - height) / RING_HEIGHT, 0.0, 1.0)
	if strength <= 0.0:
		return
	_rings.resize(MAX_RINGS)
	_rings[_next_ring] = Vector4(at.x, at.z, _time, strength)
	_next_ring = (_next_ring + 1) % MAX_RINGS
	material.set_shader_parameter("rings_made", _rings)

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
	# Mirroring turns the view upside down; the water shader reads it flipped.
	var up := pose.basis.y
	up = Vector3(-up.x, up.y, -up.z)
	eye.global_transform = Transform3D(Basis.looking_at(forward, up), origin)
	eye.size = camera.size
	eye.near = camera.near
	eye.far = camera.far
	# The water stays under the view, wherever the place is.
	var sight := -pose.basis.z
	var reach := (height - pose.origin.y) / sight.y if absf(sight.y) > 0.001 else 0.0
	var centre := pose.origin + sight * reach
	plane.global_position = Vector3(centre.x, height, centre.z)
	# The water holds the low sun: it keeps its bearing as the view turns.
	var ahead := Vector2(sight.x, sight.z).normalized()
	var across := Vector2(pose.basis.x.x, pose.basis.x.z).normalized()
	material.set_shader_parameter("view_forward", ahead)
	material.set_shader_parameter("view_right", across)
	material.set_shader_parameter("sun_bearing", angle_difference(ahead.angle(), Vector2(_sun_from.x, _sun_from.z).angle()))

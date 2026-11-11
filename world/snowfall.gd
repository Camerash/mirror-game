extends GPUParticles3D
## Snow falling slowly over a place. It follows the view, so it falls
## wherever the stage camera looks. Presentation only.

const FLAKES := 120
## Far flakes are small and dim.
const FAR_FLAKES := 170
## Some flakes fall nearer the eye: a little larger and softer.
const NEAR_FLAKES := 20
const SPAN := 30.0
const LIFE := 16.0

## The stage camera whose view the snow fills.
var camera: Camera3D
## The snow starts this far above the point the view centres on.
var lift := 9.0

func _ready() -> void:
	_fall(self, FLAKES, 0.062, 0.7, 1.0)
	var far := GPUParticles3D.new()
	_fall(far, FAR_FLAKES, 0.04, 0.34, 0.7)
	add_child(far)
	var near := GPUParticles3D.new()
	_fall(near, NEAR_FLAKES, 0.085, 0.5, 1.5)
	add_child(near)

## Sets `layer` up as falling snow: `count` flakes of `size`, at `alpha`.
static func _fall(layer: GPUParticles3D, count: int, size: float, alpha: float, speed: float) -> void:
	layer.amount = count
	layer.lifetime = LIFE / speed
	layer.preprocess = LIFE / speed
	layer.local_coords = false
	layer.visibility_aabb = AABB(Vector3(-SPAN, -40.0, -SPAN), Vector3(SPAN * 2.0, 60.0, SPAN * 2.0))
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fall := ParticleProcessMaterial.new()
	fall.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fall.emission_box_extents = Vector3(SPAN * 0.5, 0.5, SPAN * 0.5)
	fall.direction = Vector3(0.18, -1.0, 0.08)
	fall.spread = 7.0
	fall.initial_velocity_min = 0.75 * speed
	fall.initial_velocity_max = 1.25 * speed
	# The air is never quite still: each flake wanders as it falls.
	fall.turbulence_enabled = true
	fall.turbulence_noise_strength = 0.35
	fall.turbulence_noise_scale = 3.0
	fall.turbulence_noise_speed = Vector3(0.12, 0.0, 0.08)
	fall.turbulence_influence_min = 0.04
	fall.turbulence_influence_max = 0.14
	fall.gravity = Vector3.ZERO
	# No two flakes are one size.
	fall.scale_min = 0.35
	fall.scale_max = 1.5
	layer.process_material = fall
	var flake := QuadMesh.new()
	# Each flake is drawn out a little along its fall, so that in a still
	# frame the snow reads as falling, not as stars.
	flake.size = Vector2(size, size * 1.45)
	layer.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 32
	soft.height = 32
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.95))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	soft.gradient = fade
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	white.albedo_texture = soft
	white.albedo_color = Color(1.0, 0.98, 0.97, alpha)
	flake.material = white
	layer.draw_pass_1 = flake

func _process(_delta: float) -> void:
	if camera == null:
		return
	# The point the view centres on, at the height the camera frames.
	var pose := camera.global_transform
	var sight := -pose.basis.z
	var reach := -pose.origin.y / sight.y if absf(sight.y) > 0.001 else 0.0
	var centre := pose.origin + sight * reach
	global_position = Vector3(centre.x, lift, centre.z)

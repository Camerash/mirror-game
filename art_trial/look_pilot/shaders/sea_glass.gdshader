shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;
// Frosted sea glass: translucent, brighter where the rounded edges catch
// the light, with a cloudy interior and fine bubbles.
#include "res://art_trial/look_pilot/shaders/noise.gdshaderinc"
uniform vec3 tint : source_color = vec3(0.5, 0.85, 0.8);
uniform vec3 box_centre = vec3(0.0);
uniform vec3 box_size = vec3(0.0);
uniform float opacity = 0.62;
uniform float glow = 0.35;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec2 plane = face_plane(world_position, normal);
	float edge = box_size.x > 0.0 ? face_edge(world_position, normal, box_centre, box_size) : 1.0;
	float rim = 1.0 - smoothstep(0.0, 0.12, edge);
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float frost = fbm(plane * 3.0);
	vec2 grid = plane * 26.0;
	vec2 id = floor(grid);
	float bubble = step(0.9, hash(id)) * smoothstep(0.16, 0.08, length(fract(grid) - 0.5));
	vec3 color = tint * (0.85 + 0.3 * frost);
	color = mix(color, vec3(0.92, 1.0, 0.98), rim * 0.6 + bubble * 0.7);
	ALBEDO = color;
	ALPHA = clamp(opacity + 0.2 * frost + 0.3 * rim + 0.25 * facing, 0.0, 0.95);
	ROUGHNESS = 0.3 + 0.3 * frost;
	EMISSION = tint * glow * (0.6 + 0.8 * rim);
}

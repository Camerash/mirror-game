shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
// A shallow pool lying on a terrace: an irregular rounded patch of clear
// aqua water with caustic light and a darker ring of wet sand.
#include "res://art_trial/look_pilot/shaders/noise.gdshaderinc"
uniform vec3 water : source_color = vec3(0.37, 0.77, 0.77);
uniform vec3 wet_sand : source_color = vec3(0.62, 0.55, 0.43);
uniform float seed = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 centred = UV * 2.0 - 1.0;
	float wobble = 0.3 * (fbm(UV * 2.5 + seed) - 0.5);
	float shape = sqrt(length(centred * centred)) + wobble;
	float inside = 1.0 - smoothstep(0.72, 0.76, shape);
	float ring = (1.0 - smoothstep(0.76, 0.95, shape)) * (1.0 - inside);
	vec2 plane = world_position.xz * 4.0;
	vec2 warped = plane + vec2(fbm(plane * 0.7), fbm(plane * 0.7 + 3.0)) * 2.0;
	float caustic = pow(1.0 - abs(noise(warped) * 2.0 - 1.0), 6.0);
	vec3 color = mix(water * 0.85, vec3(1.0), caustic * 0.6);
	ALBEDO = inside > 0.0 ? color : wet_sand;
	ALPHA = inside * (0.55 + 0.35 * caustic) + ring * 0.45;
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
}

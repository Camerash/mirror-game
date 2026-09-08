shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float ribbon_time = 0.0;
uniform float ribbon_alpha = 1.0;

void fragment() {
	float distance_fade = pow(1.0 - UV.x, 1.7);
	float flow = 0.86 + sin(ribbon_time * 0.9 + UV.x * 5.0) * 0.08;
	ALBEDO = mix(vec3(0.30, 0.68, 0.82), vec3(0.84, 0.97, 1.0), distance_fade);
	ALPHA = distance_fade * flow * 0.26 * ribbon_alpha;
}

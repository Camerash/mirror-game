shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float ribbon_time = 0.0;
uniform float ribbon_alpha = 1.0;
uniform float source_sign = 1.0;

void vertex() {
	VERTEX.z *= source_sign;
}

void fragment() {
	float edge_fade = pow(1.0 - UV.x, 1.2);
	float drift = 0.90 + sin(ribbon_time * 0.55 + UV.y * 2.0) * 0.04;
	ALBEDO = mix(vec3(0.30, 0.65, 0.76), vec3(0.80, 0.95, 1.0), edge_fade);
	ALPHA = edge_fade * drift * 0.60 * ribbon_alpha;
}

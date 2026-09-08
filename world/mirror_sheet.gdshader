shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float sheet_time = 0.0;
uniform float sheet_alpha = 0.11;
uniform bool removal = false;
uniform vec2 panel_size = vec2(3.0);
varying vec3 local_position;
void vertex() {
 local_position = VERTEX;
}

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(41.19, 289.71))) * 43758.55);
}

void fragment() {
	vec2 edge_distance = panel_size * 0.5 - abs(local_position.xy);
	float nearest_edge = min(edge_distance.x, edge_distance.y);
	float perimeter = 1.0 - smoothstep(0.035, 0.18, nearest_edge);
	vec2 drift = local_position.xy * 4.0 + vec2(sheet_time * 0.08, -sheet_time * 0.05);
	vec2 cell = floor(drift);
	float speck = 1.0 - smoothstep(0.02, 0.11, length(fract(drift) - vec2(0.5)));
	float particle = step(0.95, hash(cell)) * speck * (1.0 - smoothstep(0.10, 0.46, nearest_edge));
	ALBEDO = mix(vec3(0.47, 0.72, 0.82), vec3(0.83, 0.96, 1.0), perimeter * 0.72 + particle * 0.28);
	float opacity = sheet_alpha * 0.12 + perimeter * 0.075 + particle * 0.11;
	if (removal) {
		float dash = step(0.52, fract((local_position.x + local_position.y) * 3.5));
		opacity = perimeter * dash * 0.08;
	}
	ALPHA = opacity;
}

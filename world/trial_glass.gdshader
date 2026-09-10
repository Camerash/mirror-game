shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform float sheet_time = 0.0;
uniform float sheet_alpha = 0.11;
uniform bool removal = false;
uniform vec2 panel_size = vec2(3.0);
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	vec2 distance_to_edge = panel_size * 0.5 - abs(local_position.xy);
	float edge = 1.0 - smoothstep(0.01, 0.16, min(distance_to_edge.x, distance_to_edge.y));
	float cloud = sin(local_position.x * 1.7 + sin(local_position.y * 2.1) + sheet_time * 0.025) * 0.5 + 0.5;
	ALBEDO = mix(vec3(0.63, 0.74, 0.79), vec3(0.91, 0.94, 0.93), cloud);
	ROUGHNESS = 0.16 + cloud * 0.035;
	SPECULAR = 0.7;
	METALLIC = 0.1;
	ALPHA = (0.04 + cloud * 0.025 + edge * 0.06) * (removal ? 0.3 : 1.0);
}

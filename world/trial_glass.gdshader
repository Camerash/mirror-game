shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform float sheet_time = 0.0;
uniform float sheet_alpha = 0.11;
uniform bool removal = false;
uniform vec2 panel_size = vec2(3.0);
// Multiplies the opacity. The stage sweep panel has no ribbons or motes, so it
// needs more glass to read.
uniform float presence = 1.0;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	vec2 distance_to_edge = panel_size * 0.5 - abs(local_position.xy);
	// The foot of the pane stays clear, so she and the stones behind it show.
	float nearest = min(distance_to_edge.x, panel_size.y * 0.5 - local_position.y);
	// Frost grows in from the frame in fine crystals; the middle stays clear,
	// so what stands behind the glass is not washed out.
	float frost = pow(1.0 - smoothstep(0.0, 0.16, nearest), 1.6);
	float crystals = 0.62 + 0.38 * sin(local_position.x * 31.0 + sin(local_position.y * 27.0) * 2.0) * sin(local_position.y * 23.0 + local_position.x * 7.0);
	// A slow sheen crosses the pane, as on glass turned in the light.
	float across = local_position.x * 0.8 + local_position.y * 0.55 - sheet_time * 0.11;
	float sheen = pow(0.5 + 0.5 * sin(across * 2.1), 6.0) * 0.6 + pow(0.5 + 0.5 * sin(across * 0.9 + 1.7), 10.0);
	ALBEDO = mix(vec3(0.62, 0.76, 0.86), vec3(0.95, 0.97, 1.0), clamp(frost * crystals + sheen * 0.6, 0.0, 1.0));
	ROUGHNESS = 0.2;
	SPECULAR = 0.5;
	METALLIC = 0.0;
	EMISSION = ALBEDO * (0.22 * frost + 0.16 * sheen);
	ALPHA = (0.025 + frost * crystals * 0.42 + sheen * 0.05) * (removal ? 0.3 : 1.0) * presence;
}

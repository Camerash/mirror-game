shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float sheet_time = 0.0;
uniform float sheet_alpha = 0.11;

void fragment() {
	float ripple = sin(UV.x * 18.0 + UV.y * 11.0 + sheet_time * 1.4) * 0.5 + 0.5;
	float bands = smoothstep(0.72, 0.96, sin((UV.x - UV.y) * 30.0 - sheet_time * 0.7) * 0.5 + 0.5);
	ALBEDO = mix(vec3(0.48, 0.76, 0.86), vec3(0.87, 0.95, 0.98), ripple * 0.26 + bands * 0.18);
	ALPHA = sheet_alpha + ripple * 0.025;
}

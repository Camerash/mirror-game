shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float sheet_time = 0.0;
uniform float sheet_alpha = 0.11;

void fragment() {
	float broad_flow = sin(UV.x * 10.0 + UV.y * 6.0 + sheet_time * 0.65);
	float crossing_flow = sin((UV.x * 5.0 - UV.y * 9.0) - sheet_time * 0.38);
	float interference = broad_flow * crossing_flow * 0.5 + 0.5;
	float filament = pow(1.0 - abs(sin(UV.x * 23.0 + UV.y * 14.0 + broad_flow * 2.0 + crossing_flow * 1.7)), 9.0);
	float centre_fade = smoothstep(0.0, 0.7, length(UV - vec2(0.5)) * 1.42);
	ALBEDO = mix(vec3(0.38, 0.66, 0.79), vec3(0.82, 0.94, 0.98), interference * 0.34 + centre_fade * 0.14 + filament * 0.45);
	ALPHA = sheet_alpha + interference * 0.018 + centre_fade * 0.018 + filament * 0.18;
}

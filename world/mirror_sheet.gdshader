shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float sheet_time = 0.0;
uniform float sheet_alpha = 0.11;
uniform bool full_plane = false;
uniform bool removal = false;
uniform vec3 fade_low;
uniform vec3 fade_high;
varying vec3 local_position;
varying vec3 world_position;
void vertex() {
 local_position = VERTEX;
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 surface = local_position.xy / 3.0 + vec2(0.5);
	float broad_flow = sin(surface.x * 10.0 + surface.y * 6.0 + sheet_time * 0.65);
	float crossing_flow = sin((surface.x * 5.0 - surface.y * 9.0) - sheet_time * 0.38);
	float interference = broad_flow * crossing_flow * 0.5 + 0.5;
	float filament = pow(1.0 - abs(sin(surface.x * 23.0 + surface.y * 14.0 + broad_flow * 2.0 + crossing_flow * 1.7)), 9.0);
	float centre_fade = smoothstep(0.0, 0.7, length(UV - vec2(0.5)) * 1.42);
	ALBEDO = mix(vec3(0.38, 0.66, 0.79), vec3(0.82, 0.94, 0.98), interference * 0.34 + centre_fade * 0.14 + filament * 0.45);
	float fade = 1.0;
	if (full_plane) {
		vec3 outside = max(max(fade_low - world_position, world_position - fade_high), vec3(0.0));
		fade = 1.0 - smoothstep(0.0, 3.0, length(outside));
	}
	float opacity = sheet_alpha + interference * 0.018 + centre_fade * 0.018 + filament * 0.18;
	if (removal) {
		float dash = step(0.5, fract(surface.x * 4.0 + surface.y * 4.0));
		opacity = filament * dash * 0.15;
	}
	ALPHA = opacity * fade;
}

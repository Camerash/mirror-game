shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float mote_time = 0.0;
uniform float mote_alpha = 1.0;
uniform float source_sign = 1.0;
uniform float pixel_world_size = 0.01;

void vertex() {
	float progress = fract(mote_time * 0.22 + COLOR.r);
	vec3 centre = VERTEX - vec3((UV * 2.0 - 1.0) * COLOR.g * 0.03, 0.0);
	centre.z += source_sign * progress * 0.35;
	vec4 view_position = MODELVIEW_MATRIX * vec4(centre, 1.0);
	view_position.xy += (UV * 2.0 - 1.0) * max(pixel_world_size, COLOR.g * 0.03);
	POSITION = PROJECTION_MATRIX * view_position;
}

void fragment() {
	float round_dot = 1.0 - smoothstep(0.25, 0.5, length(UV - vec2(0.5)));
	float progress = fract(mote_time * 0.22 + COLOR.r);
	ALBEDO = vec3(0.72, 0.93, 0.98);
	ALPHA = round_dot * (1.0 - progress) * 0.78 * mote_alpha;
}

shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform float source_sign = 1.0;
uniform float guide_alpha = 1.0;

void vertex() {
	vec3 centre = VERTEX - vec3((UV.x - 0.5) * 0.025, 0.0, 0.0);
	centre.z *= source_sign;
	vec4 view_position = MODELVIEW_MATRIX * vec4(centre, 1.0);
	vec3 view_normal = (MODELVIEW_MATRIX * vec4(0.0, 0.0, source_sign, 0.0)).xyz;
	vec2 lateral = vec2(-view_normal.y, view_normal.x);
	float lateral_length = length(lateral);
	if (lateral_length < 0.0001) {
		lateral = vec2(1.0, 0.0);
	} else {
		lateral /= lateral_length;
	}
	view_position.xy += lateral * (UV.x - 0.5) * 0.025;
	POSITION = PROJECTION_MATRIX * view_position;
}

void fragment() {
	float distance_fade = pow(1.0 - smoothstep(0.0, 0.45, UV.y), 2.0);
	float lateral_fade = 1.0 - smoothstep(0.2, 0.5, abs(UV.x - 0.5));
	ALBEDO = vec3(0.70, 0.82, 0.88);
	ALPHA = distance_fade * lateral_fade * 0.04 * guide_alpha;
}

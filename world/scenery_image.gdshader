shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// The image of the pond's scenery in the ice, drawn as a second pass of the
// scenery itself. For the game's level, parallel view, the image of a point
// at height h over the ice lies on the ice a fixed way toward the viewer, so
// each vertex is laid down there. No second camera is needed, and the image
// is never geometry to stand on.

uniform float ice_level = 0.0;
uniform vec3 tint : source_color = vec3(0.10, 0.08, 0.20);
uniform float strength = 0.34;

varying float lift;

void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The same sway as the scenery, so the image moves with it.
	float gust = sin(TIME * 0.9 + at.x * 0.7 + at.z * 1.1) + 0.45 * sin(TIME * 2.1 + at.x * 1.9 - at.z * 0.6);
	at.xz += vec2(0.93, 0.36) * gust * 0.05 * UV.y * UV.y;
	lift = max(at.y - ice_level, 0.0);
	vec3 ahead = -INV_VIEW_MATRIX[2].xyz;
	at.xz += ahead.xz * (lift / min(ahead.y, -0.05));
	at.y = ice_level + 0.004;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(at, 1.0)).xyz;
}

void fragment() {
	ALBEDO = tint;
	// The image thins with height, as the stones' image does.
	ALPHA = strength * (1.0 - smoothstep(0.1, 1.3, lift));
}

shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;
// A multiply pass drawn over a surface: it darkens and tints toward the
// underside of a floating island, the way painted dioramas fade their bases.
uniform vec3 base : source_color = vec3(1.0);
uniform vec3 tint : source_color = vec3(0.62, 0.55, 0.64);
uniform float top = -0.1;
uniform float bottom = -3.0;
varying float height;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	ALBEDO = base * mix(vec3(1.0), tint, smoothstep(top, bottom, height));
}

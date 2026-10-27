shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Nearly clear mirror glass with a soft glow along its edges.
uniform vec3 tint : source_color = vec3(0.85, 0.92, 1.0);
uniform vec3 glow : source_color = vec3(0.75, 0.9, 1.0);
uniform float clarity = 0.08;
uniform float glow_width = 0.06;
uniform float glow_strength = 0.8;

void fragment() {
	vec2 edge = min(UV, 1.0 - UV);
	float near_edge = 1.0 - smoothstep(0.0, glow_width, min(edge.x, edge.y));
	ALBEDO = mix(tint, glow * (1.0 + glow_strength), near_edge);
	ALPHA = clarity + near_edge * 0.55;
}

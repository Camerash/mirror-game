shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A soft shadow straight below a floating block, on the first surface under
// it, so its height reads in a fixed isometric view. UV spans the quad and
// UV2 holds its size in world units, so the soft edge has a fixed width.
uniform vec3 shade : source_color = vec3(0.16, 0.13, 0.2);
uniform float strength = 0.26;
uniform float feather = 0.14;

void fragment() {
	vec2 inside = min(UV, 1.0 - UV) * UV2;
	float edge = smoothstep(0.0, feather, min(inside.x, inside.y));
	ALBEDO = shade;
	ALPHA = strength * edge * COLOR.a;
}

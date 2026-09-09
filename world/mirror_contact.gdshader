shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform bool removal = false;

void fragment() {
	float centre = 1.0 - smoothstep(0.0, 0.5, abs(UV.x - 0.5));
	float core = 1.0 - smoothstep(0.06, 0.20, abs(UV.x - 0.5));
	ALBEDO = mix(vec3(0.42, 0.82, 0.88), vec3(0.96, 0.98, 0.92), core);
	float dash = removal ? step(0.46, fract(UV.y * 9.0)) : 1.0;
	ALPHA = max(centre * 0.72, core * 0.95) * dash * (removal ? 0.35 : 1.0);
}

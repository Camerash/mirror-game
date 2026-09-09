shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform bool removal = false;

void fragment() {
	float seam_distance = abs(UV.x - 0.5);
	float pixel_width = fwidth(UV.x);
	float core_half_width = max(0.012 / 0.36 * 0.5, pixel_width);
	float core = 1.0 - smoothstep(core_half_width - pixel_width, core_half_width + pixel_width, seam_distance);
	float edge_fade = 1.0 - smoothstep(0.38, 0.5, seam_distance);
	float halo = exp(-pow(seam_distance / 0.22, 2.0)) * edge_fade;
	float halo_variation = 0.96 + 0.04 * sin(UV.y * 2.7 + TIME * 0.10);
	ALBEDO = mix(vec3(0.42, 0.82, 0.88), vec3(0.97, 0.98, 0.94), core);
	float dash = removal ? step(0.46, fract(UV.y * 9.0)) : 1.0;
	ALPHA = max(halo * halo_variation * 0.55, core * 0.95) * dash * (removal ? 0.35 : 1.0);
}

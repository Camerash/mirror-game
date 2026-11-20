shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// One soft shadow on the water for each stone and each copy. The mask is a
// picture that `water_shadow.gd` draws from above: white is full shadow.
uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec3 shade : source_color = vec3(0.07, 0.10, 0.16);
uniform float strength = 0.4;
// 0 to 1: a shadow comes with the stone that casts it, not before it.
uniform float shown = 1.0;

void fragment() {
	ALBEDO = shade;
	ALPHA = texture(mask, UV).r * strength * shown;
}

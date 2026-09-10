shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment() {
 ALBEDO=vec3(0.48,0.70,0.78);
 ALPHA=0.10*pow(1.0-UV.y,2.0);
}

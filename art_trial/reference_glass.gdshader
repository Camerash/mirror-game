shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
void fragment() {
 float wash = smoothstep(-0.7,0.7,sin(UV.x*3.0 + UV.y*4.0));
 ALBEDO = mix(vec3(0.28,0.40,0.46),vec3(0.72,0.79,0.83),wash);
 METALLIC = 0.15;
 ROUGHNESS = 0.12;
 SPECULAR = 0.75;
 ALPHA = 0.17 + wash*0.075;
}

shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
// A broad silver sheen, with no fine noise or simulated studio card.
void fragment() {
 vec2 position = UV * vec2(1.1, 2.43);
 float grazing = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
 float edge_distance = min(min(position.x, 1.1-position.x), min(position.y, 2.43-position.y));
 float edge = 1.0 - smoothstep(0.0, 0.035, edge_distance);
 float sheen = smoothstep(0.15, 0.8, UV.y * 0.7 + UV.x * 0.3);
 ALBEDO = mix(vec3(0.55, 0.64, 0.67), vec3(0.69, 0.75, 0.77), sheen);
 METALLIC = 0.35;
 ROUGHNESS = 0.44;
 SPECULAR = 0.3;
 ALPHA = 0.24 + grazing * 0.26 + edge * 0.10;
}

shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_prepass_alpha;

uniform float ghost_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float flow_time = 0.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float flowing_fog = sin(world_position.y * 7.0 - flow_time * 1.4 + sin(world_position.x * 4.0 + flow_time * 0.7) * 1.5) * 0.5 + 0.5;
	float pearl = sin(world_position.x * 9.0 - world_position.z * 6.0 + flow_time * 0.6) * 0.5 + 0.5;
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.2);
	vec3 mirror_blue = mix(vec3(0.32, 0.60, 0.82), vec3(0.82, 0.95, 1.0), pearl * 0.45 + flowing_fog * 0.30);
	ALBEDO = mirror_blue;
	EMISSION = mirror_blue * (0.13 + rim * 0.33 + flowing_fog * 0.07);
	ALPHA = ghost_opacity * (0.15 + flowing_fog * 0.13 + rim * 0.31);
}

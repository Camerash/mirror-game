shader_type spatial;
render_mode diffuse_burley;

uniform vec4 pigment : source_color = vec4(0.76, 0.70, 0.60, 1.0);
uniform bool absolute_surface = false;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = sin(world_position.x * 39.0 + sin(world_position.z * 27.0)) * sin(world_position.y * 35.0 + world_position.z * 31.0);
	vec3 color = pigment.rgb * (0.99 + grain * 0.01);
	if (absolute_surface) {
		float bands = smoothstep(0.40, 0.44, fract((world_position.x + world_position.z + world_position.y) * 4.0));
		color = mix(color * 0.88, color, bands);
	}
	ALBEDO = color;
	ROUGHNESS = 0.92;
}

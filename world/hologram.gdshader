shader_type spatial;
render_mode blend_mix, diffuse_burley, cull_disabled, depth_prepass_alpha;

uniform vec4 pigment : source_color = vec4(0.35, 0.55, 0.75, 1.0);
uniform bool hologram_enabled = false;
uniform vec3 box_centre;
uniform vec3 box_size = vec3(1.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float top = smoothstep(0.58, 0.88, world_normal.y);
	float contour = sin(world_position.x * 3.4 + sin(world_position.z * 2.6)) * 0.5 + 0.5;
	vec3 normalized_box = abs(world_position - box_centre) / max(box_size * 0.5, vec3(0.05));
	float edge_coordinate = max(min(normalized_box.x, normalized_box.y), min(max(normalized_box.x, normalized_box.y), normalized_box.z));
	float boundary = smoothstep(0.88, 0.995, edge_coordinate);
	vec3 pearl_blue = mix(vec3(0.29, 0.48, 0.70), vec3(0.70, 0.87, 0.98), contour * 0.24 + top * 0.34 + boundary * 0.24);
	float grain = sin(world_position.x * 41.0 + world_position.z * 33.0) * sin(world_position.y * 37.0 + world_position.z * 21.0);
	ALBEDO = hologram_enabled ? pearl_blue * (0.96 + grain * 0.035) : pigment.rgb;
	EMISSION = hologram_enabled ? pearl_blue * (0.12 + top * 0.10 + boundary * 0.22) : vec3(0.0);
	ROUGHNESS = 0.66;
	ALPHA = hologram_enabled ? mix(0.42 + boundary * 0.26, 1.0, top) : 1.0;
}

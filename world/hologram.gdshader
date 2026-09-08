shader_type spatial;
render_mode blend_mix, diffuse_burley, cull_disabled, depth_prepass_alpha;

uniform vec4 pigment : source_color = vec4(0.35, 0.55, 0.75, 1.0);
uniform bool hologram_enabled = false;
uniform vec3 box_centre;
uniform vec3 box_size = vec3(1.0);
uniform mat4 world_to_material;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 source_position = (world_to_material * vec4(world_position, 1.0)).xyz;
	float top = smoothstep(0.58, 0.88, world_normal.y);
	float contour = sin(source_position.x * 3.4 + sin(source_position.z * 2.6)) * 0.5 + 0.5;
	vec3 local = world_position - box_centre;
	vec3 half_size = max(box_size * 0.5, vec3(0.0001));
	vec3 face = abs(world_normal);
	vec2 edge_distance = face.y > max(face.x, face.z) ? half_size.xz - abs(local.xz) : (face.x > face.z ? half_size.zy - abs(local.zy) : half_size.xy - abs(local.xy));
	float boundary = 1.0 - smoothstep(0.012, 0.045, min(edge_distance.x, edge_distance.y));
	vec3 pearl_blue = mix(vec3(0.29, 0.48, 0.70), vec3(0.70, 0.87, 0.98), contour * 0.24 + top * 0.34 + boundary * 0.24);
	float grain = sin(source_position.x * 41.0 + source_position.z * 33.0) * sin(source_position.y * 37.0 + source_position.z * 21.0);
	ALBEDO = hologram_enabled ? pearl_blue * (0.96 + grain * 0.035) : pigment.rgb;
	EMISSION = hologram_enabled ? pearl_blue * (0.12 + top * 0.10 + boundary * 0.22) : vec3(0.0);
	ROUGHNESS = 0.66;
	ALPHA = hologram_enabled ? mix(0.42 + boundary * 0.26, 1.0, top) : 1.0;
}

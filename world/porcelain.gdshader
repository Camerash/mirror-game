shader_type spatial;
render_mode blend_mix, diffuse_burley, cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D roughness_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D height_map : repeat_enable, filter_linear_mipmap;
uniform bool polygon_surface = false;
uniform bool absolute_surface = false;
uniform bool stone_trial = false;
uniform vec3 box_centre;
uniform vec3 box_size = vec3(1.0);
uniform vec3 source_size = vec3(1.0);
uniform mat4 world_to_material;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 source_uv(vec3 position, vec3 normal) {
	vec3 face = abs(normal);
	if (face.y > max(face.x, face.z)) {
		return position.xz * 0.62;
	}
	return face.x > face.z ? position.zy * 0.62 : position.xy * 0.62;
}

float arch_line(vec2 coordinate) {
	float horizontal = fract(coordinate.x + 0.5) - 0.5;
	float vertical = clamp(coordinate.y, 0.0, 1.0);
	float band = 0.0;
	for (int index = 0; index < 3; index++) {
		float radius = 0.42 - float(index) * 0.115;
		float arc = vertical >= 0.30 ? abs(length(vec2(horizontal * 1.08, vertical - 0.30)) - radius) : 1.0;
		float legs = vertical < 0.30 ? abs(abs(horizontal * 1.08) - radius) : 1.0;
		band = max(band, 1.0 - smoothstep(0.006, 0.019, min(arc, legs)));
	}
	return band;
}

void fragment() {
	vec3 source_position = (world_to_material * vec4(world_position, 1.0)).xyz;
	mat3 world_to_source = mat3(world_to_material);
	vec3 source_normal = normalize(world_to_source * world_normal);
	vec3 half_source = max(source_size * 0.5, vec3(0.0001));
	vec3 face = abs(source_normal);
	vec3 source_plane_distance = abs(abs(source_position) - half_source);
	float source_boundary = dot(source_plane_distance, face);
	bool cut_face = (polygon_surface && COLOR.g > 0.5) || source_boundary > 0.003;
	bool top_face = source_normal.y > 0.72;
	bool side_face = !top_face && face.y < 0.72;
	vec2 uv = source_uv(source_position, source_normal);
	vec3 base = mix(texture(albedo_map, uv).rgb, vec3(0.79, 0.88, 0.96), 0.43);
	float map_roughness = texture(roughness_map, uv).r;
	float height = texture(height_map, uv).r - 0.5;
	vec3 detail = texture(normal_map, uv).rgb * 2.0 - 1.0;
	vec3 tangent_seed = abs(source_normal.y) < 0.88 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(tangent_seed, source_normal));
	vec3 bitangent = normalize(cross(source_normal, tangent));
	vec3 source_relief = normalize(source_normal + tangent * detail.x * 0.10 + bitangent * detail.y * 0.10);
	if (side_face && !cut_face) {
		float horizontal = face.x > face.z ? source_position.z : source_position.x;
		float vertical = source_position.y / source_size.y + 0.5;
		float arch = arch_line(vec2(horizontal, vertical));
		float arch_dx = (arch_line(vec2(horizontal + 0.010, vertical)) - arch_line(vec2(horizontal - 0.010, vertical))) * 50.0;
		float arch_dy = (arch_line(vec2(horizontal, vertical + 0.010)) - arch_line(vec2(horizontal, vertical - 0.010))) * 50.0;
		vec3 arch_axis = face.x > face.z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		source_relief = normalize(source_relief + arch_axis * arch_dx * 0.009 + vec3(0.0, 1.0, 0.0) * arch_dy * 0.009);
		base = mix(base, vec3(0.45, 0.70, 0.76), arch * 0.25);
		map_roughness = mix(map_roughness, 0.24, arch);
	}
	if (cut_face) {
		base = mix(base, vec3(0.72, 0.80, 0.84), 0.34);
		map_roughness = 0.49;
	}
	if (top_face || cut_face) {
		base *= 1.055 + height * 0.035;
	}
	if (top_face && !cut_face) {
		vec2 top_edge = half_source.xz - abs(source_position.xz);
		float border = 1.0 - smoothstep(0.004, 0.012, abs(min(top_edge.x, top_edge.y) - 0.065));
		base *= 1.0 - border * 0.16;
		map_roughness += border * 0.08;
	}
	if (!cut_face) {
		vec3 manufactured_edge = max(abs(source_position) - (half_source - vec3(0.035)), vec3(0.0)) * (vec3(1.0) - face);
		source_relief = normalize(source_relief + sign(source_position) * manufactured_edge * 24.0);
	}
	mat3 source_to_world = inverse(world_to_source);
	vec3 world_relief = normalize(source_to_world * source_relief);
	NORMAL = normalize((VIEW_MATRIX * vec4(world_relief, 0.0)).xyz);
	ALBEDO = base;
	METALLIC = 0.0;
	SPECULAR = 0.76;
	ROUGHNESS = clamp(map_roughness + height * 0.08, 0.12, 0.54);
	ALPHA = (top_face || cut_face) ? 1.0 : 0.90;
}

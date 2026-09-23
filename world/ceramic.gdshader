shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D roughness_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D height_map : repeat_enable, filter_linear_mipmap;
uniform bool jade_surface = false;
uniform bool polygon_surface = false;
uniform vec3 box_centre;
uniform vec3 box_size = vec3(1.0);
uniform vec3 source_size = vec3(1.0);
uniform mat4 world_to_material;
uniform vec4 clip_plane = vec4(0.0);
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
		float line = min(arc, vertical < 0.30 ? legs : 1.0);
		band = max(band, 1.0 - smoothstep(0.006, 0.019, line));
	}
	return band;
}

void fragment() {
	if (clip_plane.xyz != vec3(0.0) && dot(clip_plane.xyz, world_position) > clip_plane.w) {
		discard;
	}
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
	vec3 base = texture(albedo_map, uv).rgb;
	float map_roughness = texture(roughness_map, uv).r;
	float height = texture(height_map, uv).r - 0.5;
	vec3 detail = texture(normal_map, uv).rgb * 2.0 - 1.0;
	vec3 tangent_seed = abs(source_normal.y) < 0.88 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(tangent_seed, source_normal));
	vec3 bitangent = normalize(cross(source_normal, tangent));
	vec3 source_relief = normalize(source_normal + tangent * detail.x * 0.13 + bitangent * detail.y * 0.13);
	float arch = 0.0;
	if (side_face && !cut_face) {
		float horizontal = face.x > face.z ? source_position.z : source_position.x;
		float vertical = source_position.y / source_size.y + 0.5;
		arch = arch_line(vec2(horizontal, vertical));
		float arch_dx = (arch_line(vec2(horizontal + 0.010, vertical)) - arch_line(vec2(horizontal - 0.010, vertical))) * 50.0;
		float arch_dy = (arch_line(vec2(horizontal, vertical + 0.010)) - arch_line(vec2(horizontal, vertical - 0.010))) * 50.0;
		vec3 arch_axis = face.x > face.z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
		source_relief = normalize(source_relief + arch_axis * arch_dx * 0.055 + vec3(0.0, 1.0, 0.0) * arch_dy * 0.055);
	}
	if (arch > 0.0) {
		source_relief = normalize(source_relief - source_normal * arch * 0.13);
		base = mix(base, jade_surface ? vec3(0.075, 0.16, 0.12) : vec3(0.33, 0.46, 0.39), arch * 0.32);
		map_roughness = mix(map_roughness, 0.31, arch);
	}
	if (cut_face) {
		base = mix(base, jade_surface ? vec3(0.18, 0.31, 0.24) : vec3(0.71, 0.68, 0.57), 0.45);
		map_roughness = 0.62;
	}
	if (top_face && !cut_face) {
		base *= 1.04 + height * 0.04;
		map_roughness *= 0.76;
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
	SPECULAR = jade_surface ? 0.62 : 0.55;
	ROUGHNESS = clamp(map_roughness + height * 0.10, 0.16, 0.68);
}

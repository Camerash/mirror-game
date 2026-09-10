shader_type spatial;
render_mode diffuse_burley, depth_prepass_alpha;

uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D roughness_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D height_map : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.82, 0.75, 0.61);
uniform bool jade = false;
uniform bool reflected = false;
uniform bool cut_surface = false;
varying vec3 source_position;
varying vec3 source_normal;
varying mat3 normal_to_view;

void vertex() {
	source_position = VERTEX;
	source_normal = NORMAL;
 normal_to_view = mat3(MODELVIEW_MATRIX);
}

vec4 triplanar(sampler2D map, vec3 position, vec3 normal) {
	vec3 weights = pow(abs(normal), vec3(5.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	return texture(map, position.zy) * weights.x + texture(map, position.xz) * weights.y + texture(map, position.xy) * weights.z;
}

float arch_distance(vec2 point, float radius) {
	float legs = abs(abs(point.x) - radius);
	float arc = abs(length(vec2(point.x, point.y - radius)) - radius);
	return point.y < radius ? legs : arc;
}

float ceramic_arch(vec2 point) {
	float result = 0.0;
	for (int index = 0; index < 3; index++) {
		float offset = (float(index) - 1.0) * 0.29;
		float line = arch_distance(vec2(point.x - offset, point.y - 0.10), 0.092);
		result = max(result, 1.0 - smoothstep(0.012, 0.045, line));
	}
	return result;
}

float jade_arch(vec2 point) {
	float result = 0.0;
	for (int index = 0; index < 3; index++) {
		float radius = 0.27 - float(index) * 0.07;
		float line = arch_distance(vec2(point.x, point.y - 0.10), radius);
		result = max(result, 1.0 - smoothstep(0.010, 0.042, line));
	}
	return result;
}

void fragment() {
	vec3 normal = normalize(source_normal);
	vec3 face = abs(normal);
	bool top = normal.y > 0.72;
	bool side = !top && face.y < 0.72;
	vec2 side_point = face.x > face.z ? source_position.zy : source_position.xy;
	side_point.y += 0.35;
 float arch = 0.0;
	if (side && !cut_surface) {
		arch = jade ? jade_arch(side_point) : ceramic_arch(side_point);
	}
	float top_border = jade && top && !cut_surface ? 1.0 - smoothstep(0.015, 0.060, abs(min(0.5 - abs(source_position.x), 0.5 - abs(source_position.z)) - 0.080)) : 0.0;
	vec3 base = triplanar(albedo_map, source_position * 1.35, normal).rgb * tint * 1.18;
	float roughness = triplanar(roughness_map, source_position * 1.35, normal).r;
	float height = triplanar(height_map, source_position * 1.35, normal).r - 0.5;
	if (cut_surface) {
		base = mix(base, jade ? vec3(0.13, 0.29, 0.18) : vec3(0.61, 0.55, 0.42), 0.58);
		roughness = 0.56;
	} else {
		base = mix(base, jade ? vec3(0.055, 0.18, 0.09) : vec3(0.33, 0.38, 0.27), arch * 0.48);
		roughness = mix(roughness, 0.28, arch * 0.72);
		base = mix(base, vec3(0.13, 0.31, 0.19), top_border * 0.34);
		roughness = mix(roughness, 0.24, top_border * 0.60);
	}
	vec3 relief_normal = normal;
 if (!cut_surface) {
  vec3 wave = vec3(cos(source_position.x*7.0+source_position.z*2.0),sin(source_position.y*6.0),sin(source_position.z*8.0+source_position.x*1.5));
  relief_normal = normalize(normal + wave*(vec3(1.0)-abs(normal))*0.055);
 }
 if (side && !cut_surface) {
  float h_right = jade ? jade_arch(side_point+vec2(0.002,0)) : ceramic_arch(side_point+vec2(0.002,0));
  float h_left = jade ? jade_arch(side_point-vec2(0.002,0)) : ceramic_arch(side_point-vec2(0.002,0));
  float h_up = jade ? jade_arch(side_point+vec2(0,0.002)) : ceramic_arch(side_point+vec2(0,0.002));
  float h_down = jade ? jade_arch(side_point-vec2(0,0.002)) : ceramic_arch(side_point-vec2(0,0.002));
  vec3 horizontal = face.x > face.z ? vec3(0,0,1) : vec3(1,0,0);
  relief_normal = normalize(normal + horizontal * (h_right-h_left)*2.0 + vec3(0,1,0)*(h_up-h_down)*2.0);
 }
 NORMAL = normalize(normal_to_view*relief_normal);
 ALBEDO = reflected ? mix(base, vec3(0.24, 0.44, 0.57), 0.72) : base;
	ROUGHNESS = clamp(roughness + height * 0.15, 0.11, 0.62);
	SPECULAR = jade ? 0.72 : 0.60;
 ALPHA = reflected && side && !cut_surface ? 0.96 : 1.0;
}

shader_type spatial;
render_mode diffuse_burley, depth_prepass_alpha;

uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D roughness_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D side_normal : repeat_disable, filter_linear_mipmap;
uniform sampler2D top_normal : repeat_disable, filter_linear_mipmap;
uniform sampler2D side_masks : repeat_disable, filter_linear_mipmap;
uniform sampler2D top_masks : repeat_disable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.90, 0.94, 0.98);
uniform bool jade = false;
uniform bool reflected = false;
uniform bool goal_socket = false;
uniform float variation = 0.0;
varying vec3 source_position;
varying vec3 source_normal;
varying mat3 normal_to_view;

void vertex() {
 source_position = VERTEX;
 source_normal = NORMAL;
 normal_to_view = mat3(MODELVIEW_MATRIX);
}

vec3 weights_for(vec3 normal) {
 vec3 weights = pow(abs(normal), vec3(8.0));
 return weights / max(dot(weights, vec3(1.0)), 0.001);
}

vec3 grain(sampler2D map, vec3 position, vec3 weights) {
 return texture(map, position.zy).rgb * weights.x + texture(map, position.xz).rgb * weights.y + texture(map, position.xy).rgb * weights.z;
}

void fragment() {
 vec3 n = normalize(source_normal);
 vec3 weights = weights_for(n);
 vec2 uv_x = vec2(source_position.z + 0.5, (source_position.y + 0.35) / 0.7);
 vec2 uv_z = vec2(source_position.x + 0.5, (source_position.y + 0.35) / 0.7);
 vec2 uv_y = source_position.xz + vec2(0.5);
 // PNG rows run down; the bake's tile V runs up.
 uv_x.y = 1.0 - uv_x.y;
 uv_z.y = 1.0 - uv_z.y;
 uv_y.y = 1.0 - uv_y.y;
 vec3 nx = texture(side_normal, uv_x).rgb * 2.0 - 1.0;
 vec3 nz = texture(side_normal, uv_z).rgb * 2.0 - 1.0;
 vec3 ny = texture(top_normal, uv_y).rgb * 2.0 - 1.0;
 vec3 masks = texture(side_masks, uv_x).rgb * weights.x + texture(top_masks, uv_y).rgb * weights.y + texture(side_masks, uv_z).rgb * weights.z;
 // Build source-local tangent slopes. Reflected copies keep these coordinates.
 float relief_strength = jade ? 0.26 : 0.38;
 vec3 relief = n + vec3(0.0, nx.y, nx.x) * weights.x * relief_strength;
 relief += vec3(ny.x, 0.0, ny.y) * weights.y * relief_strength;
 relief += vec3(nz.x, nz.y, 0.0) * weights.z * relief_strength;
 vec3 sample_position = source_position * 1.35 + vec3(variation * 0.271, variation * 0.173, variation * 0.391);
 vec3 mapped_base = grain(albedo_map, sample_position, weights) * tint;
 vec3 base_tone = jade ? vec3(0.055, 0.105, 0.075) : vec3(0.72, 0.66, 0.52);
 vec3 base = mix(base_tone, base_tone * (0.92 + mapped_base * 0.16), jade ? 0.10 : 0.08) * (1.0 + variation * 0.012);
 float mapped_roughness = grain(roughness_map, sample_position, weights).r;
 float roughness = mix(jade ? 0.43 : 0.36, mapped_roughness, 0.18);
 relief = normalize(relief);
 float pool = clamp(masks.g * 0.55, 0.0, 0.55);
 float socket = goal_socket ? (1.0-smoothstep(0.10,0.14,length(source_position.xz))) * (1.0-smoothstep(0.29,0.345,source_position.y)) : 0.0;
 base = mix(base, jade ? vec3(0.055,0.12,0.09) : vec3(0.34,0.46,0.40), pool);
 base = mix(base, jade ? vec3(0.17,0.25,0.20) : vec3(0.80,0.83,0.71), masks.b * 0.055);
 base = mix(base,vec3(0.018,0.035,0.025),socket);
 NORMAL = normalize(normal_to_view * relief);
 ALBEDO = reflected ? mix(base, vec3(0.40,0.59,0.73), 0.42) : base;
 AO = mix(mix(1.0, masks.r, 0.46),0.38,socket);
 AO_LIGHT_AFFECT = 0.22;
 ROUGHNESS = clamp(roughness - pool * 0.025, 0.31, 0.47);
 SPECULAR = jade ? 0.40 : 0.46;
 ROUGHNESS = mix(ROUGHNESS,0.50,socket);
 CLEARCOAT = (jade ? 0.07 : 0.10) * (1.0-socket);
 CLEARCOAT_ROUGHNESS = 0.46;
 ALPHA = reflected && abs(n.y) < 0.72 ? 0.94 : 1.0;
}

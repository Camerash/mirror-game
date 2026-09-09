shader_type spatial;
render_mode diffuse_burley;

uniform vec4 pigment : source_color = vec4(0.76, 0.70, 0.60, 1.0);
uniform bool absolute_surface = false;
uniform bool stone_trial = false;
uniform bool polygon_surface = false;
uniform vec3 box_centre;
uniform vec3 box_size = vec3(1.0);
uniform mat4 world_to_material;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 source_position = (world_to_material * vec4(world_position, 1.0)).xyz;
	vec3 source_normal = normalize((world_to_material * vec4(world_normal, 0.0)).xyz);
	float grain = sin(source_position.x * 39.0 + sin(source_position.z * 27.0)) * sin(source_position.y * 35.0 + source_position.z * 31.0);
	vec3 color = pigment.rgb * (0.99 + grain * 0.01);
	if (stone_trial && !absolute_surface) {
		vec3 local = world_position - box_centre;
		vec3 half_size = max(box_size * 0.5, vec3(0.0001));
		vec3 face = abs(source_normal);
		vec3 world_face = abs(world_normal);
		// Round the lighting at edges without moving vertices or walkable tops.
		vec3 edge_distance = max(abs(local) - (half_size - vec3(0.045)), vec3(0.0));
		vec3 rounded_normal = polygon_surface ? world_normal : normalize(world_normal + sign(local) * edge_distance * 8.0);
		NORMAL = normalize((VIEW_MATRIX * vec4(rounded_normal, 0.0)).xyz);
		vec2 surface = face.y > max(face.x, face.z) ? source_position.xz : (face.x > face.z ? source_position.zy : source_position.xy);
		vec2 scaled = surface * vec2(1.42, 1.17);
		scaled += vec2(sin(surface.y * 8.7), sin(surface.x * 9.3)) * 0.008;
		float row = floor(scaled.y);
		scaled.x += mod(row, 2.0) * 0.32 + (hash21(vec2(row, 8.0)) - 0.5) * 0.12;
		vec2 tile = fract(scaled);
		vec2 cell = floor(scaled);
		float joint_width = 0.003 + hash21(cell) * 0.006;
		float joint = 1.0 - smoothstep(joint_width, joint_width + 0.020, min(min(tile.x, 1.0 - tile.x), min(tile.y, 1.0 - tile.y)));
		vec2 tangent_edge_distance = world_face.y > max(world_face.x, world_face.z) ? half_size.xz - abs(local.xz) : (world_face.x > world_face.z ? half_size.zy - abs(local.zy) : half_size.xy - abs(local.xy));
		float bevel = 1.0 - smoothstep(0.012, 0.045, polygon_surface ? COLOR.r : min(tangent_edge_distance.x, tangent_edge_distance.y));
		float chip = sin(surface.x * 31.0 + surface.y * 17.0) * sin(surface.x * 11.0 - surface.y * 23.0) + (hash21(cell) - 0.5) * 0.35;
		float wear = sin(surface.x * 4.3 + sin(surface.y * 3.1)) * 0.5 + 0.5;
		float pores = sin(surface.x * 57.0 + surface.y * 41.0) * sin(surface.y * 47.0 - surface.x * 29.0);
		float highlight = face.y > 0.8 ? 1.10 : 0.87;
		color *= highlight + chip * 0.030 + (hash21(cell) - 0.5) * 0.10;
		color = mix(color, color * 0.68, joint * 0.65);
		color = mix(color, color * 0.78, bevel * 0.42);
		color = mix(color, color * (0.94 + pores * 0.025), wear * 0.10);
		color += vec3(0.045, 0.035, 0.020) * (1.0 - bevel) * (face.y > 0.8 ? 1.0 : 0.25);
	} else if (absolute_surface) {
		float bands = smoothstep(0.40, 0.44, fract((source_position.x + source_position.z + source_position.y) * 4.0));
		color = mix(vec3(0.09, 0.25, 0.15), color, bands * (stone_trial ? 0.62 : 0.82));
	}
	if (polygon_surface && !stone_trial) {
		float edge = 1.0 - smoothstep(0.008, 0.045, COLOR.r);
		color = mix(color, absolute_surface ? vec3(0.06, 0.19, 0.11) : color * 0.64, edge * 0.58);
	}
	ALBEDO = color;
	ROUGHNESS = 0.92;
}

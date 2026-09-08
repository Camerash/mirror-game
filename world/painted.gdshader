shader_type spatial;
render_mode diffuse_burley;

uniform vec4 pigment : source_color = vec4(0.76, 0.70, 0.60, 1.0);
uniform bool absolute_surface = false;
uniform bool stone_trial = false;
uniform vec3 box_centre;
uniform vec3 box_size = vec3(1.0);
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
	float grain = sin(world_position.x * 39.0 + sin(world_position.z * 27.0)) * sin(world_position.y * 35.0 + world_position.z * 31.0);
	vec3 color = pigment.rgb * (0.99 + grain * 0.01);
	if (stone_trial && !absolute_surface) {
		vec3 local = world_position - box_centre;
		vec3 half_size = max(box_size * 0.5, vec3(0.05));
		vec3 face = abs(world_normal);
		// Round the lighting at edges without moving vertices or walkable tops.
		vec3 edge_distance = max(abs(local) - (half_size - vec3(0.045)), vec3(0.0));
		vec3 rounded_normal = normalize(sign(local) * edge_distance);
		NORMAL = normalize((VIEW_MATRIX * vec4(rounded_normal, 0.0)).xyz);
		vec2 surface = face.y > max(face.x, face.z) ? local.xz : (face.x > face.z ? local.zy : local.xy);
		vec2 scaled = surface * vec2(1.62, 1.34);
		float row = floor(scaled.y);
		scaled.x += mod(row, 2.0) * 0.32 + (hash21(vec2(row, 8.0)) - 0.5) * 0.12;
		vec2 tile = fract(scaled);
		vec2 cell = floor(scaled);
		float joint_width = 0.008 + hash21(cell) * 0.010;
		float joint = 1.0 - smoothstep(joint_width, joint_width + 0.020, min(min(tile.x, 1.0 - tile.x), min(tile.y, 1.0 - tile.y)));
		vec2 edge_axes = face.y > max(face.x, face.z) ? abs(local.xz / half_size.xz) : (face.x > face.z ? abs(local.zy / half_size.zy) : abs(local.xy / half_size.xy));
		float bevel = smoothstep(0.78, 0.98, max(edge_axes.x, edge_axes.y));
		float chip = sin(surface.x * 31.0 + surface.y * 17.0) * sin(surface.x * 11.0 - surface.y * 23.0) + (hash21(cell) - 0.5) * 0.35;
		float highlight = face.y > 0.8 ? 1.10 : 0.87;
		color *= highlight + chip * 0.025 + (hash21(cell) - 0.5) * 0.09;
		color = mix(color, color * 0.62, joint * 0.72);
		color = mix(color, color * 0.78, bevel * 0.42);
		color += vec3(0.045, 0.035, 0.020) * (1.0 - bevel) * (face.y > 0.8 ? 1.0 : 0.25);
	} else if (absolute_surface) {
		float bands = smoothstep(0.40, 0.44, fract((world_position.x + world_position.z + world_position.y) * 4.0));
		color = stone_trial ? mix(color * 0.94, color, bands * 0.45) : mix(color * 0.88, color, bands);
	}
	ALBEDO = color;
	ROUGHNESS = 0.92;
}

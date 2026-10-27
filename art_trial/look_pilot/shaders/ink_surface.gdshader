shader_type spatial;
render_mode unshaded;
// Paper with watercolour washes: three tonal bands from a fixed light
// direction, broken up by noise, darker toward the undersides.
uniform vec3 paper : source_color = vec3(0.95, 0.93, 0.88);
uniform vec3 wash : source_color = vec3(0.36, 0.42, 0.52);
uniform vec3 light_dir = vec3(-0.45, 0.8, 0.35);
uniform float strength = 0.6;
uniform float underside = 0.35;
uniform bool use_vertex_color = false;
uniform vec3 box_centre = vec3(0.0);
uniform vec3 box_size = vec3(0.0);
uniform float edge_width = 0.026;
uniform vec3 ink : source_color = vec3(0.13, 0.13, 0.15);
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += amplitude * noise(p);
		p *= 2.1;
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec3 axis = abs(normal);
	vec2 plane = axis.y > max(axis.x, axis.z) ? world_position.xz : (axis.x > axis.z ? world_position.zy : world_position.xy);
	float lit = dot(normal, normalize(light_dir));
	float band = lit > 0.55 ? 0.0 : (lit > -0.1 ? 0.42 : 0.8);
	float bloom = fbm(plane * 1.2 + 4.0);
	float amount = band * (0.55 + 0.9 * bloom) + smoothstep(-0.4, -3.0, world_position.y) * underside;
	vec3 tint = use_vertex_color ? COLOR.rgb : wash;
	vec3 color = mix(paper, tint, clamp(amount * strength + (use_vertex_color ? 0.55 : 0.0), 0.0, 1.0));
	color *= 0.93 + 0.07 * fbm(plane * 14.0);
	if (box_size.x > 0.0) {
		// Ink along every edge of a box face, with a slight brush wobble.
		vec3 local = world_position - box_centre;
		vec3 margin = box_size * 0.5 - abs(local);
		float distance_to_edge = axis.y > max(axis.x, axis.z) ? min(margin.x, margin.z) : (axis.x > axis.z ? min(margin.y, margin.z) : min(margin.x, margin.y));
		float width = edge_width * (0.7 + 0.6 * fbm(plane * 3.0 + 9.0));
		color = mix(color, ink, 1.0 - smoothstep(width * 0.6, width, distance_to_edge));
	}
	ALBEDO = color;
}

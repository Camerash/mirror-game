shader_type spatial;
render_mode unshaded, depth_draw_opaque;
// The mirror's copy as translucent blue ink brushed over the paper.
uniform vec3 ink : source_color = vec3(0.16, 0.30, 0.55);
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz * 1.6 + world_position.y * vec2(0.9, -0.7);
	float wash = noise(p) * 0.6 + noise(p * 3.1) * 0.3 + noise(p * 9.0) * 0.1;
	ALBEDO = mix(vec3(0.93, 0.94, 0.95), ink, 0.35 + 0.55 * wash);
	ALPHA = 0.55 + 0.4 * wash;
}

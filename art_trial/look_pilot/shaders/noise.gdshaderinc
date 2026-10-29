// Value noise shared by the look pilot's material shaders.
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

// The face plane a world point lies on, from its normal: xz on tops, the
// horizontal axis and height on sides.
vec2 face_plane(vec3 position, vec3 normal) {
	vec3 axis = abs(normal);
	return axis.y > max(axis.x, axis.z) ? position.xz : (axis.x > axis.z ? vec2(position.z, position.y) : position.xy);
}

// Distance from a point on a box face to the nearest edge of that face.
float face_edge(vec3 position, vec3 normal, vec3 centre, vec3 size) {
	vec3 axis = abs(normal);
	vec3 margin = size * 0.5 - abs(position - centre);
	return axis.y > max(axis.x, axis.z) ? min(margin.x, margin.z) : (axis.x > axis.z ? min(margin.y, margin.z) : min(margin.x, margin.y));
}

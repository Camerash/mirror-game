shader_type spatial;
render_mode diffuse_lambert, cull_disabled;
// One surface for the pond's scenery: reeds, twigs, rocks, posts and drifts.
// COLOR.rgb is the bare colour, COLOR.a how readily snow lies on it, and
// UV.y how far the wind moves it. UV.x runs from 0 at the heart of a drift to
// 1 at its edge, where the snow thins to scattered grains.

uniform vec3 snow : source_color = vec3(0.93, 0.93, 0.95);

varying vec3 world_normal;
varying vec3 world_position;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The wind comes in slow gusts down the pond.
	float gust = sin(TIME * 0.9 + at.x * 0.7 + at.z * 1.1) + 0.45 * sin(TIME * 2.1 + at.x * 1.9 - at.z * 0.6);
	VERTEX.xz += vec2(0.93, 0.36) * gust * 0.05 * UV.y * UV.y;
	world_position = at;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float grain = hash(floor(world_position * 14.0));
	if (UV.x > 0.0 && smoothstep(0.25, 1.0, UV.x) > hash(floor(world_position * vec3(46.0, 1.0, 46.0))) * 0.96 + 0.02) {
		discard;
	}
	float lies = smoothstep(0.30, 0.62, world_normal.y + (grain - 0.5) * 0.25) * COLOR.a;
	ALBEDO = mix(COLOR.rgb * (0.88 + 0.24 * grain), snow, lies);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}

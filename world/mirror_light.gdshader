shader_type spatial;
// The light that the glowing edge of the mirror puts on the water. It is
// added to the water. The light is strongest straight below an edge of the
// frame. It is wider and weaker where the edge is higher above the water.
// An edge that is much higher than the lowest edge gives almost no light.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 corners[4];
uniform float water_level = -100.0;
uniform float strength = 0.22;
uniform vec3 tint : source_color = vec3(0.62, 0.91, 0.95);
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float lowest = min(min(corners[0].y, corners[1].y), min(corners[2].y, corners[3].y));
	float light = 0.0;
	for (int index = 0; index < 4; index++) {
		vec3 from = corners[index];
		vec3 to = corners[(index + 1) % 4];
		vec2 line = to.xz - from.xz;
		float size = dot(line, line);
		// An upright edge is one point from above: its lower end.
		float along = size > 0.0001 ? clamp(dot(world.xz - from.xz, line) / size, 0.0, 1.0) : (from.y < to.y ? 0.0 : 1.0);
		vec3 nearest = mix(from, to, along);
		float height = nearest.y - water_level;
		if (height <= 0.0) {
			continue;
		}
		float width = clamp(0.08 + 0.1 * height, 0.11, 0.38);
		float away = length(world.xz - nearest.xz) / width;
		float fall = 1.0 / (1.0 + away * away);
		light = max(light, pow(0.11 / width, 0.6) * fall * fall * exp(-(nearest.y - lowest) * 1.5));
	}
	ALBEDO = tint;
	ALPHA = strength * light;
}

shader_type spatial;
render_mode unshaded, fog_disabled;
// The still ice of the pond, far below a place. From the game's view every
// line of sight ends on it, so it is the whole backdrop: a painted gradient
// from the near ice to the far, the place mirrored in it, blown snow lying
// on it, and warm light pooled under each summer copy.

uniform sampler2D reflection : source_color, filter_linear, repeat_disable;
uniform vec3 near_color : source_color = vec3(0.15, 0.16, 0.31);
uniform vec3 mid_color : source_color = vec3(0.50, 0.50, 0.74);
uniform vec3 far_color : source_color = vec3(0.95, 0.71, 0.66);
uniform vec3 pool_color : source_color = vec3(1.0, 0.79, 0.50);
uniform float mirror = 0.8;
// Each pool: the light's place in the world (xyz) and its strength (w).
uniform vec4 pools[6];
uniform int pool_count = 0;
uniform float ice_time = 0.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += amplitude * noise(p);
		p = p * 2.03 + 7.1;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	float depth = SCREEN_UV.y;
	vec3 base = mix(far_color, mid_color, smoothstep(-0.05, 0.30, depth));
	base = mix(base, near_color, smoothstep(0.25, 1.0, depth));
	// The sky the ice holds: soft cloud, lit from the far side.
	vec2 plain = world_position.xz;
	vec2 drift = plain * 0.07 + vec2(ice_time * 0.004, 0.0);
	float cloud = fbm(drift + vec2(fbm(drift * 1.7 + 4.0), fbm(drift * 1.7 + 9.0)) * 0.9);
	cloud = smoothstep(0.42, 0.78, cloud);
	vec3 colour = mix(base, mix(far_color, vec3(1.0), 0.25), cloud * mix(0.30, 0.12, depth));
	// The stones, mirrored: soft, pale, and thinning with height. The image
	// arrives already darkened by height; its brightness says how much of
	// the ice it covers.
	vec2 at = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y);
	vec2 step_x = vec2(0.0020, 0.0);
	vec2 step_y = vec2(0.0, 0.0032);
	vec3 image = texture(reflection, at).rgb * 0.36
		+ (texture(reflection, at + step_x).rgb + texture(reflection, at - step_x).rgb
		+ texture(reflection, at + step_y).rgb + texture(reflection, at - step_y).rgb) * 0.16;
	float cover = clamp(max(image.r, max(image.g, image.b)) / 0.7, 0.0, 1.0);
	image = mix(image, vec3(dot(image, vec3(0.3, 0.5, 0.2))), 0.3);
	image = mix(image, base * cover, 0.25);
	colour = colour * (1.0 - cover * mirror) + image * mirror;
	// Warm light from each summer copy, pooled on the ice below it. A copy
	// high above the ice lights it wider and much fainter.
	for (int index = 0; index < pool_count; index++) {
		float lift = max(pools[index].y - world_position.y, 0.0);
		float reach = 1.5 + lift * 0.4;
		float distance_to = length(plain - pools[index].xz) / reach;
		colour += pool_color * pools[index].w * exp(-distance_to * distance_to * 2.2) * 0.62 / (1.0 + lift * lift * lift * 0.12);
	}
	ALBEDO = colour;
}

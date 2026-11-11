shader_type spatial;
render_mode unshaded, fog_disabled;
// The still water that lies on the pond's ice, below a place. From the
// game's view every line of sight ends on it, so it is the whole backdrop.
// It shows:
//   the sky it holds: light where it holds the low sun, deep toward the
//     viewer;
//   the place, mirrored (`reflection`): darker than the place, broken by the
//     ripples, and gone with height (the image arrives darkened by height);
//   its own motion: a slow swell, rings where a drop falls or where
//     something disturbs the water (`rings_made`), and the sun's path;
//   warm light from each summer copy.
// All of it lies in the world, so it turns with the view; only the sun
// keeps its bearing. It takes no light and no shadow: a shadow on the water
// reads as a stone under it.

uniform sampler2D reflection : source_color, filter_linear, repeat_disable;
uniform vec3 near_color : source_color = vec3(0.15, 0.16, 0.31);
uniform vec3 mid_color : source_color = vec3(0.50, 0.50, 0.74);
uniform vec3 far_color : source_color = vec3(0.95, 0.71, 0.66);
uniform vec3 pool_color : source_color = vec3(1.0, 0.79, 0.50);
uniform vec3 sun_color : source_color = vec3(1.0, 0.77, 0.64);
// How much of the water the image of the place covers.
uniform float mirror = 0.6;
// Each pool: the light's place in the world (xyz) and its strength (w).
uniform vec4 pools[6];
uniform int pool_count = 0;
// Each ring something made: its place (x, z), when it began (`ice_time`) and
// its strength.
uniform vec4 rings_made[4];
uniform float ice_time = 0.0;
// The view's directions on the water (x, z). The sun's bearing is measured
// from the view's, positive to the right.
uniform vec2 view_forward = vec2(0.0, -1.0);
uniform vec2 view_right = vec2(1.0, 0.0);
uniform float sun_bearing = 0.6;

// The screen spans this much of the sky the water holds, in radians.
const float SPAN = 1.5;
// A ring something made lives this long, in seconds, and spreads this far.
const float RING_LIFE = 2.8;
const float RING_REACH = 3.4;

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

// The slope of the water at a place: a slow swell.
vec2 swell(vec2 p, float t) {
	p += (vec2(noise(p * 0.31 + t * 0.04), noise(p * 0.31 + 7.0 - t * 0.03)) - 0.5) * 2.2;
	vec2 d1 = vec2(0.93, 0.36);
	vec2 d2 = vec2(-0.42, 0.91);
	vec2 d3 = vec2(0.66, -0.75);
	return d1 * cos(dot(p, d1) * 2.3 + t * 0.9) * 0.5
		+ d2 * cos(dot(p, d2) * 4.1 - t * 1.3) * 0.3
		+ d3 * cos(dot(p, d3) * 7.7 + t * 1.9) * 0.2;
}

// One ring that spreads from `centre`: its slope (xy) and its crest (z).
// `age` runs from 0 to 1 over its life, `reach` is its last radius, and
// `fine` says how close its crests lie.
vec3 ring(vec2 p, vec2 centre, float age, float reach, float fine) {
	vec2 away = p - centre;
	float distance_to = max(length(away), 0.001);
	float wave = (distance_to - age * reach) * fine;
	float envelope = exp(-wave * wave * 0.12) * (1.0 - age) * (1.0 - age) * smoothstep(0.0, 0.08, age);
	return vec3(away / distance_to * cos(wave) * envelope, max(sin(wave), 0.0) * envelope);
}

// Small rings where a flake of snow or a last drop meets the water. The
// water is a grid of cells; one falls in some of them, each time at a new
// spot and of a new size.
vec3 drops(vec2 p, float t, float cell_size, float seed) {
	vec2 cell = floor(p / cell_size);
	if (hash(cell + seed + 1.3) < 0.45) {
		return vec3(0.0);
	}
	float period = 4.0 + 9.0 * hash(cell + seed + 9.0);
	float clock = t / period + hash(cell + seed + 5.0);
	float turn = floor(clock);
	float age = fract(clock) / 0.42;
	if (age > 1.0) {
		return vec3(0.0);
	}
	float size = 0.35 + 0.65 * hash(cell + seed + turn * 1.7);
	vec2 centre = (cell + 0.5 + (vec2(hash(cell + seed + turn), hash(cell + seed + turn + 3.1)) - 0.5) * 0.4) * cell_size;
	return ring(p, centre, age, cell_size * 0.20 * size, 26.0 / (0.4 + 0.6 * size)) * (0.3 + 0.4 * size);
}

void fragment() {
	float depth = SCREEN_UV.y;
	vec2 plain = world_position.xz;
	float across = dot(plain, view_right);
	float bearing = (SCREEN_UV.x - 0.5) * SPAN;

	// The water moves: a slow swell, rings where the last drops fall, and
	// rings from what disturbs it.
	vec3 rings = drops(plain, ice_time, 3.1, 0.0) + drops(plain + 1.7, ice_time, 5.3, 13.0);
	for (int index = 0; index < 4; index++) {
		float age = (ice_time - rings_made[index].z) / RING_LIFE;
		if (rings_made[index].w > 0.0 && age > 0.0 && age < 1.0) {
			rings += ring(plain, rings_made[index].xy, age, RING_REACH, 8.0) * rings_made[index].w * 2.6;
		}
	}
	vec2 slope = swell(plain, ice_time) * 0.3 + rings.xy * 1.3;
	// The slope moves what the water shows, across and down the view.
	vec2 moved = vec2(dot(slope, view_right), -dot(slope, view_forward) * 0.5) * 0.0042;

	// The sky the water holds: light where it holds the low sun, deep
	// elsewhere and deepest toward the viewer. The light spreads from the
	// sun's place; it is not a band across the view, which reads as a
	// horizon.
	vec2 from_sun = vec2((bearing - sun_bearing) / SPAN, (depth + 0.06) * 1.25);
	float sun_spread = pow(1.0 - smoothstep(0.0, 1.15, length(from_sun)), 1.7) * 0.66;
	vec3 colour = mix(mid_color, far_color, sun_spread);
	colour = mix(colour, near_color, smoothstep(0.30, 0.95, depth) * (1.0 - sun_spread * 0.5));

	// The low sun, and its path of light down the water: the swell breaks
	// it into short bright lines of many sizes.
	float off_sun = bearing - sun_bearing;
	float halo = exp(-(off_sun * off_sun * 3.2 + depth * depth * 16.0));
	float core = exp(-(off_sun * off_sun * 34.0 + depth * depth * 48.0));
	colour += sun_color * (halo * 0.16 + core * 0.7);
	float spread = 0.045 + depth * 0.10;
	float path = exp(-(off_sun * off_sun) / (spread * spread)) * (1.0 - smoothstep(0.10, 0.80, depth));
	vec2 lines_at = vec2(across, dot(plain, view_forward) * 2.6);
	float glitter = smoothstep(0.38, 0.52, swell(lines_at * 3.2, ice_time * 0.6).y);
	glitter += smoothstep(0.40, 0.52, swell(lines_at * 6.7 + 9.0, ice_time * 0.8).y) * 0.5;
	// The lines lie in loose groups, with dark water between them.
	glitter *= path * smoothstep(0.35, 0.75, noise(lines_at * 0.45 + vec2(0.0, ice_time * 0.06)));

	// The place, mirrored: soft, darker than the place, in the water's
	// colour. The ripples pull it into streaks across the view and open gaps
	// in it. Its brightness says how much of it is left at that height.
	vec2 at = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y) + moved;
	at.x += (noise(vec2(depth * 95.0 - ice_time * 0.35, across * 0.7)) - 0.5) * 0.0034
		+ (noise(vec2(depth * 31.0 + ice_time * 0.2, across * 0.3)) - 0.5) * 0.0050;
	vec2 soft = vec2(0.0036, 0.0050);
	vec4 image = texture(reflection, at) * 0.4
		+ (texture(reflection, at + vec2(soft.x, 0.0)) + texture(reflection, at - vec2(soft.x, 0.0))
		+ texture(reflection, at + vec2(0.0, soft.y)) + texture(reflection, at - vec2(0.0, soft.y))) * 0.15;
	float streak = 0.72 + 0.28 * smoothstep(0.15, 0.75, noise(vec2(across * 0.9, depth * 38.0 - ice_time * 0.3)));
	float cover = image.a * smoothstep(0.0, 0.07, max(image.r, max(image.g, image.b))) * mirror * streak;
	colour = mix(colour, image.rgb * mix(vec3(1.0), colour * 1.6, 0.5) * 0.55, cover);
	colour += sun_color * glitter * 0.42 * (1.0 - cover * 0.7);
	// A thin light line lies on the crest of each ring.
	colour += (colour * 0.5 + mix(mid_color, far_color, 0.4) * 0.07) * rings.z;

	// Warm light from each summer copy lies on the water below it. The light
	// of a copy high above the water does not reach it. The light breathes.
	float breath = 0.92 + 0.08 * sin(ice_time * 2.6) * (0.55 + 0.45 * sin(ice_time * 0.9 + 1.0));
	for (int index = 0; index < pool_count; index++) {
		float lift = max(pools[index].y - world_position.y, 0.0);
		float distance_to = length(plain + slope * 0.08 - pools[index].xz) / (1.35 + lift * 0.4);
		float warm = pools[index].w * breath * 0.55 * exp(-lift * lift * 0.6);
		colour += pool_color * warm * (exp(-distance_to * distance_to * 3.2) * 1.2 + exp(-distance_to * distance_to * 0.8) * 0.24) * (1.0 - cover * 0.55);
	}

	// The corners fall away, so the eye stays on the place.
	vec2 from_centre = (SCREEN_UV - vec2(0.5, 0.46)) * vec2(1.0, 0.86);
	colour *= 1.0 - smoothstep(0.30, 0.86, length(from_centre)) * 0.42;

	// A little grain keeps the dark water from showing steps of colour.
	colour += (hash(FRAGCOORD.xy) - 0.5) * 0.006;
	ALBEDO = colour;
}

shader_type spatial;
render_mode specular_disabled, ambient_light_disabled, fog_disabled;
// The still ice of the pond, far below a place. From the game's view every
// line of sight ends on it, so it is the whole backdrop, painted in three
// layers:
//   what the ice holds: the dusk sky, the dark of the far trees, a low sun
//     and its glitter path. These slide over the ice as the view turns.
//   what lies on the ice: blown snow, cracks, frost. These stay in the world.
//   the place itself: the stones mirrored, their shadow, and warm light
//     pooled under each summer copy.
// It takes no light but the sun's shadow (see `light`).

uniform sampler2D reflection : source_color, filter_linear, repeat_disable;
uniform vec3 near_color : source_color = vec3(0.15, 0.16, 0.31);
uniform vec3 mid_color : source_color = vec3(0.50, 0.50, 0.74);
uniform vec3 far_color : source_color = vec3(0.95, 0.71, 0.66);
uniform vec3 pool_color : source_color = vec3(1.0, 0.79, 0.50);
uniform vec3 sun_color : source_color = vec3(1.0, 0.77, 0.64);
uniform vec3 shore_color : source_color = vec3(0.16, 0.14, 0.28);
uniform vec3 snow_color : source_color = vec3(0.81, 0.76, 0.90);
uniform float mirror = 0.62;
// How much the sun's shadow darkens the ice.
uniform float shade = 0.4;
// Each pool: the light's place in the world (xyz) and its strength (w).
uniform vec4 pools[6];
uniform int pool_count = 0;
uniform float ice_time = 0.0;
// The view's directions on the ice (x, z), and its bearing; the sun's
// bearing is measured from the view's, positive to the right.
uniform vec2 view_forward = vec2(0.0, -1.0);
uniform vec2 view_right = vec2(1.0, 0.0);
uniform float view_bearing = 0.0;
uniform float sun_bearing = 0.6;
// The direction on the ice (x, z) from the place toward the sun.
uniform vec2 sun_along = vec2(0.0, -1.0);

// The screen spans this much of the panorama the ice holds, in radians.
const float SPAN = 1.5;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
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

// The distance from `p` to the nearest border between scattered cells: the
// lines along which ice cracks.
float crack_distance(vec2 p) {
	vec2 cell = floor(p);
	vec2 within = fract(p);
	vec2 nearest = vec2(0.0);
	float least = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 to = vec2(float(x), float(y)) + hash2(cell + vec2(float(x), float(y))) - within;
			float d = dot(to, to);
			if (d < least) {
				least = d;
				nearest = to;
			}
		}
	}
	least = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 to = vec2(float(x), float(y)) + hash2(cell + vec2(float(x), float(y))) - within;
			vec2 between = to - nearest;
			if (dot(between, between) > 0.0001) {
				least = min(least, dot(0.5 * (nearest + to), normalize(between)));
			}
		}
	}
	return least;
}

// One row of far trees held in the ice: soft dark streaks of uneven length
// that hang from the far edge. `along` runs across the panorama.
float trees(float along, float depth, float reach, float thin) {
	float cell = floor(along);
	float pick = hash(vec2(cell, 7.0));
	float centre = 0.3 + 0.4 * hash(vec2(cell, 3.0));
	float half_width = thin * (0.5 + pick);
	float length_here = reach * (0.35 + 0.65 * pick * pick);
	float across = smoothstep(half_width, half_width * 0.25, abs(fract(along) - centre));
	return across * (1.0 - smoothstep(length_here * 0.35, length_here, depth)) * step(0.22, pick);
}

// A fish under the ice, one to each wide patch of the pond, on a slow round
// of its own. Returns its dark shape; `blotch` is the pale pattern on a koi.
float fish(vec2 plain, float time, out float blotch) {
	vec2 cell = floor(plain / 9.0);
	float pick = hash(cell + 3.7);
	blotch = 0.0;
	if (pick < 0.3) {
		return 0.0;
	}
	float pace = (0.10 + 0.08 * pick) * (hash(cell + 9.1) > 0.5 ? 1.0 : -1.0);
	float turn = time * pace + pick * 40.0;
	vec2 round_size = vec2(2.4 + pick, 1.5 + 1.2 * hash(cell + 5.5));
	vec2 heading = normalize(vec2(-sin(turn) * round_size.x, cos(turn) * round_size.y) * sign(pace));
	vec2 from = plain - (cell + 0.5) * 9.0 - vec2(cos(turn), sin(turn)) * round_size;
	float along = dot(from, heading);
	float across = dot(from, vec2(-heading.y, heading.x));
	// It swims: the tail leads the body from side to side.
	across += sin(along * 13.0 - time * 4.0) * 0.024 * smoothstep(0.05, -0.25, along);
	float girth = 0.058 * smoothstep(0.21, 0.03, along) * smoothstep(-0.25, -0.02, along) + 0.05 * smoothstep(-0.15, -0.27, along);
	float body = (1.0 - smoothstep(girth * 0.35, girth + 0.012, abs(across))) * step(-0.27, along) * step(along, 0.21);
	blotch = body * smoothstep(0.5, 0.66, noise(vec2(along * 9.0 + pick * 20.0, across * 12.0)));
	return body;
}

void fragment() {
	float depth = SCREEN_UV.y;
	vec2 plain = world_position.xz;
	float bearing = (SCREEN_UV.x - 0.5) * SPAN;

	// What lies on the ice. Blown snow lies in a few long, soft drifts down
	// the wind.
	vec2 wind = normalize(vec2(1.0, 0.38));
	vec2 drift_at = vec2(dot(plain, wind) * 0.085, dot(plain, vec2(-wind.y, wind.x)) * 0.30);
	float drift = fbm(drift_at + vec2(noise(drift_at * 1.6 + 11.0)) * 0.7);
	float streak = noise(vec2(drift_at.x * 5.0, drift_at.y * 16.0));
	float snow = smoothstep(0.54, 0.80, drift + (streak - 0.5) * 0.05);
	// Loose snow moves over the ice in thin veils.
	vec2 veil_at = vec2(drift_at.x * 3.0 - ice_time * 0.22, drift_at.y * 5.0);
	float gust = 0.5 + 0.5 * sin(dot(plain, wind) * 0.35 - ice_time * 0.9);
	float veil = smoothstep(0.55, 0.88, fbm(veil_at)) * (0.10 + 0.34 * gust * gust);
	// Frost: the ice is clear and dark in places, pale in others.
	float frost = noise(plain * 0.17 + 3.0) * 0.65 + noise(plain * 0.45 + 8.0) * 0.35;

	// The sky the ice holds, from the far ice to the near.
	// The light of the low sun spreads over the ice from where the ice holds
	// the sun; away from it the ice is dark. A little of the dusk stays in
	// the far ice on every side. So the light has a source, not a horizon.
	vec2 from_sun = vec2((bearing - sun_bearing) / SPAN, (depth + 0.06) * 1.25);
	float sun_spread = pow(1.0 - smoothstep(0.0, 1.15, length(from_sun)), 1.7);
	float far_light = max(sun_spread, (1.0 - smoothstep(0.0, 0.24, depth)) * 0.34);
	vec3 colour = mix(mid_color, far_color, far_light);
	colour = mix(colour, near_color, smoothstep(0.30, 0.95, depth) * (1.0 - sun_spread * 0.5));
	colour *= 0.86 + 0.26 * frost;
	// The low sun comes through the far trees: long bars of light lie over
	// the ice between their shadows, all the way to the viewer.
	float across_sun = dot(plain, vec2(-sun_along.y, sun_along.x));
	float along_sun = dot(plain, sun_along);
	float bars = noise(vec2(across_sun * 0.9, along_sun * 0.03 + 3.0)) * 0.6 + noise(vec2(across_sun * 2.3 + 7.0, along_sun * 0.05)) * 0.4;
	// The bars are soft and broken along their length, so none reads as a path.
	float sunlit = smoothstep(0.40, 0.82, bars) * (0.45 + 0.55 * noise(vec2(across_sun * 0.3 + 11.0, along_sun * 0.22)));
	// The light lifts the ice in its own colour, so the dark stays deep.
	colour = colour * (1.0 + sunlit * mix(0.15, 0.85, smoothstep(0.15, 0.9, depth))) + sun_color * sunlit * 0.012;

	// The far trees, mirrored: bare trunks that reach from the far edge
	// toward the viewer. The image wavers a little.
	float waver = sin(depth * 40.0 + ice_time * 1.1) * 0.0035 * (0.4 + depth * 4.0) + sin(depth * 13.0 - ice_time * 0.6) * 0.002;
	float along = (view_bearing + bearing + waver) * 7.0;
	float shore = trees(along, depth, 0.30, 0.10) * 0.85;
	shore = max(shore, trees(along * 2.7 + 13.0, depth, 0.22, 0.13) * 0.6);
	shore = max(shore, trees(along * 6.1 + 31.0, depth, 0.15, 0.2) * 0.4);
	shore *= 1.0 - smoothstep(0.04, 0.34, depth) * 0.55;
	// No bank: the trees hang from beyond the view, so the ice has no horizon.
	shore *= 0.55 + 0.45 * smoothstep(0.0, 0.05, depth);

	// The low sun, held in the far ice, behind the trees.
	float off_sun = bearing - sun_bearing;
	float halo = exp(-(off_sun * off_sun * 3.2 + depth * depth * 16.0));
	float core = exp(-(off_sun * off_sun * 34.0 + depth * depth * 48.0));
	colour += sun_color * (halo * 0.42 + core * 1.5) * (1.0 - shore * 0.55);
	colour = mix(colour, shore_color, shore * (0.86 - core * 0.5));

	// Its glitter path: short bright dashes that lie on the ice, down the
	// line from the sun to the viewer. Each one comes and goes.
	float spread = 0.05 + depth * 0.13;
	float path = exp(-(off_sun * off_sun) / (spread * spread)) * (1.0 - smoothstep(0.08, 0.72, depth));
	vec2 dash_at = vec2(dot(plain, view_right) * 4.2, dot(plain, view_forward) * 8.5);
	float spark = noise(dash_at + vec2(ice_time * 0.22, 0.0)) * noise(dash_at * 2.3 + vec2(5.0, ice_time * 0.38));
	float glitter = smoothstep(0.44, 0.64, spark) * path * (1.0 - shore * 0.7);

	// The stones, mirrored: dark, stretched down the ice and wavering, and
	// thinning with height. The image arrives already darkened by height; its
	// brightness says how much of the ice it covers.
	vec2 at = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y);
	at.x += sin(depth * 170.0 + ice_time * 1.3) * 0.0007 + sin(depth * 63.0 - ice_time * 0.7) * 0.0012;
	vec2 step_y = vec2(0.0, 0.0030);
	vec3 image = texture(reflection, at).rgb * 0.5
		+ (texture(reflection, at + step_y).rgb + texture(reflection, at - step_y).rgb) * 0.25;
	float cover = clamp(max(image.r, max(image.g, image.b)) / 0.7, 0.0, 1.0);
	// The ice takes the image into its own colour and depth.
	image *= mix(vec3(1.0), colour * 1.7, 0.6) * 0.62;
	// Rough ice breaks the image into streaks across the view.
	float broken = 0.72 + 0.28 * noise(vec2(dot(plain, view_right) * 1.3, dot(plain, view_forward) * 8.0));
	float held = mirror * (1.0 - snow * 0.85) * broken;
	colour = colour * (1.0 - cover * held) + image * held;
	colour += sun_color * glitter * 0.85 * (1.0 - snow) * (1.0 - cover * 0.6);

	// Life in the pond: fish move under the ice.
	float blotch;
	float swimmer = fish(plain, ice_time, blotch) * (1.0 - snow * 0.7);
	colour = mix(colour, colour * 0.42, swimmer * 0.62);
	colour += vec3(0.55, 0.26, 0.10) * blotch * 0.20 * (1.0 - snow * 0.7);

	// Cracks run through the clear ice, pale where they catch the light.
	vec2 crack_at = plain * 0.15 + vec2(noise(plain * 0.25), noise(plain * 0.25 + 5.0)) * 0.22;
	float crack = crack_distance(crack_at);
	float thin = fwidth(crack) * 1.2 + 0.004;
	float line = (1.0 - smoothstep(0.0, thin, crack)) * 0.07 + (1.0 - smoothstep(0.0, 0.035, crack)) * 0.02;
	colour += mix(mid_color, vec3(1.0), 0.5) * line * smoothstep(0.5, 0.85, noise(plain * 0.33 + 9.0)) * (1.0 - depth * 0.35);

	// The snow that lies on the ice hides what the ice holds.
	vec3 lying = snow_color * (0.80 + 0.20 * streak) * mix(1.0, 0.72, smoothstep(0.2, 1.0, depth));
	lying += sun_color * halo * 0.25;
	colour = mix(colour, lying, (snow * 0.08 + veil * (1.0 - snow) * 0.20) * mix(1.0, 0.6, depth));

	// Warm light from each summer copy, pooled on the ice below it. The light
	// of a copy high above the ice does not reach it. The light breathes.
	float breath = 0.82 + 0.18 * sin(ice_time * 2.6) * (0.55 + 0.45 * sin(ice_time * 0.9 + 1.0));
	for (int index = 0; index < pool_count; index++) {
		float lift = max(pools[index].y - world_position.y, 0.0);
		float reach = 2.0 + lift * 0.4;
		float distance_to = length(plain - pools[index].xz) / reach;
		float warm = pools[index].w * breath * 1.45 * exp(-lift * lift * 0.6);
		colour += pool_color * warm * (exp(-distance_to * distance_to * 3.6) * 1.0 + exp(-distance_to * distance_to * 0.8) * 0.2) * (0.85 + snow * 0.5) * (1.0 - cover * 0.55);
	}

	// The corners fall away, so the eye stays on the place.
	vec2 from_centre = (SCREEN_UV - vec2(0.5, 0.46)) * vec2(1.0, 0.86);
	colour *= 1.0 - smoothstep(0.30, 0.86, length(from_centre)) * 0.42;

	// The part in `ALBEDO` is what the sun's shadow takes away.
	ALBEDO = colour * shade;
	EMISSION = colour * (1.0 - shade);
}

void light() {
	// Only the sun reaches the ice, and only to say where its shadow falls.
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += vec3(ATTENUATION);
	}
}

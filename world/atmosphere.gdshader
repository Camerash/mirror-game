shader_type spatial;
render_mode blend_mix, unshaded, fog_disabled, cull_disabled, depth_draw_never;

uniform vec3 plane_normal = vec3(1.0, 0.0, 0.0);
uniform float plane_offset = 0.0;
uniform float source_direction = 1.0;
uniform bool mirror_enabled = false;
uniform bool has_mirror = false;
uniform bool atmosphere_enabled = true;
uniform vec3 section_centre;
uniform vec3 camera_right;
uniform vec3 camera_up;
uniform vec2 view_size;
uniform float atmosphere_time = 0.0;
uniform bool haze_mode = false;
uniform vec3 haze_centre;
uniform vec3 haze_extent = vec3(1.0);
uniform bool art_trial = false;
uniform float haze_layer = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float noise_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float cloud_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(noise_hash(cell), noise_hash(cell + vec2(1.0, 0.0)), f.x), mix(noise_hash(cell + vec2(0.0, 1.0)), noise_hash(cell + vec2(1.0)), f.x), f.y);
}
float clouds(vec2 p) {
	return cloud_noise(p) * 0.55 + cloud_noise(p * 2.1 + vec2(4.7)) * 0.30 + cloud_noise(p * 4.3 + vec2(2.1)) * 0.15;
}

void fragment() {
	if (haze_mode) {
		float side = (dot(world_position, plane_normal) - plane_offset) * source_direction;
		float range = length((world_position - haze_centre) / max(haze_extent, vec3(0.1)));
		float radial = 1.0 - smoothstep(0.25, 1.0, length((UV - vec2(0.5)) * 2.0));
		float noise = clouds(world_position.xz * 0.65 + vec2(atmosphere_time * 0.025 + haze_layer * 2.7, haze_layer));
		float fade = radial * smoothstep(0.18, 0.80, noise);
		vec3 base_haze = mix(vec3(0.94, 0.65, 0.39), vec3(0.40, 0.70, 0.78), smoothstep(-0.2, 0.2, side));
		vec3 trial_haze = mix(vec3(0.68, 0.60, 0.56), vec3(0.49, 0.60, 0.73), smoothstep(-0.2, 0.2, side));
		vec3 neutral_haze = art_trial ? vec3(0.57, 0.55, 0.64) : vec3(0.67, 0.72, 0.73);
		ALBEDO = has_mirror ? (art_trial ? trial_haze : base_haze) : neutral_haze;
		ALPHA = fade * (art_trial ? 0.62 : 0.14) * (atmosphere_enabled ? 1.0 : 0.0);
	} else {
		vec3 neutral_low = vec3(0.74, 0.78, 0.76);
		vec3 neutral_high = vec3(0.94, 0.91, 0.83);
		float drift = sin(UV.x * 17.0 + UV.y * 10.0 + atmosphere_time * 0.15) * 0.004;
		vec3 trial_low = vec3(0.20, 0.20, 0.29);
		vec3 trial_high = vec3(0.40, 0.40, 0.50);
		float distant_cloud = (clouds(UV * vec2(7.0, 9.0) + vec2(atmosphere_time * 0.006)) - 0.5) * 0.10;
		ALBEDO = (art_trial ? mix(trial_low, trial_high, 1.0 - UV.y) + distant_cloud : mix(neutral_low, neutral_high, 1.0 - UV.y)) + drift;
		ALPHA = 1.0;
	}
}

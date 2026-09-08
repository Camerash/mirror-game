shader_type spatial;
render_mode blend_mix, unshaded, fog_disabled, cull_disabled, depth_draw_never;

uniform vec3 plane_normal = vec3(1.0, 0.0, 0.0);
uniform float plane_offset = 0.0;
uniform float source_direction = 1.0;
uniform bool mirror_enabled = false;
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
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (haze_mode) {
		float side = (dot(world_position, plane_normal) - plane_offset) * source_direction;
		float range = length((world_position - haze_centre) / max(haze_extent, vec3(0.1)));
		float radial = 1.0 - smoothstep(0.25, 1.0, length((UV - vec2(0.5)) * 2.0));
		float noise = 0.72 + 0.28 * sin(world_position.x * 0.42 + world_position.z * 0.31 + atmosphere_time * 0.18);
		float fade = (1.0 - smoothstep(0.28, 0.88, range)) * radial * noise;
		vec3 base_haze = mix(vec3(0.94, 0.65, 0.39), vec3(0.40, 0.70, 0.78), smoothstep(-0.2, 0.2, side));
		vec3 trial_haze = mix(vec3(0.72, 0.48, 0.40), vec3(0.34, 0.45, 0.66), smoothstep(-0.2, 0.2, side));
		ALBEDO = art_trial ? trial_haze : base_haze;
		ALPHA = fade * (art_trial ? 0.26 : 0.16) * (atmosphere_enabled ? 1.0 : 0.0);
	} else {
		vec3 neutral_low = vec3(0.74, 0.78, 0.76);
		vec3 neutral_high = vec3(0.94, 0.91, 0.83);
		float drift = sin(UV.x * 17.0 + UV.y * 10.0 + atmosphere_time * 0.15) * 0.004;
		vec3 trial_low = vec3(0.20, 0.20, 0.29);
		vec3 trial_high = vec3(0.40, 0.40, 0.50);
		float clouds = sin(UV.x * 11.0 + sin(UV.y * 8.0)) * sin(UV.y * 13.0 + UV.x * 4.0) * 0.018;
		ALBEDO = (art_trial ? mix(trial_low, trial_high, 1.0 - UV.y) + clouds : mix(neutral_low, neutral_high, 1.0 - UV.y)) + drift;
		ALPHA = 1.0;
	}
}

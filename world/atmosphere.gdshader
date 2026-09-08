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
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (haze_mode) {
		float side = dot(world_position, plane_normal) - plane_offset;
		float range = length((world_position - haze_centre) / max(haze_extent, vec3(0.1)));
		float fade = (1.0 - smoothstep(0.35, 1.0, range)) * (0.5 + 0.5 * sin(atmosphere_time * 0.45 + world_position.x * 1.7));
		ALBEDO = mix(vec3(0.94, 0.65, 0.39), vec3(0.40, 0.70, 0.78), smoothstep(-0.2, 0.2, side));
		ALPHA = fade * 0.16 * (atmosphere_enabled ? 1.0 : 0.0);
	} else {
		vec3 neutral_low = vec3(0.74, 0.78, 0.76);
		vec3 neutral_high = vec3(0.94, 0.91, 0.83);
		float drift = sin(UV.x * 17.0 + UV.y * 10.0 + atmosphere_time * 0.15) * 0.004;
		ALBEDO = mix(neutral_low, neutral_high, 1.0 - UV.y) + drift;
		ALPHA = 1.0;
	}
}

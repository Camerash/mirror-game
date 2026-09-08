shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never;

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

void fragment() {
    // A background cross-section through the level, in world coordinates.
    // Solid surfaces and the unbounded 3D veil locate the boundary at other depths.
    vec3 sample_position = section_centre + camera_right * (UV.x - 0.5) * view_size.x
        + camera_up * (0.5 - UV.y) * view_size.y;
    float distance_to_plane = (dot(sample_position, plane_normal) - plane_offset) * source_direction;
    float alternate = mirror_enabled && atmosphere_enabled ? smoothstep(-0.16, 0.16, distance_to_plane) : 0.0;
    vec3 daylight = mix(vec3(0.87, 0.80, 0.67), vec3(0.96, 0.92, 0.81), 1.0 - UV.y);
    vec3 dusk = mix(vec3(0.19, 0.25, 0.36), vec3(0.38, 0.48, 0.61), 1.0 - UV.y);
    float drift = sin(UV.x * 17.0 + UV.y * 10.0 + atmosphere_time * 0.15) * 0.006;
    ALBEDO = mix(daylight, dusk, alternate) + drift;
}

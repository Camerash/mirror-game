shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
#include "res://world/water_image.gdshaderinc"
uniform float sheet_time = 0.0;
uniform float sheet_alpha = 0.11;
uniform bool removal = false;
uniform vec2 panel_size = vec2(3.0);
// Multiplies the opacity. The stage sweep panel has no ribbons or motes, so it
// needs more glass to read.
uniform float presence = 1.0;
// The height of the water below the place.
uniform float water_level = -100.0;
varying vec3 local_position;
varying vec3 world_position;
void vertex() {
	local_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 distance_to_edge = panel_size * 0.5 - abs(local_position.xy);
	// The foot of the pane stays clear, so she and the stones behind it show.
	// Frost comes far down from the top of the pane and only a little in from
	// its sides, so the pane reads as glass and its lower half stays clear.
	float nearest = min(distance_to_edge.x, (panel_size.y * 0.5 - local_position.y) * 0.22);
	// Frost grows in from the frame in fine crystals; the middle stays clear,
	// so what stands behind the glass is not washed out.
	float frost = pow(1.0 - smoothstep(0.0, 0.16, nearest), 1.6);
	float crystals = 0.86 + 0.14 * sin(local_position.x * 2.9 + sin(local_position.y * 2.3) * 1.5);
	// A slow sheen crosses the pane, as on glass turned in the light.
	float across = local_position.x * 0.8 + local_position.y * 0.55 - sheet_time * 0.11;
	float sheen = pow(0.5 + 0.5 * sin(across * 2.1), 6.0) * 0.6 + pow(0.5 + 0.5 * sin(across * 0.9 + 1.7), 10.0);
	ALBEDO = mix(vec3(0.62, 0.76, 0.86), vec3(0.95, 0.97, 1.0), clamp(frost * crystals + sheen * 0.6, 0.0, 1.0));
	ROUGHNESS = 0.2;
	SPECULAR = 0.5;
	METALLIC = 0.0;
	EMISSION = ALBEDO * (0.22 * frost + 0.16 * sheen);
	ALPHA = (0.012 + frost * crystals * 0.42 + sheen * 0.025) * (removal ? 0.3 : 1.0) * presence;
	if ((CAMERA_VISIBLE_LAYERS & 1u) == 0u) {
		// Drawn for the image in the water: a pale sheet, gone with height.
		ALPHA = 0.5 * image_keep(world_position.y - water_level) * (removal ? 0.3 : 1.0) * presence;
	}
}

shader_type spatial;
render_mode diffuse_lambert, cull_disabled;
#include "res://world/water_image.gdshaderinc"
// One surface for the pond's scenery: the reeds. COLOR.rgb is the bare
// colour and UV.y how far the wind moves a point.

// Far things take on the colour of the air: the scenery stays behind the
// stones in value.
uniform vec3 haze : source_color = vec3(0.30, 0.28, 0.48);
uniform float water_level = -100.0;

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
}

void fragment() {
	float grain = hash(floor(world_position * 60.0)) * 0.4 + 0.3;
	// Vertex colours arrive as written; bring them into the light's space.
	ALBEDO = mix(pow(COLOR.rgb, vec3(2.2)) * (0.88 + 0.24 * grain), haze, 0.6);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	if ((CAMERA_VISIBLE_LAYERS & 1u) == 0u) {
		// Drawn for the image in the water, which is gone with height.
		EMISSION = image_colour(ALBEDO, world_position.y - water_level);
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
	}
}

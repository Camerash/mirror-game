shader_type spatial;
// Mother-of-pearl: a pale nacre whose colour shifts with the viewing angle
// and with soft bands across the surface.
#include "res://art_trial/look_pilot/shaders/noise.gdshaderinc"
uniform float strength = 0.5;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec2 plane = face_plane(world_position, normal);
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float bands = fbm(plane * 2.2 + vec2(fbm(plane * 1.3) * 2.0));
	float hue = facing * 1.1 + bands * 1.4 + dot(normal, vec3(0.21, 0.37, 0.13));
	vec3 iris = 0.5 + 0.5 * cos(6.2832 * (hue + vec3(0.0, 0.33, 0.67)));
	ALBEDO = mix(vec3(0.93, 0.92, 0.96), iris, strength);
	METALLIC = 0.3;
	ROUGHNESS = 0.16;
	CLEARCOAT = 1.0;
}

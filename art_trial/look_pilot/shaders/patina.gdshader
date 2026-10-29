shader_type spatial;
// Old bronze under green patina, with recessed fret bands around each face
// where the verdigris gathers.
#include "res://art_trial/look_pilot/shaders/noise.gdshaderinc"
uniform vec3 bronze : source_color = vec3(0.55, 0.37, 0.2);
uniform vec3 verdigris : source_color = vec3(0.33, 0.6, 0.52);
uniform vec3 box_centre = vec3(0.0);
uniform vec3 box_size = vec3(0.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec2 plane = face_plane(world_position, normal);
	float edge = box_size.x > 0.0 ? face_edge(world_position, normal, box_centre, box_size) : 1.0;
	float fret = edge < 0.36 ? step(0.55, fract(edge * 11.0)) : 0.0;
	float patina = smoothstep(0.35, 0.65, fbm(plane * 3.0) + fret * 0.35 + (1.0 - smoothstep(0.0, 0.06, edge)) * -0.3);
	vec3 color = mix(bronze, verdigris * (0.8 + 0.4 * fbm(plane * 14.0)), patina);
	color *= 1.0 - fret * 0.3;
	ALBEDO = color;
	METALLIC = mix(0.85, 0.1, patina);
	ROUGHNESS = mix(0.32, 0.75, patina);
}

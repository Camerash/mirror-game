shader_type spatial;
// A block overgrown with meadow: grass with dots of blossom in several
// colours, thickest on top.
#include "res://art_trial/look_pilot/shaders/noise.gdshaderinc"
uniform vec3 grass : source_color = vec3(0.36, 0.55, 0.2);
uniform vec3 grass_light : source_color = vec3(0.62, 0.74, 0.3);
uniform float density = 0.55;
varying vec3 world_position;
varying vec3 world_normal;

const vec3 PETALS[4] = vec3[](vec3(0.97, 0.66, 0.77), vec3(0.98, 0.96, 0.9), vec3(0.97, 0.84, 0.36), vec3(0.8, 0.66, 0.93));

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec2 plane = face_plane(world_position, normal);
	vec3 color = mix(grass, grass_light, fbm(plane * 4.0)) * (0.8 + 0.3 * fbm(plane * 30.0));
	float amount = density * (normal.y > 0.5 ? 1.0 : 0.65);
	for (int layer = 0; layer < 2; layer++) {
		vec2 grid = plane * (18.0 + float(layer) * 11.0) + float(layer) * 7.3;
		vec2 id = floor(grid);
		vec2 offset = vec2(hash(id + 1.7), hash(id + 4.9)) * 0.5 + 0.25;
		float flower = step(1.0 - amount, hash(id)) * smoothstep(0.32, 0.2, length(fract(grid) - offset));
		vec3 petal = PETALS[int(hash(id + 8.0) * 3.99)];
		color = mix(color, petal, flower);
	}
	color *= mix(1.0, 0.7, smoothstep(-0.2, -1.2, world_position.y));
	ALBEDO = color;
	ROUGHNESS = 0.95;
}

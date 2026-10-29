shader_type spatial;
// Weathered stone for blocks: brick courses on the sides and paving on top
// (when the box is known), per-stone tone, worn edges, grain, and optional
// moss, shells and wet patches. Darker and tinted toward the undersides.
#include "res://art_trial/look_pilot/shaders/noise.gdshaderinc"
uniform vec3 stone : source_color = vec3(0.86, 0.83, 0.74);
uniform vec3 groove_color : source_color = vec3(0.55, 0.52, 0.45);
uniform vec3 moss_color : source_color = vec3(0.42, 0.52, 0.22);
uniform vec3 under_tint : source_color = vec3(0.7, 0.72, 0.6);
uniform vec3 box_centre = vec3(0.0);
uniform vec3 box_size = vec3(0.0);
uniform float bricks = 1.0;
uniform float course = 0.33;
uniform float brick_length = 0.66;
uniform float paving = 0.5;
uniform float groove = 0.022;
uniform float grain = 0.12;
uniform float bump = 0.25;
uniform float moss = 0.0;
uniform float shells = 0.0;
uniform float wet = 0.0;
uniform float roughness = 0.85;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec3 axis = abs(normal);
	bool top = axis.y > max(axis.x, axis.z);
	vec2 plane = face_plane(world_position, normal);
	bool boxed = box_size.x > 0.0;
	vec3 low = box_centre - box_size * 0.5;
	float groove_line = 0.0;
	vec2 cell = floor(plane * 3.0);
	if (boxed && bricks > 0.0) {
		vec2 size = top ? vec2(paving) : vec2(brick_length, course);
		vec2 grid = (plane - (top ? low.xz : vec2(0.0, low.y))) / size;
		float row = floor(grid.y);
		grid.x += 0.5 * mod(row, 2.0) + (top ? 0.0 : 0.17 * row);
		cell = floor(grid);
		vec2 inside = min(fract(grid), 1.0 - fract(grid)) * size;
		float wobble = 0.6 + 0.8 * noise(plane * 9.0);
		groove_line = 1.0 - smoothstep(groove * 0.4 * wobble, groove * wobble, min(inside.x, inside.y));
	}
	float edge = boxed ? face_edge(world_position, normal, box_centre, box_size) : 1.0;
	bool coursed = boxed && bricks > 0.0;
	float detail = fbm(plane * 5.0 + (coursed ? cell * 3.7 : vec2(0.0)));
	float tone = coursed ? hash(cell) : noise(plane * 1.5);
	vec3 color = stone * (0.92 + 0.12 * tone) * (1.0 - grain + grain * 2.0 * detail);
	color *= 0.96 + 0.08 * fbm(plane * 22.0);
	float chipped = 1.0 - smoothstep(0.0, 0.05 + 0.04 * noise(plane * 7.0), edge);
	color = mix(color, groove_color, max(groove_line * 0.85, chipped * 0.35 * bricks));
	float rough = roughness;
	if (moss > 0.0) {
		float growth = fbm(plane * 1.7 + 11.0) + groove_line * 0.25 + (1.0 - smoothstep(0.0, 0.3, edge)) * 0.15;
		if (!top && boxed) {
			float from_top = low.y + box_size.y - world_position.y;
			growth = fbm(plane * 2.4 + 5.0) + 0.35 - from_top * (0.9 + 0.8 * noise(vec2(plane.x * 3.0, 0.0)));
		}
		float amount = smoothstep(0.58, 0.68, growth) * moss;
		vec3 green = moss_color * (0.75 + 0.5 * fbm(plane * 12.0));
		color = mix(color, green, amount);
		rough = mix(rough, 1.0, amount);
	}
	if (shells > 0.0) {
		vec2 grid = plane * 16.0;
		vec2 id = floor(grid);
		vec2 offset = vec2(hash(id + 2.3), hash(id + 5.1)) * 0.5 + 0.25;
		float pick = hash(id);
		float dot_mask = step(1.0 - 0.09 * shells, pick) * smoothstep(0.3, 0.18, length(fract(grid) - offset));
		vec3 shell = mix(vec3(0.83, 0.74, 0.86), vec3(0.95, 0.9, 0.88), hash(id + 9.0));
		color = mix(color, shell, dot_mask);
		float pits = step(0.95, hash(floor(plane * 40.0))) * 0.12 * shells;
		color *= 1.0 - pits;
	}
	if (wet > 0.0) {
		float damp = smoothstep(0.45, 0.65, fbm(plane * 1.3 + 3.0)) * wet;
		color *= 1.0 - 0.18 * damp;
		rough = mix(rough, 0.18, damp);
	}
	color *= mix(vec3(1.0), under_tint, smoothstep(-0.2, -3.0, world_position.y));
	vec2 step_size = vec2(0.02, 0.0);
	float height = fbm(plane * 6.0);
	vec2 slope = vec2(fbm(plane * 6.0 + step_size.xy) - height, fbm(plane * 6.0 + step_size.yx) - height) / 0.02;
	vec3 tangent = top ? vec3(1.0, 0.0, 0.0) : (axis.x > axis.z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0));
	vec3 bitangent = top ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 bent = normalize(normal - (tangent * slope.x + bitangent * slope.y) * bump * 0.05);
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	ALBEDO = color;
	ROUGHNESS = rough;
	AO = 1.0 - groove_line * 0.5;
}

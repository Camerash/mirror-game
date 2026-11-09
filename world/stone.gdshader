shader_type spatial;
render_mode diffuse_lambert, cull_disabled;
// The surface of every gameplay block: garden limestone under snow. The look
// follows the kind of solid and the direction of each face, and is drawn in
// the source's own space, so a copy shows its source exactly, mirrored.
//   kind 0, an original: stone, snow on top that hangs over the edge.
//   kind 1, a copy: the same stone in summer, moss where the snow lay.
//   kind 2, an absolute: stone bound by a band of bronze under green patina.

uniform int kind = 0;
uniform bool polygon_surface = false;
uniform vec3 box_centre;
uniform vec3 box_size = vec3(1.0);
uniform vec3 source_size = vec3(1.0);
// The source box's centre in the world: the pattern runs on through
// neighbouring blocks, and a copy keeps its source's pattern.
uniform vec3 seed = vec3(0.0);
uniform mat4 world_to_material;
uniform vec4 clip_plane = vec4(0.0);

uniform vec3 stone : source_color = vec3(0.74, 0.69, 0.60);
uniform vec3 snow : source_color = vec3(0.93, 0.93, 0.95);
uniform vec3 patina : source_color = vec3(0.22, 0.32, 0.28);
uniform vec3 summer_stone : source_color = vec3(0.80, 0.70, 0.55);
uniform vec3 moss : source_color = vec3(0.40, 0.46, 0.22);
uniform vec3 summer_glow : source_color = vec3(0.95, 0.85, 0.63);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void fragment() {
	if (clip_plane.xyz != vec3(0.0) && dot(clip_plane.xyz, world_position) > clip_plane.w) {
		discard;
	}
	vec3 source_position = (world_to_material * vec4(world_position, 1.0)).xyz;
	mat3 world_to_source = mat3(world_to_material);
	vec3 source_normal = normalize(world_to_source * world_normal);
	vec3 half_source = max(source_size * 0.5, vec3(0.0001));
	vec3 face = abs(source_normal);
	vec3 source_plane_distance = abs(abs(source_position) - half_source);
	float source_boundary = dot(source_plane_distance, face);
	// A face the mirror cut, or the inside of a clipped block, shows bare stone.
	bool cut_face = (polygon_surface && COLOR.g > 0.5) || source_boundary > 0.003 || !FRONT_FACING;
	bool top_face = source_normal.y > 0.72;
	bool side_face = face.y < 0.72;
	bool summer = kind == 1;
	vec3 place = source_position + seed;
	float below_top = half_source.y - source_position.y;

	float blotch = value_noise(place * 1.7) * 0.6 + value_noise(place * 5.3) * 0.4;
	vec3 base = (summer ? summer_stone : stone) * (0.93 + blotch * 0.12);
	float roughness = 0.82;
	float metallic = 0.0;
	vec3 relief = source_normal;
	vec3 glow = vec3(0.0);
	vec3 cover = summer ? moss * (0.82 + value_noise(place * 9.0) * 0.36) : snow;

	if (cut_face) {
		base = mix(base, summer ? summer_stone : stone, 0.6) * 1.05;
	} else if (top_face) {
		base = cover;
		roughness = summer ? 0.9 : 0.72;
		if (summer) {
			// Small flowers, a few to a block.
			vec2 cell = floor(place.xz * 7.0);
			vec2 jitter = vec2(hash(vec3(cell, 5.0)), hash(vec3(cell, 9.0))) * 0.6 - 0.3;
			vec2 within = fract(place.xz * 7.0) - 0.5 - jitter;
			float pick = hash(vec3(cell, 3.0));
			float flower = step(0.84, pick) * smoothstep(0.17, 0.09, length(within) * (0.7 + pick * 0.6));
			base = mix(base, pick > 0.93 ? vec3(0.95, 0.80, 0.36) : vec3(0.96, 0.95, 0.90), flower);
		} else {
			// Snow lies in soft drifts, not flat.
			float e = 0.06;
			float drift_x = value_noise(vec3(place.x + e, 0.0, place.z) * 2.6) - value_noise(vec3(place.x - e, 0.0, place.z) * 2.6);
			float drift_z = value_noise(vec3(place.x, 0.0, place.z + e) * 2.6) - value_noise(vec3(place.x, 0.0, place.z - e) * 2.6);
			relief = normalize(relief - vec3(drift_x, 0.0, drift_z) * 0.7);
		}
	} else if (side_face) {
		// The cover hangs over the edge in an uneven lip.
		float along = face.x > face.z ? place.z : place.x;
		float lip = 0.07 + 0.11 * value_noise(vec3(along * 2.3, 1.7, seed.y)) + 0.04 * value_noise(vec3(along * 7.0, 4.1, seed.y));
		float covered = 1.0 - smoothstep(lip - 0.012, lip, below_top);
		// Its shadow on the stone just under it.
		float under = (1.0 - smoothstep(lip, lip + 0.11, below_top)) * (1.0 - covered);
		// Old stone is darker and damp toward its foot.
		float foot = smoothstep(0.15, 1.1, below_top);
		base *= 1.0 - foot * 0.24;
		if (kind == 2) {
			float band = smoothstep(0.34, 0.35, below_top) * (1.0 - smoothstep(0.50, 0.51, below_top));
			float streak = value_noise(vec3(along * 11.0, below_top * 2.0, 2.3));
			vec3 bronze = mix(patina, patina * 1.35 + vec3(0.02, 0.05, 0.04), streak * 0.6);
			float rim = smoothstep(0.014, 0.0, abs(below_top - 0.355)) + smoothstep(0.014, 0.0, abs(below_top - 0.495));
			base = mix(base, bronze * (1.0 - rim * 0.35), band);
			roughness = mix(roughness, 0.48, band);
			metallic = band * 0.35;
			// The stone under the band is in its shadow.
			base *= 1.0 - (1.0 - smoothstep(0.51, 0.58, below_top)) * step(0.51, below_top) * 0.22;
		}
		base *= 1.0 - under * (summer ? 0.20 : 0.26);
		base = mix(base, cover, covered);
		roughness = mix(roughness, summer ? 0.9 : 0.72, covered);
		metallic *= 1.0 - covered;
		// The lip is round: it turns up toward the sky.
		relief = normalize(relief + vec3(0.0, 1.0, 0.0) * covered * (0.35 + 0.5 * (1.0 - below_top / max(lip, 0.001))));
	} else {
		base *= 0.8;
	}
	if (!cut_face && !top_face) {
		// Worn edges: the sides round into each other. Tops stay flat, so
		// the cover runs unbroken over neighbouring blocks.
		vec3 edge = max(abs(source_position) - (half_source - vec3(0.04)), vec3(0.0)) * (vec3(1.0) - face);
		edge.y = 0.0;
		relief = normalize(relief + sign(source_position) * edge * 9.0);
	}
	if (summer) {
		glow = summer_glow * 0.16;
	}
	if (!FRONT_FACING) {
		relief = -relief;
	}
	mat3 source_to_world = inverse(world_to_source);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(source_to_world * relief), 0.0)).xyz);
	ALBEDO = base;
	METALLIC = metallic;
	SPECULAR = 0.35;
	ROUGHNESS = roughness;
	EMISSION = glow;
}

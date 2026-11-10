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
// The height of the ice below the place, and how far above it a stone still
// shows in the ice.
uniform float ice_height = -100.0;
uniform float image_reach = 1.5;

uniform vec3 stone : source_color = vec3(0.74, 0.69, 0.60);
uniform vec3 snow : source_color = vec3(0.93, 0.93, 0.95);
uniform vec3 patina : source_color = vec3(0.22, 0.32, 0.28);
uniform vec3 summer_stone : source_color = vec3(0.80, 0.70, 0.55);
uniform vec3 moss : source_color = vec3(0.40, 0.46, 0.22);
uniform vec3 summer_glow : source_color = vec3(0.95, 0.85, 0.63);

varying vec3 world_position;
varying vec3 world_normal;
// The box face a vertex of a shaped stone belongs to (`world/stone_mesh.gd`);
// zero on a plain box and on a cut fragment.
varying vec3 box_face;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	box_face = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 0.0)).xyz;
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
	// A shaped stone is painted by the box face it stands for, and lit by
	// its own rounded surface.
	bool shaped = dot(box_face, box_face) > 0.25;
	vec3 true_normal = normalize(world_to_source * world_normal);
	vec3 source_normal = shaped ? normalize(world_to_source * box_face) : true_normal;
	vec3 half_source = max(source_size * 0.5, vec3(0.0001));
	vec3 face = abs(source_normal);
	vec3 source_plane_distance = abs(abs(source_position) - half_source);
	float source_boundary = dot(source_plane_distance, face);
	// A face the mirror cut, or the inside of a clipped block, shows bare stone.
	bool cut_face = (polygon_surface && COLOR.g > 0.5) || (!shaped && source_boundary > 0.003) || !FRONT_FACING;
	bool top_face = source_normal.y > 0.72;
	bool side_face = face.y < 0.72;
	bool summer = kind == 1;
	vec3 place = source_position + seed;
	float below_top = half_source.y - source_position.y;

	float blotch = value_noise(place * 1.7) * 0.6 + value_noise(place * 5.3) * 0.4;
	vec3 base = (summer ? summer_stone : stone) * (0.93 + blotch * 0.12);
	float roughness = 0.82;
	float metallic = 0.0;
	vec3 relief = true_normal;
	vec3 glow = vec3(0.0);
	vec3 cover = summer ? moss * (0.82 + value_noise(place * 9.0) * 0.36) : snow;

	if (cut_face) {
		base = mix(base, summer ? summer_stone : stone, 0.6) * 1.05;
	} else if (top_face) {
		base = cover;
		roughness = summer ? 0.9 : 0.72;
		if (summer) {
			// Moss grows in cushions: darker between them, bright on top.
			float cushion = value_noise(place * vec3(4.2, 0.0, 4.2) + 3.0);
			base *= 0.74 + 0.5 * smoothstep(0.25, 0.75, cushion);
			float e = 0.05;
			float rise_x = value_noise(vec3(place.x + e, 0.0, place.z) * 4.2 + 3.0) - value_noise(vec3(place.x - e, 0.0, place.z) * 4.2 + 3.0);
			float rise_z = value_noise(vec3(place.x, 0.0, place.z + e) * 4.2 + 3.0) - value_noise(vec3(place.x, 0.0, place.z - e) * 4.2 + 3.0);
			relief = normalize(relief - vec3(rise_x, 0.0, rise_z) * 1.1);
			// Small flowers, white and a few yellow.
			vec2 cell = floor(place.xz * 6.0);
			vec2 jitter = vec2(hash(vec3(cell, 5.0)), hash(vec3(cell, 9.0))) * 0.6 - 0.3;
			vec2 within = fract(place.xz * 6.0) - 0.5 - jitter;
			float pick = hash(vec3(cell, 3.0));
			float flower = step(0.72, pick) * smoothstep(0.20, 0.10, length(within) * (0.7 + pick * 0.6));
			base = mix(base, pick > 0.9 ? vec3(1.0, 0.80, 0.30) : vec3(1.0, 0.97, 0.90), flower);
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
		if (shaped) {
			// The roll of the cover is real; only its drips are painted.
			lip = 0.082 + 0.07 * value_noise(vec3(along * 3.1, 1.7, seed.y)) * value_noise(vec3(along * 9.0, 4.1, seed.y));
		}
		float covered = 1.0 - smoothstep(lip - 0.012, lip, below_top);
		// Its shadow on the stone just under it.
		float under = (1.0 - smoothstep(lip, lip + 0.11, below_top)) * (1.0 - covered);
		// Old stone is darker and damp toward its foot.
		float foot = smoothstep(0.15, 1.1, below_top);
		base *= 1.0 - foot * 0.24;
		// Weather runs down it in streaks; it is pitted, and lichen has
		// taken hold in pale patches.
		float run = value_noise(vec3(along * 8.0, below_top * 0.8, seed.y + 7.0));
		base *= 1.0 - smoothstep(0.50, 0.95, run) * 0.30 * (1.0 - foot * 0.5);
		base *= 0.90 + 0.20 * value_noise(place * 21.0);
		float lichen = smoothstep(0.62, 0.74, value_noise(place * 3.1 + 17.0)) * smoothstep(0.3, 0.7, value_noise(place * 13.0));
		base = mix(base, vec3(0.62, 0.64, 0.52) * (summer ? 1.1 : 0.9), lichen * 0.55);
		// A crack or two, where frost has split it.
		float split = abs(value_noise(vec3(along * 1.9, below_top * 1.4, seed.y + 21.0)) - 0.5);
		float fissure = (1.0 - smoothstep(0.0, 0.012, split)) * smoothstep(0.35, 0.6, value_noise(place * 1.3 + 40.0));
		base *= 1.0 - fissure * 0.45;
		// Rime climbs the foot, over the cold of the ice.
		float rime = (1.0 - smoothstep(0.0, 0.16 + 0.10 * value_noise(vec3(along * 6.0, 9.0, seed.y)), half_source.y * 2.0 - below_top)) * (summer ? 0.0 : 0.55);
		base = mix(base, snow * 0.92, rime);
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
		if (!shaped) {
			relief = normalize(relief + vec3(0.0, 1.0, 0.0) * covered * (0.35 + 0.5 * (1.0 - below_top / max(lip, 0.001))));
		}
	} else {
		base *= 0.8;
	}
	if (!cut_face && !top_face && !shaped) {
		// Worn edges: the sides round into each other. Tops stay flat, so
		// the cover runs unbroken over neighbouring blocks.
		vec3 edge = max(abs(source_position) - (half_source - vec3(0.04)), vec3(0.0)) * (vec3(1.0) - face);
		edge.y = 0.0;
		relief = normalize(relief + sign(source_position) * edge * 9.0);
	}
	if (summer) {
		// The copy is the lantern of a place: it holds its own colour in any light.
		// Its sides glow like paper round a flame: most at the heart of each face.
		vec3 across_face = abs(source_position) / half_source * (vec3(1.0) - face);
		float rim = smoothstep(0.25, 1.0, max(across_face.x, max(across_face.y, across_face.z)));
		glow = top_face && !cut_face ? base * 0.85 : mix(vec3(1.0, 0.66, 0.30) * 1.15, vec3(0.90, 0.46, 0.22) * 0.45, rim) * (0.85 + 0.3 * blotch);
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
	if ((CAMERA_VISIBLE_LAYERS & 1u) == 0u) {
		// Drawn for the image in the ice. The image darkens to nothing with
		// height above the ice, so it is strongest under the stone and never
		// looks solid. It carries its own plain light; the ice reads how
		// much of it is left from its brightness.
		float keep = 1.0 - smoothstep(0.0, image_reach, world_position.y - ice_height);
		float lit = 0.55 + 0.45 * max(dot(normalize(source_to_world * relief), vec3(0.25, 0.51, 0.82)), 0.0);
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = (base * lit + glow) * keep * keep;
	}
}

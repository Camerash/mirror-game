shader_type spatial;
render_mode unshaded;
// The surface of the garden that stands round the pond
// (`world/garden_backdrop.gd`). COLOR.rgb is the bare value of a thing.
// COLOR.a marks the one lit window (0) and the ground of the garden (0.5).
//
// The garden is far, in the mist: a thing is paler the further it stands
// behind the place, by the same rule as the far water (`world/ice.gdshader`).
// It carries its own soft light, which is the same from each view. Soft snow
// lies on each thing that faces the sky: the roofs, the tops of the walls and
// the branches (owner, 2026-11-18). The garden has no flat top, and its snow
// is in the mist and less bright than the snow of the place, so it is not
// taken for ground. The water shows no image of the garden: a pale image
// along the foot of a wall reads as a ledge.

uniform vec3 mist : source_color = vec3(0.80, 0.82, 0.82);
uniform vec3 lamp : source_color = vec3(1.0, 0.71, 0.40);
uniform float water_level = -100.0;
// How much of its side is there: 1 behind the place, 0 where the side would
// stand between the view and the place. Between the two, the side shows
// through a fine screen.
instance uniform float shown = 1.0;

// The snow of the garden, a little below the snow of the place.
const vec3 SNOW = vec3(0.80, 0.83, 0.87);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (shown < 1.0 && shown <= fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))))) {
		discard;
	}
	// How far behind the middle of the view this point stands, along the
	// water. The view is from far away, so its lines of sight are parallel.
	vec3 sight = -INV_VIEW_MATRIX[2].xyz;
	vec3 middle = CAMERA_POSITION_WORLD + sight * ((water_level - CAMERA_POSITION_WORLD.y) / (abs(sight.y) > 0.001 ? sight.y : 0.001));
	float behind = dot(world_position.xz - middle.xz, normalize(sight.xz + vec2(0.00001)));
	float lift = world_position.y - water_level;
	float veil = mix(0.46, 0.94, smoothstep(2.0, 20.0, behind));

	vec3 bare = pow(COLOR.rgb, vec3(2.2));
	// A soft light from the upper left of the view keeps each face in shape.
	vec3 seen = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	bare *= 0.84 + 0.16 * dot(seen, vec3(-0.48, 0.52, 0.71));
	// The foot is wet and dark where it stands in the water.
	bare *= 1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.35, lift));
	// Snow on what faces the sky, in soft drifts. It is thin on a steep face.
	float drift = sin(world_position.x * 1.3 + world_position.z * 1.9) * sin(world_position.x * 0.8 - world_position.z * 2.3 + world_position.y);
	float snow = smoothstep(0.12, 0.5, world_normal.y + drift * 0.06);
	bare = mix(bare, SNOW * (0.94 + 0.06 * drift) * (0.9 + 0.1 * dot(seen, vec3(-0.48, 0.52, 0.71))), snow);
	// The snow keeps a little more of itself in the mist than the walls do.
	vec3 colour = mix(bare, mist, veil * (1.0 - snow * 0.18));
	if (COLOR.a < 0.25) {
		// The lit window: warm, and soft through the mist.
		colour = mix(lamp, mist, 0.3 + veil * 0.45);
	} else if (COLOR.a < 0.75) {
		// The ground behind the walls is lost in the mist.
		colour = mix(mist * 0.8, mist, veil);
	}
	ALBEDO = colour;
}

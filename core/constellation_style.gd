class_name ConstellationStyle
extends RefCounted
## Session-only display settings. They do not belong to level or mirror state.

const DEFAULTS := {"brightness": 0.8, "glow": 0.35, "size": 3.0, "halo": 5.0}
const LIMITS := {
	"brightness": Vector3(0, 1, 0.05), "glow": Vector3(0, 1, 0.05),
	"size": Vector3(1, 6, 0.5), "halo": Vector3(0, 12, 0.5)}
const LABELS := {"brightness": "Core brightness", "glow": "Glow strength", "size": "Dot diameter", "halo": "Halo radius"}

static func normalized(values: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate()
	for key: String in DEFAULTS:
		var value: Variant = values.get(key, DEFAULTS[key])
		if (value is float or value is int) and is_finite(float(value)):
			var limits: Vector3 = LIMITS[key]
			result[key] = clampf(snappedf(float(value), limits.z), limits.x, limits.y)
	return result

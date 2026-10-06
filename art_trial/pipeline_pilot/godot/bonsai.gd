extends RefCounted
## Bonsai in a shallow oval celadon pot: filleted lathe pot, mossy soil,
## an S-curved tapering trunk with root flare, four branches and five
## cloud pads (soft union of puffs). Origin at the base centre, y up.
const Lib = preload("res://lib.gd")

const POT_SCALE := Vector3(1.1, 1.0, 0.9)
const SOIL_Y := 0.218

static func build() -> Node3D:
	var glaze := Lib.Surf.new(Lib.material("celadon_glaze", "bcd6c4", 0.35, 0.0, true))
	var moss := Lib.Surf.new(Lib.material("moss", "ffffff", 0.95, 0.0, true))
	moss.use_colors = true
	var bark := Lib.Surf.new(Lib.material("bark", "6b5040", 0.8, 0.0, true))
	bark.use_colors = true
	glaze.use_colors = true
	var leaves := Lib.Surf.new(Lib.material("foliage", "ffffff", 0.75, 0.0, true))
	leaves.use_colors = true
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006
	_pot(glaze)
	_soil(moss, noise)
	var trunk := PackedVector3Array([
		Vector3(0.03, 0.15, 0.0),
		Vector3(0.035, 0.27, 0.01),
		Vector3(-0.025, 0.40, 0.02),
		Vector3(0.035, 0.54, -0.005),
		Vector3(0.01, 0.68, 0.015),
		Vector3(-0.03, 0.83, 0.0),
	])
	_tube(bark, noise, trunk, 30, 20, 0.062, 0.018, true)
	# Pads: centre, horizontal radius, squash, x/z stretch, colour.
	var pads := [
		[Vector3(-0.03, 0.885, 0.0), 0.17, Vector2(1.1, 0.9), "729d5c"],
		[Vector3(-0.225, 0.50, 0.05), 0.15, Vector2(1.15, 0.85), "6a9455"],
		[Vector3(0.215, 0.62, -0.03), 0.14, Vector2(1.1, 0.9), "76a160"],
		[Vector3(0.0, 0.70, -0.21), 0.13, Vector2(1.0, 0.85), "6c9657"],
		[Vector3(0.13, 0.75, 0.18), 0.11, Vector2(1.0, 0.95), "70995a"],
	]
	var branch_t := [0.0, 0.38, 0.52, 0.62, 0.72]
	for k in pads.size():
		var pad: Array = pads[k]
		var centre: Vector3 = pad[0]
		if k > 0:
			var start := Lib.spline(trunk, branch_t[k])
			var end := centre - Vector3(0, 0.03, 0)
			var mid1 := start.lerp(end, 0.4) + Vector3(0, -0.015, 0)
			var mid2 := start.lerp(end, 0.75) + Vector3(0, 0.01, 0)
			_tube(bark, noise, PackedVector3Array([start, mid1, mid2, end]), 10, 10, 0.034, 0.013, false)
		_pad(leaves, rng, noise, centre, pad[1], pad[2], Color(pad[3]))
	var node := MeshInstance3D.new()
	node.name = "BonsaiMesh"
	# Bark first: Godot 4.7.2 glTF import never flags the first primitive for
	# vertex-colour albedo, and bark needs none.
	node.mesh = Lib.commit([bark, glaze, moss, leaves], "bonsai")
	var root := Node3D.new()
	root.name = "Bonsai"
	root.add_child(node)
	return root

static func _pot(s: Lib.Surf) -> void:
	var pot := Lib.profile([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.205, 0.0, 0.006),
		Vector3(0.212, 0.032, 0.006),
		Vector3(0.245, 0.038, 0.01),
		Vector3(0.278, 0.07, 0.035),
		Vector3(0.284, 0.198, 0.012),
		Vector3(0.276, 0.206, 0.004),
		Vector3(0.296, 0.222, 0.008),
		Vector3(0.298, 0.248, 0.007),
		Vector3(0.268, 0.248, 0.007),
		Vector3(0.262, 0.215, 0.005),
		Vector3(0.0, 0.215, 0.0),
	], 3, 0.012)
	var first := s.verts.size()
	Lib.lathe(s, pot, 36, Lib.xf_transform(Transform3D(Basis.from_scale(POT_SCALE), Vector3.ZERO)))
	# Baked occlusion: darker foot and underside, shaded inner lip.
	for k in range(first, s.verts.size()):
		var p := s.verts[k]
		var n := s.norms[k]
		var g := lerpf(0.55, 1.0, smoothstep(0.0, 0.14, p.y))
		if n.dot(Vector3(p.x, 0.0, p.z).normalized()) < -0.2 and p.y > 0.2:
			g *= lerpf(0.7, 1.0, smoothstep(0.215, 0.245, p.y))
		s.cols[k] = Color(g, g, g)

static func _soil(s: Lib.Surf, noise: FastNoiseLite) -> void:
	var rings: Array = []
	var segs := 36
	var count := 10
	for i in count:
		var f := float(i) / (count - 1)
		var r := 0.266 * f
		var ring := PackedVector3Array()
		for j in segs:
			var a := TAU * j / segs
			var x := cos(a) * r
			var z := sin(a) * r
			var y := SOIL_Y + 0.014 * (1.0 - f * f) + 0.004 * noise.get_noise_2d(x * 14.0, z * 14.0) * f
			if i == count - 1:
				y = SOIL_Y + 0.004
			ring.append(Vector3(x, y, z) * POT_SCALE)
		rings.append(ring)
	var dark := Color("5c4b38").srgb_to_linear()
	var green := Color("6b7b43").srgb_to_linear()
	Lib.ring_grid(s, rings, func(_p: Vector3, _i: int) -> Vector3: return Vector3.UP,
		func(p: Vector3, _n: Vector3, _i: int) -> Color:
			return dark.lerp(green, 0.35 + 0.65 * smoothstep(-0.35, 0.25, noise.get_noise_2d(p.x * 5.0 + 40.0, p.z * 5.0))))

## Tapering tube along a Catmull-Rom path, closed with poles at both ends.
## Root flare and lobes when flare is set.
static func _tube(s: Lib.Surf, noise: FastNoiseLite, ctrl: PackedVector3Array, rings_n: int, segs: int, r0: float, r1: float, flare: bool) -> void:
	var centres := PackedVector3Array()
	var tangents := PackedVector3Array()
	for i in rings_n:
		var t := float(i) / (rings_n - 1)
		centres.append(Lib.spline(ctrl, pow(t, 1.35)))
	for i in rings_n:
		tangents.append((centres[mini(i + 1, rings_n - 1)] - centres[maxi(i - 1, 0)]).normalized())
	var normal := tangents[0].cross(Vector3.RIGHT if absf(tangents[0].x) < 0.9 else Vector3.FORWARD).normalized()
	var rows: Array = []
	var row_centres := PackedVector3Array()
	var poles := PackedVector3Array()
	# Bottom pole.
	var start_pole := centres[0] - tangents[0] * r0 * 0.6
	rows.append(_pole_ring(start_pole, segs))
	row_centres.append(start_pole)
	poles.append(-tangents[0])
	var arc := 0.0
	for i in rings_n:
		if i > 0:
			arc += centres[i].distance_to(centres[i - 1])
			var axis := tangents[i - 1].cross(tangents[i])
			if axis.length() > 1e-6:
				normal = normal.rotated(axis.normalized(), tangents[i - 1].angle_to(tangents[i]))
		normal = (normal - tangents[i] * normal.dot(tangents[i])).normalized()
		var binormal := tangents[i].cross(normal)
		var t := pow(float(i) / (rings_n - 1), 1.35)
		var radius := lerpf(r0, r1, pow(t, 0.85))
		var ring := PackedVector3Array()
		for j in segs:
			var a := TAU * j / segs
			var dir := normal * cos(a) + binormal * sin(a)
			var r := radius * (1.0 + 0.07 * noise.get_noise_3d(cos(a) * 1.6, sin(a) * 1.6, arc * 5.0 + r0 * 50.0))
			if flare:
				var f := clampf(1.0 - (centres[i].y - (SOIL_Y - 0.01)) / 0.1, 0.0, 1.0)
				f *= f
				r *= 1.0 + 0.6 * f + 0.55 * f * pow(0.5 + 0.5 * cos(5.0 * a + 0.6), 2.0)
			ring.append(centres[i] + dir * r)
		rows.append(ring)
		row_centres.append(centres[i])
		poles.append(Vector3.ZERO)
	var end_pole := centres[rings_n - 1] + tangents[rings_n - 1] * r1 * 0.8
	rows.append(_pole_ring(end_pole, segs))
	row_centres.append(end_pole)
	poles.append(tangents[rings_n - 1])
	Lib.ring_grid(s, rows,
		func(p: Vector3, i: int) -> Vector3:
			var d := p - row_centres[i]
			return d if d.length() > 1e-6 else poles[i],
		func(_p: Vector3, _n: Vector3, _i: int) -> Color: return Color.WHITE)

static func _pole_ring(p: Vector3, segs: int) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for j in segs:
		ring.append(p)
	return ring

## Cloud pad: soft union of puffs, star-shaped round the pad centre, squashed
## (flatter underside), coloured darker underneath.
static func _pad(s: Lib.Surf, rng: RandomNumberGenerator, noise: FastNoiseLite, centre: Vector3, a: float, stretch: Vector2, colour: Color) -> void:
	var puffs: Array = [[Vector3(0, 0.05 * a, 0), 0.6 * a]]
	var ring_n := 6
	var phase := rng.randf() * TAU
	for k in ring_n:
		var ang := phase + TAU * k / ring_n + rng.randf_range(-0.25, 0.25)
		var d := a * rng.randf_range(0.5, 0.62)
		puffs.append([Vector3(cos(ang) * d, rng.randf_range(-0.05, 0.12) * a, sin(ang) * d), a * rng.randf_range(0.4, 0.5)])
	for k in 3:
		var ang := phase + TAU * k / 3.0 + rng.randf_range(0.2, 0.9)
		puffs.append([Vector3(cos(ang) * a * 0.3, 0.3 * a, sin(ang) * a * 0.3), a * rng.randf_range(0.36, 0.44)])
	var sharp := 11.0 / a
	var rows_n := 12
	var segs := 32
	var rows: Array = []
	for i in rows_n + 1:
		var v := -PI * 0.5 + PI * i / rows_n
		var ring := PackedVector3Array()
		for j in segs:
			var u := TAU * j / segs
			var d := Vector3(cos(v) * cos(u), sin(v), cos(v) * sin(u))
			var acc := 0.0
			for puff: Array in puffs:
				var c: Vector3 = puff[0]
				var rho: float = puff[1]
				var b := d.dot(c)
				var disc := b * b - (c.length_squared() - rho * rho)
				if disc >= 0.0:
					var hit := b + sqrt(disc)
					if hit > 0.0:
						acc += exp(sharp * hit)
			var r := log(acc) / sharp
			var p := d * r
			p.y *= lerpf(0.42, 0.62, smoothstep(-0.3 * a, 0.3 * a, p.y))
			p.x *= stretch.x
			p.z *= stretch.y
			ring.append(centre + p)
		rows.append(ring)
	var base := colour.srgb_to_linear()
	var tip := Color("9dbb6a").srgb_to_linear()
	var shade := Color("33502e").srgb_to_linear()
	Lib.ring_grid(s, rows,
		func(p: Vector3, i: int) -> Vector3:
			var d := p - centre
			if d.length() < 1e-6 or i == 0 or i == rows_n:
				return Vector3.UP if i > 0 else Vector3.DOWN
			return d,
		func(p: Vector3, n: Vector3, _i: int) -> Color:
			var c := shade.lerp(base, smoothstep(-0.7, 0.35, n.y))
			var lift := smoothstep(0.35, 1.0, n.y) * 0.45 + 0.18 * noise.get_noise_3d(p.x * 18.0, p.y * 18.0, p.z * 18.0)
			return c.lerp(tip, clampf(lift, 0.0, 1.0)))

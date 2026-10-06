extends RefCounted
## Procedural mesh helpers: per-material surfaces, rounded (bevelled) boxes,
## filleted lathe profiles, swept tubes and smooth grids with outward normals.

class Surf:
	var material: Material
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var use_colors := false

	func _init(m: Material) -> void:
		material = m

	func vert(p: Vector3, n: Vector3, uv: Vector2, c: Color = Color(1, 1, 1)) -> int:
		verts.append(p)
		norms.append(n.normalized())
		uvs.append(uv)
		cols.append(c)
		return verts.size() - 1

	## Adds a triangle wound so its face agrees with the vertex normals
	## (Godot: clockwise front faces). Degenerate triangles are dropped.
	func tri(a: int, b: int, c: int) -> void:
		var pa := verts[a]
		var g := (verts[c] - pa).cross(verts[b] - pa)
		if g.length_squared() < 1e-16:
			return
		if g.dot(norms[a] + norms[b] + norms[c]) < 0.0:
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])

	func grid(rows: int, cols_n: int, base: int) -> void:
		for r in rows - 1:
			for c in cols_n - 1:
				var a := base + r * cols_n + c
				tri(a, a + 1, a + cols_n + 1)
				tri(a, a + cols_n + 1, a + cols_n)

static func material(mat_name: String, hex: String, rough: float, metal: float, vcol := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name
	m.albedo_color = Color(hex)
	m.roughness = rough
	m.metallic = metal
	m.vertex_color_use_as_albedo = vcol
	return m

static func commit(surfs: Array, mesh_name: String) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.resource_name = mesh_name
	for s: Surf in surfs:
		if s.idx.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.verts
		arrays[Mesh.ARRAY_NORMAL] = s.norms
		arrays[Mesh.ARRAY_TEX_UV] = s.uvs
		if s.use_colors:
			arrays[Mesh.ARRAY_COLOR] = s.cols
		arrays[Mesh.ARRAY_INDEX] = s.idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, s.material)
	return mesh

# ---------- point/normal transforms (Callable(p, n) -> [p, n]) ----------

static func xf_offset(o: Vector3) -> Callable:
	return func(p: Vector3, n: Vector3) -> Array: return [p + o, n]

static func xf_transform(t: Transform3D) -> Callable:
	var nb := t.basis.inverse().transposed()
	return func(p: Vector3, n: Vector3) -> Array: return [t * p, (nb * n).normalized()]

## Bends local (arc length x, radial offset y, depth z) round a circle of
## radius rm centred at c, angle measured from +X towards +Y.
static func xf_bend(rm: float, c: Vector3) -> Callable:
	return func(p: Vector3, n: Vector3) -> Array:
		var a := p.x / rm
		var rho := rm + p.y
		var t := Vector3(-sin(a), cos(a), 0.0)
		var r := Vector3(cos(a), sin(a), 0.0)
		var pos := c + r * rho + Vector3(0.0, 0.0, p.z)
		var nn := (t * (n.x * rm / rho) + r * n.y + Vector3(0.0, 0.0, n.z)).normalized()
		return [pos, nn]

## Keystone taper: x scales with height above the arch centre so the sides
## lie on radial planes through c.
static func xf_taper(y_ref: float, c: Vector3) -> Callable:
	return func(p: Vector3, n: Vector3) -> Array:
		var a := p.y / y_ref
		var b := p.x / y_ref
		var pos := c + Vector3(p.x * a, p.y, p.z)
		var nn := Vector3(n.x / a, -b * n.x / a + n.y, n.z).normalized()
		return [pos, nn]

# ---------- rounded box ----------

static func _samples(h: float, r: float, m: int, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var c := h - r
	for k in range(m, 0, -1):
		out.append(-c - r * tan(PI * 0.25 * k / m))
	for i in n + 1:
		out.append(-c + 2.0 * c * i / n)
	for k in range(1, m + 1):
		out.append(c + r * tan(PI * 0.25 * k / m))
	out[0] = -h
	out[out.size() - 1] = h
	return out

## Box with elliptical rounded edges (radii rv per axis), smooth analytic
## normals on the bevels and exact face normals on the flat parts.
static func rounded_box(s: Surf, centre: Vector3, size: Vector3, rv: Vector3, m: int, sub: Vector3i, xf: Callable, uv_scale := 1.0) -> void:
	var h := size * 0.5
	var c := h - rv
	var samples: Array = []
	for a in 3:
		samples.append(_samples(h[a], rv[a], m, sub[a]))
	for a in 3:
		for sgn: float in [-1.0, 1.0]:
			var u := (a + 1) % 3
			var v := (a + 2) % 3
			var su: PackedFloat32Array = samples[u]
			var sv: PackedFloat32Array = samples[v]
			var base := s.verts.size()
			for j in sv.size():
				for i in su.size():
					var p := Vector3()
					p[a] = sgn * h[a]
					p[u] = su[i]
					p[v] = sv[j]
					var inner := p.clamp(-c, c)
					var e := ((p - inner) / rv).normalized()
					var q := inner + e * rv
					var nrm := (e / rv).normalized()
					var res: Array = xf.call(q + centre, nrm)
					s.vert(res[0], res[1], Vector2(su[i], sv[j]) * uv_scale)
			s.grid(sv.size(), su.size(), base)

# ---------- lathe with filleted profile ----------

## pts: Vector3(r, y, f). f > 0 fillet radius, f == 0 hard corner,
## f < 0 smooth pass-through point. Returns rows [Vector2 pos, Vector2 normal].
## auto_step > 0 picks fewer arc segments for small fillets (one per auto_step of radius).
static func profile(pts: Array, arc_segs := 3, auto_step := 0.0) -> Array:
	var out: Array = []
	var n := pts.size()
	for k in n:
		var p := Vector2(pts[k].x, pts[k].y)
		var f: float = pts[k].z
		var nin := Vector2.ZERO
		var nout := Vector2.ZERO
		if k > 0:
			var t := (p - Vector2(pts[k - 1].x, pts[k - 1].y)).normalized()
			nin = Vector2(t.y, -t.x)
		if k < n - 1:
			var t := (Vector2(pts[k + 1].x, pts[k + 1].y) - p).normalized()
			nout = Vector2(t.y, -t.x)
		if k == 0:
			out.append([p, nout])
		elif k == n - 1:
			out.append([p, nin])
		elif f > 0.0:
			var pa := Vector2(pts[k - 1].x, pts[k - 1].y)
			var pb := Vector2(pts[k + 1].x, pts[k + 1].y)
			var u := (pa - p).normalized()
			var w := (pb - p).normalized()
			var beta := acos(clampf(u.dot(w), -1.0, 1.0)) * 0.5
			if beta > PI * 0.5 - 0.002:
				out.append([p, (nin + nout).normalized()])
				continue
			var rr := f
			var d := rr / tan(beta)
			var dmax := 0.5 * minf((pa - p).length(), (pb - p).length())
			if d > dmax:
				d = dmax
				rr = d * tan(beta)
			var t1 := p + u * d
			var t2 := p + w * d
			var cc := p + (u + w).normalized() * (rr / sin(beta))
			var a1 := (t1 - cc).angle()
			var da := wrapf((t2 - cc).angle() - a1, -PI, PI)
			var segs := arc_segs
			if auto_step > 0.0:
				segs = clampi(ceili(rr / auto_step), 1, arc_segs)
			for i in segs + 1:
				var ang := a1 + da * i / segs
				var q := cc + Vector2(cos(ang), sin(ang)) * rr
				var nn := (q - cc).normalized()
				if nn.dot(nin + nout) < 0.0:
					nn = -nn
				out.append([q, nn])
		elif f == 0.0:
			out.append([p, nin])
			out.append([p, nout])
		else:
			out.append([p, (nin + nout).normalized()])
	return out

static func lathe(s: Surf, rows: Array, segs: int, xf: Callable, phase := 0.0) -> void:
	var base := s.verts.size()
	var vacc := 0.0
	for k in rows.size():
		var pr: Vector2 = rows[k][0]
		var nr: Vector2 = rows[k][1]
		if k > 0:
			vacc += (pr - (rows[k - 1][0] as Vector2)).length()
		for i in segs + 1:
			var phi := TAU * float(i % segs) / segs + phase
			var cp := cos(phi)
			var sp := sin(phi)
			var res: Array = xf.call(Vector3(pr.x * cp, pr.y, pr.x * sp), Vector3(nr.x * cp, nr.y, nr.x * sp))
			s.vert(res[0], res[1], Vector2(float(i) / segs, vacc))
	s.grid(rows.size(), segs + 1, base)

# ---------- smooth grids (organic) ----------

## pts: rows of PackedVector3Array, each ring closed (wraps). Normals by
## central differences, flipped to agree with outward(p, row) -> Vector3.
## Pole rows (all points equal) take the outward direction.
static func ring_grid(s: Surf, pts: Array, outward: Callable, colour: Callable) -> void:
	var rows := pts.size()
	var cols_n: int = (pts[0] as PackedVector3Array).size()
	var base := s.verts.size()
	for i in rows:
		var ring: PackedVector3Array = pts[i]
		var prev: PackedVector3Array = pts[maxi(i - 1, 0)]
		var next: PackedVector3Array = pts[mini(i + 1, rows - 1)]
		for j in cols_n + 1:
			var jj := j % cols_n
			var p := ring[jj]
			var dj := ring[(jj + 1) % cols_n] - ring[(jj - 1 + cols_n) % cols_n]
			var di := next[jj] - prev[jj]
			var nrm := dj.cross(di)
			var out_dir: Vector3 = outward.call(p, i)
			if nrm.length_squared() < 1e-14:
				nrm = out_dir
			elif nrm.dot(out_dir) < 0.0:
				nrm = -nrm
			nrm = nrm.normalized()
			s.vert(p, nrm, Vector2(float(j) / cols_n, float(i) / (rows - 1)), colour.call(p, nrm, i))
	s.grid(rows, cols_n + 1, base)

## Catmull-Rom point on a polyline of control points, t in [0, 1].
static func spline(ctrl: PackedVector3Array, t: float) -> Vector3:
	var n := ctrl.size() - 1
	var x := clampf(t, 0.0, 1.0) * n
	var i := mini(int(floor(x)), n - 1)
	var f := x - i
	var p0 := ctrl[maxi(i - 1, 0)]
	var p1 := ctrl[i]
	var p2 := ctrl[i + 1]
	var p3 := ctrl[mini(i + 2, n)]
	if i == 0:
		p0 = p1 * 2.0 - p2
	if i + 2 > n:
		p3 = p2 * 2.0 - p1
	return p1.cubic_interpolate(p2, p0, p3, f)

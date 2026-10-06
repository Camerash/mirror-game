extends RefCounted
## Shrine gate: two-step plinth, two columns with base and capital, a
## nine-voussoir semicircular arch with a jade keystone, a cap slab and a
## warm-metal finial. 1 unit = one game block; origin at the base centre.
const Lib = preload("res://lib.gd")

const SPRING := 2.2          # arch springing height (top of abacus)
const R_MID := 0.85          # arch centre-line radius (over the columns)
const ARCH_T := 0.18         # radial thickness
const ARCH_D := 0.36         # depth (z)
const VOUSSOIRS := 9
const SLAB_Y := 3.18         # cap slab underside

static func build() -> Node3D:
	var ivory := Lib.Surf.new(Lib.material("ivory_glaze", "efe6d8", 0.35, 0.0))
	var jade := Lib.Surf.new(Lib.material("jade", "5f8f78", 0.3, 0.0))
	var metal := Lib.Surf.new(Lib.material("warm_metal", "c9a36a", 0.35, 1.0))
	var none := Lib.xf_offset(Vector3.ZERO)
	var bevel := Vector3.ONE * 0.03
	# Plinth and jade band.
	Lib.rounded_box(ivory, Vector3(0, 0.1, 0), Vector3(3.0, 0.2, 2.0), bevel, 1, Vector3i.ONE, none)
	Lib.rounded_box(ivory, Vector3(0, 0.3, 0), Vector3(2.6, 0.2, 1.6), bevel, 1, Vector3i.ONE, none)
	Lib.rounded_box(jade, Vector3(0, 0.3, 0), Vector3(2.63, 0.06, 1.63), Vector3.ONE * 0.02, 1, Vector3i.ONE, none)
	# Columns with base, shaft (slight entasis) and echinus; square abacus.
	var column := Lib.profile([
		Vector3(0.0, 0.40, 0.0),
		Vector3(0.22, 0.40, 0.0),
		Vector3(0.22, 0.445, 0.025),
		Vector3(0.19, 0.445, 0.006),
		Vector3(0.19, 0.475, 0.012),
		Vector3(0.16, 0.50, 0.03),
		Vector3(0.162, 1.0, -1.0),
		Vector3(0.157, 1.55, -1.0),
		Vector3(0.151, 1.975, 0.0),
		Vector3(0.162, 1.980, -1.0),
		Vector3(0.168, 1.991, -1.0),
		Vector3(0.162, 2.002, -1.0),
		Vector3(0.150, 2.007, 0.0),
		Vector3(0.149, 2.035, 0.012),
		Vector3(0.168, 2.050, -1.0),
		Vector3(0.183, 2.066, -1.0),
		Vector3(0.193, 2.088, -1.0),
		Vector3(0.198, 2.110, -1.0),
		Vector3(0.199, 2.128, 0.0),
		Vector3(0.0, 2.128, 0.0),
	], 2)
	for side: float in [-1.0, 1.0]:
		Lib.lathe(ivory, column, 26, Lib.xf_offset(Vector3(side * R_MID, 0, 0)))
		Lib.rounded_box(ivory, Vector3(side * R_MID, 2.16, 0), Vector3(0.42, 0.08, 0.42), Vector3.ONE * 0.02, 1, Vector3i.ONE, none)
	# Arch: bent rounded boxes; joints are the narrow end bevels.
	var step := PI / VOUSSOIRS
	var centre := Vector3(0, SPRING, 0)
	var joint := Vector3(0.012, 0.025, 0.025)
	for i in VOUSSOIRS:
		if i == VOUSSOIRS / 2:
			continue
		var length := R_MID * step
		Lib.rounded_box(ivory, Vector3(R_MID * step * (i + 0.5), 0, 0), Vector3(length, ARCH_T, ARCH_D), joint, 1, Vector3i(3, 1, 1), Lib.xf_bend(R_MID, centre))
	# Keystone: tapered to the radial joints, a little proud of the arch on
	# every side, carrying the cap slab.
	var y_bot := R_MID - ARCH_T * 0.5 - 0.02
	var y_top := SLAB_Y - SPRING + 0.004
	var y_ref := (y_bot + y_top) * 0.5
	var half := y_ref * tan(step * 0.5)
	Lib.rounded_box(jade, Vector3(0, y_ref, 0), Vector3(half * 2.0, y_top - y_bot, ARCH_D + 0.04), joint, 1, Vector3i.ONE, Lib.xf_taper(y_ref, centre))
	# Cap slab.
	Lib.rounded_box(ivory, Vector3(0, SLAB_Y + 0.05, 0), Vector3(2.0, 0.1, 0.5), Vector3.ONE * 0.025, 1, Vector3i.ONE, none)
	# Finial: collar, onion dome and spike, 0.3 tall.
	var finial := Lib.profile([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.075, 0.0, 0.0),
		Vector3(0.075, 0.022, 0.008),
		Vector3(0.036, 0.03, 0.01),
		Vector3(0.04, 0.045, -1.0),
		Vector3(0.06, 0.06, -1.0),
		Vector3(0.075, 0.08, -1.0),
		Vector3(0.082, 0.10, -1.0),
		Vector3(0.080, 0.12, -1.0),
		Vector3(0.069, 0.14, -1.0),
		Vector3(0.051, 0.16, -1.0),
		Vector3(0.031, 0.18, -1.0),
		Vector3(0.018, 0.20, -1.0),
		Vector3(0.010, 0.225, -1.0),
		Vector3(0.005, 0.26, -1.0),
		Vector3(0.0, 0.30, 0.0),
	], 2)
	Lib.lathe(metal, finial, 16, Lib.xf_offset(Vector3(0, SLAB_Y + 0.1 - 0.002, 0)))
	var node := MeshInstance3D.new()
	node.name = "ShrineGateMesh"
	node.mesh = Lib.commit([ivory, jade, metal], "shrine_gate")
	var root := Node3D.new()
	root.name = "ShrineGate"
	root.add_child(node)
	return root

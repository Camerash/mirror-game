"""Shrine gate generator (asset A). Run: python gate.py -- --out /abs/shrine_gate.glb"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as c  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = c.out_arg(os.path.join(HERE, 'out', 'shrine_gate.glb'))

# Spec dimensions (units = game blocks; Blender Z up, Y = depth, -Y = front).
COL_X = 0.85
STEP_TOP = 0.40
SPRING = 2.20           # springing height = abacus top
ARCH_RI, ARCH_RO = 0.76, 0.94
ARCH_DEPTH = 0.36
SLAB_BOTTOM = SPRING + ARCH_RO + 0.005
SLAB_H = 0.10
SINK = 0.005            # parts sink this far into their support: no coplanar faces

c.reset()
ivory = c.material('IvoryGlaze', '#efe6d8', 0.35)
jade = c.material('Jade', '#5f8f78', 0.30)
metal = c.material('WarmMetal', '#c9a36a', 0.35, metallic=1.0)
root = c.root_empty('ShrineGateParts')
uv_targets = []

# Plinth: two steps, and a thin jade band proud of the upper step's sides.
uv_targets.append(c.box('StepLower', (3.0, 2.0, 0.2), (0, 0, 0.1), ivory, 0.03, 3, root))
uv_targets.append(c.box('StepUpper', (2.6, 1.6, 0.2 + SINK), (0, 0, 0.3 - SINK / 2), ivory, 0.03, 3, root))
uv_targets.append(c.box('StepBand', (2.6 + 0.03, 1.6 + 0.03, 0.06), (0, 0, 0.30), jade, 0.02, 3, root))


def bezier(p0, p1, p2, n):
    pts = []
    for i in range(1, n + 1):
        t = i / n
        pts.append(tuple((1 - t) ** 2 * a + 2 * (1 - t) * t * b + t * t * d for a, b, d in zip(p0, p1, p2)))
    return pts


# Column profile (r, z): plinth disc + torus base, shaft, astragal, neck, echinus.
column_profile = [
    (0.0, STEP_TOP - SINK), (0.22, STEP_TOP - SINK), (0.22, 0.425), (0.217, 0.436), (0.208, 0.443), (0.198, 0.446),
    (0.199, 0.456), (0.204, 0.467), (0.204, 0.479), (0.198, 0.489), (0.186, 0.496), (0.172, 0.500),
    (0.164, 0.507), (0.160, 0.520),
    (0.160, 1.975), (0.167, 1.979), (0.171, 1.990), (0.167, 2.001), (0.160, 2.005),
    (0.160, 2.040),
] + bezier((0.160, 2.040), (0.192, 2.070), (0.188, 2.125), 5) + [(0.0, 2.125)]

for side, x in (('L', -COL_X), ('R', COL_X)):
    c.lathe(f'Column{side}', column_profile, 24, ivory, location=(x, 0, 0), parent=root)
    uv_targets.append(c.box(f'Abacus{side}', (0.42, 0.42, 0.08), (x, 0, SPRING - 0.04), ivory, 0.02, 2, root))

# Arch: voussoirs as bevelled prisms (the bevels read as joints), jade keystone.
KEY_HALF = math.radians(6.5)
n_side = 5
step = (math.pi / 2 - KEY_HALF) / n_side


def ring_point(r, a):
    return (r * math.cos(a), SPRING + r * math.sin(a))


def voussoir(a0, a1, arc_steps=3):
    """Intrados and extrados polylines (same order); springing stones sink into the abacus."""
    def sunk(points):
        return [(x, z - SINK if abs(z - SPRING) < 1e-9 else z) for x, z in points]
    inner = [ring_point(ARCH_RI, a0 + (a1 - a0) * i / arc_steps) for i in range(arc_steps + 1)]
    outer = [ring_point(ARCH_RO, a0 + (a1 - a0) * i / arc_steps) for i in range(arc_steps + 1)]
    return sunk(inner), sunk(outer)


index = 0
for k in range(n_side):
    for a0, a1 in ((k * step, (k + 1) * step), (math.pi - (k + 1) * step, math.pi - k * step)):
        index += 1
        uv_targets.append(c.prism_strip(f'Voussoir{index:02d}', *voussoir(a0, a1), -ARCH_DEPTH / 2, ARCH_DEPTH / 2, ivory, 0.02, 2, root))

key_in = ARCH_RI - 0.03
key_top = SLAB_BOTTOM + SINK
key_inner = [ring_point(key_in, math.pi / 2 - KEY_HALF + KEY_HALF * i) for i in range(3)]
key_outer = [((key_top - SPRING) / math.tan(a), key_top) for a in (math.pi / 2 - KEY_HALF, math.pi / 2 + KEY_HALF)]
key_outer.insert(1, (0.0, key_top))  # flat top, embedded in the cap slab
uv_targets.append(c.prism_strip('Keystone', key_inner, key_outer, -ARCH_DEPTH / 2 - 0.025, ARCH_DEPTH / 2 + 0.025, jade, 0.02, 2, root))

# Cap slab over the crown and the warm-metal onion finial.
uv_targets.append(c.box('CapSlab', (2.0, 0.5, SLAB_H), (0, 0, SLAB_BOTTOM + SLAB_H / 2), ivory, 0.03, 3, root))
top = SLAB_BOTTOM + SLAB_H
finial_profile = [(r, top - SINK + z) for r, z in [
    (0.0, 0.0), (0.062, 0.0), (0.066, 0.008), (0.064, 0.018), (0.055, 0.024), (0.035, 0.028), (0.028, 0.038),
    (0.035, 0.050), (0.055, 0.065), (0.075, 0.085), (0.086, 0.110), (0.084, 0.135), (0.072, 0.160),
    (0.052, 0.180), (0.030, 0.200), (0.016, 0.220), (0.010, 0.240), (0.006, 0.270), (0.0, 0.305)]]
c.lathe('Finial', finial_profile, 20, metal, parent=root)

for obj in uv_targets:
    c.smart_uv(obj)

c.report('gate')
c.export(OUT, os.path.splitext(OUT)[0] + '.blend', join_name='ShrineGate')

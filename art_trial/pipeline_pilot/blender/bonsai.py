"""Bonsai-in-a-pot generator (asset B). Run: python bonsai.py -- --out /abs/bonsai.glb"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as c  # noqa: E402
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = c.out_arg(os.path.join(HERE, 'out', 'bonsai.glb'))

c.reset()
celadon = c.material('CeladonGlaze', '#94b8ad', 0.35)
moss = c.material('Moss', '#5a6b3c', 0.95)
bark = c.material('Bark', '#6b5040', 0.80)
greens = [c.material('FoliageA', '#6f9a5a', 0.85), c.material('FoliageB', '#7ba564', 0.85),
          c.material('FoliageC', '#648f52', 0.85)]
root = c.root_empty('BonsaiParts')

# Pot: shallow round celadon pot with a foot ring and a rolled rim (lathe).
pot_profile = [
    (0.0, 0.012), (0.180, 0.012), (0.186, 0.004), (0.194, 0.0), (0.214, 0.0), (0.221, 0.006), (0.223, 0.022),
    (0.221, 0.040), (0.228, 0.046), (0.252, 0.052), (0.266, 0.060), (0.273, 0.072),
    (0.278, 0.110), (0.283, 0.150), (0.287, 0.190),
    (0.292, 0.200), (0.300, 0.206), (0.305, 0.215), (0.305, 0.232), (0.300, 0.243), (0.291, 0.249),
    (0.276, 0.250), (0.263, 0.248), (0.256, 0.242), (0.252, 0.225), (0.250, 0.205), (0.0, 0.205)]
c.lathe('Pot', pot_profile, 32, celadon, parent=root)

# Moss mound filling the pot, sunk into the inner wall.
soil_profile = [(0.0, 0.246), (0.03, 0.2457), (0.06, 0.2448), (0.09, 0.2432), (0.12, 0.2410), (0.15, 0.2385),
                (0.18, 0.2353), (0.21, 0.2312), (0.235, 0.226), (0.248, 0.220), (0.256, 0.214),
                (0.256, 0.200), (0.0, 0.200)]
moss_obj = c.lathe('Moss', soil_profile, 32, moss, parent=root)
noise = bpy.data.textures.new('MossNoise', 'CLOUDS')
noise.noise_scale = 0.035
displace = moss_obj.modifiers.new('Lumps', 'DISPLACE')
displace.texture = noise
displace.texture_coords = 'GLOBAL'
displace.direction = 'Z'
displace.strength = 0.012
moss_obj.modifiers.move(2, 1)  # displace before the weighted normals

# Trunk skeleton for the Skin modifier, as chains of (position, radius).
# Skin's hulls at branch nodes broke (open / overlapping faces) wherever a segment next to a
# hull was shorter than the node radius, so: the only hull is the root flare at the trunk base
# (segments there >= its radius), and branches are separate islands that start on the trunk
# axis, their start caps buried inside the trunk.
TRUNK = [
    ((-0.04, 0.00, 0.215), 0.075), ((-0.03, 0.00, 0.29), 0.058), ((0.00, 0.005, 0.33), 0.054),
    ((0.02, 0.01, 0.37), 0.051), ((0.05, 0.005, 0.41), 0.048), ((0.06, 0.00, 0.45), 0.045),
    ((0.05, -0.005, 0.49), 0.042), ((0.03, -0.01, 0.53), 0.039), ((0.00, -0.005, 0.565), 0.036),
    ((-0.03, 0.00, 0.60), 0.033), ((-0.04, 0.005, 0.635), 0.030), ((-0.04, 0.01, 0.67), 0.027),
    ((-0.025, 0.005, 0.71), 0.024), ((-0.01, 0.00, 0.75), 0.021), ((0.00, 0.00, 0.80), 0.017),
    ((0.01, 0.00, 0.86), 0.013)]
ROOTS = [  # attached to the trunk base, spreading over the moss
    [((0.07, 0.03, 0.226), 0.028), ((0.14, 0.055, 0.220), 0.011)],
    [((-0.13, 0.04, 0.224), 0.026), ((-0.20, 0.065, 0.216), 0.010)],
    [((-0.06, -0.11, 0.224), 0.022), ((-0.08, -0.17, 0.216), 0.009)],
    [((0.03, 0.11, 0.226), 0.020)]]
BRANCHES = [  # low right (longest), back, mid left, upper right
    [((0.06, 0.00, 0.45), 0.026), ((0.14, 0.02, 0.47), 0.024), ((0.21, 0.03, 0.475), 0.018), ((0.27, 0.04, 0.47), 0.013)],
    [((0.03, -0.01, 0.53), 0.022), ((0.02, 0.10, 0.575), 0.019), ((0.00, 0.17, 0.60), 0.013)],
    [((-0.03, 0.00, 0.60), 0.023), ((-0.11, -0.02, 0.625), 0.021), ((-0.18, -0.03, 0.63), 0.015), ((-0.225, -0.03, 0.64), 0.011)],
    [((-0.04, 0.01, 0.67), 0.019), ((0.06, 0.00, 0.715), 0.017), ((0.13, -0.01, 0.74), 0.012)]]
nodes, edges, island_roots = [], [], []


def add_chain(points, attach=None):
    start = len(nodes)
    nodes.extend(points)
    edges.extend((i, i + 1) for i in range(start, len(nodes) - 1))
    if attach is None:
        island_roots.append(start)
    else:
        edges.append((attach, start))
    return start


base = add_chain(TRUNK)
for chain in ROOTS:
    add_chain(chain, attach=base)
for chain in BRANCHES:
    add_chain(chain)
mesh = bpy.data.meshes.new('Trunk')
mesh.from_pydata([p for p, _ in nodes], edges, [])
trunk = bpy.data.objects.new('Trunk', mesh)
bpy.context.scene.collection.objects.link(trunk)
trunk.parent = root
mesh.materials.append(bark)
skin = trunk.modifiers.new('Skin', 'SKIN')
skin.use_smooth_shade = True
skin.branch_smoothing = 0.5
for vert, (_, radius) in zip(mesh.skin_vertices[0].data, nodes):
    vert.radius = (radius, radius)
for index in island_roots:
    mesh.skin_vertices[0].data[index].use_root = True
sub = trunk.modifiers.new('Subdivision', 'SUBSURF')
sub.levels = sub.render_levels = 2
dec = trunk.modifiers.new('Decimate', 'DECIMATE')
dec.ratio = 0.32  # 0.25 left faint sliver streaks on the trunk

# Foliage pads: seeded ellipsoid lumps per pad, merged by voxel remesh.
pads = [  # centre, (rx, ry, rz) of the main body, material index, seed; sizes shrink toward the apex
    ((0.27, 0.04, 0.505), (0.145, 0.125, 0.050), 0, 1),
    ((-0.225, -0.03, 0.670), (0.120, 0.100, 0.045), 1, 2),
    ((0.00, 0.17, 0.640), (0.105, 0.090, 0.045), 2, 3),
    ((0.13, -0.01, 0.775), (0.100, 0.090, 0.042), 0, 4),
    ((0.01, 0.00, 0.905), (0.085, 0.080, 0.050), 1, 5),
]


def ellipsoid(bm, centre, radii):
    geom = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    for v in geom['verts']:
        v.co = Vector((v.co.x * radii[0] + centre[0], v.co.y * radii[1] + centre[1], v.co.z * radii[2] + centre[2]))


for i, (centre, radii, mat_index, seed) in enumerate(pads):
    rng = random.Random(seed)
    bm = bmesh.new()
    ellipsoid(bm, centre, radii)
    for k in range(7):  # ring of lumps around the rim
        a = 2 * math.pi * k / 7 + rng.uniform(-0.3, 0.3)
        d = rng.uniform(0.45, 0.75)
        r = rng.uniform(0.40, 0.55) * radii[0]
        lump = (centre[0] + math.cos(a) * radii[0] * d, centre[1] + math.sin(a) * radii[1] * d,
                centre[2] + radii[2] * rng.uniform(0.35, 0.8))
        ellipsoid(bm, lump, (r, r, r * 0.75))
    for k in range(3):  # crown lumps
        a = 2 * math.pi * k / 3 + rng.uniform(-0.5, 0.5)
        d = rng.uniform(0.0, 0.35)
        r = rng.uniform(0.35, 0.5) * radii[0]
        lump = (centre[0] + math.cos(a) * radii[0] * d, centre[1] + math.sin(a) * radii[1] * d,
                centre[2] + radii[2] * rng.uniform(0.7, 1.1))
        ellipsoid(bm, lump, (r, r, r * 0.7))
    pad = c.link(f'Pad{i + 1}', bm, greens[mat_index], root)
    rem = pad.modifiers.new('Remesh', 'REMESH')
    rem.mode = 'VOXEL'
    rem.voxel_size = 0.012
    rem.use_smooth_shade = True
    smooth = pad.modifiers.new('Smooth', 'SMOOTH')
    smooth.factor = 0.5
    smooth.iterations = 4
    dec = pad.modifiers.new('Decimate', 'DECIMATE')
    dec.ratio = 0.25

c.report('bonsai')
c.export(OUT, os.path.splitext(OUT)[0] + '.blend', join_name='Bonsai')

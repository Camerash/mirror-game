"""First creation of the girl's shape blockout (run once).

    blender -b --factory-startup --python art_sources/girl/build_blockout.py

Writes art_sources/girl/girl.blend. That .blend is the editable source from
then on: corrections are edits to it, not reruns of this script.

Conventions: Blender units, +Z up, feet at the origin, front faces -Y, her
own left hand is +X. She is 0.8 units tall (the game's capsule height), so
the game can load her at scale 1.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).resolve().parent / 'girl.blend'
TAU = math.tau

# Flat colours sampled from docs/art/her/beanie_b.jpg (sRGB 0-255).
COLOURS = {
    'Skin': (236, 205, 190), 'Eye': (38, 32, 32), 'Hair': (56, 46, 45),
    'Beanie': (233, 223, 208), 'Coat': (148, 167, 178), 'Tights': (128, 131, 137),
    'Boots': (60, 66, 74), 'Mitten': (152, 62, 38), 'Toggle': (176, 140, 100),
    'Loop': (78, 80, 85),
}


def linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    rgb = [linear(v) for v in COLOURS[name]]
    mat.diffuse_color = (*rgb, 1.0)
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*rgb, 1.0)
    bsdf.inputs['Roughness'].default_value = 0.85
    bsdf.inputs['Specular IOR Level'].default_value = 0.25
    return mat


def make_object(name, bm, mat, smooth=True):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
    mesh.materials.append(material(mat))
    obj = bpy.data.objects.new(name, mesh)
    COLLECTION.objects.link(obj)
    return obj


def ring(z, rx, ry_front, ry_back=None, n=32, p=2.0, cx=0.0, cy=0.0, wobble=None):
    """A superellipse ring, counter-clockwise seen from above, starting at -Y."""
    ry_back = ry_front if ry_back is None else ry_back
    pts = []
    for i in range(n):
        t = -math.pi / 2 + TAU * i / n
        c, s = math.cos(t), math.sin(t)
        x = rx * math.copysign(abs(c) ** (2 / p), c)
        y = (ry_front if s < 0 else ry_back) * math.copysign(abs(s) ** (2 / p), s)
        k = 1.0 + (wobble(t) if wobble else 0.0)
        pts.append(Vector((cx + x * k, cy + y * k, z)))
    return pts


def loft(rings, cap_bottom=False, cap_top=False, skip=None):
    """Quads between consecutive rings (listed bottom to top), optional fan caps."""
    bm = bmesh.new()
    rows = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    for j in range(len(rows) - 1):
        a, b = rows[j], rows[j + 1]
        for i in range(n):
            if skip and skip(j, i):
                continue
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    caps = ([(rows[0], rings[1], True)] if cap_bottom else []) + \
           ([(rows[-1], rings[-2], False)] if cap_top else [])
    for row, other, flip in caps:
        centre = sum((v.co for v in row), Vector()) / n
        centre.z += 0.35 * (row[0].co.z - other[0].z)   # a slight dome
        c = bm.verts.new(centre)
        for i in range(n):
            vs = (row[(i + 1) % n], row[i], c) if flip else (row[i], row[(i + 1) % n], c)
            bm.faces.new(vs)
    return bm


def tube(points, radii, n=16, up=Vector((0, 0, 1)), cap_bottom=False, cap_top=False):
    """Loft round rings along a polyline (listed bottom to top)."""
    rings = []
    overall = points[-1] - points[0]
    for k, (p, r) in enumerate(zip(points, radii)):
        d = (points[min(k + 1, len(points) - 1)] - points[max(k - 1, 0)]).normalized()
        if d.dot(overall) < 0:      # an inward-turned lip doubles back
            d = -d
        e1 = Vector((0, -1, 0))
        e1 = (e1 - d * e1.dot(d)).normalized()
        e2 = d.cross(e1)
        rings.append([p + r * (math.cos(TAU * i / n) * e1 + math.sin(TAU * i / n) * e2)
                      for i in range(n)])
    bm = loft(rings, cap_bottom, cap_top)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def quad_sphere(shape, res=6):
    """All-quad sphere: a subdivided cube projected to the unit sphere, then shaped."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=res - 1, use_grid_fill=True)
    for v in bm.verts:
        v.co = shape(v.co.normalized())
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def ellipsoid(centre, rx, ry, rz, res=6, frame=None):
    a, b, c = frame or (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    return quad_sphere(lambda u: centre + a * u.x * rx + b * u.y * ry + c * u.z * rz, res)


def join(bms):
    out = bmesh.new()
    for bm in bms:
        mesh = bpy.data.meshes.new('tmp')
        bm.to_mesh(mesh)
        bm.free()
        out.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    return out


# --------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
COLLECTION = bpy.data.collections.new('Girl')
scene.collection.children.link(COLLECTION)

# Key heights (units). Three heads tall: chin 0.505, pompom top 0.800.
HEAD_C = Vector((0.0, 0.0, 0.603))
HEAD_R = (0.100, 0.098, 0.100)
FRINGE_Z = 0.607
EYE_Z = 0.583
BRIM_Z = 0.618

# Head and neck --------------------------------------------------------------
def head_shape(u):
    # Soft child cheeks: the lower face is a little fuller.
    cheek = 1.0 + 0.04 * max(0.0, math.sin(math.pi * min(1.0, max(0.0, -u.z))))
    return HEAD_C + Vector((u.x * HEAD_R[0] * cheek, u.y * HEAD_R[1] * cheek, u.z * HEAD_R[2]))

head = quad_sphere(head_shape, res=8)
neck = tube([Vector((0, 0.006, 0.455)), Vector((0, 0.006, 0.53))], [0.03, 0.03], n=12)
make_object('Head', join([head, neck]), 'Skin')

# Hair: a bob shell with a straight fringe ---------------------------------
HAIR_RINGS = [  # z, scale of the horizontal radii
    (0.502, 0.94), (0.508, 0.985), (0.522, 1.0), (0.55, 1.0), (0.58, 1.0),
    (FRINGE_Z, 1.0), (0.627, 0.99), (0.647, 0.965), (0.667, 0.92),
    (0.684, 0.85), (0.698, 0.74), (0.708, 0.58), (0.714, 0.36)]
hair_rings = [ring(z, 0.120 * s, 0.110 * s, 0.122 * s, n=40, p=2.1, cy=0.006)
              for z, s in HAIR_RINGS]
FACE_HALF_ANGLE = math.radians(43)


def face_hole(j, i):
    """Open the face below the fringe (columns centred on -Y)."""
    if HAIR_RINGS[j + 1][0] > FRINGE_Z + 1e-6:
        return False
    mid = TAU * (i + 0.5) / 40
    ang = min(mid, TAU - mid)  # angle from -Y
    return ang < FACE_HALF_ANGLE

hair = loft(hair_rings, cap_top=True, skip=face_hole)
hair_obj = make_object('Hair', hair, 'Hair')
solid = hair_obj.modifiers.new('Thickness', 'SOLIDIFY')
solid.thickness = 0.009
solid.offset = -1.0
solid.use_even_offset = True

# Beanie: folded, ribbed brim and a round crown ---------------------------
def ribs(t):
    return 0.018 * math.cos(24 * t)

BEANIE = [  # z, rx, ry, ribbed
    (BRIM_Z + 0.006, 0.120, 0.116, False),   # inner lip, tucked under
    (BRIM_Z, 0.129, 0.125, True), (BRIM_Z + 0.012, 0.134, 0.130, True),
    (BRIM_Z + 0.040, 0.135, 0.131, True), (BRIM_Z + 0.062, 0.132, 0.128, True),
    (BRIM_Z + 0.070, 0.125, 0.121, False),   # top of the fold
    (BRIM_Z + 0.074, 0.122, 0.118, False), (BRIM_Z + 0.094, 0.120, 0.116, False),
    (BRIM_Z + 0.110, 0.112, 0.108, False), (BRIM_Z + 0.122, 0.096, 0.093, False),
    (BRIM_Z + 0.130, 0.072, 0.070, False), (BRIM_Z + 0.134, 0.040, 0.039, False)]
beanie_rings = [ring(z, rx, ry, ry + 0.004, n=48, cy=0.004, wobble=ribs if rb else None)
                for z, rx, ry, rb in BEANIE]
make_object('Beanie', loft(beanie_rings, cap_bottom=True, cap_top=True), 'Beanie')

POM_R = 0.034
pom_c = Vector((0.0, 0.004, 0.800 - POM_R))
make_object('Pompom', quad_sphere(
    lambda u: pom_c + u * POM_R * (1.0 + 0.05 * math.sin(5 * u.x + 3 * u.y) * math.cos(4 * u.z)),
    res=5), 'Beanie')

# Eyes: two small dark dots on the face -----------------------------------
head_obj = bpy.data.objects['Head']
bvh = BVHTree.FromObject(head_obj, bpy.context.evaluated_depsgraph_get())
eyes = []
for side in (-1, 1):
    hit, normal, _, _ = bvh.ray_cast(Vector((side * 0.034, -1.0, EYE_Z)), Vector((0, 1, 0)))
    n = normal.normalized()
    up = Vector((0, 0, 1))
    right = up.cross(n).normalized()
    up = n.cross(right)
    eyes.append(ellipsoid(hit + n * 0.0015, 0.0078, 0.0095, 0.004, res=3,
                          frame=(right, up, n)))
make_object('Eyes', join(eyes), 'Eye')

# Coat: a solid A-line duffle, slightly too big ---------------------------
COAT = [  # z, rx, ry front, ry back
    (0.192, 0.106, 0.078, 0.073),   # inner turn of the hem
    (0.176, 0.114, 0.084, 0.079), (0.180, 0.120, 0.090, 0.084),
    (0.205, 0.117, 0.088, 0.081), (0.25, 0.109, 0.083, 0.076),
    (0.30, 0.101, 0.078, 0.071), (0.35, 0.096, 0.074, 0.068),
    (0.40, 0.094, 0.072, 0.069), (0.435, 0.094, 0.070, 0.070),
    (0.458, 0.090, 0.066, 0.068), (0.476, 0.078, 0.060, 0.063),
    (0.492, 0.058, 0.050, 0.054), (0.505, 0.042, 0.040, 0.044)]
coat_rings = [ring(z, rx, ryf, ryb, n=32, p=2.3, cy=0.004) for z, rx, ryf, ryb in COAT]
make_object('Coat', loft(coat_rings, cap_bottom=True), 'Coat')

# Hood lying on the back, and its rim around the neck ----------------------
rim = []
for i in range(24):
    t = -math.pi / 2 + TAU * i / 24
    back = max(0.0, math.sin(t))            # the rim is fuller at the back
    centre = Vector((0.052 * math.cos(t), 0.004 + 0.050 * math.sin(t), 0.494 - 0.006 * back))
    rim.append((centre, 0.011 + 0.006 * back))
bm_rim = bmesh.new()
rows = []
for centre, r in rim:
    outward = Vector((centre.x, centre.y - 0.004, 0)).normalized()
    rows.append([bm_rim.verts.new(centre + r * (math.cos(TAU * k / 10) * outward
                                                + math.sin(TAU * k / 10) * Vector((0, 0, 1))))
                 for k in range(10)])
for i in range(24):
    a, b = rows[i], rows[(i + 1) % 24]
    for k in range(10):
        bm_rim.faces.new((a[k], a[(k + 1) % 10], b[(k + 1) % 10], b[k]))
bmesh.ops.recalc_face_normals(bm_rim, faces=bm_rim.faces)

tilt = math.radians(18)    # the pouch leans back, its bottom against the coat
fa = Vector((1, 0, 0))
fb = Vector((0, math.cos(tilt), -math.sin(tilt)))
fc = Vector((0, math.sin(tilt), math.cos(tilt)))


def hood_shape(u):
    # A soft pouch: flatter where it lies on the back, rounder outside, with
    # the point of the hood dropping at the bottom centre.
    depth = 0.024 if u.y < 0 else 0.036
    drop = 0.012 * max(0.0, -u.z) ** 2 * (1 - abs(u.x))
    return (Vector((0.0, 0.080, 0.432)) + fa * u.x * 0.080 * (1 - 0.18 * max(0.0, -u.z))
            + fb * u.y * depth + fc * (u.z * 0.062 - drop))

make_object('Hood', join([bm_rim, quad_sphere(hood_shape, res=7)]), 'Coat')

# Sleeves, hand and mitten -------------------------------------------------
def arm(side):
    shoulder = Vector((side * 0.066, 0.004, 0.462))
    wrist = Vector((side * 0.130, -0.006, 0.262))
    elbow = shoulder.lerp(wrist, 0.5) + Vector((0, -0.006, 0))
    return shoulder, elbow, wrist

for side, label in ((-1, 'R'), (1, 'L')):
    shoulder, elbow, wrist = arm(side)
    d = (wrist - elbow).normalized()
    pts = [shoulder.lerp(elbow, t) for t in (0.0, 0.25, 0.6)] + \
          [elbow, elbow.lerp(wrist, 0.5), wrist, wrist - d * 0.010]
    radii = [0.030, 0.033, 0.033, 0.033, 0.035, 0.037, 0.027]
    # Listed top to bottom; tube() orders by recalculated normals.
    make_object('Sleeve.' + label, tube(pts[::-1], radii[::-1], n=16, cap_bottom=True), 'Coat')

    # Hand frame: a = down the arm, b = forward (-Y), c = across.
    a = d
    b = Vector((0, -1, 0))
    b = (b - a * b.dot(a)).normalized()
    c = a.cross(b)
    mitten = label == 'L'           # her own left is +X
    scale = 1.18 if mitten else 1.0
    palm_c = wrist + a * 0.022 * scale
    palm = ellipsoid(palm_c, 0.012 * scale, 0.018 * scale, 0.026 * scale, res=5,
                     frame=(c, b, a))
    thumb_c = wrist + a * 0.014 * scale + b * 0.015 * scale - c * side * 0.003
    tb = (a * 0.6 + b * 0.8).normalized()
    tc = a.cross(tb).normalized() if a.cross(tb).length > 1e-6 else c
    thumb = ellipsoid(thumb_c, 0.0075 * scale, 0.008 * scale, 0.013 * scale, res=3,
                      frame=(tc, tb.cross(tc).normalized(), tb))
    parts = [palm, thumb]
    if mitten:
        parts.append(tube([wrist + a * 0.004, wrist - a * 0.014], [0.021, 0.022], n=16,
                          cap_bottom=True, cap_top=True))
    else:
        parts.append(tube([wrist + a * 0.004, wrist - a * 0.014], [0.011, 0.011], n=10))
    make_object(('Mitten.' if mitten else 'Hand.') + label, join(parts),
                'Mitten' if mitten else 'Skin')

# Legs and boots ----------------------------------------------------------
for side, label in ((-1, 'R'), (1, 'L')):
    x = side * 0.037
    leg = tube([Vector((x, 0.004, 0.055)), Vector((x, 0.004, 0.13)),
                Vector((x * 1.05, 0.004, 0.25))], [0.018, 0.020, 0.024], n=14)
    make_object('Leg.' + label, leg, 'Tights')

    bx = side * 0.040
    BOOT = [  # z, rx, ry front, ry back, centre y
        (0.0, 0.026, 0.043, 0.024, -0.010), (0.006, 0.030, 0.049, 0.028, -0.011),
        (0.022, 0.031, 0.050, 0.029, -0.010), (0.038, 0.030, 0.038, 0.029, -0.004),
        (0.054, 0.028, 0.029, 0.028, 0.0), (0.072, 0.027, 0.027, 0.027, 0.002),
        (0.084, 0.027, 0.027, 0.027, 0.002), (0.087, 0.024, 0.024, 0.024, 0.002),
        (0.080, 0.021, 0.021, 0.021, 0.002)]   # inner lip of the shaft
    boot_rings = [ring(z, rx, ryf, ryb, n=20, p=2.2, cx=bx, cy=cy)
                  for z, rx, ryf, ryb, cy in BOOT]
    make_object('Boot.' + label, loft(boot_rings, cap_bottom=True, cap_top=True), 'Boots')

# Toggles and their loops on the coat front -------------------------------
coat_obj = bpy.data.objects['Coat']
bvh = BVHTree.FromObject(coat_obj, bpy.context.evaluated_depsgraph_get())
toggles, loops = [], []
for z, tilt_deg in ((0.428, 8), (0.366, -6), (0.300, 6)):
    hit, normal, _, _ = bvh.ray_cast(Vector((0.0, -1.0, z)), Vector((0, 1, 0)))
    n = normal.normalized()
    t = math.radians(tilt_deg)
    along = Vector((math.cos(t), 0, math.sin(t)))
    up = n.cross(along).normalized()
    toggles.append(ellipsoid(hit + n * 0.007, 0.019, 0.0058, 0.0058, res=3,
                             frame=(along, up, n)))
    for s in (-1, 1):
        h2, n2, _, _ = bvh.ray_cast(Vector((s * 0.024, -1.0, z + s * math.sin(t) * 0.024)),
                                    Vector((0, 1, 0)))
        loops.append(ellipsoid(h2 + n2 * 0.002, 0.011, 0.007, 0.0028, res=3,
                               frame=(along, up, n2.normalized())))
tog = make_object('Toggles', join(toggles + loops), 'Toggle')
tog.data.materials.append(material('Loop'))
n_toggle_faces = len(tog.data.polygons) // 3       # three toggles, then six loops
for poly in tog.data.polygons:
    poly.material_index = 0 if poly.index < n_toggle_faces else 1

# Root empty so the parts move together -----------------------------------
root = bpy.data.objects.new('Girl', None)
root.empty_display_type = 'PLAIN_AXES'
root.empty_display_size = 0.2
COLLECTION.objects.link(root)
for obj in COLLECTION.objects:
    if obj is not root:
        obj.parent = root

bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
print('### saved', OUT)

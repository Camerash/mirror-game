"""Build the cloak from its profile curves.

The shape lives in `cloak_profile.py` as tables measured once off the accepted
cloak. This file only turns those curves into a mesh, so there is no ray casting
at build time and nothing to correct afterwards. The generator it replaces spent
336 of its 921 lines undoing its own projection.

An opening is a gap in each row's own spread of columns, not a set of absent
cells. That one change removes the snapping, the tapering, the easing, the
squaring, the stitching and the relaxing: a row's columns are simply spread over
the cloth that row has, so its edges sit exactly on the opening's curve and its
cells are even by construction.

The cloth has no thickness. Its material must draw both sides, which
`TravellerDrawingBody` already does.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cloak_profile as profile

COLUMNS = 24
FRONT = profile.FRONT
# Heights above the border. Close together where a profile turns: the collar, the
# hood's throat, its rim and its crown.
ROWS = [0.50, 0.72, 0.95, 1.18, 1.40, 1.58, 1.70, 1.74, 1.80, 1.88, 1.96, 2.04,
        2.11, 2.145, 2.18, 2.26, 2.36, 2.48, 2.62, 2.76, 2.88, 2.97, 3.03,
        3.065, 3.09, 3.15, 3.21, 3.26]
HEM_LIFT = .002
# An opening this narrow is a tip, and the band across it is closed: that makes
# the point at the top of the front split and the top of the hood's face. Wider
# than this and the band stays open, which is what leaves the hood's throat.
TIP_BELOW = math.radians(12)

CLOTH_UV = (.625, .56)
TRIM_FOOT = .02                 # the border's atlas rows, dark to light to dark
TRIM_TOP = .105
DARK_UV = (.5, .02)             # the garment's one dark, which the brooch takes

CLASP_Z = 1.80
CLASP_RADIUS = .078
CLASP_RISE = .026
CLASP_WAIST = .55
CLASP_SIDES = 16
CLASP_BAND = (.12, .50)
ARMS_KEY = 'CloakArms'
ARMS_PUSH = .22
ARMS_SECTOR = (math.radians(40), math.radians(62))
ARMS_HEIGHTS = (1.55, 1.25)


def row_columns(z):
    """Where this row's columns sit, as angles.

    A closed row spreads them evenly round the whole ring. An open row spreads
    them over the cloth it has, so its first and last land exactly on the
    opening's edge and every cell between is the same width.
    """
    half = profile.opening_half(z)
    if half <= 0:
        return [FRONT + step * math.tau / COLUMNS for step in range(COLUMNS)], False
    span = math.tau - 2 * half
    return [FRONT + half + step * span / (COLUMNS - 1)
            for step in range(COLUMNS)], True


def place(z, angle, open_row, edge):
    """One vertex. An opening's own edge takes the rim's radius, which curls in
    on the hood and so is measured rather than read off the cloth beside it."""
    across = profile.edge_radius(z) if (open_row and edge) else profile.radius(z, angle)
    return Vector((across * math.cos(angle), across * math.sin(angle), z))


def build_grid():
    """Every row, from the border up to the crown."""
    grid, kinds = [], []
    # Both border rows share one spread of columns. Distributing each at its own
    # height gives them slightly different angles, and the band then runs
    # anywhere from 0.016 to 0.230 tall instead of an even 0.145.
    settle = sum(profile.HEM) / len(profile.HEM) + HEM_LIFT
    angles, open_row = row_columns(settle)
    for lift in (HEM_LIFT, profile.TRIM_HEIGHT):
        row = []
        for index, angle in enumerate(angles):
            z = profile.hem_at(angle) + lift
            row.append(place(z, angle, open_row, index in (0, COLUMNS - 1)))
        grid.append(row)
        kinds.append(open_row)
    for z in ROWS:
        angles, open_row = row_columns(z)
        grid.append([place(z, angle, open_row, index in (0, COLUMNS - 1))
                     for index, angle in enumerate(angles)])
        kinds.append(open_row)
    return grid, kinds


def trim_value(row, column):
    """The border's atlas row. Its colour runs across the band, not along it, so
    only v carries anything and u can stay put."""
    return (CLOTH_UV[0], TRIM_FOOT if row == 0 else TRIM_TOP)


def write(grid, kinds, name='CloakShell'):
    mesh = bpy.data.meshes.new(name)
    work = bmesh.new()
    verts = [[work.verts.new(point) for point in row] for row in grid]
    work.verts.index_update()
    uv_layer = work.loops.layers.uv.verify()
    faces, border = [], set()
    for r in range(len(grid) - 1):
        for c in range(COLUMNS - 1):
            face = work.faces.new([verts[r][c], verts[r][c + 1],
                                   verts[r + 1][c + 1], verts[r + 1][c]])
            faces.append(face)
            if r == 0:
                border.add(face)
        # The band across the front. Closed where both rows are shut, and where
        # an opening ends: one row shut and the next barely open is a tip, which
        # is the point at the top of the split and the top of the hood's face.
        # Both rows open is the opening itself, however narrow it is: the split
        # never exceeds 7 degrees, so judging by width alone sews it up.
        tips = [profile.opening_half(grid[n][0].z) for n in (r, r + 1)]
        shut = [half <= 0 for half in tips]
        if all(shut) or (any(shut) and max(tips) < TIP_BELOW):
            face = work.faces.new([verts[r][COLUMNS - 1], verts[r][0],
                                   verts[r + 1][0], verts[r + 1][COLUMNS - 1]])
            faces.append(face)
            if r == 0:
                border.add(face)
    faces += cap_crown(work, verts)
    for face in faces:
        face.smooth = True
        for loop in face.loops:
            loop[uv_layer].uv = CLOTH_UV
    for face in border:
        for loop in face.loops:
            row = 0 if loop.vert in verts[0] else 1
            loop[uv_layer].uv = (CLOTH_UV[0], TRIM_FOOT if row == 0 else TRIM_TOP)
    bmesh.ops.recalc_face_normals(work, faces=list(work.faces))
    work.to_mesh(mesh)
    work.free()
    return mesh


def cap_crown(work, verts):
    """Close the top of the hood with a fan onto its own crown."""
    ring = verts[-1]
    centre = sum((v.co for v in ring), Vector()) / len(ring)
    apex = work.verts.new(Vector((centre.x, centre.y, centre.z + CROWN_RISE)))
    return [work.faces.new([ring[c], ring[(c + 1) % COLUMNS], apex])
            for c in range(COLUMNS)]


CROWN_RISE = .045               # how far the crown stands above the last ring
CAST_RADIUS = 1.6               # outside the cloak, for seating the brooch


def rebuild(obj):
    """Replace the cloak mesh, keeping its keys, material and atlas."""
    captured = capture_keys(obj)
    grid, kinds = build_grid()
    mesh = write(grid, kinds)
    attach_clasp(mesh)
    mesh.materials.append(obj.data.materials[0])
    old = obj.data
    obj.data = mesh
    bpy.data.meshes.remove(old)
    count = apply_keys(obj, captured)
    widen = weld(obj)
    print('###   cloak: merged %d vertices by distance' % widen)
    return count + (1 if add_arms_key(obj) else 0)


def weld(obj, limit=.0008):
    """A standing check for doubles. Measured on the whole character, nothing is
    closer than this, so it should always report nothing."""
    work = bmesh.new()
    work.from_mesh(obj.data)
    before = len(work.verts)
    bmesh.ops.remove_doubles(work, verts=list(work.verts), dist=limit)
    removed = before - len(work.verts)
    if removed:
        work.to_mesh(obj.data)
    work.free()
    return removed


def capture_keys(obj):
    """Read the old keys before the mesh is replaced, because the swap frees them."""
    obj.data.calc_loop_triangles()
    blocks = obj.data.shape_keys.key_blocks
    basis = blocks[0]
    return {
        'triangles': [tuple(t.vertices) for t in obj.data.loop_triangles],
        'basis': [basis.data[i].co.copy() for i in range(len(basis.data))],
        'keys': [(b.name, [b.data[i].co.copy() for i in range(len(b.data))])
                 for b in blocks[1:]],
    }


def apply_keys(obj, captured):
    """Put every old key on the new mesh, by barycentric position."""
    triangles, points = captured['triangles'], captured['basis']
    tree = BVHTree.FromPolygons(points, triangles, all_triangles=True)
    # Bias the lookup toward the vertex's own side of the mesh. A vertex on the
    # edge of the front split is 0.008 from the far panel at the clasp, so an
    # unbiased lookup reads the wrong panel and the split moves as one piece.
    neighbourhood = [Vector() for _ in obj.data.vertices]
    counts = [0] * len(obj.data.vertices)
    for polygon in obj.data.polygons:
        centre = polygon.center
        for index in polygon.vertices:
            neighbourhood[index] += centre
            counts[index] += 1
    anchors = []
    for number, vertex in enumerate(obj.data.vertices):
        probe = vertex.co.copy()
        if counts[number]:
            toward = neighbourhood[number] / counts[number] - vertex.co
            if toward.length > 1e-9:
                probe = vertex.co + toward.normalized() * .030
        location, _, index, _ = tree.find_nearest(probe)
        if index is None:
            anchors.append(None)
            continue
        a, b, c = (points[i] for i in triangles[index])
        anchors.append((index, barycentric(location, a, b, c), vertex.co - location))
    obj.shape_key_add(name='Basis', from_mix=False).value = 0.0
    for name, moved in captured['keys']:
        key = obj.shape_key_add(name=name, from_mix=False)
        # A new key does not reliably start at zero. Left as it came, all seven
        # hood keys applied at once and threw the hood off the head.
        key.value = 0.0
        for index, anchor in enumerate(anchors):
            if anchor is None:
                continue
            triangle, (u, v, w), offset = anchor
            a, b, c = (moved[i] for i in triangles[triangle])
            key.data[index].co = a * u + b * v + c * w + offset
    return len(captured['keys'])


# `CloakOpen` is the resting look. The arms need more room than that, so a
# second key pushes the cloth out along its own surface normal, over the sector
# and the heights that a reaching arm passes through. The animation crossfades
# between the two keys.
#
# The movement has to be outward. The cape is fitted to the body with no margin,
# so a key that slides the cloth around the body (measured at swings from 25 to
# 95 degrees) drives it into the chest and the shoulders instead of opening it.
# The outward push costs nothing at rest: the body clearance stays at 0.
ARMS_KEY = 'CloakArms'
ARMS_PUSH = .22                 # how far the cloth stands off the arm's path
ARMS_SECTOR = (math.radians(40), math.radians(62))   # centre and half width
ARMS_HEIGHTS = (1.55, 1.25)                          # centre and half height


def raised_cosine(value, centre, half):
    """1.0 at the centre, 0.0 at the edge, smooth at both."""
    distance = abs(value - centre) / half
    return 0.0 if distance >= 1 else .5 * (1 + math.cos(math.pi * distance))


def add_arms_key(obj):
    """Stand the cloth off the arm's path, so a reaching arm comes through."""
    blocks = obj.data.shape_keys.key_blocks
    basis = blocks[0]
    normals = [v.normal.copy() for v in obj.data.vertices]
    key = obj.shape_key_add(name=ARMS_KEY, from_mix=False)
    key.value = 0.0
    centre, half = ARMS_SECTOR
    height, reach = ARMS_HEIGHTS
    for index in range(len(basis.data)):
        rest = basis.data[index].co
        angle = math.atan2(rest.y, rest.x)
        offset = abs((angle - FRONT + math.pi) % math.tau - math.pi)
        weight = (raised_cosine(offset, centre, half)
                  * raised_cosine(rest.z, height, reach))
        key.data[index].co = rest + normals[index] * (ARMS_PUSH * weight)
    return key


def barycentric(point, a, b, c):
    v0, v1, v2 = b - a, c - a, point - a
    d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
    d20, d21 = v2.dot(v0), v2.dot(v1)
    denominator = d00 * d11 - d01 * d01
    if abs(denominator) < 1e-12:
        return 1.0, 0.0, 0.0
    v = (d11 * d20 - d01 * d21) / denominator
    w = (d00 * d21 - d01 * d20) / denominator
    return 1.0 - v - w, v, w


def attach_clasp(mesh):
    """Add the brooch to a finished mesh, in its own pass.

    Returns the first index it used, so the split's widening can leave it alone.
    The brooch's lower half sits inside the split's own height range, and widened
    with it the brooch came out pulled sideways instead of round.
    """
    first = len(mesh.vertices)
    work = bmesh.new()
    work.from_mesh(mesh)
    add_clasp(work, work.loops.layers.uv.verify())
    work.to_mesh(mesh)
    work.free()
    return first


def add_clasp(work, uv_layer):
    """A brooch at the throat, holding the front opening shut.

    Built onto the new cape, not copied off the old one. The old cloak's own
    clasp is its collar yoke, a flat panel welded into that shell, and copying
    those triangles across fails at every offset: proud, their edges draw a hard
    V over the chest; flush, they cut through the cape.

    Its rim is cast onto the cape a point at a time, so it follows the curve
    instead of floating off it at the sides. It runs after the normals are
    recalculated and sets its own, because it is an open shell and the solver
    has no volume to work from.
    """
    tree = BVHTree.FromBMesh(work)

    def onto(z, angle):
        direction = Vector((-math.cos(angle), -math.sin(angle), 0))
        location, normal, _, _ = tree.ray_cast(
            Vector((0, 0, z)) - direction * CAST_RADIUS, direction, CAST_RADIUS)
        return location, normal

    seat, out = onto(CLASP_Z, FRONT)
    if seat is None:
        return []
    out = out.normalized()
    if out.dot(Vector((seat.x, seat.y, 0))) < 0:
        out = -out
    across = math.hypot(seat.x, seat.y)
    rim = []
    for step in range(CLASP_SIDES):
        turn = step * math.tau / CLASP_SIDES
        point, normal = onto(CLASP_Z + CLASP_RADIUS * math.sin(turn),
                             FRONT + CLASP_RADIUS * math.cos(turn) / across)
        if point is None:
            return []
        rim.append(work.verts.new(point + out * .0015))
    inner = [work.verts.new(seat + (v.co - seat) * CLASP_WAIST + out * (CLASP_RISE * .62))
             for v in rim]
    crown = work.verts.new(seat + out * CLASP_RISE)
    faces = []
    for step in range(CLASP_SIDES):
        following = (step + 1) % CLASP_SIDES
        faces.append(work.faces.new([rim[step], rim[following],
                                     inner[following], inner[step]]))
        faces.append(work.faces.new([inner[step], inner[following], crown]))
    for face in faces:
        face.smooth = True
        face.normal_update()
        if face.normal.dot(out) < 0:
            face.normal_flip()
        for loop in face.loops:
            loop[uv_layer].uv = DARK_UV
    return faces

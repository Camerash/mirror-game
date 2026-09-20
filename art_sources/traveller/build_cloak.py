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
# What an opening does to a row. SHUT is cloth all the way round. OPEN is a row
# the opening crosses. APEX is the height where it closes on a point, which is
# the top of the hood's face, the foot of that face at the brooch, and the top
# of the front seam.
SHUT, OPEN, APEX = 'shut', 'open', 'apex'

CLOTH_UV = (.625, .56)
TRIM_FOOT = .02                 # the border's atlas rows, dark to light to dark
TRIM_TOP = .105
DARK_UV = (.5, .02)             # the garment's one dark, which the brooch takes

CLASP_Z = 1.80
CLASP_RADIUS = .078
CLASP_RISE = .026
CLASP_WAIST = .55
CLASP_SIDES = 7                 # a gem, not a dome
CLASP_POINT = 3 * math.tau / 4  # with one corner straight down


def row_columns(half, kind):
    """Where this row's columns sit, as angles.

    A shut row spreads them evenly round the whole ring. A row an opening
    crosses spreads them over the cloth it has, so its first and last land
    exactly on the opening's edge and every cell between is the same width.

    An apex takes the same spread with nothing removed, so its first and last
    column land on the same angle. `write` then gives them one vertex, and the
    opening closes on a point. Treating an apex as a shut row instead leaves the
    columns 15 degrees apart there, so the opening bottoms out on a flat edge
    that is off centre by half a cell.
    """
    if kind is SHUT:
        return [FRONT + step * math.tau / COLUMNS for step in range(COLUMNS)]
    span = math.tau - 2 * half
    return [FRONT + half + step * span / (COLUMNS - 1) for step in range(COLUMNS)]


def place(z, angle, kind, edge):
    """One vertex. An opening's own edge takes the rim's radius, which curls in
    on the hood and so is measured rather than read off the cloth beside it."""
    across = (profile.edge_radius(z) if (kind is not SHUT and edge)
              else profile.radius(z, angle))
    return Vector((across * math.cos(angle), across * math.sin(angle), z))


def row_kinds(heights):
    """What each row is. A row with no opening is an apex when a row beside it
    has one, because that is where the opening closes."""
    halves = [profile.opening_half(z) for z in heights]
    kinds = []
    for index, half in enumerate(halves):
        beside = [halves[near] for near in (index - 1, index + 1)
                  if 0 <= near < len(halves)]
        kinds.append(OPEN if half > 0
                     else APEX if any(value > 0 for value in beside)
                     else SHUT)
    return halves, kinds


def build_grid():
    """Every row, from the border up to the crown."""
    # Both border rows share one spread of columns. Distributing each at its own
    # height gives them slightly different angles, and the band then runs
    # anywhere from 0.016 to 0.230 tall instead of an even 0.145.
    settle = sum(profile.HEM) / len(profile.HEM) + HEM_LIFT
    heights = [settle, settle] + list(ROWS)
    halves, kinds = row_kinds(heights)
    grid = []
    angles = row_columns(halves[0], kinds[0])
    for lift in (HEM_LIFT, profile.TRIM_HEIGHT):
        grid.append([place(profile.hem_at(angle) + lift, angle, kinds[0],
                           index in (0, COLUMNS - 1))
                     for index, angle in enumerate(angles)])
    for index, z in enumerate(ROWS, start=2):
        angles = row_columns(halves[index], kinds[index])
        grid.append([place(z, angle, kinds[index], column in (0, COLUMNS - 1))
                     for column, angle in enumerate(angles)])
    return grid, kinds


def trim_value(row, column):
    """The border's atlas row. Its colour runs across the band, not along it, so
    only v carries anything and u can stay put."""
    return (CLOTH_UV[0], TRIM_FOOT if row == 0 else TRIM_TOP)


def write(grid, kinds, name='CloakShell'):
    mesh = bpy.data.meshes.new(name)
    work = bmesh.new()
    verts = [[work.verts.new(point) for point in row] for row in grid]
    # An apex closes on one vertex: its first and last column sit on the same
    # angle, so they share a vertex and the cells around them meet in a fan.
    for row, kind in zip(verts, kinds):
        if kind is APEX:
            work.verts.remove(row[COLUMNS - 1])
            row[COLUMNS - 1] = row[0]
    work.verts.index_update()
    uv_layer = work.loops.layers.uv.verify()
    faces, border = [], set()

    def cell(*corners):
        """One face, with any repeated corner dropped. A cell against an apex
        has two corners on the shared vertex, and comes out as a triangle."""
        kept = []
        for corner in corners:
            if corner not in kept:
                kept.append(corner)
        return work.faces.new(kept) if len(kept) > 2 else None

    for r in range(len(grid) - 1):
        for c in range(COLUMNS - 1):
            face = cell(verts[r][c], verts[r][c + 1],
                        verts[r + 1][c + 1], verts[r + 1][c])
            if face is None:
                continue
            faces.append(face)
            if r == 0:
                border.add(face)
        # The band across the front: the cloth between the last column and the
        # first. An opening leaves it out, and an apex is inside the opening it
        # closes, so one open row either side is enough to leave it out. Where an
        # apex meets shut cloth the band comes out as the triangle that finishes
        # the point.
        if OPEN in (kinds[r], kinds[r + 1]):
            continue
        face = cell(verts[r][COLUMNS - 1], verts[r][0],
                    verts[r + 1][0], verts[r + 1][COLUMNS - 1])
        if face is None:
            continue
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
    set_open_key(obj)
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
OPEN_KEY = 'CloakOpen'
OPEN_SECTOR = math.radians(55)  # how far round the front the parting reaches
OPEN_TURN = math.radians(7.5)   # how far the seam's own edge swings, each side
# How much of that swing each height takes. Nothing above the seam's apex, most
# where the hands come out, and a little at the hem so the panels do not pinch.
OPEN_HEIGHTS = [(0.19, .35), (0.80, .60), (1.30, .95), (1.60, 1.0), (1.70, .85),
                (profile.SPLIT_APEX, 0.0)]
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


def set_open_key(obj):
    """Rewrite `CloakOpen` so it parts the seam instead of swinging the cloak.

    The inherited key opened the whole garment like a coat: both panels swung
    wide and the legs showed through from frame to frame. It came from a cloak
    whose front was a broad slit, and it makes no sense on one whose seam is a
    line.

    This parts the cloth around the body instead of pulling it off the body: each
    vertex turns about the up axis, away from the seam, by an amount that falls
    off with angle and follows a curve in height. The radius never changes, so
    the cloak stays fitted and only the seam opens.
    """
    blocks = obj.data.shape_keys.key_blocks
    if OPEN_KEY not in blocks:
        return 0
    basis, key = blocks[0], blocks[OPEN_KEY]
    moved = 0
    for index in range(len(basis.data)):
        rest = basis.data[index].co
        angle = math.atan2(rest.y, rest.x)
        offset = abs((angle - FRONT + math.pi) % math.tau - math.pi)
        share = raised_cosine(offset, 0.0, OPEN_SECTOR)
        height = profile.at(OPEN_HEIGHTS, rest.z) if rest.z < profile.SPLIT_APEX else 0.0
        turn = math.copysign(1, rest.x) * OPEN_TURN * share * height
        if abs(turn) < 1e-9:
            key.data[index].co = rest
            continue
        cos, sin = math.cos(turn), math.sin(turn)
        key.data[index].co = Vector((rest.x * cos - rest.y * sin,
                                     rest.x * sin + rest.y * cos, rest.z))
        moved += 1
    return moved


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
    """A seven sided gem at the throat, holding the front opening shut.

    Its corners start straight down, so the lone corner points at the seam and
    the flat top edge sits under the hood's own point. Its faces are flat, not
    smooth, because a gem is read by its facets and the rest of the character is
    smooth ceramic.

    Built onto the new cape, not copied off the old one. The old cloak's own
    clasp is its collar yoke, a flat panel welded into that shell, and copying
    those triangles across fails at every offset: proud, their edges draw a hard
    V over the chest; flush, they cut through the cape.

    Each corner is read off the cape's own profile, so the gem follows the curve
    instead of floating off it at the sides. It used to find the cape by ray
    instead, which stopped working when the seam came together: the lowest
    corner sits on the middle of the front, and its ray went straight down the
    pinch and out the other side, so the gem disappeared. The profile answers
    everywhere, including where there is no cloth to hit.

    It runs after the normals are recalculated and sets its own, because it is an
    open shell and the solver has no volume to work from.
    """
    def onto(z, angle):
        across = profile.radius(z, angle)
        return Vector((across * math.cos(angle), across * math.sin(angle), z))

    seat = onto(CLASP_Z, FRONT)
    out = Vector((seat.x, seat.y, 0)).normalized()
    across = math.hypot(seat.x, seat.y)
    rim = [work.verts.new(onto(CLASP_Z + CLASP_RADIUS * math.sin(turn),
                               FRONT + CLASP_RADIUS * math.cos(turn) / across)
                          + out * .0015)
           for turn in (CLASP_POINT + step * math.tau / CLASP_SIDES
                        for step in range(CLASP_SIDES))]
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
        face.smooth = False
        face.normal_update()
        if face.normal.dot(out) < 0:
            face.normal_flip()
        for loop in face.loops:
            loop[uv_layer].uv = DARK_UV
    return faces

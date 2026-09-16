"""Rebuild the Traveller body as one watertight, quad-dominant mesh.

The previous body was eight overlapping primitive shells: an 80-vertex torso
box with two arm tubes, a neck capsule, two ear capsules and two leg tubes
merely intersecting it. `GAME_DESIGN.md` already requires "deliberate connected
surfaces without overlapping primitive shells"; this builds that.

Column system: 20-column torso, 10-column limbs. 20 = 2 x 10, so every junction
is 1:1. Each limb hole is a 3-wide x 2-tall block of torso faces, whose boundary
is exactly 10 vertices.

The body is modelled in T-pose: the upper body and both arms are one clean
horizontal tube. The arm leaves the armhole along the hole's own normal, so
there is no corner to crease; the arms-down look is a rig pose.

The accepted hand and thumb are reused verbatim from the existing body. Its
folded cuff is not: that cuff turned back wider than the sleeve around it, so it
poked through and had to be squashed inwards to fit. The cuff is regenerated here
as a single-wall funnel instead, which cannot fold through itself.

Proportions come from `proportions.py`, not from literals here.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from body_shape import catmull_rom, even_samples, parallel_frames, ring
import proportions

COLUMNS = 20
LIMB_COLUMNS = 10
LEG_COLUMNS = 11               # ten hip columns plus the split chord's midpoint
# One atlas point per region. The inherited model interleaved cloth, trim and
# skin by height through the cuff, which is what made it read as bare wrist.
CLOTH_UV = (.375, .56)
TRIM_UV = (.625, .73)
HAND_UV = (.875, .56)
SKIN_UV = HAND_UV
PALETTE_UV = CLOTH_UV
CENTRE_Y = -.0135

# Measured from the accepted body: (z, radius x, radius y).
# Shoulder rows keep the accepted silhouette. Everything below the armhole is
# clamped against the arm tube at build time (see `torso_radius`), because the
# inherited torso was a barrel the arms passed straight through. All of it is
# under the cloak, so the clamp costs nothing visible and buys a clean mesh.
# Narrowed from the inherited barrel (rx .386/.361). The old torso was wider
# than the arms hanging beside it, so they could only ever intersect. It is
# entirely under the cloak, and the front split shows depth (ry), not width.
TORSO = ()                     # (radius x, radius y), set by `use_chart`
# A straight tube needs fewer rows than the old vase profile.
# The top three rows are spaced one sleeve radius apart, so the armhole is
# exactly as tall as the arm is thick and its top edge sits on the torso's top
# ring. The hole then matches the sleeve's cross-section and the bridge between
# them is short and flush, instead of stretching to twice the height.
TORSO_ROWS = [2.000, 1.878, 1.756, 1.630, 1.500, 1.370, 1.240, 1.170, 1.120]
# Depth only, over the last two rows. Splitting a ring .464 deep into legs .286
# across sheared the crotch into faces of aspect 5 that caught no light and read
# as a dark wedge. Width (rx) is untouched, so the front stays a straight tube.
CROTCH_TAPER = ((1.120, .64), (1.170, .85), (1.240, 1.00))   # ascending z
ARMHOLE_ROWS = (0, 2)          # the hole opens at the very top of the torso
ARMHOLE_COLUMNS = {'R': 18, 'L': 8}   # first of four vertex columns
# Legs sit entirely under the cloak (only the boots show), so they are drawn in
# to clear the hands that hang beside them.
LEG_KEYS = []                  # set by `use_chart`
LEG_ROWS = [1.07, 1.01, .93, .82, .70, .58, .45, .32]
# The tunic stops at the shoulder line, level with the top of the arm, and a
# short skin neck carries on into the head. Before this the cloth ran all the
# way to z 2.35, which read as a high blue collar with no neck at all.
# The shoulder curves into the neck along a quarter ellipse. A single chamfer
# ring left a 148-degree crease, and because it was built as a *circle* over an
# elliptical torso it also flared .033 proud at the front and back, which is the
# ledge that showed across the chest.
SHOULDER_RISE = .050               # how far the dome climbs above the torso top
SHOULDER_STEPS = (.30, .58, .80)   # fractions of the quarter turn, 20 columns each
COLLAR_RADIUS = .100               # where the cloth ends and the neck begins
# Head bottoms out at z 2.08 and only reaches radius .107 by 2.09, so a neck
# this narrow is hidden from there up and the rest of it is the visible neck.
NECK_ROWS = [(2.10, .098), (2.17, .090), (2.22, .070)]
SLEEVE_RINGS = 11
SLEEVE_RADIUS = ()             # set by `use_chart`
ELLIPSE = .82                  # measured ry/rx of the sleeve, constant
ARM_LENGTH = 0                 # set by `use_chart`; shoulder to fingertip
INHERITED_WRIST = (.2997, -.0848, .6318)
# Hand-assembly vertices above this inherited height are the old folded cuff and
# are discarded; the rest is the hand and thumb, kept as authored.
CUFF_SPLIT_Z = .54
# A subtle cuff: the band reads mostly as trim colour, not as a flare. This
# supersedes the "about 25% wider than the adjacent sleeve" line in
# GAME_DESIGN.md, which the user replaced with flush, subtle sleeves.
CUFF_FLARE = ((.45, 1.05), (.85, 1.11))


def use_chart(name):
    """Load one proportion chart into the module constants."""
    global TORSO, LEG_KEYS, ARM_LENGTH, SLEEVE_RADIUS
    chart = proportions.CHARTS[name]
    TORSO = chart['torso']
    LEG_KEYS = chart['leg_keys']
    ARM_LENGTH = chart['arm_length']
    SLEEVE_RADIUS = chart['sleeve_radius']
    return chart


def design_radius(z):
    """Constant width; depth closes only over the last rows, into the crotch."""
    radius_x, radius_y = TORSO
    return radius_x, radius_y * catmull_rom(CROTCH_TAPER, z)


def armhole_centre():
    """Centre of the armhole patch, from the unclamped shoulder rows."""
    top, bottom = ARMHOLE_ROWS
    first = ARMHOLE_COLUMNS['R']
    points = []
    for row in range(top, bottom + 1):
        z = TORSO_ROWS[row]
        rx, ry = design_radius(z)
        full = ring(Vector((0, CENTRE_Y, z)), Vector((1, 0, 0)), Vector((0, 1, 0)),
                    rx, ry, COLUMNS)
        points += [full[(first + n) % COLUMNS] for n in range(4)]
    return sum(points, Vector()) / len(points)


def arm_spine(sign=1):
    """Straight, horizontal, leaving the armhole along its own normal.

    A spine that drops from the armhole makes the hole's normal and the arm's
    direction meet at ninety degrees, and the bridge that turns that corner is
    the cave-in seen at the shoulder. Going straight out has no corner.
    """
    centre = armhole_centre()
    start = Vector((sign * abs(centre.x), centre.y, centre.z))
    outward = Vector((sign, 0, 0))
    wrist = start + outward * (ARM_LENGTH - proportions.HAND_DROP)
    reach = (wrist - start) / 3
    return even_samples(start, start + reach, wrist - reach, SLEEVE_RINGS, p3=wrist)


def hand_turn(sign):
    """The inherited hand points down; in T-pose it points along the arm."""
    return Matrix.Rotation(math.radians(-90 * sign), 4, 'Y')


def sleeve_radius(index):
    t = index / (SLEEVE_RINGS - 1)
    return SLEEVE_RADIUS[0] + (SLEEVE_RADIUS[1] - SLEEVE_RADIUS[0]) * t * t


def leg_centre(z):
    return (catmull_rom([(k[0], k[1]) for k in LEG_KEYS], z),
            catmull_rom([(k[0], k[2]) for k in LEG_KEYS], z),
            catmull_rom([(k[0], k[3]) for k in LEG_KEYS], z))


def align(target, loop):
    """Rotate/flip `loop` so its order best matches `target` vertex for vertex."""
    best, order = None, None
    for direction in (1, -1):
        turned = loop if direction > 0 else loop[::-1]
        for shift in range(len(turned)):
            candidate = turned[shift:] + turned[:shift]
            cost = sum((a - b).length_squared for a, b in zip(target, candidate))
            if best is None or cost < best:
                best, order = cost, (direction, shift)
    direction, shift = order
    turned = loop if direction > 0 else loop[::-1]
    return turned[shift:] + turned[:shift], order


class Build:
    """Accumulates vertices and quads, then writes one mesh."""

    def __init__(self):
        self.points, self.faces, self.uvs = [], [], []
        self.parts, self.weights = [], []
        self.relax = set()
        self.spines = {}

    def vertex(self, point, part, weights=None):
        self.points.append(Vector(point))
        self.parts.append(part)
        self.weights.append(dict(weights) if weights else None)
        return len(self.points) - 1

    def ring(self, points, part, weights=None):
        return [self.vertex(p, part, weights) for p in points]

    def face(self, indices, uv=PALETTE_UV):
        self.faces.append(tuple(indices))
        self.uvs.append(uv)

    def bridge(self, lower, upper, uv=PALETTE_UV, flip=False):
        for index in range(len(lower)):
            following = (index + 1) % len(lower)
            quad = (lower[index], lower[following], upper[following], upper[index])
            self.face(quad[::-1] if flip else quad, uv)

    def fan(self, loop, centre, part, uv=PALETTE_UV, flip=False):
        tip = self.vertex(centre, part)
        for index in range(len(loop)):
            following = (index + 1) % len(loop)
            tri = (loop[index], loop[following], tip)
            self.face(tri[::-1] if flip else tri, uv)
        return tip


def build_torso(build):
    """20-column loft with two armholes cut as 3x2 face blocks."""
    grid = []
    for z in TORSO_ROWS:
        rx, ry = design_radius(z)
        centre = Vector((0, CENTRE_Y, z))
        points = ring(centre, Vector((1, 0, 0)), Vector((0, 1, 0)), rx, ry, COLUMNS)
        grid.append(build.ring(points, 'torso'))
    holes = {}
    skip = set()
    for side, first in ARMHOLE_COLUMNS.items():
        top, bottom = ARMHOLE_ROWS
        columns = [(first + n) % COLUMNS for n in range(4)]
        for row in range(top, bottom):
            for column in columns[:3]:
                skip.add((row, column))
        # The two vertices enclosed by the deleted block leave the mesh.
        middle = top + 1
        holes[side] = [(top, columns[0]), (top, columns[1]), (top, columns[2]), (top, columns[3]),
                       (middle, columns[3]), (bottom, columns[3]), (bottom, columns[2]),
                       (bottom, columns[1]), (bottom, columns[0]), (middle, columns[0])]
        skip.add(('vertex', middle, columns[1]))
        skip.add(('vertex', middle, columns[2]))
    for row in range(len(TORSO_ROWS) - 1):
        for column in range(COLUMNS):
            if (row, column) in skip:
                continue
            following = (column + 1) % COLUMNS
            build.face((grid[row][column], grid[row][following],
                        grid[row + 1][following], grid[row + 1][column]))
    dead = {(r, c) for kind, r, c in (s for s in skip if s[0] == 'vertex')}
    loops = {side: [grid[r][c] for r, c in cells] for side, cells in holes.items()}
    return grid, loops, dead


def build_neck(build, grid):
    """Dome the tunic into the neck, then carry a short skin neck up."""
    def loop(z, radius_x, radius_y, columns, part):
        centre = Vector((0, CENTRE_Y + .0045, z))
        return build.ring(ring(centre, Vector((1, 0, 0)), Vector((0, 1, 0)),
                               radius_x, radius_y, columns), part)

    top_z = TORSO_ROWS[0]
    torso_x, torso_y = TORSO
    # Each ring interpolates the torso's own two radii toward the round collar,
    # so the dome stays elliptical where the body is and only becomes circular
    # as it reaches the neck. Building these as circles is what made the ledge.
    previous = grid[0]
    for step in SHOULDER_STEPS:
        turn = step * math.pi / 2
        blend = math.cos(turn)
        current = loop(top_z + SHOULDER_RISE * math.sin(turn),
                       COLLAR_RADIUS + (torso_x - COLLAR_RADIUS) * blend,
                       COLLAR_RADIUS + (torso_y - COLLAR_RADIUS) * blend,
                       COLUMNS, 'torso')
        build.bridge(previous, current, CLOTH_UV)
        previous = current

    collar_z = top_z + SHOULDER_RISE
    collar = loop(collar_z, COLLAR_RADIUS, COLLAR_RADIUS, LIMB_COLUMNS, 'neck')
    # 2:1 reduction at the top of the dome, where it reads least.
    for index in range(LIMB_COLUMNS):
        a = previous[2 * index]
        b = previous[(2 * index + 1) % COLUMNS]
        c = previous[(2 * index + 2) % COLUMNS]
        build.face((a, b, collar[index], collar[index - 1]), CLOTH_UV)
        build.face((b, c, collar[index]), CLOTH_UV)

    previous = collar
    for z, radius in NECK_ROWS:
        current = loop(z, radius, radius, LIMB_COLUMNS, 'neck')
        build.bridge(previous, current, SKIN_UV)
        previous = current
    build.fan(previous, Vector((0, CENTRE_Y + .0045, NECK_ROWS[-1][0] + .04)),
              'neck', SKIN_UV)


def build_legs(build, grid):
    """Split the hip ring into two legs across a two-quad septum.

    Splitting the ring in half leaves each leg a D whose straight side is one
    long chord - nine short segments and one of .297 - so that chord bridged to a
    .09 leg segment and sheared into the dark wedge seen at the groin. A midpoint
    on each chord halves it and makes the septum two square-ish quads.
    """
    hip = grid[-1]
    seam_z = TORSO_ROWS[-1]
    middles = {}
    for side, column in (('R', 4), ('L', 5)):
        point = build.points[hip[column]]
        middles[side] = build.vertex(Vector((point.x, CENTRE_Y, seam_z)), 'torso')
    halves = {'R': [hip[(15 + n) % COLUMNS] for n in range(10)] + [middles['R']],
              'L': [hip[5 + n] for n in range(10)] + [middles['L']]}
    build.face((hip[4], hip[5], middles['L'], middles['R']))
    build.face((middles['R'], middles['L'], hip[14], hip[15]))
    for side, sign in (('R', 1), ('L', -1)):
        previous = halves[side]
        for z in LEG_ROWS:
            x, rx, ry = leg_centre(z)
            centre = Vector((sign * x, CENTRE_Y, z))
            points = ring(centre, Vector((sign, 0, 0)), Vector((0, 1, 0)), rx, ry,
                          LEG_COLUMNS)
            ordered, _ = align([build.points[i] for i in previous], points)
            current = build.ring(ordered, 'leg' + side)
            build.bridge(previous, current, flip=(sign < 0))
            previous = current
        x, _, _ = leg_centre(LEG_ROWS[-1])
        build.fan(previous, Vector((sign * x, CENTRE_Y, LEG_ROWS[-1] - .05)),
                  'leg' + side, flip=(sign > 0))


def hand_assembly(body):
    """Pull the accepted hand off the existing body, per side, without the thumb.

    Each arm island is 202 vertices: the first 100 are the ten sleeve rings this
    rebuild replaces, and of the rest the folded cuff is dropped (see
    `CUFF_SPLIT_Z`) and the hand is kept as authored. The thumb is removed and
    the patch it stood on is closed again.
    """
    mesh = body.data
    names = {group.index: group.name for group in body.vertex_groups}
    thumb_groups = {index for index, name in names.items() if name.startswith('Thumb.')}
    work = bmesh.new()
    work.from_mesh(mesh)
    deform = work.verts.layers.deform.active
    uv_layer = work.loops.layers.uv.active

    doomed = [v for v in work.verts
              if any(v[deform].get(group, 0) > .5 for group in thumb_groups)]
    if doomed:
        bmesh.ops.delete(work, geom=doomed, context='VERTS')
        holes = [e for e in work.edges if len(e.link_faces) < 2]
        if holes:
            # `sides` is a maximum, not a hint: the thumb seam is a six-sided
            # hole, so sides=4 skipped it and left the mesh open. Fill without a
            # limit, then split the six-gon back into the two quads the thumb was
            # extruded from - its middle vertices are loop positions 1 and 4.
            existing = set(work.faces)
            bmesh.ops.holes_fill(work, edges=holes, sides=0)
            work.faces.ensure_lookup_table()
            patched = [f for f in work.faces if f not in existing]
            for face in patched:
                for loop in face.loops:
                    loop[uv_layer].uv = HAND_UV
            for face in patched:
                if len(face.verts) == 6:
                    corners = [loop.vert for loop in face.loops]
                    bmesh.ops.connect_verts(work, verts=[corners[1], corners[4]])
    work.verts.ensure_lookup_table()
    work.verts.index_update()

    seen, islands = set(), []
    for vertex in work.verts:
        if vertex.index in seen:
            continue
        stack, island = [vertex], []
        seen.add(vertex.index)
        while stack:
            current = stack.pop()
            island.append(current.index)
            for edge in current.link_edges:
                other = edge.other_vert(current)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        islands.append(sorted(island))

    result = {}
    for island in islands:
        if not 180 <= len(island) <= 202:
            continue
        if abs(work.verts[island[0]].co.z - 1.82) > .5:
            continue
        side = 'R' if work.verts[island[0]].co.x > 0 else 'L'
        sleeve = set(island[:100])
        assembly = island[100:]
        hand = [i for i in assembly if work.verts[i].co.z <= CUFF_SPLIT_Z]
        cuff = set(assembly) - set(hand)
        keep = set(hand)
        faces, uvs = [], []
        for face in work.faces:
            indices = [v.index for v in face.verts]
            if all(i in keep for i in indices):
                faces.append(tuple(indices))
                uvs.append(tuple(face.loops[0][uv_layer].uv))
        bridging = [f for f in work.faces
                    if any(v.index in cuff | sleeve for v in f.verts)
                    and any(v.index in keep for v in f.verts)]
        rim = [i for i in hand if any(i in [v.index for v in f.verts] for f in bridging)]
        neighbours = {i: set() for i in rim}
        for edge in work.edges:
            a, b = edge.verts[0].index, edge.verts[1].index
            if a in neighbours and b in neighbours:
                neighbours[a].add(b)
                neighbours[b].add(a)
        order, current = [rim[0]], rim[0]
        while len(order) < len(rim):
            following = [i for i in neighbours[current] if i not in order]
            if not following:
                break
            order.append(following[0])
            current = following[0]
        weights = {i: {names[group]: value
                       for group, value in work.verts[i][deform].items() if value > 0}
                   for i in hand}
        result[side] = {'verts': hand, 'faces': faces, 'uvs': uvs, 'rim': order,
                        'points': {i: work.verts[i].co.copy() for i in hand},
                        'weights': weights}
    work.free()
    return result


def build_arms(build, loops, hands):
    """One smooth spine, even rings, monotone radius, transported frame."""
    for side, sign in (('R', 1), ('L', -1)):
        loop = loops[side]
        spine = arm_spine(sign)
        # Vertical reference: the arm runs along x, so +x would be degenerate.
        frames = parallel_frames(spine, Vector((0, 0, 1)))
        rings = []
        for index, (point, frame) in enumerate(zip(spine, frames)):
            radius = sleeve_radius(index)
            _, normal, binormal = frame
            rings.append(ring(point, normal, binormal, radius, radius * ELLIPSE,
                              LIMB_COLUMNS))
        # The armhole boundary is torso surface and stays on it. Relaxing it
        # averaged those vertices toward the arm's first ring and pulled them out
        # to radius .416 against a torso radius of .300 - the shoulder lump.
        build.spines[side] = spine
        previous = loop
        for index, points in enumerate(rings):
            ordered, _ = align([build.points[i] for i in previous], points)
            current = build.ring(ordered, 'arm' + side)
            # Only the first ring is relaxed now. The wider band existed to
            # round a ninety-degree corner between torso wall and arm; in T-pose
            # there is no corner, and relaxing more rings pulled the sleeve in
            # and left a notch at the shoulder.
            if index < 1:
                build.relax.update(current)
            build.bridge(previous, current, CLOTH_UV)
            previous = current

        # Place the kept hand, then span the gap with a fresh cuff.
        hand = hands[side]
        inherited = Vector((sign * INHERITED_WRIST[0], INHERITED_WRIST[1],
                            INHERITED_WRIST[2]))
        turn = hand_turn(sign)
        seam_point = spine[-1]
        remap = {index: build.vertex(
            seam_point + turn @ (hand['points'][index] - inherited),
            'hand' + side, hand['weights'][index]) for index in hand['verts']}
        for face, uv in zip(hand['faces'], hand['uvs']):
            build.face(tuple(remap[i] for i in face), uv)
        wrist_ring = [remap[i] for i in hand['rim']]
        ordered, _ = align([build.points[i] for i in previous],
                           [build.points[i] for i in wrist_ring])
        lookup = {build.points[i].to_tuple(5): i for i in wrist_ring}
        wrist_ring = [lookup[p.to_tuple(5)] for p in ordered]

        seam = spine[-1]
        seam_radius = sleeve_radius(SLEEVE_RINGS - 1)
        _, normal, binormal = frames[-1]
        hand_top = sum((build.points[i] for i in wrist_ring), Vector()) / len(wrist_ring)
        # A single-wall funnel: the sleeve flares out to the lip, then the lip
        # runs straight in to the wrist. The inherited cuff folded back on itself
        # and turned wider than the sleeve, which is why it poked through.
        for across, multiple in CUFF_FLARE:
            centre = seam.lerp(hand_top, across)
            radius = seam_radius * multiple
            points = ring(centre, normal, binormal, radius, radius * ELLIPSE,
                          LIMB_COLUMNS)
            ordered, _ = align([build.points[i] for i in previous], points)
            current = build.ring(ordered, 'cuff' + side)
            build.bridge(previous, current, TRIM_UV)
            previous = current
        build.bridge(previous, wrist_ring, TRIM_UV)


def write_mesh(build, name='Body'):
    """Write the accumulated geometry, dropping the vertices the holes enclosed.

    The two vertices each armhole encloses are never referenced by a face. They
    are filtered out *before* the mesh is created and `build.kept` records the
    surviving order, so weights stay attached to the right vertices.
    """
    used = sorted({index for face in build.faces for index in face})
    remap = {old: new for new, old in enumerate(used)}
    build.kept = used
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(build.points[i]) for i in used], [],
                     [tuple(remap[i] for i in face) for face in build.faces])
    mesh.validate()
    uv = mesh.uv_layers.new(name='UVMap')
    for polygon, value in zip(mesh.polygons, build.uvs):
        polygon.use_smooth = True
        for loop in polygon.loop_indices:
            uv.data[loop].uv = value
    work = bmesh.new()
    work.from_mesh(mesh)
    work.verts.ensure_lookup_table()
    # The torso wall and the arm ring meet at roughly 80 degrees, which reads as
    # a hard crease. Relaxing only the two loops that form the fold rounds the
    # deltoid without moving the torso or the sleeve profile.
    band = [remap[i] for i in build.relax if i in remap]
    for _ in range(2):
        moved = {}
        for index in band:
            vertex = work.verts[index]
            neighbours = [e.other_vert(vertex).co for e in vertex.link_edges]
            if neighbours:
                moved[index] = vertex.co.lerp(sum(neighbours, Vector()) / len(neighbours), .5)
        for index, point in moved.items():
            work.verts[index].co = point
    bmesh.ops.recalc_face_normals(work, faces=list(work.faces))
    work.to_mesh(mesh)
    work.free()
    return mesh, len(build.points) - len(used)


def report(mesh, label):
    work = bmesh.new()
    work.from_mesh(mesh)
    work.verts.ensure_lookup_table()
    seen, islands = set(), []
    for vertex in work.verts:
        if vertex.index in seen:
            continue
        stack, size = [vertex], 0
        seen.add(vertex.index)
        while stack:
            current = stack.pop()
            size += 1
            for edge in current.link_edges:
                other = edge.other_vert(current)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        islands.append(size)
    quads = sum(1 for f in work.faces if len(f.verts) == 4)
    tris = sum(1 for f in work.faces if len(f.verts) == 3)
    ngons = sum(1 for f in work.faces if len(f.verts) > 4)
    from collections import Counter
    poles = {k: v for k, v in Counter(len(v.link_edges) for v in work.verts).items()
             if k not in (3, 4)}
    print(f'### {label}: verts={len(work.verts)} tris={sum(len(f.verts) - 2 for f in work.faces)} '
          f'quads={quads} tri_faces={tris} ngons={ngons}')
    print(f'###   islands={len(islands)} {sorted(islands, reverse=True)[:6]} '
          f'non_manifold={sum(1 for e in work.edges if not e.is_manifold)} '
          f'boundary={sum(1 for e in work.edges if e.is_boundary)} poles={sorted(poles.items())}')
    work.free()


def main():
    source = Path(__file__).resolve().parents[1] / 'traveller_animated/traveller_animated.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source))
    hands = hand_assembly(bpy.data.objects['Body'])
    print('### hand assemblies', {k: (len(v['verts']), len(v['faces']), len(v['rim']))
                                  for k, v in hands.items()})
    build = Build()
    grid, loops, dead = build_torso(build)
    build_neck(build, grid)
    build_legs(build, grid)
    build_arms(build, loops, hands)
    mesh, loose = write_mesh(build)
    print('### removed loose', loose)
    report(mesh, 'body')


if __name__ == '__main__':
    main()

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
# One atlas point per region. The inherited model interleaved cloth, trim and
# skin by height through the cuff, which is what made it read as bare wrist.
CLOTH_UV = (.375, .56)
TRIM_UV = (.625, .73)
HAND_UV = (.875, .56)
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
TORSO_ROWS = [2.000, 1.878, 1.756, 1.630, 1.500, 1.370, 1.240, 1.120]
ARMHOLE_ROWS = (0, 2)          # the hole opens at the very top of the torso
ARMHOLE_COLUMNS = {'R': 18, 'L': 8}   # first of four vertex columns
# Legs sit entirely under the cloak (only the boots show), so they are drawn in
# to clear the hands that hang beside them.
LEG_KEYS = []                  # set by `use_chart`
LEG_ROWS = [1.02, .92, .80, .68, .56, .44, .32]
NECK_ROWS = [(2.15, .150), (2.21, .140), (2.27, .120), (2.31, .080)]
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
    """Constant. The torso is a tube; upper and lower body share one radius."""
    return TORSO


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
    """Reduce the 20-column torso top to a 10-column neck, then cap it."""
    top = grid[0]
    z, radius = NECK_ROWS[0]
    centre = Vector((0, CENTRE_Y + .0045, z))
    base = build.ring(ring(centre, Vector((1, 0, 0)), Vector((0, 1, 0)),
                           radius, radius, LIMB_COLUMNS), 'neck')
    # 2:1 reduction: one quad and one triangle per inner column.
    for index in range(LIMB_COLUMNS):
        a, b, c = top[2 * index], top[(2 * index + 1) % COLUMNS], top[(2 * index + 2) % COLUMNS]
        build.face((a, b, base[index], base[index - 1]))
        build.face((b, c, base[index]))
    previous = base
    for z, radius in NECK_ROWS[1:]:
        centre = Vector((0, CENTRE_Y + .0045, z))
        current = build.ring(ring(centre, Vector((1, 0, 0)), Vector((0, 1, 0)),
                                  radius, radius, LIMB_COLUMNS), 'neck')
        build.bridge(previous, current)
        previous = current
    build.fan(previous, Vector((0, CENTRE_Y + .0045, NECK_ROWS[-1][0] + .04)), 'neck')


def build_legs(build, grid):
    """Split the 20-column hip ring into two 10-column legs sharing a septum."""
    hip = grid[-1]
    halves = {'R': [hip[(15 + n) % COLUMNS] for n in range(10)],
              'L': [hip[5 + n] for n in range(10)]}
    build.face((hip[4], hip[5], hip[14], hip[15]))
    for side, sign in (('R', 1), ('L', -1)):
        previous = halves[side]
        for z in LEG_ROWS:
            x, rx, ry = leg_centre(z)
            centre = Vector((sign * x, CENTRE_Y, z))
            points = ring(centre, Vector((sign, 0, 0)), Vector((0, 1, 0)), rx, ry, LIMB_COLUMNS)
            ordered, _ = align([build.points[i] for i in previous], points)
            current = build.ring(ordered, 'leg' + side)
            build.bridge(previous, current, flip=(sign < 0))
            previous = current
        x, _, _ = leg_centre(LEG_ROWS[-1])
        build.fan(previous, Vector((sign * x, CENTRE_Y, LEG_ROWS[-1] - .05)),
                  'leg' + side, flip=(sign > 0))


def hand_assembly(body):
    """Pull the accepted cuff, hand and thumb off the existing body, per side.

    Each arm island is 202 vertices: the first 100 are the ten sleeve rings that
    this rebuild replaces, the remaining 102 are the folded open cuff, the hand
    and the thumb, which are kept exactly as authored.
    """
    mesh = body.data
    names = {group.index: group.name for group in body.vertex_groups}
    work = bmesh.new()
    work.from_mesh(mesh)
    work.verts.ensure_lookup_table()
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
        if len(island) != 202:
            continue
        side = 'R' if mesh.vertices[island[0]].co.x > 0 else 'L'
        sleeve = set(island[:100])
        assembly = island[100:]
        # Drop the inherited folded cuff; keep the hand and thumb as authored.
        hand = [i for i in assembly if mesh.vertices[i].co.z <= CUFF_SPLIT_Z]
        cuff = set(assembly) - set(hand)
        keep = set(hand)
        faces, uvs = [], []
        for face in mesh.polygons:
            if all(i in keep for i in face.vertices):
                faces.append(tuple(face.vertices))
                uvs.append(tuple(mesh.uv_layers.active.data[face.loop_indices[0]].uv))
        # The new rim is the hand's own top ring: the kept vertices that used to
        # carry faces up into the discarded cuff.
        bridging = [f for f in mesh.polygons
                    if any(i in cuff | sleeve for i in f.vertices)
                    and any(i in keep for i in f.vertices)]
        rim = [i for i in hand if any(i in f.vertices for f in bridging)]
        neighbours = {i: set() for i in rim}
        for edge in mesh.edges:
            a, b = edge.vertices
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
        weights = {i: {names[g.group]: g.weight for g in mesh.vertices[i].groups if g.weight > 0}
                   for i in hand}
        result[side] = {'verts': hand, 'faces': faces, 'uvs': uvs, 'rim': order,
                        'points': {i: mesh.vertices[i].co.copy() for i in hand},
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
        build.relax.update(loop)
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

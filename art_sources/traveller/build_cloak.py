"""Rebuild the cloak as quads, keeping the shape the user accepted.

The old cloak was 3,332 triangles with no quads at all, edge lengths in a 258:1
range and face areas in a 999:1 range. It was also a closed double wall, which is
half its cost.

The method keeps the accepted shape by construction. A regular grid is projected
onto the old surface, so the new mesh follows the old one instead of guessing it.
The eight shape keys move across by barycentric position on the old triangles, so
large movement such as the hood folding down (2.1 units) stays correct.

The front split is a real gap in the old cloak: it widens from 0.008 at the
clasp to 0.050 at the hem. The grid leaves it open in the same way, so no face
bridges it and the keys that part it have nothing to tear. `CloakOpen` stays the
resting look, and a ninth key, `CloakArms`, stands the cloth off a reaching arm.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

sys.path.insert(0, str(Path(__file__).resolve().parent))

COLUMNS = 24
# Column 0 is at world +x, so column 18 falls on the front centre and column 6 on
# the back centre. A ray down the front centre goes through the split and finds
# nothing, which is what leaves the front open.
FRONT = 3 * math.tau / 4
# The hem is not level: it falls from z 0.241 at the sides to 0.193 at the
# front, and the painted border follows it. So the first two rows follow the hem
# as well: one just above the edge, one at the top of the border. One face row
# then carries the whole border, the same way the old cloak did, and its atlas
# gradient (dark, light, dark) comes out unbroken.
HEM_LIFT = .002
# Close together where the shape turns (collar, hood rim, crown) and further
# apart down the smooth cape.
ROWS = [0.52, 0.72, 0.92, 1.12, 1.22, 1.32, 1.41, 1.50, 1.58,
        1.66, 1.73, 1.80, 1.86, 1.90, 1.95, 2.00, 2.06, 2.12, 2.15, 2.17, 2.19, 2.26,
        2.34, 2.42, 2.50, 2.58, 2.66, 2.74, 2.82, 2.90, 2.96, 3.03, 3.06, 3.13, 3.21, 3.27,
        3.295]
CAST_RADIUS = 1.6              # well outside the cloak's widest point, 0.88
RIM = .010                     # thickness at the hem and the hood's face rim
ROLL = 1.0                     # how far the lip rolls back under the cloth, as
                               # a share of RIM, so its fold is not square
ROLL_ABOVE = 0.50              # and only above this height: not at the hem
LIP_FLOOR = .40                # the least of RIM a lip may be thinned to
# A grid of chords sits inside the curved surface it samples, so the new cloak
# would press into the body where the old one was already tight. Push each
# sample out along the surface normal to pay that back.
OUTSET = .016
# How many columns inward of an edge share its travel, evenly, so the cell
# widths grade instead of putting a sliver next to a wide quad.
SPREAD = 4
# How many columns an opening's edge may travel to reach the real rim.
SNAP_REACH = 4
# How much of its travel an opening's edge keeps in its last rows, where the
# opening closes to nothing and a hard snap pinches against the closed row.
EDGE_EASE = (.92, .97)
# The widest opening that counts as a slit worth easing.
EASE_BELOW = math.radians(12)
# The widest gap, in columns, that counts as an apex worth capping.
CAP_COLUMNS = 2
# How much of a snapped edge's shift the rows beyond the opening keep, so the
# surface returns to its plain columns over two rows instead of in one step.
TAPER = (.75, .45, .20)
# The flat cloth palette point. The atlas is a palette, not a texture, so a face
# has to stay inside one region: a corner that reads across a region boundary
# samples a colour that belongs somewhere else.
CLOTH_UV = (.625, .56)
# The atlas rows the clasp uses, which nothing else on the cloak does.
CLASP_BAND = (.12, .50)
CLASP_LIFT = .034               # how far the brooch stands off the old surface


def column_angle(column):
    return column * math.tau / COLUMNS


class Hit:
    """Where a cast landed, and the atlas value the old cloak carries there."""

    __slots__ = ('co', 'uv')

    def __init__(self, co, uv):
        self.co, self.uv = co, uv


class OuterSurface:
    """The old cloak's outer surface, sampled by ray casts that stop at the axis.

    A ray that passes through an opening goes on to hit the far panel from the
    inside, so the cast must stop at the axis rather than trust the first hit.
    """

    def __init__(self, obj, key='Basis'):
        for block in obj.data.shape_keys.key_blocks:
            block.value = 1.0 if block.name == key and key != 'Basis' else 0.0
        bpy.context.view_layer.update()
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.data
        mesh.calc_loop_triangles()
        source = mesh.uv_layers.active.data
        self.points = [v.co.copy() for v in mesh.vertices]
        self.faces = [tuple(t.vertices) for t in mesh.loop_triangles]
        # All three corner UVs, not just the first. The painted hem border is a
        # gradient across its faces, so one flat value per face loses it.
        self.uvs = [tuple(tuple(source[loop].uv) for loop in t.loops)
                    for t in mesh.loop_triangles]
        self.tree = BVHTree.FromPolygons(self.points, self.faces, all_triangles=True)

    def at(self, z, angle):
        """Outer surface point at this height and angle, or None in an opening."""
        axis = Vector((0, 0, z))
        direction = Vector((-math.cos(angle), -math.sin(angle), 0))
        origin = axis - direction * CAST_RADIUS
        travelled = 0.0
        while travelled < CAST_RADIUS:
            location, normal, index, distance = self.tree.ray_cast(
                origin, direction, CAST_RADIUS - travelled)
            if location is None:
                return None
            if normal.dot(-direction) > 0:
                return Hit(location + normal * OUTSET, self.uv_on(index, location))
            travelled += distance + 1e-4
            origin = location + direction * 1e-4
        return None

    def top(self, x, y):
        """The crown, found straight down the vertical, for the hood's cap."""
        location, normal, index, _ = self.tree.ray_cast(
            Vector((x, y, 5.0)), Vector((0, 0, -1)), 5.0)
        if location is None:
            return None
        return Hit(location + normal * OUTSET, self.uv_on(index, location))

    def uv_on(self, index, location):
        """The old atlas value at a point on one old triangle, interpolated.

        The value comes from the triangle the cast hit, never from a nearest
        point. The old cloak is a double wall, so a nearest point can belong to
        the inner wall or to the far panel, and the hem border breaks up.
        """
        if index is None:
            return CLOTH_UV
        a, b, c = (self.points[i] for i in self.faces[index])
        u, v, w = barycentric(location, a, b, c)
        corners = self.uvs[index]
        return (corners[0][0] * u + corners[1][0] * v + corners[2][0] * w,
                corners[0][1] * u + corners[1][1] * v + corners[2][1] * w)


def hem_height(surface, angle, low=.05, high=.60):
    """The lowest height with cloth at this angle, found by bisection."""
    if surface.at(high, angle) is None:
        return None
    for _ in range(30):
        middle = (low + high) / 2
        if surface.at(middle, angle) is None:
            low = middle
        else:
            high = middle
    return high


def band_top(surface, angle, low, high=.60):
    """The height where the painted hem border ends, read from the old atlas."""
    hit = surface.at(low, angle)
    if hit is None or is_cloth(hit.uv):
        return None
    for _ in range(24):
        middle = (low + high) / 2
        hit = surface.at(middle, angle)
        if hit is not None and not is_cloth(hit.uv):
            low = middle
        else:
            high = middle
    return low


def build_grid(surface):
    """Project the grid: two rows that follow the hem border, then level rows."""
    hems = [hem_height(surface, column_angle(c)) for c in range(COLUMNS)]
    feet = [None if h is None else h + HEM_LIFT for h in hems]
    found = [band_top(surface, column_angle(c), feet[c]) - feet[c]
             for c in range(COLUMNS)
             if feet[c] is not None and band_top(surface, column_angle(c), feet[c])]
    # One height for the whole border, not one per column. The old border's top
    # zig-zags, and sampled at 24 columns that becomes a ragged ribbon whose
    # gradient is squashed in some columns and stretched in others.
    height = sorted(found)[len(found) // 2] if found else .05
    tops = [None if feet[c] is None else feet[c] + height for c in range(COLUMNS)]
    grid, heights = [], []
    # One height per column, not one per row. The first two rows follow each
    # column's own hem, and re-projecting them at the row's average put the two
    # columns beside the split 0.022 out, which squashed their border faces to
    # slivers and read as dark notches in the band.
    for levels in (feet, tops):
        grid.append([None if levels[c] is None else surface.at(levels[c], column_angle(c))
                     for c in range(COLUMNS)])
        heights.append(list(levels))
    for z in ROWS:
        grid.append([surface.at(z, column_angle(c)) for c in range(COLUMNS)])
        heights.append([z] * COLUMNS)
    taper_openings(surface, grid, heights, snap_openings(surface, grid, heights))
    level_trim(grid)
    return grid


def snap_openings(surface, grid, heights):
    """Put the vertices beside an opening on the real rim, not on a grid step.

    Without this the hood's face opening follows whole cells and looks stepped.
    Returns the angle each column was moved by, for the taper that follows.
    """
    step = math.tau / COLUMNS
    shifts = {}
    for number, (row, z) in enumerate(zip(grid, heights)):
        if all(p is None for p in row) or all(p is not None for p in row):
            continue
        moves = {}
        for column in range(COLUMNS):
            following = (column + 1) % COLUMNS
            if (row[column] is None) == (row[following] is None):
                continue
            inside, direction = ((column, 1) if row[following] is None
                                 else (following, -1))
            # Reach past one column. Where an opening narrows quickly the real
            # rim is several columns from the last one that found cloth, and a
            # search bounded at one step stops short: the hood's opening came out
            # 74 degrees wide at its top where the truth is 38, which gave it a
            # flat top and two sharp corners.
            level = z[inside]
            if level is None:
                continue
            low, high = 0.0, step
            while (high < SNAP_REACH * step
                   and surface.at(level, column_angle(inside) + direction * high) is not None):
                low, high = high, high + step
            for _ in range(24):
                middle = (low + high) / 2
                if surface.at(level, column_angle(inside) + direction * middle) is None:
                    high = middle
                else:
                    low = middle
            hit = surface.at(level, column_angle(inside) + direction * low)
            if hit is None:
                continue
            moves[inside] = (hit, low, direction)
        applied = {}
        for index, (hit, travel, direction) in moves.items():
            row[index] = hit
            applied[index] = direction * travel
            # Share the travel with the columns inward of the edge. Without it
            # the snapped vertex leaves a 3 degree cell beside a 27 degree one,
            # and the two widths fold against each other.
            # Spread the travel evenly over the columns inward of the edge, so
            # the cells all take the same share of it. A fixed profile instead
            # left the spacing running 15, 17, 17, 20 degrees into the rim, and
            # the widening cells read as faint creases along the hood.
            spread = min(travel, math.tau / COLUMNS)
            for depth in range(1, SPREAD):
                inner = (index - direction * depth) % COLUMNS
                if inner in moves or row[inner] is None:
                    continue
                offset = direction * spread * (1 - depth / SPREAD)
                if z[inner] is None:
                    continue
                shared = surface.at(z[inner], column_angle(inner) + offset)
                if shared is not None:
                    row[inner] = shared
                    applied[inner] = offset
        if applied:
            shifts[number] = applied
    return ease_ends(surface, grid, heights, shifts)


def ease_ends(surface, grid, heights, shifts):
    """Let the edge back off the rim in the last rows of an opening.

    The front split closes to a slit 0.008 wide. Snapped hard onto that, the last
    open row pinches against the first closed row and creased the chest at 154
    degrees. Backing the edge off by a fraction widens the slit invisibly and
    lets the two rows meet.
    """
    numbers = sorted(shifts)
    runs, first = [], None
    for index, number in enumerate(numbers):
        if first is None:
            first = number
        if index + 1 == len(numbers) or numbers[index + 1] != number + 1:
            runs.append((first, number))
            first = None
    for low, high in runs:
        for source, step in ((low, 1), (high, -1)):
            # Only where the opening ends because the cloth closes over it. At
            # the hem it ends because the mesh does, and the split is genuinely
            # 0.05 wide there, so backing the edge off would widen the hem.
            beyond = source - step
            if not 0 <= beyond < len(grid) or any(p is None for p in grid[beyond]):
                continue
            for depth, share in enumerate(EDGE_EASE):
                number = source + step * depth
                if number not in shifts or not low <= number <= high:
                    continue
                # Only a slit. The hood's face opening also ends against cloth,
                # but it closes from 38 degrees to a point, and easing it there
                # widened the rim where it should narrow and cut two sharp
                # corners into the top of the opening.
                width = opening_width(grid[number])
                if width is None or width > EASE_BELOW:
                    continue
                for column, offset in list(shifts[number].items()):
                    if heights[number][column] is None:
                        continue
                    hit = surface.at(heights[number][column],
                                     column_angle(column) + offset * share)
                    if hit is not None:
                        grid[number][column] = hit
                        shifts[number][column] = offset * share
    return shifts


def taper_openings(surface, grid, heights, shifts):
    """Let a snapped edge come back to its column over the next rows.

    The snap only touches rows that belong to an opening, so the first full row
    beyond it sits back at the plain column angle and the surface steps there.
    Measured before this: the front split's edge runs at 247 degrees at z 1.80
    and jumps to 255 at z 1.86, which creases the chest at 154 degrees; the hood
    opening does the same at its top corners, at 134 degrees.
    """
    runs, first = [], None
    for number in range(len(grid)):
        if number in shifts:
            first = number if first is None else first
        elif first is not None:
            runs.append((first, number - 1))
            first = None
    if first is not None:
        runs.append((first, len(grid) - 1))
    for low, high in runs:
        for source, step in ((low, -1), (high, 1)):
            for depth, share in enumerate(TAPER, start=1):
                number = source + step * depth
                if not 0 <= number < len(grid) or number in shifts:
                    continue
                for column, offset in shifts[source].items():
                    if grid[number][column] is None or heights[number][column] is None:
                        continue
                    hit = surface.at(heights[number][column],
                                     column_angle(column) + offset * share)
                    if hit is not None:
                        grid[number][column] = hit


def opening_width(row):
    """The angle across an opening in one row, or None if it has no two edges."""
    edges = []
    for column in range(COLUMNS):
        following = (column + 1) % COLUMNS
        if (row[column] is None) == (row[following] is None):
            continue
        inside = column if row[following] is None else following
        edges.append(row[inside].co)
    if len(edges) != 2:
        return None
    first = math.atan2(edges[0].y, edges[0].x)
    second = math.atan2(edges[1].y, edges[1].x)
    return abs((first - second + math.pi) % math.tau - math.pi)


def level_trim(grid):
    """Give the hem border the same band of atlas rows all the way round.

    The border is a gradient across the atlas rows, dark to light to dark, and
    the rows carry the same colour at every u, so u holds no information here.
    What broke the band was v: `band_top` found 0.105 at most columns but only
    0.037 at a few, where the old border's own zig-zag runs short, and those
    columns lost the gradient and read as patches. Levelling the two rows gives
    an even band; the zig-zag is lost, and at 24 columns it was being sampled at
    an arbitrary phase anyway.
    """
    foot, band = grid[0], grid[1]
    carried = [(n, hit) for n, hit in enumerate(band)
               if hit is not None and not is_cloth(hit.uv)]
    if not carried or any(hit is None for hit in foot):
        return
    bottom = min(hit.uv[1] for hit in foot if not is_cloth(hit.uv))
    top = max(hit.uv[1] for _, hit in carried)
    for column in range(COLUMNS):
        if foot[column] is None or band[column] is None:
            continue
        # A column that read the plain cloth takes its u from the nearest column
        # that did read the border.
        near = min(carried, key=lambda item: abs(item[0] - column))[1].uv[0]
        value = near if is_cloth(band[column].uv) else band[column].uv[0]
        foot[column].uv = (value, bottom)
        band[column].uv = (value, top)


def write(grid, surface, name='CloakShell'):
    mesh = bpy.data.meshes.new(name)
    work = bmesh.new()
    verts, values, trim = {}, {}, set()
    for r, row in enumerate(grid):
        for c, hit in enumerate(row):
            if hit is not None:
                vertex = work.verts.new(hit.co)
                verts[(r, c)] = vertex
                # The clasp is carried across whole, so the grid must not try to
                # paint it as well. Its own columns are too narrow to hold it and
                # the value spread into a bar beside the split.
                values[vertex] = CLOTH_UV if is_clasp(hit.uv) else hit.uv
    work.verts.index_update()
    uv_layer = work.loops.layers.uv.verify()
    faces = []
    for r in range(len(grid) - 1):
        for c in range(COLUMNS):
            following = (c + 1) % COLUMNS
            corners = [(r, c), (r, following), (r + 1, following), (r + 1, c)]
            here = [k for k in corners if k in verts]
            if len(here) < 3:
                continue
            # Three corners means one row reaches a column the other does not,
            # where an opening narrows. Bridging it with a triangle keeps the
            # surface closed while each row keeps its own true width. Widening
            # every row of an opening to the same columns also closed it, but it
            # forced the hood's face opening to stay as wide at its top as at its
            # middle, which is what squared off its corners.
            face = work.faces.new([verts[k] for k in here])
            faces.append(face)
            # Row 0 to row 1 is the hem border by construction, so it keeps the
            # border values even where one corner reads the plain cloth.
            if r == 0:
                trim.add(face)
    faces += close_ends(work, verts, len(grid))
    faces += cap_crown(work, grid, verts, values, surface)
    for face in faces:
        face.smooth = True
        paint_face(face, values, uv_layer, face in trim)
    carry_clasp(work, surface, uv_layer)
    bmesh.ops.recalc_face_normals(work, faces=list(work.faces))
    work.to_mesh(mesh)
    work.free()
    return mesh


def carry_clasp(work, surface, uv_layer):
    """Re-emit the old clasp, which the grid is too coarse to hold.

    The clasp is eight triangles on the front centre plane, and the grid leaves
    that centre open for the split. Its atlas value therefore landed on the two
    narrow columns beside the slit and read as a bar rather than a brooch, so the
    old triangles are carried across whole, the way the hair carries its bun.
    """
    wanted = [index for index, corners in enumerate(surface.uvs)
              if all(CLASP_BAND[0] < corner[1] < CLASP_BAND[1] for corner in corners)]
    if not wanted:
        return []
    remap, faces = {}, []
    for index in wanted:
        for vertex in surface.faces[index]:
            if vertex not in remap:
                point = surface.points[vertex]
                # The cape moved out by OUTSET and its chords cut inside the
                # curve it samples, so the brooch needs more than that or it
                # sinks into the cloth it is supposed to sit on. Measured: the
                # clasp ran 0.429 to 0.447 against a cape at 0.442.
                outward = Vector((point.x, point.y, 0))
                if outward.length > 1e-6:
                    point = point + outward.normalized() * CLASP_LIFT
                remap[vertex] = work.verts.new(point)
        corners = [remap[i] for i in surface.faces[index]]
        if len(set(corners)) < 3:
            continue
        face = work.faces.new(corners)
        face.smooth = True
        for loop, value in zip(face.loops, surface.uvs[index]):
            loop[uv_layer].uv = value
        faces.append(face)
    return faces


def column_runs(columns):
    """Group column indices into runs, joining one that wraps past column 0."""
    present = sorted(columns)
    if not present:
        return []
    runs, current = [], [present[0]]
    for column in present[1:]:
        if column == current[-1] + 1:
            current.append(column)
        else:
            runs.append(current)
            current = [column]
    runs.append(current)
    if len(runs) > 1 and runs[0][0] == 0 and runs[-1][-1] == COLUMNS - 1:
        runs[0] = runs[-1] + runs[0]
        runs.pop()
    return runs


def close_ends(work, verts, rows):
    """Cap an opening where it ends, so its last row does not leave a notch.

    A cell needs three of its four corners to become a triangle. Where an opening
    ends, the columns in the middle of it have no vertex in one row and two in
    the next, so those cells have two corners and nothing is built at all: the
    hood's opening finished in a spike with a hole beside it. The gap is a
    polygon between the two rows, and a fan closes it.
    """
    made = []
    for row in range(rows - 1):
        for near, far in ((row, row + 1), (row + 1, row)):
            gaps = [c for c in range(COLUMNS)
                    if (far, c) in verts and (near, c) not in verts]
            for run in column_runs(gaps):
                # Only an apex. At its other end the hood's opening starts 55
                # degrees wide over 0.01 of height, and fanning that bridged the
                # whole throat with a flat triangular patch.
                if len(run) > CAP_COLUMNS:
                    continue
                left = (run[0] - 1) % COLUMNS
                right = (run[-1] + 1) % COLUMNS
                if (near, left) not in verts or (near, right) not in verts:
                    continue
                # Fanned to one corner the patch comes out as a long thin sheet
                # and creases: measured 121 degrees at the throat, against 116
                # in the old cloak. Each half goes to its own corner instead.
                start, end = verts[(near, left)], verts[(near, right)]
                chain = [verts[(far, c)] for c in run]
                middle = len(chain) // 2
                patch = [(start, chain[n], chain[n + 1]) for n in range(middle)]
                patch.append((start, chain[middle], end))
                patch += [(end, chain[n], chain[n + 1])
                          for n in range(middle, len(chain) - 1)]
                for corners in patch:
                    if len(set(corners)) < 3:
                        continue
                    try:
                        made.append(work.faces.new(corners))
                    except ValueError:
                        pass                      # the face is already there
    return made


def is_clasp(uv):
    return CLASP_BAND[0] < uv[1] < CLASP_BAND[1]


def is_cloth(uv):
    return abs(uv[0] - CLOTH_UV[0]) < .02 and abs(uv[1] - CLOTH_UV[1]) < .02


def paint_face(face, values, uv_layer, painted_row=False):
    """Keep one face inside one atlas region, and interpolate inside it.

    The hem border is a gradient, so its corners must keep their own values. A
    face that straddles the border and the flat cloth takes the majority region,
    because a corner on the wrong side of the boundary samples the wrong colour.
    """
    corners = [values.get(loop.vert, CLOTH_UV) for loop in face.loops]
    plain = [uv for uv in corners if is_cloth(uv)]
    if not painted_row and plain and len(plain) * 2 >= len(corners):
        for loop in face.loops:
            loop[uv_layer].uv = CLOTH_UV
        return
    painted = [uv for uv in corners if not is_cloth(uv)]
    spare = painted[0] if painted else CLOTH_UV
    for loop, uv in zip(face.loops, corners):
        loop[uv_layer].uv = spare if is_cloth(uv) else uv


def cap_crown(work, grid, verts, values, surface):
    """Close the top of the hood with a fan, so the crown is not a hole."""
    ring = [verts[(len(grid) - 1, c)] for c in range(COLUMNS)
            if (len(grid) - 1, c) in verts]
    if len(ring) != COLUMNS:
        return []
    centre = sum((v.co for v in ring), Vector()) / COLUMNS
    # The crown itself, not the middle of the last ring. The ring is level, so a
    # fan to its own centre is flat and meets the dome at 180 degrees.
    hit = surface.top(centre.x, centre.y)
    apex = work.verts.new(hit.co if hit else centre)
    values[apex] = hit.uv if hit else CLOTH_UV
    return [work.faces.new([ring[c], ring[(c + 1) % COLUMNS], apex])
            for c in range(COLUMNS)]


def add_rim(mesh, surface):
    """Give the open edges thickness, so the hem and the face rim are not paper.

    The normals must be read before the extrusion. A new boundary vertex carries
    only the strip's own faces, so its normal points anywhere and the strip comes
    out ragged.
    """
    work = bmesh.new()
    work.from_mesh(mesh)
    work.normal_update()
    uv_layer = work.loops.layers.uv.verify()
    border = [e for e in work.edges if e.is_boundary]
    if not border:
        work.free()
        return 0
    normals, inward, values = {}, {}, {}
    for edge in border:
        for vertex in edge.verts:
            key = tuple(round(n, 6) for n in vertex.co)
            normals[key] = vertex.normal.copy()
            values[vertex] = tuple(vertex.link_loops[0][uv_layer].uv)
            # The way back into the cloth, so the lip can be chamfered instead
            # of returned square. A square return folds at 90 degrees, and that
            # read as a faint crease running along the hood's opening.
            behind = [other for other in (e.other_vert(vertex) for e in vertex.link_edges)
                      if not any(f.calc_area() < 1e-9 for f in ())
                      and not other.is_boundary]
            if behind:
                step = sum(((other.co - vertex.co).normalized() for other in behind),
                           Vector()) / len(behind)
                inward[key] = step.normalized() if step.length > 1e-6 else Vector()
    carried = {tuple(round(n, 6) for n in v.co): uv for v, uv in values.items()}
    room = lip_room(border)
    result = bmesh.ops.extrude_edge_only(work, edges=border)
    for vertex in result['geom']:
        if not isinstance(vertex, bmesh.types.BMVert):
            continue
        key = tuple(round(n, 6) for n in vertex.co)
        values[vertex] = carried.get(key, CLOTH_UV)
        normal = normals.get(key)
        if normal is None or normal.length < 1e-6:
            normal = Vector((vertex.co.x, vertex.co.y, 0)).normalized()
        width = RIM * room.get(key, 1.0)
        # The hem is seen edge on, so a rolled lip shows there as a fold and a
        # square return does not. The hood's rim is seen face on, where the
        # square return is what shows.
        roll = ROLL if vertex.co.z > ROLL_ABOVE else 0.0
        vertex.co += inward.get(key, Vector()) * (width * roll) - normal * width
    for face in result['geom']:
        if isinstance(face, bmesh.types.BMFace):
            face.smooth = True
            paint_face(face, values, uv_layer)
    bmesh.ops.recalc_face_normals(work, faces=list(work.faces))
    count = len(work.faces)
    work.to_mesh(mesh)
    work.free()
    return count


def lip_room(border):
    """How much of the lip each boundary vertex has space for, 0 to 1.

    The front split closes to a hairline. Two full lips across a gap that narrow
    meet and fold back on each other, which measured 174 degrees. Each vertex
    gets only what the nearest unrelated boundary vertex leaves it.
    """
    points = list({vertex for edge in border for vertex in edge.verts})
    tree = KDTree(len(points))
    for index, vertex in enumerate(points):
        tree.insert(vertex.co, index)
    tree.balance()
    room = {}
    for vertex in points:
        linked = {edge.other_vert(vertex) for edge in vertex.link_edges}
        spare = RIM * 4
        for _, index, distance in tree.find_range(vertex.co, RIM * 4):
            other = points[index]
            if other is vertex or other in linked:
                continue
            spare = min(spare, distance)
        key = tuple(round(n, 6) for n in vertex.co)
        # Never below a floor: a lip thinned to nothing is a sliver face, which
        # costs more in the edge ratio than the overlap it avoids.
        room[key] = max(LIP_FLOOR, min(1.0, .45 * spare / RIM))
    return room


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


def rebuild(obj):
    """Replace the cloak mesh, keeping its shape, keys, material and UVs."""
    surface = OuterSurface(obj)
    captured = capture_keys(obj)
    grid = build_grid(surface)
    mesh = write(grid, surface)
    if RIM > 0:
        add_rim(mesh, surface)
    mesh.materials.append(obj.data.materials[0])
    old = obj.data
    obj.data = mesh
    bpy.data.meshes.remove(old)
    count = apply_keys(obj, captured)
    return count + (1 if add_arms_key(obj) else 0)

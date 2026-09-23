"""Rebuild the hair as chunky locks fitted to the head.

The inherited hair was a smooth double-walled helmet: 964 triangles, 79% quads,
10 ngons, two 28-valence poles at the crown, and no shape at all. Half its cost
was the second wall.

The new hair is one fitted shell. Every sample is a ray cast from the head's
centre onto the head itself, so the hair follows the skull instead of guessing
it, and the accepted hairline is measured off the old mesh rather than invented.

The cap keeps the accepted hairline, so the hood still fits: the hood clears the
old hair by only 0.039 at its tightest point, and a shell standing proud of the
old surface would push through it.

The locks are separate tufts grown off the cap's own hairline, by the same swept
ring method the arms use. Surface relief alone was tried first and is invisible
at this size: chibi hair reads by its outline, so the locks have to be part of
the outline. A lock shares its first ring with the cap, so the hair stays one
island and no seam can open.
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

# The accepted Low bun style, from the earlier bust study. Its hairline is the
# one the user approved: a side-swept fringe that sits higher on the forehead
# than the inherited cap, and slightly longer sides. The head has changed shape
# since that study, so the style is read in each head's own frame and re-fitted
# rather than copied vertex for vertex.
STYLE_FILE = HERE / 'hair_style_source.blend'
STYLE_PARTS = ('HairCap.Bun', 'Head')

# The hairline turns hard where it leaves the face, from 56 degrees of polar
# angle at the front to 143 at the side. Too few columns there cut the turn into
# a wedge down the cheek.
COLUMNS = 32
RINGS = 8                       # rings from the crown down to the hairline
CROWN_POLAR = math.radians(11)  # the first ring, so the crown fan stays small
LOCKS = 8                       # an integer, so the locks mirror about the face
# Half a period, so the fringe parts over the middle of the forehead instead of
# dropping a lock across the face.
LOCK_PHASE = math.pi
RIDGE = .048                    # a lock's own offset from the skull, if the
                                # accepted study is not available to measure
THINNEST = .034                 # below this the shell cuts into the skull,
                                # and it must stay above RIM so the lip is inside
THICKEST = .110                 # above this it pushes through the hood
SMOOTHING = 2                   # blur passes over the measured offsets
GROOVE = .012                   # how deep the parting between two locks is cut
# A lock may grow where the hairline already sits low. Over the face it may not:
# the face window is narrow, so any tuft there falls across an eye.
FACE_CLEAR = math.radians(115)
# Each lock covers this many columns of the hairline, and they are spaced this
# far apart. The centre column of each span is mirrored about the face, so the
# two sides match.
LOCK_WIDTH = 5
# Azimuths, so the locks stay put when the column count changes. The set maps
# onto itself when mirrored about the face.
LOCK_CENTRES = (0, 60, 120, 180, 240, 300)
LOCK_STEPS = 3                  # rings down a lock, before its tip
LOCK_REACH = .190               # how far a lock hangs below the hairline
LOCK_TAPER = .60                # a lock's width at the last ring, against its base
LOCK_CURL = .020                # how far a lock's tip swings away from the head
# The shoulders are at about z 2.00. A lock that reaches past this height rests
# inside them, so each lock's reach is cut to whatever room it has.
LOCK_FLOOR = 2.12
RIM = 0.030                     # the lip that turns the hairline back toward the skin
HAIR_UV = (.125, .56)
FRONT = -math.tau / 4           # the face centre, where a lock tip belongs
BINS = 48                       # azimuth samples used to read the old hairline
CAST_RANGE = 1.2                # outside the head, inside the far wall


def head_frame(obj):
    """The centre and half extents of an object's own biggest piece."""
    indices = largest_island(obj)
    points = [obj.matrix_world @ obj.data.vertices[i].co for i in indices]
    low = Vector((min(p.x for p in points), min(p.y for p in points),
                  min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points),
                   max(p.z for p in points)))
    return (low + high) / 2, (high - low) / 2


def approved_style(head):
    """The accepted bun hair, re-fitted to this head.

    Both heads are read in their own frames and one is mapped onto the other, so
    a hairline that sat a given way on the study head sits the same way here.
    """
    # A silent fallback would build different hair with no warning.
    if not STYLE_FILE.exists():
        raise FileNotFoundError(f'hair style source is missing: {STYLE_FILE}')
    # Loading objects also pulls in their meshes and materials. Left behind they
    # sit in the saved file with no users at all, so note what was there first.
    collections = (bpy.data.objects, bpy.data.meshes, bpy.data.materials,
                   bpy.data.images)
    present = [{block.name for block in group} for group in collections]

    def discard():
        # By name, and one group at a time. Removing a datablock invalidates any
        # other reference held to it, so a list of blocks goes stale mid loop.
        for group, known in zip(collections, present):
            for name in [b.name for b in group if b.name not in known and not b.users]:
                block = group.get(name)
                if block is not None and not block.users:
                    group.remove(block)

    with bpy.data.libraries.load(str(STYLE_FILE), link=False) as (source, target):
        target.objects = list(STYLE_PARTS)
    loaded = dict(zip(STYLE_PARTS, target.objects))
    if any(obj is None for obj in loaded.values()):
        for obj in loaded.values():
            if obj:
                bpy.data.objects.remove(obj, do_unlink=True)
        discard()
        raise RuntimeError(f'{STYLE_FILE.name} lacks one of {STYLE_PARTS}')
    # An object outside every collection keeps an identity matrix_world, so its
    # own placement would be lost. Link them before reading world positions.
    for obj in loaded.values():
        bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.update()
    here_centre, here_half = head_frame(head)
    there_centre, there_half = head_frame(loaded['Head'])
    cap = loaded['HairCap.Bun']
    placed = [cap.matrix_world @ v.co for v in cap.data.vertices]
    for vertex, point in zip(cap.data.vertices, placed):
        local = point - there_centre
        vertex.co = here_centre + Vector((local.x / there_half.x * here_half.x,
                                          local.y / there_half.y * here_half.y,
                                          local.z / there_half.z * here_half.z))
    cap.matrix_world = head.matrix_world.copy()

    def clean():
        for obj in loaded.values():
            bpy.data.objects.remove(obj, do_unlink=True)
        discard()

    return cap, clean


class Style:
    """The accepted hair's own thickness above the skull, in each direction.

    Carving the locks with a wave was guesswork and read as nothing. The study
    already holds the volume the user accepted, so the cap takes its offset from
    there and reproduces whatever partings and side locks the grid can express.
    """

    def __init__(self, cap):
        mesh = cap.data
        mesh.calc_loop_triangles()
        island = set(largest_island(cap))
        self.tree = BVHTree.FromPolygons(
            [cap.matrix_world @ v.co for v in mesh.vertices],
            [tuple(t.vertices) for t in mesh.loop_triangles
             if all(i in island for i in t.vertices)], all_triangles=True)

    def offset(self, centre, direction, skin):
        """How far the accepted hair stands off the skull along this ray."""
        origin = centre + direction * CAST_RANGE
        location, _, _, _ = self.tree.ray_cast(origin, -direction, CAST_RANGE)
        if location is None:
            return None
        return (location - skin).dot(direction)


class Skull:
    """The head surface, sampled by rays that leave its centre."""

    def __init__(self, head):
        mesh = head.data
        mesh.calc_loop_triangles()
        # The ears are their own islands on Head. A ray that hits an ear would
        # put the hair 0.08 further out there and bulge the cap over it.
        skull = set(largest_island(head))
        points = [v.co.copy() for v in mesh.vertices]
        faces = [tuple(t.vertices) for t in mesh.loop_triangles
                 if all(i in skull for i in t.vertices)]
        heights = [points[i].z for i in skull]
        self.centre = Vector((0, sum(points[i].y for i in skull) / len(skull),
                              (min(heights) + max(heights)) / 2))
        self.tree = BVHTree.FromPolygons(points, faces, all_triangles=True)

    def at(self, azimuth, polar):
        """The skull point and its outward normal in this direction."""
        location, normal, _, _ = self.tree.ray_cast(
            self.centre, ray(azimuth, polar), 3.0)
        if location is None:
            return None, None
        return location, (normal if normal.dot(ray(azimuth, polar)) > 0 else -normal)


def ray(azimuth, polar):
    return Vector((math.sin(polar) * math.cos(azimuth),
                   math.sin(polar) * math.sin(azimuth), math.cos(polar)))


def lock_wave(azimuth):
    """1.0 along a lock's centre line, 0.0 in the parting between two locks."""
    return .5 * (1 + math.cos(LOCKS * (azimuth - FRONT) + LOCK_PHASE))


def read_hairline(hair, skull):
    """The accepted hairline, found by casting at the old hair's own silhouette.

    Reading it as the lowest hair vertex in each azimuth bin does not work. Near
    the face the same bin holds both the edge of the face opening and the side
    hair behind it, so the lowest one wins and drags a wedge down the cheek.
    A cast answers whether there is hair in one exact direction, which is the
    question the hairline actually asks.

    Only the scalp island is cast against. The bun sits behind the head and would
    pull the line the wrong way.
    """
    mesh = hair.data
    mesh.calc_loop_triangles()
    scalp = set(largest_island(hair))
    tree = BVHTree.FromPolygons(
        [v.co.copy() for v in mesh.vertices],
        [tuple(t.vertices) for t in mesh.loop_triangles
         if all(i in scalp for i in t.vertices)], all_triangles=True)

    def covered(azimuth, polar):
        direction = Vector((math.sin(polar) * math.cos(azimuth),
                            math.sin(polar) * math.sin(azimuth), math.cos(polar)))
        origin = skull.centre + direction * CAST_RANGE
        location, _, _, _ = tree.ray_cast(origin, -direction, CAST_RANGE)
        return location is not None

    reach = []
    for index in range(BINS):
        azimuth = index * math.tau / BINS
        low, high = CROWN_POLAR, math.radians(175)
        if not covered(azimuth, low):
            reach.append(low)
            continue
        for _ in range(20):
            middle = (low + high) / 2
            if covered(azimuth, middle):
                low = middle
            else:
                high = middle
        reach.append(low)
    # One smoothing pass. The old mesh's own columns make the raw line step.
    return [(reach[(i - 1) % BINS] + 2 * reach[i] + reach[(i + 1) % BINS]) / 4
            for i in range(BINS)]


def scalp_island(hair):
    """The larger of the two hair islands: the cap, not the bun."""
    return [hair.data.vertices[i].co.copy() for i in largest_island(hair)]


def largest_island(obj):
    """The vertex indices of the object's biggest connected piece."""
    work = bmesh.new()
    work.from_mesh(obj.data)
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
        islands.append(island)
    work.free()
    return max(islands, key=len)


def hairline_at(reach, azimuth):
    """Read the measured hairline between bins."""
    position = (azimuth % math.tau) / math.tau * BINS
    low = int(position) % BINS
    blend = position - int(position)
    return reach[low] * (1 - blend) + reach[(low + 1) % BINS] * blend


def bun_island(hair):
    """The bun, kept as it is. The user accepted it."""
    mesh = hair.data
    scalp = {tuple(round(n, 6) for n in p) for p in scalp_island(hair)}
    keep = [v.index for v in mesh.vertices
            if tuple(round(n, 6) for n in v.co) not in scalp]
    chosen = set(keep)
    faces = [tuple(f.vertices) for f in mesh.polygons
             if all(i in chosen for i in f.vertices)]
    return {i: mesh.vertices[i].co.copy() for i in keep}, faces


def build(hair, head):
    """Replace the hair cap with a locked shell, and carry the bun over."""
    skull = Skull(head)
    style, release = approved_style(head)
    reach = read_hairline(style or hair, skull)
    volume = Style(style) if style else None
    bun_points, bun_faces = bun_island(hair)


    mesh = bpy.data.meshes.new('TravellerHair')
    work = bmesh.new()
    uv_layer = work.loops.layers.uv.verify()
    places, thickness = {}, {}
    for column in range(COLUMNS):
        azimuth = column * math.tau / COLUMNS
        limit = hairline_at(reach, azimuth)
        for ring in range(RINGS):
            polar = CROWN_POLAR + (limit - CROWN_POLAR) * ring / (RINGS - 1)
            location, normal = skull.at(azimuth, polar)
            if location is None:
                continue
            places[(ring, column)] = (location, normal)
            measured = None
            if volume is not None:
                measured = volume.offset(skull.centre, ray(azimuth, polar), location)
            if measured is None:
                measured = RIDGE - GROOVE * (1 - lock_wave(azimuth))
            thickness[(ring, column)] = max(THINNEST, min(THICKEST, measured))
    thickness = smooth(thickness)
    grid, skin = {}, {}
    for key, (location, normal) in places.items():
        grid[key] = work.verts.new(location + normal * thickness[key])
        skin[key] = location + normal * RIM
    faces = []
    for ring in range(RINGS - 1):
        for column in range(COLUMNS):
            following = (column + 1) % COLUMNS
            corners = [(ring, column), (ring, following),
                       (ring + 1, following), (ring + 1, column)]
            if any(k not in grid for k in corners):
                continue
            faces.append(work.faces.new([grid[k] for k in corners]))
    faces += cap_crown(work, grid, skull)
    spans = lock_spans(reach)
    for start in spans:
        faces += grow_lock(work, grid, start)
    faces += close_hairline(work, grid, skin, spans)
    faces += carry_bun(work, bun_points, bun_faces)
    for face in faces:
        face.smooth = True
        for loop in face.loops:
            loop[uv_layer].uv = HAIR_UV
    bmesh.ops.recalc_face_normals(work, faces=list(work.faces))
    work.to_mesh(mesh)
    work.free()
    mesh.materials.append(hair.data.materials[0])
    old = hair.data
    hair.data = mesh
    bpy.data.meshes.remove(old)
    # Only now: until the object holds it, the new mesh has no users either and
    # the purge would take it.
    release()
    return len(mesh.polygons)


def smooth(thickness, passes=SMOOTHING):
    """Blur the measured offsets over the grid.

    The study's own side lock ends in a step. Copied straight across it folds the
    new cap at 159 degrees, so the field is blurred: the volume stays, the crease
    goes.
    """
    for _ in range(passes):
        blurred = {}
        for (ring, column), value in thickness.items():
            total, weight = 2.0 * value, 2.0
            for step in (-1, 1):
                for key in ((ring, (column + step) % COLUMNS), (ring + step, column)):
                    if key in thickness:
                        total += thickness[key]
                        weight += 1
            blurred[(ring, column)] = total / weight
        thickness = blurred
    return thickness


def cap_crown(work, grid, skull):
    """Close the top ring with a fan onto the crown itself."""
    ring = [grid[(0, c)] for c in range(COLUMNS) if (0, c) in grid]
    if len(ring) != COLUMNS:
        return []
    location, normal = skull.at(0.0, 0.0)
    centre = sum((v.co for v in ring), Vector()) / COLUMNS
    apex = work.verts.new(location + normal * RIDGE if location else centre)
    return [work.faces.new([ring[c], ring[(c + 1) % COLUMNS], apex])
            for c in range(COLUMNS)]


def lock_spans(reach):
    """Where the locks start, skipping any span that reaches over the face."""
    spans = []
    for azimuth in LOCK_CENTRES:
        centre = round(azimuth / 360 * COLUMNS)
        start = (centre - LOCK_WIDTH // 2) % COLUMNS
        columns = [(start + n) % COLUMNS for n in range(LOCK_WIDTH + 1)]
        if all(hairline_at(reach, c * math.tau / COLUMNS) >= FACE_CLEAR
               for c in columns):
            spans.append(start)
    return spans


def span_edges(spans):
    """The hairline edges a lock grows from, so the lip skips them."""
    return {(start + n) % COLUMNS for start in spans for n in range(LOCK_WIDTH)}


def grow_lock(work, grid, start):
    """Sweep a tapered tuft off one span of the hairline, ending in a point.

    Each ring keeps going the way the cap was already going, so the lock leaves
    the head along the hair's own direction instead of stabbing out of it.
    """
    last = RINGS - 1
    base = [grid[(last, (start + n) % COLUMNS)] for n in range(LOCK_WIDTH + 1)]
    above = [grid[(last - 1, (start + n) % COLUMNS)] for n in range(LOCK_WIDTH + 1)]
    flow = [(b.co - a.co).normalized() for a, b in zip(above, base)]
    heading = (sum(flow, Vector()) / len(flow)).normalized()
    outward = sum((v.co for v in base), Vector()) / len(base)
    outward = Vector((outward.x, outward.y, 0)).normalized()
    reach = LOCK_REACH
    if heading.z < -1e-6:
        room = (min(v.co.z for v in base) - LOCK_FLOOR) / -heading.z
        reach = max(0.0, min(reach, room / (1 + 1 / LOCK_STEPS)))
    if reach < LOCK_REACH * .25:
        return []                       # no room for a tuft here
    ring, faces = base, []
    for step in range(1, LOCK_STEPS + 1):
        along = step / LOCK_STEPS
        centre = sum((v.co for v in base), Vector()) / len(base)
        width = 1 - (1 - LOCK_TAPER) * along
        following = []
        for vertex, direction in zip(base, flow):
            place = (vertex.co + direction * (reach * along)
                     + outward * (LOCK_CURL * along * along))
            middle = centre + direction * (reach * along)
            following.append(work.verts.new(middle + (place - middle) * width))
        for n in range(LOCK_WIDTH):
            faces.append(work.faces.new([ring[n], ring[n + 1],
                                         following[n + 1], following[n]]))
        ring = following
    # The tip carries on the way the lock was going. Put at the last ring's own
    # centre it makes a sliver edge and folds the tuft back on itself.
    tip = work.verts.new(sum((v.co for v in ring), Vector()) / len(ring)
                         + heading * (reach / LOCK_STEPS))
    faces += [work.faces.new([ring[n], ring[n + 1], tip]) for n in range(LOCK_WIDTH)]
    return faces


def close_hairline(work, grid, skin, spans):
    """Turn the free hairline onto the skin, so the shell is not a paper edge."""
    last = RINGS - 1
    if any((last, c) not in grid for c in range(COLUMNS)):
        return []
    grown = span_edges(spans)
    free = [c for c in range(COLUMNS) if c not in grown]
    # Only the columns a lip face actually uses. A lip vertex made for a column
    # that a lock covers has nothing attached and is left loose in the mesh.
    needed = {c for column in free for c in (column, (column + 1) % COLUMNS)}
    edge = {c: work.verts.new(skin[(last, c)]) for c in needed}
    return [work.faces.new([grid[(last, c)], grid[(last, (c + 1) % COLUMNS)],
                            edge[(c + 1) % COLUMNS], edge[c]])
            for c in free]


def carry_bun(work, points, faces):
    """Copy the bun island across unchanged."""
    remap = {index: work.verts.new(point) for index, point in points.items()}
    work.verts.index_update()
    return [work.faces.new([remap[i] for i in face]) for face in faces]

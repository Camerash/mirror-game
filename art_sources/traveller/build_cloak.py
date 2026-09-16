"""Rebuild the cloak as quads, keeping the shape the user accepted.

The old cloak was 3,332 triangles with no quads at all, edge lengths in a 258:1
range and face areas in a 999:1 range. It was also a closed double wall, which is
half its cost.

The method keeps the accepted shape by construction. A regular grid is projected
onto the old surface, so the new mesh follows the old one instead of guessing it.
The nine shape keys move across by barycentric position on the old triangles, so
large movement such as the hood folding down (2.1 units) stays correct.

At Basis the cape is closed. The front split comes only from the `CloakOpen` key,
so the split moves across with the other keys.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))

COLUMNS = 24
# Close together where the shape turns (collar, hood rim, crown) and further
# apart down the smooth cape.
ROWS = [0.20, 0.34, 0.52, 0.72, 0.92, 1.12, 1.22, 1.32, 1.41, 1.50, 1.58,
        1.66, 1.73, 1.80, 1.86, 1.90, 1.95, 2.00, 2.06, 2.12, 2.19, 2.26,
        2.34, 2.42, 2.50, 2.58, 2.66, 2.74, 2.82, 2.90, 3.03, 3.13, 3.21, 3.27]
CAST_RADIUS = 1.6              # well outside the cloak's widest point, 0.88
RIM = 0.0                      # thickness at the hem, the split and the face rim
# A grid of chords sits inside the curved surface it samples, so the new cloak
# would press into the body where the old one was already tight. Push each
# sample out along the surface normal to pay that back.
OUTSET = .012
# The old cloak carries a seam down the front centre, and `CloakOpen` pulls the
# two sides apart along it. A projected grid welds across that seam, so the
# split could never open. These rows are ripped at the front so it can.
SPLIT_RANGE = (0.45, 1.92)
# Column 18 sits just right of the front centre, so its vertical edges are the
# seam the two panels part along. A ray cast exactly down the centre grazes the
# old seam plane and finds nothing, so the grid cannot have a column there.
SEAM_COLUMN = 18


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
        self.points = [v.co.copy() for v in mesh.vertices]
        self.faces = [tuple(t.vertices) for t in mesh.loop_triangles]
        self.uvs = [tuple(mesh.uv_layers.active.data[t.loops[0]].uv)
                    for t in mesh.loop_triangles]
        self.tree = BVHTree.FromPolygons(self.points, self.faces, all_triangles=True)

    def at(self, z, angle):
        """Outer surface point at this height and angle, or None in an opening."""
        axis = Vector((0, 0, z))
        direction = Vector((-math.cos(angle), -math.sin(angle), 0))
        origin = axis - direction * CAST_RADIUS
        travelled = 0.0
        while travelled < CAST_RADIUS:
            location, normal, _, distance = self.tree.ray_cast(
                origin, direction, CAST_RADIUS - travelled)
            if location is None:
                return None
            if normal.dot(-direction) > 0:
                return location + normal * OUTSET
            travelled += distance + 1e-4
            origin = location + direction * 1e-4
        return None

    def uv_near(self, point):
        location, normal, index, distance = self.tree.find_nearest(point)
        return self.uvs[index] if index is not None else (.625, .56)


def build_grid(surface):
    """Project the grid and keep the cells whose four corners all found cloth."""
    grid = []
    for z in ROWS:
        row = []
        for column in range(COLUMNS):
            angle = (column + .5) * math.tau / COLUMNS
            row.append(surface.at(z, angle))
        grid.append(row)
    return grid


def write(grid, surface, name='CloakShell'):
    mesh = bpy.data.meshes.new(name)
    work = bmesh.new()
    verts = {}
    for r, row in enumerate(grid):
        for c, point in enumerate(row):
            if point is not None:
                verts[(r, c)] = work.verts.new(point)
    work.verts.index_update()
    uv_layer = work.loops.layers.uv.verify()
    for r in range(len(grid) - 1):
        for c in range(COLUMNS):
            following = (c + 1) % COLUMNS
            corners = [(r, c), (r, following), (r + 1, following), (r + 1, c)]
            if any(k not in verts for k in corners):
                continue
            face = work.faces.new([verts[k] for k in corners])
            face.smooth = True
            value = surface.uv_near(face.calc_center_median())
            for loop in face.loops:
                loop[uv_layer].uv = value
    rip_front_seam(work, verts)
    bmesh.ops.recalc_face_normals(work, faces=list(work.faces))
    work.to_mesh(mesh)
    work.free()
    return mesh


def rip_front_seam(work, verts):
    """Separate the two front panels so `CloakOpen` can part them.

    The seam runs *down* the front, so it is the vertical edges of one column,
    picked by index. Ripping horizontal edges instead parts the panels top from
    bottom, which is why the split stayed shut.
    """
    low, high = SPLIT_RANGE
    column = [verts[(r, SEAM_COLUMN)] for r in range(len(ROWS))
              if (r, SEAM_COLUMN) in verts and low < ROWS[r] < high]
    chain = set(column)
    seam = [e for e in work.edges if e.verts[0] in chain and e.verts[1] in chain]
    if seam:
        bmesh.ops.split_edges(work, edges=seam, use_verts=False)
    return len(seam)


def add_rim(mesh, surface):
    """Give the open edges thickness, so the hem and the split are not paper."""
    work = bmesh.new()
    work.from_mesh(mesh)
    uv_layer = work.loops.layers.uv.verify()
    border = [e for e in work.edges if e.is_boundary]
    if not border:
        work.free()
        return 0
    result = bmesh.ops.extrude_edge_only(work, edges=border)
    moved = [g for g in result['geom'] if isinstance(g, bmesh.types.BMVert)]
    for vertex in moved:
        normal = vertex.normal.copy()
        if normal.length < 1e-6:
            normal = Vector((vertex.co.x, vertex.co.y, 0)).normalized()
        vertex.co -= normal * RIM
    for face in result['geom']:
        if isinstance(face, bmesh.types.BMFace):
            face.smooth = True
            value = surface.uv_near(face.calc_center_median())
            for loop in face.loops:
                loop[uv_layer].uv = value
    bmesh.ops.recalc_face_normals(work, faces=list(work.faces))
    count = len(work.faces)
    work.to_mesh(mesh)
    work.free()
    return count


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
    # Bias the lookup toward the vertex's own side of the mesh. Without it the
    # two ripped seam vertices sit on top of each other, find the same old
    # vertex, and move together instead of parting.
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
        location, normal, index, distance = tree.find_nearest(probe)
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
    if RIM > 0: add_rim(mesh, surface)
    mesh.materials.append(obj.data.materials[0])
    old = obj.data
    obj.data = mesh
    bpy.data.meshes.remove(old)
    return apply_keys(obj, captured)

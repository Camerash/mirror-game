"""Build-time checks for the Traveller body.

Runs while the builder's part tags are still in scope, so a crossing can be
named ("armR vs legR") instead of just counted.
"""
import collections

import bpy
from mathutils.bvhtree import BVHTree


def surface(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = evaluated.data
    data.calc_loop_triangles()
    return ([evaluated.matrix_world @ v.co for v in data.vertices],
            [tuple(t.vertices) for t in data.loop_triangles])


def crossings(obj, parts=None):
    """True surface crossings, ignoring triangles that merely share a vertex."""
    points, faces = surface(obj)
    tree = BVHTree.FromPolygons(points, faces, all_triangles=True)
    pairs = [(a, b) for a, b in tree.overlap(tree)
             if a < b and not set(faces[a]).intersection(faces[b])]
    if parts is None:
        return len(pairs), collections.Counter()
    def label(face):
        return collections.Counter(parts[i] for i in face).most_common(1)[0][0]
    tally = collections.Counter(tuple(sorted((label(faces[a]), label(faces[b]))))
                               for a, b in pairs)
    return len(pairs), tally


def report(obj, build):
    """Print crossings grouped by the parts that produced them."""
    parts = [build.parts[i] for i in build.kept]
    total, tally = crossings(obj, parts)
    print('### self-intersections:', total)
    for pair, count in tally.most_common(14):
        print('   ', pair, count)
    return total


def measure(body_name='Body'):
    """Measured proportions of the built character, not the chart's prediction."""
    import mathutils
    def bounds(name):
        obj = bpy.data.objects[name]
        points = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
        return (min(p.z for p in points), max(p.z for p in points),
                min(p.x for p in points), max(p.x for p in points))
    head_z0, head_z1, head_x0, head_x1 = bounds('Head')
    floor = bounds('Boots')[0]
    top = max(bounds('Hair')[1], head_z1)
    total = top - floor
    head = head_z1 - head_z0
    rig = bpy.data.objects['Rig']
    body = bpy.data.objects[body_name]
    names = {g.index: g.name for g in body.vertex_groups}
    # Measured on the evaluated mesh, so the idle pose is what gets reported.
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    hand = [v.co.z for v, source in zip(evaluated.data.vertices, body.data.vertices)
            if any(names[g.group].startswith(('Hand.', 'Fingers.', 'Thumb.'))
                   and g.weight > .5 for g in source.groups)]
    shoulder = rig.data.bones['UpperArm.R'].head_local.z
    hip = rig.data.bones['Thigh.R'].head_local.z
    chest = 2 * max(abs(v.co.x) for v in body.data.vertices
                    if 1.50 < v.co.z < 1.70 and abs(v.co.y) < .06)
    return {'heads_tall': round(total / head, 2),
            'head_pct': round(head / total * 100),
            'arm_pct': round((shoulder - min(hand)) / total * 100),
            'leg_pct': round((hip - floor) / total * 100),
            'fingertip_z': round(min(hand), 3),
            'head_over_chest': round((head_x1 - head_x0) / chest, 2)}


def palette_regions(body_name='Body'):
    """Distinct atlas points used, so an interleaved cuff shows up as a count."""
    mesh = bpy.data.objects[body_name].data
    uv = mesh.uv_layers.active.data
    return collections.Counter(
        (round(uv[loop].uv.x, 3), round(uv[loop].uv.y, 3))
        for polygon in mesh.polygons for loop in polygon.loop_indices)


def clearance(body, others=('Garment', 'Head', 'Hair', 'Boots')):
    """Overlap counts against the other character meshes."""
    points, faces = surface(body)
    tree = BVHTree.FromPolygons(points, faces, all_triangles=True)
    result = {}
    for name in others:
        other = bpy.data.objects.get(name)
        if not other:
            continue
        points, faces = surface(other)
        result[name] = len(tree.overlap(BVHTree.FromPolygons(points, faces, all_triangles=True)))
    return result

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

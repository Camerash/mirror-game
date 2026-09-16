"""Audit the whole character and report what is worth improving.

Run with:
    Blender --background art_sources/traveller/traveller.blend \
        --python art_sources/traveller/review_mesh.py
"""
import collections
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))

CEILING = 8000      # GAME_DESIGN.md
TARGET = 6000
PARTS = ('Body', 'Head', 'Hair', 'Garment', 'Boots')


def topology(obj):
    mesh = obj.data
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
    poles = collections.Counter(len(v.link_edges) for v in work.verts)
    lengths = sorted(e.calc_length() for e in work.edges) or [0]
    areas = sorted(f.calc_area() for f in work.faces) or [1]
    sharp = sorted((math.degrees(e.calc_face_angle(0)), e.index)
                   for e in work.edges if len(e.link_faces) == 2)
    report = {
        'verts': len(work.verts),
        'tris': sum(len(f.verts) - 2 for f in work.faces),
        'quad_pct': round(100 * quads / max(quads + tris + ngons, 1)),
        'tri_faces': tris, 'ngons': ngons,
        'islands': len(islands),
        'non_manifold': sum(1 for e in work.edges if not e.is_manifold),
        'boundary': sum(1 for e in work.edges if e.is_boundary),
        'poles': {k: v for k, v in sorted(poles.items()) if k not in (3, 4)},
        'edge_ratio': round(lengths[-1] / max(lengths[0], 1e-9)),
        'area_ratio': round(areas[-1] / max(areas[0], 1e-12)),
        'sharpest': round(sharp[-1][0], 1) if sharp else 0,
    }
    work.free()
    return report


def surface(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = evaluated.data
    data.calc_loop_triangles()
    return ([evaluated.matrix_world @ v.co for v in data.vertices],
            [tuple(t.vertices) for t in data.loop_triangles])


def hidden_inside(obj, others):
    """Triangles fully inside another opaque mesh - geometry nobody will see."""
    points, faces = surface(obj)
    trees = []
    for name in others:
        other = bpy.data.objects.get(name)
        if other and other is not obj:
            p, f = surface(other)
            trees.append((other.name, p, BVHTree.FromPolygons(p, f, all_triangles=True)))
    buried = collections.Counter()
    for face in faces:
        centre = sum((points[i] for i in face), Vector()) / 3
        for name, p, tree in trees:
            hit = tree.ray_cast(centre, Vector((0, 0, 1)))
            down = tree.ray_cast(centre, Vector((0, 0, -1)))
            side = tree.ray_cast(centre, Vector((1, 0, 0)))
            if hit[0] is not None and down[0] is not None and side[0] is not None:
                buried[name] += 1
                break
    return buried


def main():
    print('### PART TOPOLOGY')
    total = 0
    rows = {}
    for name in PARTS:
        obj = bpy.data.objects.get(name)
        if not obj:
            continue
        rows[name] = topology(obj)
        total += rows[name]['tris']
    for name, r in sorted(rows.items(), key=lambda kv: -kv[1]['tris']):
        share = round(100 * r['tris'] / total)
        print(f"   {name:8s} {r['tris']:5d} tris ({share:2d}%)  verts {r['verts']:4d}  "
              f"quads {r['quad_pct']:3d}%  tri {r['tri_faces']:3d}  ngon {r['ngons']:2d}  "
              f"islands {r['islands']}")
        print(f"            non-manifold {r['non_manifold']}  boundary {r['boundary']}  "
              f"poles {r['poles']}  edge-ratio {r['edge_ratio']}:1  "
              f"area-ratio {r['area_ratio']}:1  sharpest {r['sharpest']}deg")
    print(f"### TOTAL {total} tris   target {TARGET}   ceiling {CEILING}")

    print('### GEOMETRY NOBODY SEES (triangles enclosed by another opaque mesh)')
    for name in PARTS:
        obj = bpy.data.objects.get(name)
        if not obj:
            continue
        buried = hidden_inside(obj, PARTS)
        if buried:
            print(f"   {name:8s} {dict(buried)}")

    print('### RIG')
    rig = bpy.data.objects.get('Rig')
    body = bpy.data.objects['Body']
    names = {g.index: g.name for g in body.vertex_groups}
    used = collections.Counter()
    for vertex in body.data.vertices:
        for group in vertex.groups:
            if group.weight > .001:
                used[names[group.group]] += 1
    dead = [b.name for b in rig.data.bones if b.use_deform and b.name not in used]
    print(f"   bones {len(rig.data.bones)}  carrying weight {len(used)}  "
          f"unweighted deform bones {dead}")
    influences = [sum(1 for g in v.groups if g.weight > .001) for v in body.data.vertices]
    print(f"   max influences {max(influences)}  mean {sum(influences)/len(influences):.2f}")

    print('### DATABLOCK CLUTTER')
    orphans = [d.name for c in (bpy.data.materials, bpy.data.images, bpy.data.meshes,
                                bpy.data.actions, bpy.data.armatures) for d in c if d.users == 0]
    print(f"   zero-user datablocks: {orphans or 'none'}")
    print(f"   objects {len(bpy.data.objects)}: "
          f"{[o.name for o in bpy.data.objects if o.type not in ('MESH',)]}")

    print('### SYMMETRY (Body, mirrored vertex match)')
    mesh = body.data
    lookup = {(round(-v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)) for v in mesh.vertices}
    missing = sum(1 for v in mesh.vertices
                  if (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)) not in lookup)
    print(f"   vertices without a mirror partner: {missing} of {len(mesh.vertices)}")


if __name__ == '__main__':
    main()

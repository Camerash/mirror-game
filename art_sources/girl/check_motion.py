"""Measure her actions in girl.blend. Never saves.

    blender -b art_sources/girl/girl.blend --python art_sources/girl/check_motion.py

- ground: the lowest point of the evaluated mesh in every frame (snow is z 0)
- slide: Walk stance boot soles must move back at the ground speed (1.5 units/s)
- coat: leg and boot faces that cross the coat's outer surface (the hidden
  inner cap is skipped), per frame of the Walk
- clearance: the left mitten against the head, hair and beanie (Raise, Wave, Lift)
"""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

FPS = 60
WALK_SPEED = 1.1
rig = bpy.data.objects['Girl']
coll = bpy.data.collections['Girl']


def use(name):
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    rig.animation_data.action_slot = act.slots[0]
    return int(act.frame_range[1])


def world_verts(obj, dg):
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    m = ev.matrix_world
    verts = [m @ v.co for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    return verts, polys


def tree(obj, dg, keep=None):
    verts, polys = world_verts(obj, dg)
    if keep:
        polys = [p for p in polys if keep(verts, p)]
    return BVHTree.FromPolygons(verts, polys), verts


def outer_coat(verts, poly):
    c = sum((verts[i] for i in poly), Vector()) / len(poly)
    r = Vector((c.x, c.y - 0.004, 0)).length
    # the inner hem turn and the hidden cap sit inside the hem, r < 0.10
    return r > 0.10 or c.z > 0.30


def main():
    scene = bpy.context.scene
    report = []
    for name in ('Idle', 'Walk', 'Wake', 'Lift', 'Raise', 'Lower', 'Wave'):
        end = use(name)
        low, worst_overlap, clear = 1e9, 0, 1e9
        boot_y = []
        for f in range(0, end + 1):
            scene.frame_set(f)
            dg = bpy.context.evaluated_depsgraph_get()
            for obj in coll.objects:
                if obj.type == 'MESH':
                    verts, _ = world_verts(obj, dg)
                    low = min(low, min(v.z for v in verts))
            if name == 'Walk':
                coat, _ = tree(bpy.data.objects['Coat'], dg, outer_coat)
                hits = 0
                for part in ('Leg.L', 'Leg.R', 'Boot.L', 'Boot.R'):
                    t, _ = tree(bpy.data.objects[part], dg)
                    hits += len(coat.overlap(t))
                worst_overlap = max(worst_overlap, hits)
                verts, _ = world_verts(bpy.data.objects['Boot.L'], dg)
                sole = [v for v in verts if v.z < 0.004] or verts
                boot_y.append(sum(v.y for v in sole) / len(sole))
            if name in ('Raise', 'Wave', 'Lift', 'Lower'):
                mit, _ = world_verts(bpy.data.objects['Mitten.L'], dg)
                for part in ('Head', 'Hair', 'Beanie'):
                    t, _ = tree(bpy.data.objects[part], dg)
                    for v in mit[::3]:
                        hit = t.find_nearest(v)
                        if hit[0] is not None:
                            clear = min(clear, hit[3])
        line = '### %-6s ground min z %+.4f' % (name, low)
        if name == 'Walk':
            half = end // 2
            speeds = [(boot_y[f + 1] - boot_y[f]) * FPS for f in range(0, half - 1)]
            line += ' | stance boot speed %.3f..%.3f (want %.2f) | coat/leg overlaps max %d' % (
                min(speeds), max(speeds), WALK_SPEED, worst_overlap)
        if clear < 1e9:
            line += ' | mitten to head/hair/beanie min %.4f' % clear
        report.append(line)
    rig.animation_data.action = None
    scene.frame_set(0)
    dg = bpy.context.evaluated_depsgraph_get()
    coat, _ = tree(bpy.data.objects['Coat'], dg, outer_coat)
    rest = sum(len(coat.overlap(tree(bpy.data.objects[p], dg)[0])) for p in ('Leg.L', 'Leg.R', 'Boot.L', 'Boot.R'))
    report.append('### rest pose coat/leg overlaps %d' % rest)
    print('\n'.join(report))


main()

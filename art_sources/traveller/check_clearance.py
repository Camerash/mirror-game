"""Count the frames where an arm passes through the garment.

Run with:
    Blender --background art_sources/traveller/traveller.blend \
        --python art_sources/traveller/check_clearance.py

The animation notes carried this number as a hand measurement, "122 to 262
triangle pairs". That was taken at two frames. Measured at every frame of both
clips it is 78 to 374, on 58 of the 61 frames, so the hand measurement was not
the worst case and could not show a change. This script makes the number
repeatable.

It poses the rig from `hood_motion` through `build_animation.pose_frame` instead
of playing the NLA tracks. The tracks are muted and slotted, and the clips are
written from that same data, so posing from the data measures what the clips
hold and needs no track to be unmuted.

A crossing is a triangle of the arms that intersects a triangle of the garment.
The arms are the body vertices whose largest weight belongs to an arm bone.
"""
import sys
from pathlib import Path

import bpy
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_animation as anim
import hood_motion as motion

ARM_BONES = ('UpperArm', 'Forearm', 'Hand', 'Fingers')


def arm_vertices(body):
    """Body vertices that belong to an arm, by their largest weight."""
    names = {group.index: group.name for group in body.vertex_groups}
    chosen = set()
    for vertex in body.data.vertices:
        best = max(vertex.groups, key=lambda g: g.weight, default=None)
        if best is not None and names[best.group].startswith(ARM_BONES):
            chosen.add(vertex.index)
    return chosen


def surface(obj, keep=None):
    """World-space points and triangles of the evaluated mesh."""
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = evaluated.data
    data.calc_loop_triangles()
    points = [evaluated.matrix_world @ v.co for v in data.vertices]
    triangles = [tuple(t.vertices) for t in data.loop_triangles
                 if keep is None or any(i in keep for i in t.vertices)]
    return points, triangles


# Cloth above this height in the garment's own rest shape is the hood. The two
# are worth separating: a hole in the cape can clear the cape, and only the
# hood's own fold can clear the hood.
HOOD_REST_Z = 2.20


def crossings(body, garment, keep):
    """How many arm triangles meet cloth, split into cape and hood."""
    points, triangles = surface(body, keep)
    cloth_points, cloth_triangles = surface(garment)
    arms = BVHTree.FromPolygons(points, triangles, all_triangles=True)
    cloth = BVHTree.FromPolygons(cloth_points, cloth_triangles, all_triangles=True)
    rest = garment.data.shape_keys.key_blocks[0].data
    cape = hood = 0
    for _, index in arms.overlap(cloth):
        if max(rest[i].co.z for i in cloth_triangles[index]) > HOOD_REST_Z:
            hood += 1
        else:
            cape += 1
    return cape, hood


def clip_counts(rig, body, garment, keep, phases, path, rests):
    """The crossing count at every frame of one clip."""
    blocks = garment.data.shape_keys.key_blocks
    counts = []
    for frame in range(motion.LAST + 1):
        anim.pose_frame(rig, path, frame, rests)
        weights = motion.phase_weights(phases, frame)
        weights['CloakOpen'] = motion.at(motion.OPEN, frame)
        weights['CloakArms'] = motion.at(motion.ARMS, frame)
        for block in blocks[1:]:
            block.value = weights.get(block.name, 0.0)
        bpy.context.view_layer.update()
        counts.append(crossings(body, garment, keep))
    return counts


def main():
    rig = bpy.data.objects['Rig']
    body = bpy.data.objects['Body']
    garment = bpy.data.objects['Garment']
    keep = arm_vertices(body)
    rests = {'R': anim.idle_wrist(rig, 'R')}
    print('### arm vertices %d' % len(keep))
    failures = {'cape': 0, 'hood': 0}
    for name, (phases, path) in anim.CLIPS.items():
        counts = clip_counts(rig, body, garment, keep, phases, path, rests)
        for which, column in (('cape', 0), ('hood', 1)):
            bad = [f for f, c in enumerate(counts) if c[column]]
            failures[which] += len(bad)
            if not bad:
                print('### %s %s: clear at every frame' % (name, which))
                continue
            worst = max(c[column] for c in counts)
            print('### %s %s: %d of %d frames cross, worst %d at frame %d'
                  % (name, which, len(bad), len(counts), worst,
                     [c[column] for c in counts].index(worst)))
            print('    frames %s'
                  % ' '.join('%d:%d' % (f, counts[f][column]) for f in bad))
    anim.clear_pose(rig)
    for block in garment.data.shape_keys.key_blocks[1:]:
        block.value = 0.0
    print('### arm crossing frames: cape %d, hood %d  (both must be 0)'
          % (failures['cape'], failures['hood']))


if __name__ == '__main__':
    main()

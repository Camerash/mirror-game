"""Prove the walk: that it loops, that it clears the cloth, and that the three
cloak deformations read the caps the design sets.

Run with:
    Blender --background art_sources/traveller/traveller.blend \
        --python art_sources/traveller/check_walk.py

`GAME_DESIGN.md` line 102 caps sway at 0.032 units and twist at 6 degrees, and
pins the shoulders. Those are numbers, so they are checked rather than trusted.

The gait's own hem travel is checked against the same sway cap. It has to be:
`skin_body.cloak` clamps the cloak's hem and knee to `Pelvis`, so every bit of
hem motion the walk makes by itself comes from the pelvis channels, and two
degrees of pelvis twist alone already moves the hem 0.0417.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_animation as anim
import build_cloak
import check_clearance
import walk_motion as walk

LEG_BONES = ('Thigh', 'Shin', 'Foot')
DRIFT = (build_cloak.SWAY_KEY, build_cloak.SURGE_KEY, build_cloak.TWIST_KEY)
PINNED = 0.004          # what counts as still, at the collar and above


def leg_vertices(body):
    names = {group.index: group.name for group in body.vertex_groups}
    chosen = set()
    for vertex in body.data.vertices:
        best = max(vertex.groups, key=lambda g: g.weight, default=None)
        if best is not None and names[best.group].startswith(LEG_BONES):
            chosen.add(vertex.index)
    return chosen


def bone_pose(rig):
    return [tuple(round(value, 6) for value in bone.matrix_basis.to_quaternion())
            + tuple(round(value, 6) for value in bone.location)
            for bone in rig.pose.bones]


def check_loop(rig):
    anim.pose_walk(rig, 0)
    first = bone_pose(rig)
    anim.pose_walk(rig, walk.LAST)
    last = bone_pose(rig)
    same = first == last
    print('### walk loops: frame 0 and frame %d are the same pose: %s'
          % (walk.LAST, 'yes' if same else 'NO'))
    return same


def check_clearance_over_walk(rig, body, garment):
    keep = leg_vertices(body)
    blocks = garment.data.shape_keys.key_blocks
    for block in blocks[1:]:
        block.value = 0.0
    bad = []
    for frame in range(walk.LAST + 1):
        anim.pose_walk(rig, frame)
        count = check_clearance.crossings(body, garment, keep)
        if count:
            bad.append((frame, count))
    print('### leg vertices %d' % len(keep))
    if bad:
        print('### legs cross the cloak on %d of %d frames: %s'
              % (len(bad), walk.LAST + 1,
                 ' '.join('%d:%d' % row for row in bad)))
    else:
        print('### legs clear the cloak at every frame')
    return not bad


def check_gait_hem(rig, garment):
    """How far the gait alone sways the hem, against the sway cap.

    Sway is sideways, so this measures the horizontal travel. The pelvis also
    lifts the whole body twice a cycle and the cloak rides up with it; that is
    the gait's rise, not sway, and it is reported beside the sway rather than
    added to it.
    """
    blocks = garment.data.shape_keys.key_blocks
    for block in blocks[1:]:
        block.value = 0.0
    rest = [blocks[0].data[i].co.copy() for i in range(len(blocks[0].data))]
    hem = [i for i, point in enumerate(rest) if point.z <= 0.40]
    anim.clear_pose(rig)
    bpy.context.view_layer.update()
    still = evaluated(garment)
    worst = rise = 0.0
    for frame in range(walk.LAST + 1):
        anim.pose_walk(rig, frame)
        moved = evaluated(garment)
        for i in hem:
            offset = moved[i] - still[i]
            worst = max(worst, math.hypot(offset.x, offset.y))
            rise = max(rise, abs(offset.z))
    print('### the gait alone sways the hem %.4f (cap %.3f) %s, and lifts it %.4f'
          % (worst, build_cloak.SWAY,
             'ok' if worst <= build_cloak.SWAY else 'OVER', rise))
    return worst <= build_cloak.SWAY


def evaluated(obj):
    bpy.context.view_layer.update()
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    return [ev.matrix_world @ v.co for v in ev.data.vertices]


def check_drift(rig, garment):
    """Each deformation at 1 reads its cap, and leaves the shoulders alone."""
    anim.clear_pose(rig)
    blocks = garment.data.shape_keys.key_blocks
    for block in blocks[1:]:
        block.value = 0.0
    rest = evaluated(garment)
    local = [blocks[0].data[i].co.copy() for i in range(len(blocks[0].data))]
    hem = [i for i, point in enumerate(local) if point.z <= 0.40]
    above = [i for i, point in enumerate(local) if point.z >= 1.90]
    good = True
    for name in DRIFT:
        for block in blocks[1:]:
            block.value = 0.0
        blocks[name].value = 1.0
        moved = evaluated(garment)
        travel = max((moved[i] - rest[i]).length for i in hem)
        pinned = max((moved[i] - rest[i]).length for i in above)
        if name == build_cloak.TWIST_KEY:
            turn = max(abs(math.degrees(
                (math.atan2(moved[i].y, moved[i].x)
                 - math.atan2(rest[i].y, rest[i].x) + math.pi) % math.tau - math.pi))
                for i in hem if rest[i].length > 1e-6)
            cap = math.degrees(build_cloak.TWIST)
            ok = turn <= cap + .05 and pinned <= PINNED
            print('### %-13s hem turns %.2f deg (cap %.0f)  above the collar %.4f  %s'
                  % (name, turn, cap, pinned, 'ok' if ok else 'FAIL'))
        else:
            ok = travel <= build_cloak.SWAY + .0005 and pinned <= PINNED
            print('### %-13s hem moves %.4f (cap %.3f)  above the collar %.4f  %s'
                  % (name, travel, build_cloak.SWAY, pinned, 'ok' if ok else 'FAIL'))
        good = good and ok
    for block in blocks[1:]:
        block.value = 0.0
    return good


def main():
    rig = bpy.data.objects['Rig']
    body = bpy.data.objects['Body']
    garment = bpy.data.objects['Garment']
    results = [check_loop(rig),
               check_clearance_over_walk(rig, body, garment),
               check_gait_hem(rig, garment),
               check_drift(rig, garment)]
    anim.clear_pose(rig)
    print('### walk checks: %d of %d pass' % (sum(results), len(results)))


if __name__ == '__main__':
    main()

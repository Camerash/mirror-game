"""Add the armature and skin weights to girl.blend (run once on the blockout).

    blender -b art_sources/girl/girl.blend --python art_sources/girl/rig_setup.py

Bones sit at the blockout's joints. Weights are set from each vertex's
position, part by part, so they stay predictable: rigid parts follow one bone,
limbs blend across the joint, and the coat blends hips -> spine -> chest with
its lower front and back following the thighs a little, so the hem swings and
the legs never push through it.
"""
import math

import bpy
from mathutils import Vector

# name: (head, tail, parent)
BONES = {
    'Root': ((0, 0, 0), (0, 0, 0.06), None),
    'Hips': ((0, 0.004, 0.275), (0, 0.004, 0.33), 'Root'),
    'Spine': ((0, 0.004, 0.33), (0, 0.004, 0.40), 'Hips'),
    'Chest': ((0, 0.004, 0.40), (0, 0.004, 0.47), 'Spine'),
    'Neck': ((0, 0.006, 0.47), (0, 0.006, 0.53), 'Chest'),
    'Head': ((0, 0.006, 0.53), (0, 0.006, 0.70), 'Neck'),
    'Hair': ((0, 0.010, 0.62), (0, 0.040, 0.52), 'Head'),
    'Pompom': ((0, 0.004, 0.745), (0, 0.004, 0.80), 'Head'),
}
for s, side in (('L', 1), ('R', -1)):
    shoulder = Vector((side * 0.060, 0.004, 0.452))
    elbow = Vector((side * 0.098, -0.002, 0.362))
    wrist = Vector((side * 0.130, -0.006, 0.262))
    d = (wrist - elbow).normalized()
    BONES['UpperArm.' + s] = (shoulder, elbow, 'Chest')
    BONES['LowerArm.' + s] = (elbow, wrist, 'UpperArm.' + s)
    BONES['Hand.' + s] = (wrist, wrist + d * 0.05, 'LowerArm.' + s)
    BONES['UpperLeg.' + s] = ((side * 0.037, 0.004, 0.275), (side * 0.038, 0.003, 0.160), 'Hips')
    BONES['LowerLeg.' + s] = ((side * 0.038, 0.003, 0.160), (side * 0.040, 0.004, 0.045), 'UpperLeg.' + s)
    BONES['Foot.' + s] = ((side * 0.040, 0.004, 0.045), (side * 0.040, -0.045, 0.012), 'LowerLeg.' + s)


def smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def torso_weights(p):
    """Coat, hood and toggles: hips -> spine -> chest by height, the shoulders
    a little to the upper arm, the lower coat partly to the thigh on its side."""
    w = {}
    up = smooth(0.30, 0.36, p.z)            # hips -> spine
    top = smooth(0.38, 0.44, p.z)           # spine -> chest
    w['Hips'] = 1 - up
    w['Spine'] = up * (1 - top)
    w['Chest'] = up * top
    if p.z > 0.47:
        n = smooth(0.47, 0.51, p.z) * 0.5
        w['Neck'] = n
        w['Chest'] *= 1 - n
    for s, side in (('L', 1), ('R', -1)):
        reach = smooth(0.060, 0.095, p.x * side) * smooth(0.40, 0.44, p.z)
        if reach > 0:
            arm = 0.35 * reach
            for k in w:
                w[k] *= 1 - arm
            w['UpperArm.' + s] = arm
    leg_side = smooth(-0.02, 0.05, p.x)     # 0 = right, 1 = left
    low = smooth(0.27, 0.19, p.z)
    front = 0.55 if p.y < 0.004 else 0.30
    thigh = low * front
    if thigh > 0:
        for k in w:
            w[k] *= 1 - thigh
        w['UpperLeg.L'] = w.get('UpperLeg.L', 0) + thigh * leg_side
        w['UpperLeg.R'] = w.get('UpperLeg.R', 0) + thigh * (1 - leg_side)
    return w


def along(p, a, b):
    ab = Vector(b) - Vector(a)
    return (p - Vector(a)).dot(ab) / ab.length_squared


def limb_weights(p, upper, lower, end=None):
    ha, ta = BONES[upper][0], BONES[upper][1]
    t = along(p, ha, ta)
    k = smooth(0.80, 1.15, t)
    w = {upper: 1 - k, lower: k}
    if end:
        e = smooth(-0.05, 0.10, along(p, BONES[end][0], BONES[end][1]))
        if e > 0:
            w = {b: v * (1 - e) for b, v in w.items()}
            w[end] = e
    return w


def weights_for(name, p):
    if name in ('Head', 'Eyes', 'Beanie'):
        if name == 'Head' and p.z < 0.50:
            n = smooth(0.46, 0.50, p.z)
            return {'Neck': n, 'Chest': 1 - n}
        return {'Head': 1.0}
    if name == 'Hair':
        h = 0.6 * smooth(0.60, 0.51, p.z) * smooth(-0.04, 0.04, p.y)
        return {'Head': 1 - h, 'Hair': h}
    if name == 'Pompom':
        return {'Pompom': 1.0}
    if name in ('Coat', 'Hood', 'Toggles'):
        return torso_weights(p)
    side = name[-1]
    if name.startswith('Sleeve'):
        return limb_weights(p, 'UpperArm.' + side, 'LowerArm.' + side)
    if name.startswith(('Hand', 'Mitten')):
        return {'Hand.' + side: 1.0}
    if name.startswith('Leg'):
        return limb_weights(p, 'UpperLeg.' + side, 'LowerLeg.' + side)
    if name.startswith('Boot'):
        f = smooth(0.075, 0.055, p.z)
        return {'Foot.' + side: f, 'LowerLeg.' + side: 1 - f}
    raise KeyError(name)


def main():
    coll = bpy.data.collections['Girl']
    old_root = bpy.data.objects.get('Girl')
    if old_root and old_root.type == 'EMPTY':
        bpy.data.objects.remove(old_root)

    # Toggles are 3 px in game: half their triangles.
    tog = bpy.data.objects['Toggles']
    dec = tog.modifiers.new('Lighter', 'DECIMATE')
    dec.ratio = 0.5
    with bpy.context.temp_override(object=tog, active_object=tog, selected_objects=[tog]):
        bpy.ops.object.modifier_apply(modifier=dec.name)

    arm_data = bpy.data.armatures.new('GirlRig')
    rig = bpy.data.objects.new('Girl', arm_data)
    coll.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, (head, tail, parent) in BONES.items():
        eb = arm_data.edit_bones.new(name)
        eb.head, eb.tail = Vector(head), Vector(tail)
        eb.roll = 0.0
        eb.use_deform = name != 'Root'
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    arm_data.display_type = 'STICK'
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'

    for obj in list(coll.objects):
        if obj.type != 'MESH':
            continue
        obj.parent = rig
        obj.vertex_groups.clear()
        groups = {}
        for v in obj.data.vertices:
            for bone, wt in weights_for(obj.name, v.co).items():
                if wt <= 1e-4:
                    continue
                if bone not in groups:
                    groups[bone] = obj.vertex_groups.new(name=bone)
                groups[bone].add([v.index], wt, 'REPLACE')
        mod = obj.modifiers.new('Rig', 'ARMATURE')
        mod.object = rig
        # Armature first, so Solidify and Subsurf act on the posed shape.
        with bpy.context.temp_override(object=obj):
            bpy.ops.object.modifier_move_to_index(modifier='Rig', index=0)
        print('### weighted', obj.name, sorted(groups))
    bpy.ops.wm.save_mainfile()
    print('### rig saved')


main()

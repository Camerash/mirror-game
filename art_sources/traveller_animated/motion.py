"""Two authored standing actions. Blender IK is an authoring aid only."""
import bpy
from mathutils import Matrix, Quaternion, Vector

from arm_rig import ARM_BONES, pose_grip, set_elbow_planes
from hood_shapes import DOWN_PHASES, UP_PHASES, set_phase

CLIPS = {'HoodDown': DOWN_PHASES, 'HoodUp': UP_PHASES}


def smooth(value):
    value = max(0, min(1, value))
    return value*value*(3-2*value)


def path_point(frame, knots):
    for (start, left), (end, right) in zip(knots, knots[1:]):
        if start <= frame <= end:
            return Vector(left).lerp(Vector(right), smooth((frame-start)/(end-start)))
    return Vector(knots[0][1] if frame < knots[0][0] else knots[-1][1])


def reset_pose(rig):
    for name in ARM_BONES:
        rig.pose.bones[name].matrix_basis = Matrix.Identity(4)
    for side in ('L', 'R'):
        for name in ('Forearm.', 'Hand.'):
            for constraint in rig.pose.bones[name+side].constraints:
                constraint.influence = 0
    bpy.context.view_layer.update()


def pose_action(cloth, rig, frame, clip):
    phases = CLIPS[clip]
    release = 39 if clip == 'HoodDown' else 45
    if frame <= 0 or frame >= 60:
        reset_pose(rig)
        set_phase(cloth, frame, phases)
        return
    for side in ('L', 'R'):
        for name in ('Forearm.', 'Hand.'):
            for constraint in rig.pose.bones[name+side].constraints:
                constraint.influence = 1
    contact_frame = 12 if frame < 12 else min(frame, release)
    amount = smooth((frame-7)/5) if frame < 12 else 1-smooth((frame-release)/4)
    pose_grip(cloth, rig, contact_frame, phases, amount)
    contacts = {side: (bpy.data.objects['Grip.'+side].location.copy(),
                       bpy.data.objects['Grip.'+side].rotation_quaternion.copy()) for side in ('L', 'R')}
    for side, sign in (('L', -1), ('R', 1)):
        target = bpy.data.objects['Grip.'+side]
        contact, rotation = contacts[side]
        rest = Vector((sign*.31, -.08, .52))
        rest_rotation = rig.data.bones['Hand.'+side].matrix_local.to_quaternion()
        if frame < 12:
            target.location = path_point(frame, ((0, rest), (2, (sign*.13, -.15, .60)),
                                                 (5, (sign*.13, -.75, 1.05)),
                                                 (8, (sign*.20, -.85, 1.70)),
                                                 (10, contact+Vector((0, -.25, 0))), (12, contact)))
            target.rotation_quaternion = rest_rotation.slerp(rotation, smooth((frame-4)/8))
            shoulder = smooth(frame/9)
        elif frame > release:
            away = contact+Vector((0, -.14, .02))
            outside_frame = 51 if clip == 'HoodDown' else 54
            target.location = path_point(frame, ((release, contact), (release+3, away),
                                                 (release+6, (sign*.20, -.85, contact.z)),
                                                 (outside_frame, (sign*.20, -.85, 1.60)),
                                                 (57, (sign*.13, -.75, 1.05)),
                                                 (59, (sign*.13, -.15, .60)), (60, rest)))
            target.rotation_quaternion = rotation.slerp(rest_rotation, smooth((frame-release)/8))
            shoulder = 1-smooth((frame-50)/10)
        else:
            shoulder = 1
        clavicle = rig.pose.bones['Clavicle.'+side]
        clavicle.rotation_quaternion = Quaternion().slerp(clavicle.rotation_quaternion, shoulder)
    set_phase(cloth, frame, phases)
    bpy.context.view_layer.update()
    set_elbow_planes(rig)

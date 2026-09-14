"""Bake the native IK result into standard bone and morph actions."""
import bpy
from mathutils import Quaternion

from arm_rig import ARM_BONES
from motion import CLIPS, pose_action


FPS = 60
LAST_FRAME = 120


def action_curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for slot in action.slots:
                bag = strip.channelbag(slot)
                if bag:
                    yield from bag.fcurves


def save_track(owner, clip):
    animation = owner.animation_data
    action = animation.action
    action.name = clip+'.'+('Rig' if owner.id_type == 'OBJECT' else 'Garment')
    for curve in action_curves(action):
        for point in curve.keyframe_points:
            point.interpolation = 'LINEAR'
    track = animation.nla_tracks.new()
    track.name = clip
    strip = track.strips.new(clip, 0, action)
    strip.action_slot = animation.action_slot
    track.mute = True
    animation.action = None


def select_clip(clip):
    """Select both baked actions. Fractional scene frames use normal Blender evaluation."""
    for owner in (bpy.data.objects['Rig'], bpy.data.objects['Garment'].data.shape_keys):
        animation = owner.animation_data
        track = animation.nla_tracks[clip]
        animation.action = track.strips[0].action
        animation.action_slot = track.strips[0].action_slot
        animation.use_nla = False


def bake_actions(cloth, rig):
    samples = {}
    for clip in CLIPS:
        frames = []
        for step in range(LAST_FRAME+1):
            pose_action(cloth, rig, step/2, clip)
            matrices = {name: rig.convert_space(pose_bone=rig.pose.bones[name],
                         matrix=rig.pose.bones[name].matrix, from_space='POSE', to_space='LOCAL').copy()
                        for name in ARM_BONES}
            values = {key.name: key.value for key in list(cloth.data.shape_keys.key_blocks)[1:]}
            frames.append((matrices, values))
        samples[clip] = frames
    # Retain the authoring controls in the blend, but disable their constraints.
    # The exported file contains only the selected rig and standard baked tracks.
    for bone in rig.pose.bones:
        for constraint in bone.constraints:
            constraint.mute = True
    for clip, frames in samples.items():
        previous = {name: Quaternion() for name in ARM_BONES}
        for frame, (matrices, values) in enumerate(frames):
            for name, matrix in matrices.items():
                bone = rig.pose.bones[name]
                location, rotation, scale = matrix.decompose()
                assert max(abs(value-1) for value in scale) < .0001
                rotation.make_compatible(previous[name])
                previous[name] = rotation.copy()
                bone.rotation_mode = 'QUATERNION'
                bone.location, bone.rotation_quaternion, bone.scale = location, rotation, (1, 1, 1)
                bone.keyframe_insert('location', frame=frame)
                bone.keyframe_insert('rotation_quaternion', frame=frame)
            for name, value in values.items():
                key = cloth.data.shape_keys.key_blocks[name]
                key.value = value
                key.keyframe_insert('value', frame=frame)
        save_track(rig, clip)
        save_track(cloth.data.shape_keys, clip)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start, scene.frame_end = 0, LAST_FRAME
    select_clip('HoodDown')
    scene.frame_set(0)
    rig['authoring_controls'] = 'Grip.L/R and ElbowPole.L/R; muted IK; rebuild with build_study.py'

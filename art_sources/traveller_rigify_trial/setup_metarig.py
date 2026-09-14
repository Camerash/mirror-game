"""Create only the native right-arm metarig in the isolated trial file."""
import math
import bpy
from mathutils import Vector
from rigify.rigs.limbs.arm import create_sample

assert 'TrialMetarig' not in bpy.data.objects
bpy.ops.object.armature_add(enter_editmode=False)
meta = bpy.context.object
meta.name = 'TrialMetarig'
bpy.ops.object.mode_set(mode='EDIT')
meta.data.edit_bones.remove(meta.data.edit_bones[0])
bpy.ops.object.mode_set(mode='OBJECT')
create_sample(meta)
for bone in meta.data.edit_bones:
    bone.name = bone.name.replace('.L', '.R')
shoulder = Vector((.32, 0, 1.83))
elbow = shoulder + Vector((.17, -.10, -math.sqrt(.690**2-.17**2-.10**2)))
wrist = elbow + Vector((.02, .0268, -math.sqrt(.6244269**2-.02**2-.0268**2)))
for name, head, tail in [('upper_arm.R', shoulder, elbow), ('forearm.R', elbow, wrist),
                         ('hand.R', wrist, wrist+Vector((0, 0, -.16)))]:
    bone = meta.data.edit_bones[name]
    bone.head, bone.tail, bone.roll = head, tail, 0

def add(name, head, tail, parent, connected=False):
    bone = meta.data.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    if parent:
        bone.parent = meta.data.edit_bones[parent]
    bone.use_connect = connected
    return bone

add('chest', (0, 0, 1.60), (0, 0, 1.94), None)
add('clavicle.R', (0, 0, 1.90), shoulder, 'chest')
meta.data.edit_bones['upper_arm.R'].parent = meta.data.edit_bones['clavicle.R']
add('fingers.01.R', wrist+Vector((0, 0, -.095)), wrist+Vector((0, 0, -.145)), 'hand.R')
add('fingers.02.R', wrist+Vector((0, 0, -.145)), wrist+Vector((0, 0, -.195)), 'fingers.01.R', True)
add('thumb.01.R', wrist+Vector((-.045, 0, -.07)), wrist+Vector((-.08, -.01, -.10)), 'hand.R')
add('thumb.02.R', wrist+Vector((-.08, -.01, -.10)), wrist+Vector((-.115, -.02, -.13)), 'thumb.01.R', True)
bpy.ops.object.mode_set(mode='OBJECT')
for name in ('chest', 'clavicle.R'):
    meta.pose.bones[name].rigify_type = 'basic.super_copy'
params = meta.pose.bones['upper_arm.R'].rigify_parameters
params.segments = 2
params.bbones = 1
params.rotation_axis = 'automatic'
for name in ('fingers.01.R', 'thumb.01.R'):
    meta.pose.bones[name].rigify_type = 'limbs.super_finger'
    meta.pose.bones[name].rigify_parameters.bbones = 1
    meta.pose.bones[name].rigify_parameters.make_extra_ik_control = False
bpy.context.view_layer.objects.active = meta
collection = meta.data.collections[0]
collection.name = "Trial Arm"
collection.rigify_ui_row = 1
for bone in meta.data.bones:
    collection.assign(bone)
bpy.ops.pose.rigify_generate()
rig = bpy.context.object
rig.name = 'TrialRig'
rig.show_in_front = True
meta.hide_set(True)
result = {'rig': rig.name, 'bones': len(rig.data.bones),
          'deform_bones': [b.name for b in rig.data.bones if b.use_deform],
          'arm_lengths': [meta.data.bones[n].length for n in ('upper_arm.R', 'forearm.R')]}

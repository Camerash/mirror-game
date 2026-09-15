"""A unit-scale elbow support with a shared bend rotation."""
import bpy
from mathutils import Matrix
import pose_tools
import check_pose

pose_tools.author_pose('Trial_Rest')
body = bpy.data.objects['Body']
rig = bpy.data.objects['TrialRig']
if body.modifiers.get('Elbow surface correction'):
    body.modifiers.remove(body.modifiers['Elbow surface correction'])
if body.vertex_groups.get('ElbowSurface'):
    body.vertex_groups.remove(body.vertex_groups['ElbowSurface'])
upper = rig.data.bones['ORG-upper_arm.R']
lower = rig.data.bones['ORG-forearm.R']
joint = lower.head_local.copy()
axis = (upper.tail_local-upper.head_local).normalized()
rotation = upper.matrix_local.to_quaternion().slerp(lower.matrix_local.to_quaternion(), .5)
matrix = rotation.to_matrix().to_4x4()
matrix.translation = joint
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
bone = rig.data.edit_bones.new('DEF-elbow_support.R')
bone.head = joint
bone.tail = joint+axis*.12
bone.matrix = matrix
bone.length = .12
bone.parent = rig.data.edit_bones['root']
bone.inherit_scale = 'NONE'
bpy.ops.object.mode_set(mode='OBJECT')
control = rig.pose.bones[bone.name]
for target, influence in (('ORG-upper_arm.R', 1), ('ORG-forearm.R', .5)):
    constraint = control.constraints.new('COPY_ROTATION')
    constraint.target = rig
    constraint.subtarget = target
    constraint.influence = influence
constraint = control.constraints.new('COPY_LOCATION')
constraint.target = rig
constraint.subtarget = 'ORG-forearm.R'
group = body.vertex_groups.new(name=control.name)
deform_groups = [g for g in body.vertex_groups if g.name.startswith('DEF-')]
for index in check_pose.members(body, 'TrialSleeve'):
    s = (body.data.vertices[index].co-joint).dot(axis)
    if abs(s) >= .32:
        continue
    t = 1-abs(s)/.32
    weight = t*t*(3-2*t)
    other = 'DEF-upper_arm.R.001' if s < 0 else 'DEF-forearm.R'
    for deform in deform_groups:
        deform.remove([index])
    group.add([index], weight, 'REPLACE')
    body.vertex_groups[other].add([index], 1-weight, 'REPLACE')
rig.update_tag()
bpy.context.view_layer.update()

"""One local arm binding pass; the rest of the character stays fixed."""
import bpy
from mathutils import Vector

body = bpy.data.objects['Body']
rig = bpy.data.objects['TrialRig']
meta = bpy.data.objects['TrialMetarig']
assert not body.get('trial_binding'), 'Trial arm already bound'
shoulder = meta.data.bones['upper_arm.R'].head_local.copy()
elbow = meta.data.bones['forearm.R'].head_local.copy()
wrist = meta.data.bones['hand.R'].head_local.copy()
old_wrist = Vector((.31, -.08, .52))
right = list(range(516, 688))+list(range(718, 748))
body.vertex_groups.clear()
for bone in rig.data.bones:
    if bone.use_deform:
        body.vertex_groups.new(name=bone.name)
body.vertex_groups['DEF-chest'].add(list(range(len(body.data.vertices))), 1, 'REPLACE')
body.vertex_groups.new(name='TrialRightArm').add(right, 1, 'REPLACE')


def bind(indices, weights):
    for group in body.vertex_groups:
        if group.name.startswith('DEF-'):
            group.remove(indices)
    for name, weight in weights.items():
        body.vertex_groups['DEF-'+name].add(indices, weight, 'REPLACE')


sections = [(shoulder.lerp(elbow,t), (elbow-shoulder).normalized()) for t in (0,.2,.45,.72,.9,1)]
sections += [(elbow.lerp(wrist,t), (wrist-elbow).normalized()) for t in (.10,.28,.55,.82,1)]
weights = [
    {'clavicle.R':.7,'chest':.3}, {'clavicle.R':.2,'upper_arm.R':.8},
    {'upper_arm.R':.5,'upper_arm.R.001':.5}, {'upper_arm.R.001':1},
    {'upper_arm.R.001':.8,'forearm.R':.2}, {'upper_arm.R.001':.5,'forearm.R':.5},
    {'upper_arm.R.001':.2,'forearm.R':.8}, {'forearm.R':1},
    {'forearm.R':.5,'forearm.R.001':.5}, {'forearm.R.001':1}, {'forearm.R.001':1}]
for row,(center,axis) in enumerate(sections):
    ids = list(range(516+row*10,526+row*10))
    old_center = sum((body.data.vertices[i].co for i in ids), Vector())/10
    rotation = Vector((0,0,-1)).rotation_difference(axis)
    if row == 10:
        center = wrist-axis*.055
    for i in ids:
        offset = body.data.vertices[i].co-old_center
        body.data.vertices[i].co = center+rotation@offset
    bind(ids, weights[row])
for i in list(range(626,688)):
    body.data.vertices[i].co += wrist-old_wrist
for row,depth,width,weight in [
    (11,.105,.136,{'forearm.R.001':.2,'hand.R':.8}),
    (12,.098,.148,{'hand.R':1}),
    (13,.088,.142,{'hand.R':.6,'fingers.01.R':.4}),
    (14,.068,.122,{'fingers.01.R':.6,'fingers.02.R':.4}),
    (15,.048,.090,{'fingers.02.R':1})]:
    ids = list(range(516+row*10,526+row*10))
    center = sum((body.data.vertices[i].co for i in ids),Vector())/10
    rx = max(abs(body.data.vertices[i].co.x-center.x) for i in ids)
    ry = max(abs(body.data.vertices[i].co.y-center.y) for i in ids)
    for i in ids:
        v = body.data.vertices[i]
        v.co.x = center.x+(v.co.x-center.x)*width/(2*rx)
        v.co.y = center.y+(v.co.y-center.y)*depth/(2*ry)
    bind(ids,weight)
for ids,weights in [(list(range(676,682)),{'thumb.01.R':1}), (list(range(682,688)),{'thumb.02.R':1})]:
    bind(ids,weights)
axis = (wrist-elbow).normalized()
rotation = Vector((0,0,-1)).rotation_difference(axis)
for i in range(718,748):
    body.data.vertices[i].co = wrist+rotation@(body.data.vertices[i].co-old_wrist)
bind(list(range(718,748)), {'forearm.R.001':1})
modifier = body.modifiers.new('Trial Rigify skin','ARMATURE')
modifier.object = rig
rig.pose.bones['upper_arm_parent.R']['IK_Stretch'] = 0
rig.pose.bones['upper_arm_parent.R']['pole_vector'] = True
body['trial_binding'] = True
body.data.update()
bpy.context.view_layer.update()
result = {'vertices':len(body.data.vertices),'deform_bones':sum(b.use_deform for b in rig.data.bones),
          'modifiers':[m.type for m in body.modifiers]}

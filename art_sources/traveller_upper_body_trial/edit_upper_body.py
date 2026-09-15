"""One local torso/shoulder/sleeve rebuild in the separate inspection copy."""
import math
import bpy
import bmesh
from mathutils import Vector

body = bpy.data.objects['Body']
rig = bpy.data.objects['TrialRig']
assert not body.get('upper_body_rebuilt'), 'This local edit has already run'
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
for armature in (rig, bpy.data.objects['TrialMetarig']):
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode='EDIT')
    rest = {b.name: (b.head.copy(), b.tail.copy(), b.use_connect) for b in armature.data.edit_bones}
    for bone in armature.data.edit_bones:
        bone.use_connect = False
    for bone in armature.data.edit_bones:
        head, tail, connected = rest[bone.name]
        if bone.name.endswith('.R') or '.R.' in bone.name:
            head.z += .12
            tail.z += .12
        bone.head = head
        bone.tail = tail
    for bone in armature.data.edit_bones:
        bone.use_connect = rest[bone.name][2]
    bpy.ops.object.mode_set(mode='OBJECT')
for bone in rig.pose.bones:
    bone.ik_stretch = 0.0
    for constraint in bone.constraints:
        if constraint.type == 'IK':
            constraint.use_stretch = False

bm = bmesh.new()
bm.from_mesh(body.data)
bm.verts.ensure_lookup_table()
original = list(bm.verts)
deform = bm.verts.layers.deform.active
uv = bm.loops.layers.uv.active
group = {g.name: g.index for g in body.vertex_groups}
hand_ring = original[626:636]
for vertex in bm.verts:
    if vertex[deform].get(group['TrialHand'], 0) > .5:
        vertex.co.z += .12
remove = [v for v in bm.verts if v[deform].get(group['TrialTorso'], 0) > .5
          or v[deform].get(group['TrialSleeve'], 0) > .5]
bmesh.ops.delete(bm, geom=remove, context='VERTS')


def vertex(point, weights, regions):
    v = bm.verts.new(point)
    for name, weight in weights.items():
        v[deform][group['DEF-' + name]] = weight
    for name in regions:
        v[deform][group[name]] = 1
    return v


def face(vertices, tex=(.375, .56)):
    f = bm.faces.new(vertices)
    f.smooth = True
    for loop in f.loops:
        loop[uv].uv = tex
    return f


def bridge(first, second, tex=(.375, .56)):
    for i in range(len(first)):
        j = (i + 1) % len(first)
        face((first[i], first[j], second[j], second[i]), tex)


torso = []
for z, rx, ry in ((2.14,.17,.15),(2.115,.255,.18),(1.98,.30,.19),
                  (1.84,.275,.175),(1.70,.235,.165),(1.52,.25,.17),
                  (1.28,.28,.19),(1.08,.31,.20)):
    torso.append([vertex((rx*math.sin(i*math.tau/20), -.012-ry*math.cos(i*math.tau/20), z),
                         {'chest':1}, ('TrialTorso',)) for i in range(20)])
# The armhole is an ellipse on the side, not a rectangular cut in a flat chest.
seam = [torso[2][5],torso[2][6],torso[2][7],torso[3][7],torso[3][6],
        torso[3][5],torso[3][4],torso[3][3],torso[2][3],torso[2][4]]
for i, v in enumerate(seam):
    angle = i*math.tau/10
    v.co = (.295, .135*math.sin(angle), 1.95+.15*math.cos(angle))
    weight = .12+.26*(math.cos(angle)+1)/2
    v[deform][group['DEF-chest']] = 1-weight
    v[deform][group['DEF-upper_arm.R']] = weight
    for name in ('TrialRightArm','TrialSleeve','TrialShoulderSeam'):
        v[deform][group[name]] = 1
for row in range(len(torso)-1):
    for col in range(20):
        if row == 2 and 3 <= col < 7:
            continue
        nxt = (col+1)%20
        face((torso[row][col],torso[row][nxt],torso[row+1][nxt],torso[row+1][col]))
face(list(reversed(torso[0])))
face(torso[-1])

shoulder = rig.data.bones['ORG-upper_arm.R'].head_local.copy()
elbow = rig.data.bones['ORG-forearm.R'].head_local.copy()
wrist = rig.data.bones['ORG-forearm.R'].tail_local.copy()
upper_axis = (elbow-shoulder).normalized()
fore_axis = (wrist-elbow).normalized()
rows = [(shoulder+Vector((.065,-.012,-.03)),Vector((.85,-.1,-.53)).normalized(),.31,.29,0)]
rows += [(shoulder+upper_axis*s,upper_axis,w,d,s) for s,w,d in
         ((.23,.29,.27),(.42,.29,.27),(.57,.28,.26),(.65,.28,.26),(.69,.27,.26))]
rows += [(elbow+fore_axis*s,fore_axis,w,d,.69+s) for s,w,d in
         ((.07,.27,.25),(.15,.27,.25),(.33,.255,.235),(.50,.27,.24),(.5544,.34,.30),(.6144,.35,.30))]


def sleeve_ring(center, axis, width, depth, weights):
    u = axis.cross(Vector((0,1,0))).normalized()
    v = u.cross(axis).normalized()
    return [vertex(center+u*math.cos(i*math.tau/10)*width/2+v*math.sin(i*math.tau/10)*depth/2,
                   weights, ('TrialRightArm','TrialSleeve')) for i in range(10)]


previous = seam
for row, (center, axis, width, depth, s) in enumerate(rows):
    if row == 0:
        weights = {'chest':.15,'upper_arm.R':.85}
    elif s < .50:
        weights = {'upper_arm.R':1}
    elif s < .85:
        lower_weight = max(0,min(1,(s-.50)/.35))
        weights = {'upper_arm.R.001':1-lower_weight,'forearm.R':lower_weight}
    else:
        weights = {'forearm.R.001':1}
    ring = sleeve_ring(center,axis,width,depth,weights)
    bridge(previous,ring)
    previous = ring
# The return stays inside the outer cuff and narrows before the sleeve wall.
for depth, width, thickness in ((.010,.326,.276),(.070,.238,.212),(.095,.198,.175)):
    ring = sleeve_ring(wrist-fore_axis*depth,fore_axis,width,thickness,{'forearm.R.001':1})
    bridge(previous,ring)
    previous = ring
bridge(previous,hand_ring,(.875,.56))
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(body.data)
bm.free()
body.data.update()
body.modifiers[0].use_deform_preserve_volume = True
body['upper_body_rebuilt'] = True
rig.update_tag()
bpy.context.view_layer.update()

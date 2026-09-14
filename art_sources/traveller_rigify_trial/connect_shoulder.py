"""One native shoulder loop, a shared sleeve seam, and rounded hand ends."""
import bpy
import bmesh
from mathutils import Vector

body=bpy.data.objects['Body']
assert not body.get('trial_shoulder_connected')
for name,indices in [('TrialTorso',range(80)),('TrialHand',range(626,688)),
                     ('TrialSleeve',list(range(516,626))+list(range(718,748)))]:
    body.vertex_groups.new(name=name).add(list(indices),1,'REPLACE')
body.vertex_groups.new(name='TrialShoulderSeam')
bm=bmesh.new()
bm.from_mesh(body.data)
bm.verts.ensure_lookup_table()
original=list(bm.verts)
deform=bm.verts.layers.deform.active
uv=bm.loops.layers.uv.active
torso=set(original[:80])
faces=[f for f in bm.faces if all(v in torso for v in f.verts)]
edges={e for f in faces for e in f.edges}
bmesh.ops.bisect_plane(bm,geom=list(torso)+list(edges)+faces,dist=1e-6,
                      plane_co=(0,0,1.70),plane_no=(0,0,1))
top=[original[i] for i in range(23,28)]
bottom=[]
for column in range(3,8):
    point=original[20+column].co.lerp(original[40+column].co,(1.92-1.70)/(.37))
    vertex=min(bm.verts,key=lambda v:(v.co-point).length)
    assert (vertex.co-point).length<1e-5
    bottom.append(vertex)
opening=set(top+bottom)
cut=[f for f in bm.faces if all(v in opening for v in f.verts)]
assert len(cut)==4, len(cut)
root=original[516:526]
cap=[f for f in bm.faces if set(f.verts)==set(root)]
assert len(cap)==1
bmesh.ops.delete(bm,geom=cut+cap,context='FACES_ONLY')
# The clockwise circle follows the upper shoulder, back, armpit and front.
seam=[top[2],top[3],top[4],bottom[4],bottom[3],bottom[2],bottom[1],bottom[0],top[0],top[1]]
for vertex in seam:
    vertex[deform].clear()
    vertex[deform][body.vertex_groups['DEF-chest'].index]=.85
    vertex[deform][body.vertex_groups['DEF-clavicle.R'].index]=.15
    for name in ('TrialTorso','TrialRightArm','TrialSleeve','TrialShoulderSeam'):
        vertex[deform][body.vertex_groups[name].index]=1
bmesh.ops.weld_verts(bm,targetmap=dict(zip(root,seam)))


def round_end(ring,axis,bone,depth):
    cap=[f for f in bm.faces if set(f.verts)==set(ring)]
    assert len(cap)==1
    bmesh.ops.delete(bm,geom=cap,context='FACES_ONLY')
    center=sum((v.co for v in ring),Vector())/len(ring)
    inner=[bm.verts.new(center+(v.co-center)*.55+axis*depth*.72) for v in ring]
    tip=bm.verts.new(center+axis*depth)
    for v in inner+[tip]:
        for name in ('TrialRightArm','TrialHand',bone):v[deform][body.vertex_groups[name].index]=1
    for i in range(len(ring)):
        j=(i+1)%len(ring)
        for vertices in [(ring[i],ring[j],inner[j],inner[i]),(inner[i],inner[j],tip)]:
            face=bm.faces.new(vertices);face.smooth=True
            for loop in face.loops:loop[uv].uv=(.875,.56)


round_end(original[666:676],Vector((0,0,-1)),'DEF-fingers.02.R',.016)
thumb_axis=Vector((-.035,-.010,-.030)).normalized()
round_end(original[682:688],thumb_axis,'DEF-thumb.02.R',.009)
loose=[edge for edge in bm.edges if not edge.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='EDGES')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(body.data)
bm.free()
body.data.update()
body['trial_shoulder_connected']=True
bpy.context.view_layer.update()
result={'vertices':len(body.data.vertices),'shoulder_shared_vertices':10,
        'new_torso_loop':1,'finger_end':'Rounded native profile rings and cap'}

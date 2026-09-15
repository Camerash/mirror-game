"""Focused checks for the single Rigify trial arm, including Body subregions."""
import bpy
from mathutils.bvhtree import BVHTree


def surface(obj):
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data=evaluated.data
    data.calc_loop_triangles()
    return [evaluated.matrix_world@v.co for v in data.vertices], [tuple(t.vertices) for t in data.loop_triangles]


def members(obj,name):
    index=obj.vertex_groups[name].index
    return {v.index for v in obj.data.vertices if any(g.group==index and g.weight>.5 for g in v.groups)}


def tree(points,faces):
    return BVHTree.FromPolygons(points,faces,all_triangles=True)


def crossing_pairs(points,left,right,same=False):
    pairs=tree(points,left).overlap(tree(points,right))
    return [(a,b) for a,b in pairs if (not same or a<b) and not set(left[a]).intersection(right[b])]


def sleeve_rings(body):
    """Find sleeve rows from the explicit shared shoulder boundary."""
    allowed = members(body, 'TrialSleeve')
    neighbors = {i: set() for i in allowed}
    for edge in body.data.edges:
        a, b = edge.vertices
        if a in allowed and b in allowed:
            neighbors[a].add(b)
            neighbors[b].add(a)
    rings = [members(body, 'TrialShoulderSeam')]
    visited = set(rings[0])
    while True:
        following = set().union(*(neighbors[i] for i in rings[-1])) - visited
        if not following:
            return rings
        assert len(following) == 10, 'Sleeve row connectivity changed'
        rings.append(following)
        visited.update(following)


def inspect_pose():
    body=bpy.data.objects['Body'];rig=bpy.data.objects['TrialRig']
    points,faces=surface(body)
    selected={name:members(body,name) for name in ('TrialRightArm','TrialTorso','TrialHand','TrialSleeve','TrialOppositeArm')}
    parts={name:[f for f in faces if all(i in ids for i in f)] for name,ids in selected.items()}
    arm=parts['TrialRightArm'];hand=parts['TrialHand'];torso=parts['TrialTorso']
    other_arm=parts['TrialOppositeArm']
    rest=[f for f in faces if f not in hand]
    counts={'arm/torso':len(crossing_pairs(points,arm,torso)),
            'arm/opposite_arm':len(crossing_pairs(points,arm,other_arm)),
            'arm/self':len(crossing_pairs(points,arm,arm,True)),
            'hand/body':len(crossing_pairs(points,hand,rest))}
    at=tree(points,arm)
    for name in ('Head','Hair','Garment'):
        p,f=surface(bpy.data.objects[name]);counts['arm/'+name]=len(at.overlap(tree(p,f)))
    garment=bpy.data.objects['Garment'];gp,gf=surface(garment);gt=tree(gp,gf)
    counts['cloth/self']=len(crossing_pairs(gp,gf,gf,True))
    for name in ('Head','Hair'):
        p,f=surface(bpy.data.objects[name]);counts['cloth/'+name]=len(gt.overlap(tree(p,f)))
    deform={b.name for b in rig.data.bones if b.use_deform}
    influences=[[g.weight for g in v.groups if body.vertex_groups[g.group].name in deform and g.weight>0] for v in body.data.vertices]
    triangles={n:len(surface(bpy.data.objects[n])[1]) for n in ('Body','Boots','Head','Hair','Garment')}
    return {'pairs':counts,'triangles':triangles,'total_triangles':sum(triangles.values()),
            'max_influences':max(map(len,influences)),
            'normalization_error':max(abs(sum(w)-1) for w in influences),
            'bone_scale_error':max(abs(s-1) for p in rig.pose.bones for s in p.scale),
            'deform_matrix_scale_error':max(abs(s-1) for p in rig.pose.bones if p.name in deform for s in p.matrix.to_scale()),
            'modifiers':[m.type for m in body.modifiers],
            'note':'Only right arm is under test. Opposite arm is unchanged baseline geometry.'}

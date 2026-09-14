"""Native static pose assets for the isolated right-arm control trial."""
import math
import bpy
from mathutils import Matrix, Quaternion, Vector

POSES={
    'Trial_Rest': {'hood':0.0,'opening':0.0,'contact':None},
    'Trial_EyeGrip': {'hood':0.0,'opening':1.0,'contact':(17,16,.14)},
    'Trial_RearPickup': {'hood':1.0,'opening':1.0,'contact':(13,12,.5)},
}


def controls(rig):
    return [p for p in rig.pose.bones if not p.name.startswith(('DEF-','MCH-','ORG-','VIS_'))]


def garment_pose(name):
    values=POSES[name]
    keys=bpy.data.objects['Garment'].data.shape_keys.key_blocks
    for key in list(keys)[1:]:key.value=0
    keys['HoodLowered'].value=values['hood']
    keys['CloakOpen'].value=values['opening']
    bpy.context.view_layer.update()


def author_pose(name):
    rig=bpy.data.objects['TrialRig']
    for bone in controls(rig):bone.matrix_basis=Matrix.Identity(4)
    settings=rig.pose.bones['upper_arm_parent.R']
    settings['IK_FK']=0.0
    settings['IK_Stretch']=0.0
    settings['pole_vector']=True
    settings['IK_parent']=2
    settings['pole_parent']=2
    garment_pose(name)
    if name=='Trial_Rest':return
    first,second,fraction=POSES[name]['contact']
    garment=bpy.data.objects['Garment']
    data=garment.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    point=garment.matrix_world@(data.vertices[first].co.lerp(data.vertices[second].co,fraction))
    if name=='Trial_EyeGrip':
        offset=Vector((0,-.16,-.10))
        rotation=Quaternion((1,0,0),math.radians(150))
        pole=Vector((1.20,-.80,1.95))
    else:
        offset=Vector((.11,0,.13))
        rotation=Quaternion((0,0,1),-math.pi/2)
        pole=Vector((1.20,-.55,1.35))
    hand=rig.pose.bones['hand_ik.R']
    matrix=rotation.to_matrix().to_4x4()@hand.bone.matrix_local
    matrix.translation=point+offset
    hand.matrix=matrix
    target=rig.pose.bones['upper_arm_ik_target.R']
    matrix=target.matrix.copy();matrix.translation=pole;target.matrix=matrix
    for bone,angle in [('fingers.01.R',-.55),('fingers.02.R',-.55),('thumb.01.R',.18),('thumb.02.R',.25)]:
        rig.pose.bones[bone].rotation_mode='XYZ'
        rig.pose.bones[bone].rotation_euler.x=angle
    bpy.context.view_layer.update()


def save_pose(name):
    rig=bpy.data.objects['TrialRig']
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.poselib.create_pose_asset(pose_name=name,asset_library_reference='LOCAL')
    asset=bpy.data.actions.get(name)
    if asset is None:
        asset=next(a for a in bpy.data.actions if a.asset_data and a.name.startswith(name))
    p=POSES[name]
    asset.asset_data.description=(f'Right arm only. HoodLowered={p["hood"]}; CloakOpen={p["opening"]}. '
        f'IK/FK=IK; IK Stretch=0; IK parent=clavicle.R; pole parent=clavicle.R. '
        f'Material contact={p["contact"]}. Geometry failures are recorded in trial_checks.json; not production-approved.')
    asset.use_fake_user=True
    bpy.ops.object.mode_set(mode='OBJECT')
    return asset


def apply_pose(name):
    rig=bpy.data.objects['TrialRig']
    for bone in controls(rig):bone.matrix_basis=Matrix.Identity(4)
    rig.pose.apply_pose_from_action(bpy.data.actions[name])
    garment_pose(name)
    bpy.context.view_layer.update()

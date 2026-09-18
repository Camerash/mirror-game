"""Assemble the single Traveller source: new body, extended rig, kept assets.

Run with:
    Blender --background --python art_sources/traveller/build_traveller.py

The accepted Head and Boots are carried over untouched. The body mesh, the arm
bones, the cloak and the hair are rebuilt. The cloak keeps its accepted shape and
its eight hood keys, and gains `CloakArms` for the reaching animation. The hair
keeps its accepted hairline and its bun.
"""
import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_body as body_builder
import build_cloak
import build_hair
import proportions
import check_body
import skin_body
import build_animation

SOURCE = HERE.parents[0] / 'traveller_animated/traveller_animated.blend'
TARGET = HERE / 'traveller.blend'
CHART = os.environ.get('TRAVELLER_CHART', 'chibi')
# Four deform segments per arm. Bendy bones do not survive glTF export, so the
# continuous curve has to come from real joints posed along an arc.
ARM_BONES = ['UpperArm.%s', 'UpperArm.%s.001', 'Forearm.%s', 'Forearm.%s.001']


def arm_segments(samples):
    """Split the spine into four even bone spans, whatever its sample count."""
    last = samples - 1
    cuts = [round(last * n / 4) for n in range(5)]
    return [(ARM_BONES[n], cuts[n], cuts[n + 1]) for n in range(4)]


def ear_islands(old_body):
    """The two ear shells, which belong on the head rather than the torso."""
    mesh = old_body.data
    work = bmesh.new()
    work.from_mesh(mesh)
    work.verts.ensure_lookup_table()
    seen, islands = set(), []
    for vertex in work.verts:
        if vertex.index in seen:
            continue
        stack, island = [vertex], []
        seen.add(vertex.index)
        while stack:
            current = stack.pop()
            island.append(current.index)
            for edge in current.link_edges:
                other = edge.other_vert(current)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        islands.append(sorted(island))
    ears = []
    for island in islands:
        if len(island) != 52:
            continue
        keep = set(island)
        faces = [tuple(f.vertices) for f in mesh.polygons if all(i in keep for i in f.vertices)]
        uvs = [tuple(mesh.uv_layers.active.data[f.loop_indices[0]].uv)
               for f in mesh.polygons if all(i in keep for i in f.vertices)]
        ears.append({'verts': island, 'faces': faces, 'uvs': uvs,
                     'points': {i: mesh.vertices[i].co.copy() for i in island}})
    work.free()
    return ears


def move_ears_to_head(ears, head):
    """Append the ear shells to Head with the body material in a second slot."""
    mesh = head.data
    if len(mesh.materials) < 2:
        mesh.materials.append(bpy.data.materials['TravellerDrawingBody'])
    slot = len(mesh.materials) - 1
    work = bmesh.new()
    work.from_mesh(mesh)
    uv = work.loops.layers.uv.verify()
    for ear in ears:
        remap = {i: work.verts.new(ear['points'][i]) for i in ear['verts']}
        work.verts.index_update()
        for face, value in zip(ear['faces'], ear['uvs']):
            new = work.faces.new([remap[i] for i in face])
            new.smooth = True
            new.material_index = slot
            for loop in new.loops:
                loop[uv].uv = value
    bmesh.ops.recalc_face_normals(work, faces=list(work.faces))
    work.to_mesh(mesh)
    work.free()
    mesh.update()


def clear_pose(rig):
    """Return every bone to rest.

    The inherited file was saved mid-pose (arms up, mid-unhood) using a mix of
    euler and quaternion channels, so a rebind inherits that pose and tears the
    mesh. The source of truth must open at rest.
    """
    for bone in rig.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.rotation_axis_angle = (0, 0, 1, 0)
        bone.rotation_euler = (0, 0, 0)
        bone.scale = (1, 1, 1)
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.view_layer.update()


def pose_idle(rig, angle=None):
    """Drop the arms to the resting silhouette.

    The mesh is modelled in T-pose, so this is the pose everything else is
    judged against: the garment is fitted to it and the game idles in it.
    """
    angle = proportions.IDLE_ARM_ANGLE if angle is None else angle
    chain = ['UpperArm.%s', 'UpperArm.%s.001', 'Forearm.%s', 'Forearm.%s.001',
             'Hand.%s', 'Fingers.%s']
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    for side, sign in (('R', 1), ('L', -1)):
        pivot = rig.data.bones[chain[0] % side].head_local.copy()
        turn = (Matrix.Translation(pivot)
                @ Matrix.Rotation(math.radians(angle * sign), 4, 'Y')
                @ Matrix.Translation(-pivot))
        for template in chain:
            name = template % side
            if name in rig.pose.bones:
                rig.pose.bones[name].matrix = turn @ rig.data.bones[name].matrix_local
                bpy.context.view_layer.update()


def bind_cloak(garment, rig):
    """Skin the cloak instead of hanging it off one bone.

    It runs after the cloak is rebuilt, because that replaces the mesh and the
    vertex indices with it. The swap keeps the garment exactly where it was: the
    world matrix is put back after the parent changes, so the rest pose is
    untouched and the bind comes out as identity.
    """
    world = garment.matrix_world.copy()
    garment.parent = bpy.data.objects['TravellerAnimated']
    garment.parent_type = 'OBJECT'
    garment.parent_bone = ''
    garment.matrix_parent_inverse = garment.parent.matrix_world.inverted()
    garment.matrix_world = world
    influences = skin_body.cloak(garment, rig)
    for modifier in [m for m in garment.modifiers if m.type == 'ARMATURE']:
        garment.modifiers.remove(modifier)
    modifier = garment.modifiers.new('Cloak skin', 'ARMATURE')
    modifier.object = rig
    return influences


def store_idle_action(rig):
    """Keep the idle pose in the file as an action, so it is reproducible."""
    pose_idle(rig)
    action = bpy.data.actions.get('Idle') or bpy.data.actions.new('Idle')
    if not rig.animation_data:
        rig.animation_data_create()
    rig.animation_data.action = action
    for bone in rig.pose.bones:
        bone.keyframe_insert('rotation_quaternion', frame=1)
    rig.animation_data.action = None
    return action


def scale_head(factor):
    """Scale head, hair and ears about the chin, keeping their shapes exactly."""
    if abs(factor - 1) < 1e-6:
        return
    base = min(v.co.z for v in bpy.data.objects['Head'].data.vertices)
    for name in ('Head', 'Hair'):
        mesh = bpy.data.objects[name].data
        for vertex in mesh.vertices:
            vertex.co = Vector((vertex.co.x * factor, vertex.co.y * factor,
                                base + (vertex.co.z - base) * factor))
        mesh.update()


def extend_rig(rig, spines):
    """Split each arm into four deform segments laid along the new tube centre.

    The old arm bones sat up to 0.14 inside the torso, off the sleeve centre
    line, so rotating them swung the sleeve wide. These follow the mesh.
    """
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    edit = rig.data.edit_bones
    for side in ('L', 'R'):
        spine = spines[side]
        for name in ('UpperArm.' + side, 'Forearm.' + side, 'Elbow.' + side):
            if edit.get(name):
                edit.remove(edit[name])
        edit['Clavicle.' + side].tail = spine[0]
        parent = edit['Clavicle.' + side]
        for template, first, last in arm_segments(len(spine)):
            bone = edit.new(template % side)
            bone.head, bone.tail = spine[first], spine[last]
            bone.parent = parent
            bone.use_connect = True
            bone.use_deform = True
            # Blender's automatic roll is unstable between nearly parallel
            # bones: it gave the first segment an axis 80 degrees off its
            # neighbours. Aligning every segment's Z to world +Y puts local X
            # along world X on both sides, so one rotation value bends the whole
            # arc forward predictably and symmetrically.
            bone.align_roll(Vector((0, 1, 0)))
            parent = bone
        # The hand chain was authored pointing down; swing it onto the T-pose
        # arm so bones and mesh agree.
        pivot = spine[-1]
        turn = (Matrix.Translation(pivot)
                @ body_builder.hand_turn(1 if side == 'R' else -1)
                @ Matrix.Translation(-pivot))
        inherited = Vector((1 if side == 'R' else -1, 1, 1))
        for name in ('Hand.' + side, 'Fingers.' + side):
            bone = edit.get(name)
            if bone:
                head, tail, roll = bone.head.copy(), bone.tail.copy(), bone.roll
                offset = spine[-1] - Vector((inherited.x * .2997, -.0848, .6318))
                bone.head = turn @ (head + offset)
                bone.tail = turn @ (tail + offset)
        # The thumb geometry is gone, so its bone would only be dead weight.
        if edit.get('Thumb.' + side):
            edit.remove(edit['Thumb.' + side])
        hand = edit['Hand.' + side]
        hand.parent = parent
        hand.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    # A two-bone IK bends one elbow; this arm is a four-segment arc with no
    # hinge, so the constraints and their elbow poles go. Grip stays as the
    # contact target an arc solver aims at.
    for side in ('L', 'R'):
        for name in ('Forearm.' + side, 'Hand.' + side):
            bone = rig.pose.bones[name]
            for constraint in list(bone.constraints):
                bone.constraints.remove(constraint)
        pole = bpy.data.objects.get('ElbowPole.' + side)
        if pole:
            bpy.data.objects.remove(pole, do_unlink=True)
        grip = bpy.data.objects.get('Grip.' + side)
        if grip:
            grip.location = spines[side][-1]


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    chart = body_builder.use_chart(CHART)
    print('### chart', CHART, proportions.summary(CHART))
    old_body = bpy.data.objects['Body']
    hands = body_builder.hand_assembly(old_body)
    ears = ear_islands(old_body)
    build = body_builder.Build()
    grid, loops, _ = body_builder.build_torso(build)
    body_builder.build_neck(build, grid)
    body_builder.build_legs(build, grid)
    body_builder.build_arms(build, loops, hands)
    mesh, _ = body_builder.write_mesh(build, 'TravellerBody')
    mesh.materials.append(bpy.data.materials['TravellerDrawingBody'])
    old_body.data = mesh
    move_ears_to_head(ears, bpy.data.objects['Head'])
    scale_head(chart['head_scale'])
    rig = bpy.data.objects['Rig']
    clear_pose(rig)
    extend_rig(rig, build.spines)
    influences = skin_body.apply(old_body, rig, build)
    print('### max influences', influences)
    # Exactly one armature modifier. Looking the old one up by the name this
    # script uses missed the inherited modifier ('Body skin'), so every rebuild
    # stacked another and the mesh was deformed twice over.
    for modifier in [m for m in old_body.modifiers if m.type == 'ARMATURE']:
        old_body.modifiers.remove(modifier)
    modifier = old_body.modifiers.new('Body skin', 'ARMATURE')
    modifier.object = rig
    assert sum(1 for m in old_body.modifiers if m.type == 'ARMATURE') == 1
    for key in ('animated_arm_start', 'upper_body_rebuilt'):
        if key in old_body.keys():
            del old_body[key]
    clear_pose(rig)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = old_body.evaluated_get(depsgraph)
    drift = max((evaluated.data.vertices[i].co - mesh.vertices[i].co).length
                for i in range(len(mesh.vertices)))
    print('### rest-pose drift (must be ~0):', round(drift, 6))
    # 64 samples over 3-4 unit area lights dithers the soft shadows badly enough
    # that render noise gets read as faceting. Review renders are cheap; raise it.
    bpy.context.scene.eevee.taa_render_samples = 512
    print('### cloak keys', build_cloak.rebuild(bpy.data.objects['Garment']))
    print('### cloak influences', bind_cloak(bpy.data.objects['Garment'], rig))
    print('### hair faces', build_hair.build(bpy.data.objects['Hair'],
                                             bpy.data.objects['Head']))
    body_builder.report(mesh, 'body')
    check_body.report(old_body, build)
    print('### clearance', check_body.clearance(old_body))
    store_idle_action(rig)
    print('### measured ', check_body.measure())   # in the idle pose
    print('### posed crossings', check_body.crossings(old_body)[0])
    clear_pose(rig)
    print('### clips    ', build_animation.build(rig, bpy.data.objects['Garment']))
    print('### palette  ', dict(check_body.palette_regions()))
    print('### rig bones', len(rig.data.bones),
          [b.name for b in rig.data.bones if 'Arm' in b.name])
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
    print('### saved', TARGET)


if __name__ == '__main__':
    main()

"""Assemble the single Traveller source: new body, extended rig, kept assets.

Run with:
    Blender --background --python art_sources/traveller/build_traveller.py

The accepted Garment (with its nine hood shape keys), Head, Hair and Boots are
carried over untouched. Only the body mesh and the arm bones are rebuilt.
"""
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_body as body_builder
import check_body
import skin_body

SOURCE = HERE.parents[0] / 'traveller_animated/traveller_animated.blend'
TARGET = HERE / 'traveller.blend'
# Four deform segments per arm. Bendy bones do not survive glTF export, so the
# continuous curve has to come from real joints posed along an arc.
ARM_SEGMENTS = [('UpperArm.%s', 0, 3), ('UpperArm.%s.001', 3, 6),
                ('Forearm.%s', 6, 9), ('Forearm.%s.001', 9, 12)]


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
        for template, first, last in ARM_SEGMENTS:
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
    old_body = bpy.data.objects['Body']
    hands = body_builder.hand_assembly(old_body)
    ears = ear_islands(old_body)
    build = body_builder.Build()
    grid, loops, _ = body_builder.build_torso(build, body_builder.arm_spine())
    body_builder.build_neck(build, grid)
    body_builder.build_legs(build, grid)
    body_builder.build_arms(build, loops, hands)
    mesh, _ = body_builder.write_mesh(build, 'TravellerBody')
    mesh.materials.append(bpy.data.materials['TravellerDrawingBody'])
    old_body.data = mesh
    move_ears_to_head(ears, bpy.data.objects['Head'])
    rig = bpy.data.objects['Rig']
    clear_pose(rig)
    extend_rig(rig, build.spines)
    influences = skin_body.apply(old_body, rig, build)
    print('### max influences', influences)
    modifier = old_body.modifiers.get('Armature') or old_body.modifiers.new('Body skin', 'ARMATURE')
    modifier.object = rig
    for key in ('animated_arm_start', 'upper_body_rebuilt'):
        if key in old_body.keys():
            del old_body[key]
    clear_pose(rig)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = old_body.evaluated_get(depsgraph)
    drift = max((evaluated.data.vertices[i].co - mesh.vertices[i].co).length
                for i in range(len(mesh.vertices)))
    print('### rest-pose drift (must be ~0):', round(drift, 6))
    body_builder.report(mesh, 'body')
    check_body.report(old_body, build)
    print('### clearance', check_body.clearance(old_body))
    print('### rig bones', len(rig.data.bones),
          [b.name for b in rig.data.bones if 'Arm' in b.name])
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
    print('### saved', TARGET)


if __name__ == '__main__':
    main()

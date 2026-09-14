"""Check actual baked bones and morphs at 120 Hz, including half-key intervals."""
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from arm_rig import ARM_BONES
from bake_animation import select_clip
from hood_shapes import GRIP_VERTICES, GRIP_FRACTION
from motion import CLIPS

MESHES = ('Head', 'Hair', 'Body', 'Boots', 'Garment')


def surface(obj):
    data = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    data.calc_loop_triangles()
    points = [obj.matrix_world@v.co for v in data.vertices]
    faces = [tuple(p.vertices) for p in data.loop_triangles]
    return points, faces, BVHTree.FromPolygons(points, faces, all_triangles=True)


def self_crossings(faces, tree):
    return sum(a < b and not set(faces[a]).intersection(faces[b]) for a, b in tree.overlap(tree))


def crossings(cloth):
    _, faces, tree = surface(cloth)
    result = {'self': self_crossings(faces, tree)}
    for name in ('Head', 'Hair', 'Body'):
        result[name] = len(tree.overlap(surface(bpy.data.objects[name])[2]))
    return result


def godot(point):
    return Vector((point.x, point.z, -point.y))


def bounds(points):
    lower = [min(point[i] for point in points) for i in range(3)]
    upper = [max(point[i] for point in points) for i in range(3)]
    margin = .015
    return {'position': [value-margin for value in lower],
            'size': [b-a+2*margin for a, b in zip(lower, upper)]}


def run_checks():
    cloth, rig, body = [bpy.data.objects[name] for name in ('Garment', 'Rig', 'Body')]
    select_clip('HoodDown')
    bpy.context.scene.frame_set(0)
    fixed = {name: surface(bpy.data.objects[name])[0] for name in ('Head', 'Hair', 'Boots')}
    stationary = {bone.name: bone.matrix.copy() for bone in rig.pose.bones if bone.name not in ARM_BONES}
    all_points = {name: [] for name in MESHES}
    local_points = {name: [] for name in MESHES}
    report = {'sample_rate_hz': 120, 'samples_per_clip': 241, 'clips': {}}
    for clip in CLIPS:
        select_clip(clip)
        failed, grip_gaps = [], []
        fixed_error = scale_error = 0
        for step in range(241):
            frame = step/2
            bpy.context.scene.frame_set(int(frame), subframe=frame%1)
            current = {name: surface(bpy.data.objects[name]) for name in MESHES}
            points, faces, tree = current['Garment']
            result = {'self': self_crossings(faces, tree)}
            result.update({name: len(tree.overlap(current[name][2])) for name in ('Head', 'Hair', 'Body')})
            arm_points, body_faces, _ = current['Body']
            arm_start = int(body['animated_arm_start'])
            arm_faces = [face for face in body_faces if min(face) >= arm_start]
            arm_tree = BVHTree.FromPolygons(arm_points, arm_faces, all_triangles=True)
            result.update({'Arms/'+name: len(arm_tree.overlap(current[name][2])) for name in ('Head', 'Hair')})
            if any(result.values()):
                failed.append({'seconds': frame/60, **result})
            for name, reference in fixed.items():
                fixed_error = max(fixed_error, max((a-b).length for a, b in zip(current[name][0], reference)))
            for name, matrix in stationary.items():
                fixed_error = max(fixed_error, max(abs(a-b) for ra, rb in zip(rig.pose.bones[name].matrix, matrix) for a, b in zip(ra, rb)))
            scale_error = max(scale_error, max(abs(value-1) for bone in rig.pose.bones for value in bone.scale))
            if 24 <= frame <= (78 if clip == 'HoodDown' else 90):
                for first, second in GRIP_VERTICES.values():
                    point = points[first].lerp(points[second], GRIP_FRACTION)
                    grip_gaps.append(arm_tree.find_nearest(point)[3])
            for name in MESHES:
                all_points[name].extend(godot(point) for point in current[name][0])
                inverse = bpy.data.objects[name].matrix_world.inverted()
                local_points[name].extend(godot(inverse@point) for point in current[name][0])
        report['clips'][clip] = {'failures': failed, 'fixed_geometry_max_error': fixed_error,
                                 'bone_scale_max_error': scale_error,
                                 'rim_midpoint_to_skin_distance': [min(grip_gaps), max(grip_gaps)]}
    counts = {name: len(surface(bpy.data.objects[name])[1]) for name in MESHES}
    report['triangles'] = counts
    report['total_triangles'] = sum(counts.values())
    bones = set(rig.data.bones.keys())
    report['max_bone_influences'] = max(sum(group.weight > 0 and body.vertex_groups[group.group].name in bones for group in vertex.groups) for vertex in body.data.vertices)
    report['garment_modifiers'] = [modifier.type for modifier in cloth.modifiers]
    report['bones'] = len(rig.data.bones)
    report['rigid_attachments'] = {name: bpy.data.objects[name].parent_bone for name in ('Head', 'Hair', 'Garment')}
    report['foot_groups'] = [group.name for group in bpy.data.objects['Boots'].vertex_groups]
    report['passed'] = (report['total_triangles'] <= 8000 and report['max_bone_influences'] <= 4
        and not report['garment_modifiers']
        and all(not data['failures'] and data['fixed_geometry_max_error'] < 1e-6
                and data['bone_scale_max_error'] < 1e-6 for data in report['clips'].values()))
    bound_data = {'global': bounds([p for values in all_points.values() for p in values]),
                  'meshes': {name: bounds(points) for name, points in local_points.items()}}
    (ROOT/'assets/studies/traveller_animated_bounds.json').write_text(json.dumps(bound_data, indent=2)+'\n')
    (HERE/'animation_checks.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2), flush=True)
    assert report['passed'], 'Baked animation check failed; see animation_checks.json'


if __name__ == '__main__':
    run_checks()

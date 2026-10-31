"""Export her to assets/character/girl.glb and check what the game will get.

    blender -b art_sources/girl/girl.blend --python art_sources/girl/export.py

glTF is +Y up: Blender +Z becomes +Y and her front (-Y) becomes +Z, which is
the facing world/character_visual.gd expects. Modifiers (hair Solidify and
Subsurf) are applied; the armature is kept as a skin. Every action is
exported by name. She is 0.8 units tall with her feet at the origin, so the
game uses her at scale 1.
"""
import json
import struct
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'assets/character/girl.glb'
ACTIONS = ('Idle', 'Walk', 'Wake', 'Lift', 'Raise', 'Lower', 'Wave')
TRIANGLE_AIM = 15000
HEIGHT = 0.8


def export(path=TARGET):
    path.parent.mkdir(parents=True, exist_ok=True)
    rig = bpy.data.objects['Girl']
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.collections['Girl'].objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format='GLB', use_selection=True,
        export_yup=True, export_apply=True, export_extras=False,
        export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_frame_step=1,
        export_optimize_animation_size=True, export_anim_single_armature=True,
        export_skins=True, export_all_influences=False, export_morph=False,
        export_rest_position_armature=True, export_reset_pose_bones=True)
    return path


def inspect(path=TARGET):
    data = path.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20 + length])
    report = {'triangles': 0, 'meshes': {}, 'materials': [m['name'] for m in doc.get('materials', [])],
              'skins': [len(s['joints']) for s in doc.get('skins', [])], 'animations': {}}
    lo, hi = [1e9] * 3, [-1e9] * 3
    for node in doc['nodes']:
        if 'mesh' not in node:
            continue
        count = 0
        for prim in doc['meshes'][node['mesh']]['primitives']:
            count += doc['accessors'][prim['indices']]['count'] // 3
            acc = doc['accessors'][prim['attributes']['POSITION']]
            lo = [min(a, b) for a, b in zip(lo, acc['min'])]
            hi = [max(a, b) for a, b in zip(hi, acc['max'])]
        report['meshes'][node['name']] = count
        report['triangles'] += count
    for anim in doc.get('animations', []):
        end = 0.0
        for sampler in anim['samplers']:
            end = max(end, doc['accessors'][sampler['input']]['max'][0])
        report['animations'][anim['name']] = round(end, 3)
    report['bounds'] = ([round(v, 4) for v in lo], [round(v, 4) for v in hi])
    return report


def main():
    path = export()
    report = inspect(path)
    print('### exported', path)
    for key, value in report.items():
        print('###  ', key, value)
    failures = []
    if sorted(report['animations']) != sorted(ACTIONS):
        failures.append('animations %s' % sorted(report['animations']))
    (lo, hi) = report['bounds']
    if abs(hi[1] - HEIGHT) > 0.002 or abs(lo[1]) > 0.002:
        failures.append('height %.4f..%.4f, not 0..%.1f (+Y up)' % (lo[1], hi[1], HEIGHT))
    if report['triangles'] > TRIANGLE_AIM:
        failures.append('triangles %d over %d' % (report['triangles'], TRIANGLE_AIM))
    print('### export check:', 'PASS' if not failures else 'FAIL ' + '; '.join(failures))
    return failures


if __name__ == '__main__':
    sys.exit(1 if main() else 0)

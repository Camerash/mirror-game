"""Export the Traveller to glTF and check what the runtime will actually get.

Run with:
    Blender --background art_sources/traveller/traveller.blend \
        --python art_sources/traveller/export.py
"""
import json
import struct
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'assets/studies/traveller.glb'
PARTS = ('TravellerAnimated', 'Rig', 'Head', 'Hair', 'Body', 'Boots', 'Garment')
TRIANGLE_CEILING = 8000     # GAME_DESIGN.md
ATLAS = (1024, 1024)


def export(path=TARGET):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for name in PARTS:
        obj = bpy.data.objects.get(name)
        if obj:
            obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format='GLB', use_selection=True,
        export_apply=False, export_extras=True, export_animations=True,
        export_animation_mode='ACTIONS', export_merge_animation='NLA_TRACK',
        export_force_sampling=False, export_anim_single_armature=False,
        export_optimize_animation_size=True, export_all_influences=False,
        export_morph=True, export_morph_normal=True)
    return path


def inspect(path=TARGET):
    """Read the GLB back and report what a runtime would load."""
    data = path.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20 + length])
    binary = data[28 + length:]
    report = {'materials': [m['name'] for m in doc.get('materials', [])],
              'images': len(doc.get('images', [])),
              'animations': [a['name'] for a in doc.get('animations', [])],
              'meshes': {}, 'triangles': 0, 'influence_sets': 0}
    for node in doc['nodes']:
        if 'mesh' not in node:
            continue
        primitives = doc['meshes'][node['mesh']]['primitives']
        count = 0
        for primitive in primitives:
            indices = doc['accessors'][primitive['indices']]['count']
            count += indices // 3
            if 'WEIGHTS_1' in primitive['attributes']:
                report['influence_sets'] = max(report['influence_sets'], 2)
            elif 'WEIGHTS_0' in primitive['attributes']:
                report['influence_sets'] = max(report['influence_sets'], 1)
        report['meshes'][node['name']] = count
        report['triangles'] += count
    for image in doc.get('images', []):
        view = doc['bufferViews'][image['bufferView']]
        png = binary[view.get('byteOffset', 0):view.get('byteOffset', 0) + view['byteLength']]
        if png[:8] == b'\x89PNG\r\n\x1a\n':
            report['atlas'] = struct.unpack_from('>II', png, 16)
    joints = {n['name'] for n in doc['nodes'] if 'mesh' not in n and 'children' in n}
    report['skins'] = [len(s['joints']) for s in doc.get('skins', [])]
    return report, doc


def main():
    path = export()
    report, _ = inspect(path)
    print('### exported', path)
    for key in ('materials', 'images', 'atlas', 'meshes', 'triangles',
                'influence_sets', 'skins', 'animations'):
        print('###  ', key, report.get(key))
    failures = []
    if len(report['materials']) > 2:
        failures.append('more than two materials')
    if report['images'] != 1 or report.get('atlas') != ATLAS:
        failures.append('atlas is not a single %dx%d image' % ATLAS)
    if report['triangles'] > TRIANGLE_CEILING:
        failures.append('triangles %d over the %d ceiling'
                        % (report['triangles'], TRIANGLE_CEILING))
    if report['influence_sets'] > 1:
        failures.append('more than four bone influences per vertex')
    print('### export check:', 'PASS' if not failures else 'FAIL ' + '; '.join(failures))
    return failures


if __name__ == '__main__':
    sys.exit(1 if main() else 0)

"""Compare the new static endpoints with the approved drawing source."""
import json
from pathlib import Path
import sys

import bpy
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from bake_animation import select_clip
from check_animation import surface


def main():
    current = {name: bpy.data.objects[name] for name in ('Head', 'Hair', 'Boots', 'Garment')}
    with bpy.data.libraries.load(str(ROOT/'art_sources/traveller_drawing/traveller_drawing.blend'), link=False) as (source, loaded):
        loaded.objects = list(current)
    collection = bpy.data.collections.new('EndpointReference')
    bpy.context.scene.collection.children.link(collection)
    reference = {}
    for name, obj in zip(current, loaded.objects):
        reference[name] = obj
        collection.objects.link(obj)
    report = {}
    select_clip('HoodDown')
    for name in ('Head', 'Hair', 'Boots'):
        a, b = current[name], reference[name]
        assert len(a.data.vertices) == len(b.data.vertices)
        report[name+'_local_vertex_error'] = max((x.co-y.co).length for x, y in zip(a.data.vertices, b.data.vertices))
    old = reference['Garment']
    new = current['Garment']
    original_count = len(old.data.vertices)
    hood_count = int(old['hood_vertices'])
    outer_count = int(new['single_surface_vertices'])
    for name, frame in (('raised', 0), ('lowered', 120)):
        old.data.shape_keys.key_blocks['HoodLowered'].value = float(frame == 120)
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        a = surface(new)[0]
        b = surface(old)[0]
        report[name+'_original_outer_vertex_error'] = max((a[i]-b[i]).length for i in range(original_count))
        report[name+'_hood_lining_vertex_error'] = max((a[i+outer_count]-b[i+original_count]).length for i in range(hood_count))
        outer_faces = [tuple(p.vertices) for p in old.data.polygons]
        outer_tree = BVHTree.FromPolygons(b[:original_count], outer_faces)
        report[name+'_support_row_surface_error'] = max(outer_tree.find_nearest(point)[3] for point in a[original_count:outer_count])
    report['passed'] = max(report.values()) < 1e-6
    (HERE/'endpoint_checks.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))
    assert report['passed'], 'Approved endpoint surface changed'


if __name__ == '__main__':
    main()

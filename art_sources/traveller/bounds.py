"""Sampled culling bounds for the exported clips.

The study writes these into each `MeshInstance3D.custom_aabb` and fits its camera
to the global box, so the camera cannot drift while a clip plays and a skinned
mesh cannot be culled when its pose leaves the rest box. The test checks every
sampled vertex against them.

They are sampled at every half frame, because the test steps 0.125 s and a clip
is 60 frames, so it lands on 7.5, 22.5, 37.5 and 52.5 as well as on whole
frames. Whole frames are not enough: a vertex does not move linearly between
two bone rotations, so it can leave the box that two neighbouring frames span.
That went unnoticed while the arms stayed near the body and the 0.002 margin
covered the error. It stopped being covered when the arms began to reach
outside the cape.

Written in Godot's axes, not Blender's: the exporter turns Z-up into Y-up, so
(x, y, z) here is (x, z, -y) there.
"""
import json
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
TARGET = HERE.parents[1] / 'assets/studies/traveller_bounds.json'
PARTS = ('Head', 'Hair', 'Garment', 'Body', 'Boots')
CLIPS = ('HoodDown', 'HoodUp')
LAST = 60
MARGIN = .002   # so a vertex exactly on a face of the box cannot fail on rounding


def bind(clip):
    """Put both halves of a clip on their owners, bone track and morph track."""
    for owner, suffix in ((bpy.data.objects['Rig'], '.Rig'),
                          (bpy.data.objects['Garment'].data.shape_keys, '.Garment')):
        action = bpy.data.actions.get(clip + suffix)
        if action is None:
            continue
        if not owner.animation_data:
            owner.animation_data_create()
        owner.animation_data.action = action
        for slot in action.slots:
            owner.animation_data.action_slot = slot
            break


def sample():
    """Lowest and highest corner of every part, over every frame of every clip."""
    boxes = {}
    for clip in CLIPS:
        bind(clip)
        for step in range(2 * LAST + 1):
            bpy.context.scene.frame_set(step // 2, subframe=.5 * (step % 2))
            bpy.context.view_layer.update()
            depsgraph = bpy.context.evaluated_depsgraph_get()
            for name in PARTS:
                obj = bpy.data.objects.get(name)
                if obj is None:
                    continue
                evaluated = obj.evaluated_get(depsgraph)
                mesh = evaluated.to_mesh()
                matrix = evaluated.matrix_world
                for vertex in mesh.vertices:
                    point = matrix @ vertex.co
                    here = (point.x, point.z, -point.y)
                    low, high = boxes.get(name, (here, here))
                    boxes[name] = (tuple(min(a, b) for a, b in zip(low, here)),
                                   tuple(max(a, b) for a, b in zip(high, here)))
                evaluated.to_mesh_clear()
    return boxes


def box(low, high):
    return {'position': [value - MARGIN for value in low],
            'size': [high[i] - low[i] + 2 * MARGIN for i in range(3)]}


def write(path=TARGET):
    boxes = sample()
    if not boxes:
        raise RuntimeError('no parts sampled; the clips are missing')
    low = tuple(min(values[0][i] for values in boxes.values()) for i in range(3))
    high = tuple(max(values[1][i] for values in boxes.values()) for i in range(3))
    data = {'global': box(low, high),
            'meshes': {name: box(*values) for name, values in sorted(boxes.items())}}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n')
    print('### bounds', path)
    print('###   global position %s size %s'
          % ([round(v, 4) for v in data['global']['position']],
             [round(v, 4) for v in data['global']['size']]))
    return path


if __name__ == '__main__':
    sys.path.insert(0, str(HERE))
    write()

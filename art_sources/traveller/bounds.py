"""Sampled culling bounds for the exported clips.

The study writes these into each `MeshInstance3D.custom_aabb` and fits its camera
to the global box, so the camera cannot drift while a clip plays and a skinned
mesh cannot be culled when its pose leaves the rest box. The test checks every
sampled vertex against them.

They are sampled at every half frame, because the test steps 0.125 s and a clip
is 60 frames, so it lands on 7.5, 22.5, 37.5 and 52.5 as well as on whole
frames. Whole frames are not enough: a vertex does not move linearly between
two bone rotations, so it can leave the box that two neighbouring frames span.

The three cloak deformations are driven at runtime, not keyed, and they run
both ways, so the box has to hold them as well. They are linear offsets, so the
extreme of any direction is at a corner of the weight cube: the eight corners
are sampled, and only for the garment, because nothing else carries them.

Written in Godot's axes, not Blender's: the exporter turns Z-up into Y-up, so
(x, y, z) here is (x, z, -y) there.
"""
import json
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
TARGET = HERE.parents[1] / 'assets/character/traveller_bounds.json'
PARTS = ('Head', 'Hair', 'Garment', 'Body', 'Boots')
CLIPS = ('HoodDown', 'HoodUp', 'Walk')
DRIFT = ('CloakSide', 'CloakForward', 'CloakTwist')
LAST = 60
MARGIN = .002   # so a vertex exactly on a face of the box cannot fail on rounding


def bind(clip):
    """Put both halves of a clip on their owners, bone track and morph track.

    A clip without a morph half clears the one that is there. The walk has bone
    tracks only, and leaving the previous clip's morph action on the garment
    would fold a hood pose into the walk's own box.
    """
    for owner, suffix in ((bpy.data.objects['Rig'], '.Rig'),
                          (bpy.data.objects['Garment'].data.shape_keys, '.Garment')):
        action = bpy.data.actions.get(clip + suffix)
        if not owner.animation_data:
            owner.animation_data_create()
        owner.animation_data.action = action
        if action is None:
            continue
        for slot in action.slots:
            owner.animation_data.action_slot = slot
            break


def corners():
    """The eight settings of the three runtime deformations, plus all-zero."""
    out = [(0.0, 0.0, 0.0)]
    for first in (-1.0, 1.0):
        for second in (-1.0, 1.0):
            for third in (-1.0, 1.0):
                out.append((first, second, third))
    return out


def widen(boxes, name, points):
    for point in points:
        here = (point.x, point.z, -point.y)
        low, high = boxes.get(name, (here, here))
        boxes[name] = (tuple(min(a, b) for a, b in zip(low, here)),
                       tuple(max(a, b) for a, b in zip(high, here)))


def measure(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    matrix = evaluated.matrix_world
    points = [matrix @ vertex.co for vertex in mesh.vertices]
    evaluated.to_mesh_clear()
    return points


def sample():
    """Lowest and highest corner of every part, over every frame of every clip."""
    boxes = {}
    garment = bpy.data.objects['Garment']
    blocks = garment.data.shape_keys.key_blocks
    for clip in CLIPS:
        bind(clip)
        for step in range(2 * LAST + 1):
            bpy.context.scene.frame_set(step // 2, subframe=.5 * (step % 2))
            bpy.context.view_layer.update()
            for name in PARTS:
                obj = bpy.data.objects.get(name)
                if obj is not None:
                    widen(boxes, name, measure(obj))
            # The garment again, at each corner of the runtime weight cube.
            for setting in corners()[1:]:
                for key, value in zip(DRIFT, setting):
                    blocks[key].value = value
                bpy.context.view_layer.update()
                widen(boxes, 'Garment', measure(garment))
            for key in DRIFT:
                blocks[key].value = 0.0
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

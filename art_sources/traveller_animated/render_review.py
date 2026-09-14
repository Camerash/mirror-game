"""Render both baked clips from fixed cameras for the shape review."""
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from bake_animation import select_clip

OUTPUT = ROOT/'docs/art/traveller-animation/blender'
FRAMES = Path('/tmp/traveller-animation-final-frames')
VIEWS = {'front': (0, -7, 1.8), 'side': (7, 0, 1.8), 'three-quarter': (4.8, -5.2, 2.7)}


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.resolution_percentage = 60
    scene.render.image_settings.file_format = 'PNG'
    scene.render.threads_mode, scene.render.threads = 'FIXED', 4
    for view, position in VIEWS.items():
        scene.camera.location = position
        scene.camera.rotation_euler = (Vector((0, .12, 1.70))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
        scene.camera.data.ortho_scale = 3.90
        for clip in ('HoodDown', 'HoodUp'):
            select_clip(clip)
            directory = FRAMES/view/clip
            directory.mkdir(parents=True, exist_ok=True)
            for sample in range(31):
                scene.frame_set(sample*4)
                scene.render.filepath = str(directory/f'{sample:03d}.png')
                bpy.ops.render.render(write_still=True)
                if sample in (0, 6, 15, 21, 30):
                    (OUTPUT/f'{clip}-{view}-{sample*4:03d}.png').write_bytes(Path(scene.render.filepath).read_bytes())


if __name__ == '__main__':
    main()

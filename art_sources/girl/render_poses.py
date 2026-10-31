"""Render pose stills of her actions into one review sheet. Never saves.

    xvfb-run -a blender -b art_sources/girl/girl.blend --python art_sources/girl/render_poses.py \
        -- OUT.png Action:frame[:yaw] ...

Each still is 320 px square, orthographic, light grey; yaw 0 is from her
front, 90 from her left, 45 her front-left (the game's side), -45 front-right.
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

os.environ['GIRL_REVIEW_IMPORT'] = '1'
sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_review as rr  # noqa: E402

args = sys.argv[sys.argv.index('--') + 1:]
out, shots = Path(args[0]), args[1:]
scene, cam = rr.setup()
rig = bpy.data.objects['Girl']
rig.animation_data_create()
scene.render.resolution_x = scene.render.resolution_y = 320
scene.eevee.taa_render_samples = 12
tiles = []
for i, shot in enumerate(shots):
    tmp = out.parent / ('_still%02d.png' % i)
    parts = shot.split(':')
    name, frame = parts[0], int(parts[1])
    yaw = float(parts[2]) if len(parts) > 2 else 45.0
    elev = math.radians(float(parts[3])) if len(parts) > 3 else math.radians(12)
    act = bpy.data.actions[name]
    rig.animation_data.action = act
    if act.slots:
        rig.animation_data.action_slot = act.slots[0]
    scene.frame_set(frame)
    cam.data.ortho_scale = 1.0
    rr.aim(cam, Vector((0, 0, 0.38)), yaw, elev)
    scene.render.filepath = str(tmp)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(tmp), check_existing=False)
    img.pixels[0]  # load now, before the next render
    tiles.append((img, shot))
    os.remove(tmp)
# Compose with Blender's own image API (no PIL in Blender's Python).
cols = min(6, len(tiles))
rows = math.ceil(len(tiles) / cols)
W = H = 320
sheet = bpy.data.images.new('sheet', cols * W, rows * H)
px = [0.0] * (cols * W * rows * H * 4)
for i, (img, _) in enumerate(tiles):
    c, r = i % cols, rows - 1 - i // cols
    src = list(img.pixels)
    for y in range(H):
        row = ((r * H + y) * cols * W + c * W) * 4
        px[row:row + W * 4] = src[y * W * 4:(y + 1) * W * 4]
sheet.pixels = px
sheet.filepath_raw = str(out)
sheet.file_format = 'PNG'
sheet.save()
print('### sheet', out, '|', ' '.join(s for _, s in tiles))

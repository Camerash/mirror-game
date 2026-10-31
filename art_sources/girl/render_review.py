"""Render the blockout review views and print the shape checks. Never saves.

    blender -b art_sources/girl/girl.blend --python art_sources/girl/render_review.py [-- view ...]

Views: front side back three_quarter game game_small (default: all).
Writes PNGs to docs/art/her/blockout/. game_small uses the game's pixel
density: 80 px for her 0.8 units, standing on a 1-unit snowy cube.
"""
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ.get('GIRL_REVIEW_OUT', ROOT / 'docs/art/her/blockout'))
HEIGHT = 0.8
GAME_PX = 80.0                      # her on-screen height in the game
ELEV = math.radians(30)
SRGB_BG = (222, 223, 227)


def linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def checks():
    dg = bpy.context.evaluated_depsgraph_get()
    tris, top, bottom, report = 0, -1e9, 1e9, []
    for obj in bpy.data.collections['Girl'].objects:
        if obj.type != 'MESH':
            continue
        ev = obj.evaluated_get(dg)
        mesh = ev.to_mesh()
        mesh.calc_loop_triangles()
        n = len(mesh.loop_triangles)
        quads = sum(1 for p in mesh.polygons if len(p.vertices) == 4)
        tris += n
        zs = [(ev.matrix_world @ v.co) for v in mesh.vertices]
        top = max(top, max(v.z for v in zs))
        bottom = min(bottom, min(v.z for v in zs))
        report.append('%-10s tris %5d  quads %3d%%  x %+.3f..%+.3f' % (
            obj.name, n, 100 * quads // max(1, len(mesh.polygons)),
            min(v.x for v in zs), max(v.x for v in zs)))
        ev.to_mesh_clear()
    for line in report:
        print('###  ', line)
    print('### triangles %d, height %.4f (bottom %.4f, top %.4f)' % (tris, top - bottom, bottom, top))
    mitten = bpy.data.objects.get('Mitten.L')
    if mitten:
        xs = [(mitten.matrix_world @ v.co).x for v in mitten.data.vertices]
        print('### mitten centre x %+.3f -> her %s hand (her left is +X, front faces -Y)'
              % (sum(xs) / len(xs), 'LEFT' if sum(xs) > 0 else 'RIGHT'))


def setup():
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.eevee.taa_render_samples = 32
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.render.film_transparent = False
    world = bpy.data.worlds.new('Review')
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (*[linear(v) for v in SRGB_BG], 1)
    bg.inputs['Strength'].default_value = 1.0
    scene.world = world
    # Soft key from the front-left above, a gentle fill; the world adds the rest.
    for name, energy, rot, size in (('Key', 2.2, (50, 0, -35), 18), ('Fill', 0.5, (70, 0, 150), 30)):
        light = bpy.data.lights.new(name, 'SUN')
        light.energy = energy
        light.angle = math.radians(size)
        obj = bpy.data.objects.new(name, light)
        obj.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(obj)
    cam = bpy.data.objects.new('ReviewCam', bpy.data.cameras.new('ReviewCam'))
    cam.data.type = 'ORTHO'
    cam.data.clip_end = 100
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def aim(cam, target, yaw_deg, elev):
    """Camera looking at target from yaw (0 = from -Y, 90 = from +X) and elevation."""
    yaw = math.radians(yaw_deg)
    d = Vector((math.sin(yaw) * math.cos(elev), -math.cos(yaw) * math.cos(elev), math.sin(elev)))
    cam.location = target + d * 10
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()


def snow_cube(scene):
    mat = bpy.data.materials.new('Snow')
    rgb = [linear(v) for v in (226, 230, 236)]
    mat.diffuse_color = (*rgb, 1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*rgb, 1)
    mesh = bpy.data.meshes.new('Cube')
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, -0.5))
    bevel = bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.04, segments=3, affect='EDGES')
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    mesh.materials.append(mat)
    obj = bpy.data.objects.new('SnowCube', mesh)
    scene.collection.objects.link(obj)
    return obj


VIEWS = {  # yaw, elevation, ortho scale, resolution, centre z
    'front': (0, 0, 0.92, 640, 0.40),
    'side': (90, 0, 0.92, 640, 0.40),          # from her left (+X)
    'back': (180, 0, 0.92, 640, 0.40),
    'three_quarter': (-45, 0, 0.92, 640, 0.40),  # her front right
    'game': (45, ELEV, 1.0, 900, 0.38),          # her front left, the game's angle
}


def main():
    wanted = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    wanted = wanted or list(VIEWS) + ['game_small']
    checks()
    scene, cam = setup()
    OUT.mkdir(parents=True, exist_ok=True)
    for name in wanted:
        if name == 'game_small':
            snow_cube(scene)
            # 80 px for a 0.8-unit vertical span seen at 30 degrees.
            px_per_unit = GAME_PX / (HEIGHT * math.cos(ELEV))
            res = 360
            yaw, elev, scale, centre = 45, ELEV, res / px_per_unit, 0.1
        else:
            yaw, elev, scale, res, centre = VIEWS[name]
        scene.render.resolution_x = scene.render.resolution_y = res
        cam.data.ortho_scale = scale
        aim(cam, Vector((0, 0, centre)), yaw, elev)
        scene.render.filepath = str(OUT / ('%s.png' % name))
        bpy.ops.render.render(write_still=True)
        print('### rendered', scene.render.filepath)


if __name__ == "__main__" and not os.environ.get("GIRL_REVIEW_IMPORT"):
    main()

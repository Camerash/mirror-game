"""Build a separate girl blockout study with fixed review cameras.

Run setup() inside Blender. render_view(name, directory) writes a native render.
This study does not export or replace a runtime asset.
"""
from pathlib import Path
import runpy

import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
VIEWS = {
    "front": (0, -5, 0.85),
    "side": (5, 0, 0.85),
    "back": (0, 5, 0.85),
    "three-quarter": (3, -5, 1.9),
    "game": (3, -5, 4.3),
}


def point_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def setup():
    """Create a new study; refuse to overwrite an existing open study."""
    if bpy.data.scenes.get("TravellerGirlStudy"):
        raise RuntimeError("Study already open. Edit it in place or reopen its saved file.")
    scene = bpy.data.scenes.new("TravellerGirlStudy")
    bpy.context.window.scene = scene
    runpy.run_path(str(SOURCE / "blockout.py"))["build_character"]()
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    scene.world = bpy.data.worlds.new("TG_ReviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.55, 0.55, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.4
    review = bpy.data.collections.new("TravellerGirlReview")
    scene.collection.children.link(review)
    for name, position in VIEWS.items():
        data = bpy.data.cameras.new("TG_Camera_" + name)
        data.type = 'ORTHO'
        data.ortho_scale = 2.05
        camera = bpy.data.objects.new(data.name, data)
        review.objects.link(camera)
        camera.location = position
        point_at(camera, (0, 0, 0.82))
    for name, position, energy, size in (
        ("Key", (-3, -4, 5), 400, 4),
        ("Fill", (3, -1, 3), 140, 3),
        ("Rim", (1, 3, 4), 220, 3),
    ):
        data = bpy.data.lights.new("TG_" + name, 'AREA')
        data.energy, data.shape, data.size = energy, 'DISK', size
        light = bpy.data.objects.new(data.name, data)
        review.objects.link(light)
        light.location = position
        point_at(light, (0, 0, 0.8))
    scene.camera = bpy.data.objects["TG_Camera_three-quarter"]
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
            area.spaces.active.shading.color_type = 'MATERIAL'
            area.spaces.active.overlay.show_overlays = False
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "blockout.blend"))
    return scene


def render_view(name, directory):
    if name not in VIEWS:
        raise ValueError("Unknown review camera: " + name)
    scene = bpy.data.scenes["TravellerGirlStudy"]
    directory = Path(directory).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    scene.camera = bpy.data.objects["TG_Camera_" + name]
    scene.render.filepath = str(directory / (name + ".png"))
    bpy.ops.render.render(write_still=True, scene=scene.name)
    return scene.render.filepath

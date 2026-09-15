"""Set matched review views. Use Blender Lab render tools to capture them."""
import bpy
from mathutils import Vector

VIEWS = {
    'front': (0, -7, 2.3),
    'side': (7, 0, 2.3),
    'three-quarter': (5, -7, 3.2),
    'rear': (0, 7, 2.3),
}


def prepare(view, reference=False, gray=False, uncloaked=False):
    scene = bpy.data.scenes['Reference_Source_Unchanged' if reference else 'Scene']
    bpy.context.window.scene = scene
    camera = scene.camera
    camera.location = VIEWS[view]
    camera.rotation_euler = (Vector((0, 0, 1.7)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 3.6
    for obj in scene.objects:
        if obj.name.startswith('Garment'):
            obj.hide_render = uncloaked
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 4
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    gray_material = bpy.data.materials.get('ReviewGray')
    if gray and gray_material is None:
        gray_material = bpy.data.materials.new('ReviewGray')
        gray_material.use_nodes = True
        shader = gray_material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (.36, .36, .36, 1)
        shader.inputs['Roughness'].default_value = .8
    scene.view_layers[0].material_override = gray_material if gray else None
    bpy.context.view_layer.update()

"""Bake editable high-relief ceramic and jade face tiles with Cycles.

Run with: blender --background --python art_sources/reference/bake_reference_detail_maps.py

Each source uses local tile coordinates. Side tiles map (x, y) to UV and top
tiles map (x, z) to UV. The high mesh is a displaced 385-square surface; the
low plane is the selected-to-active bake target.
"""
from pathlib import Path
import math
import bpy


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_sources" / "reference"
ASSETS = ROOT / "assets" / "reference"
SIZE = 1024
GRID = 384


def gaussian(value, width):
    return math.exp(-((value / width) ** 2))


def arch_distance(u, v, centre, radius, base, vertical_scale=1.0):
    """Distance to a round-topped arch centreline, with straight legs."""
    if v <= base:
        return abs(abs(u - centre) - radius)
    return abs(math.hypot(u - centre, (v - base) / vertical_scale) - radius)


def rectangle_distance(u, v, inset):
    return min(abs(u - inset), abs(u - (1.0 - inset)), abs(v - inset), abs(v - (1.0 - inset)))


def ceramic_arch_distance(u, v, centre):
    """Physical-space distance to the approved low semicircle and its legs."""
    horizontal = u - centre
    vertical = v * 0.7
    if vertical <= 0.24:
        return math.hypot(abs(horizontal) - 0.105, max(0.06 - vertical, 0.0))
    return abs(math.hypot(horizontal, vertical - 0.24) - 0.105)


def surface_height(kind, face, u, v):
    # Gentle hand-formed waviness gives the glaze a real, non-flat bake source.
    height = 0.0
    if kind == "jade":
        height = 0.007 * (gaussian(u - 0.22, 0.23) + gaussian(v - 0.68, 0.31) - 1.0)
    elif face == "top":
        height = (0.026 * gaussian(math.hypot(u - 0.47, v - 0.53), 0.44)
                  + 0.003 * gaussian(math.hypot(u - 0.31, v - 0.29), 0.19)
                  - 0.002 * gaussian(math.hypot(u - 0.67, v - 0.62), 0.24)
                  + 0.002 * gaussian(math.hypot(u - 0.78, v - 0.20), 0.13))
    if face == "side":
        if kind == "ceramic":
            for centre in (0.22, 0.50, 0.78):
                distance = ceramic_arch_distance(u, v, centre)
                height -= 0.018 * gaussian(distance, 0.008)
                height += 0.006 * gaussian(distance - 0.014, 0.008)
        else:
            for radius in (0.39, 0.30, 0.21):
                distance = arch_distance(u, v, 0.50, radius, 0.075, 1.85)
                height -= 0.053 * gaussian(distance, 0.018)
                height += 0.014 * gaussian(distance - 0.039, 0.022)
            height += 0.018 * gaussian(rectangle_distance(u, v, 0.055), 0.018)
    else:
        if kind == "jade":
            height += 0.026 * gaussian(rectangle_distance(u, v, 0.075), 0.018)
            height -= 0.035 * gaussian(rectangle_distance(u, v, 0.155), 0.016)
            ring = abs(math.hypot(u - 0.50, v - 0.50) - 0.23)
            height -= 0.040 * gaussian(ring, 0.014)
            height += 0.012 * gaussian(ring - 0.035, 0.020)
    # Small asymmetric fired-glaze pools around borders, made as geometry.
    for x, y, strength in ((0.10, 0.13, 0.006), (0.84, 0.16, 0.004), (0.16, 0.83, 0.005), (0.76, 0.76, 0.004)):
        height += strength * gaussian(math.hypot(u - x, v - y), 0.045)
    return height


def mesh_surface(name, kind, face):
    vertices, faces, uvs = [], [], []
    for row in range(GRID + 1):
        v = row / GRID
        for col in range(GRID + 1):
            u = col / GRID
            horizontal, vertical = u - 0.5, (v - 0.5) * 0.7
            height = surface_height(kind, face, u, v)
            vertices.append((horizontal, vertical, height) if face == "side" else (horizontal, height, v - 0.5))
    for row in range(GRID):
        for col in range(GRID):
            index = row * (GRID + 1) + col
            faces.append((index, index + 1, index + GRID + 2, index + GRID + 1) if face == "side" else (index, index + GRID + 1, index + GRID + 2, index + 1))
            u0, u1, v0, v1 = col / GRID, (col + 1) / GRID, row / GRID, (row + 1) / GRID
            uvs.extend(((u0, v0), (u1, v0), (u1, v1), (u0, v1)) if face == "side" else ((u0, v0), (u0, v1), (u1, v1), (u1, v0)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    uv = mesh.uv_layers.new(name="TileUV")
    for loop, value in zip(uv.data, uvs):
        loop.uv = value
    mesh.update()
    object_ = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(object_)
    return object_


def low_target(name, face):
    vertices = ((-0.5, -0.35, -0.10), (0.5, -0.35, -0.10), (0.5, 0.35, -0.10), (-0.5, 0.35, -0.10)) if face == "side" else ((-0.5, -0.10, -0.5), (0.5, -0.10, -0.5), (0.5, -0.10, 0.5), (-0.5, -0.10, 0.5))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], ((0, 1, 2, 3),) if face == "side" else ((0, 3, 2, 1),))
    uv = mesh.uv_layers.new(name="TileUV")
    coordinates = ((0, 0), (1, 0), (1, 1), (0, 1)) if face == "side" else ((0, 0), (0, 1), (1, 1), (1, 0))
    for loop, value in zip(uv.data, coordinates):
        loop.uv = value
    target = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(target)
    return target


def image(name):
    item = bpy.data.images.new(name, SIZE, SIZE, alpha=False, float_buffer=True)
    item.colorspace_settings.name = "Non-Color"
    item.filepath_raw = str(ASSETS / name)
    item.file_format = "PNG"
    return item


def bake(kind, face):
    high = mesh_surface("%s %s high relief" % (kind, face), kind, face)
    low = low_target("%s %s low bake target" % (kind, face), face)
    normal = image("detail_%s_%s_normal.png" % (kind, face))
    ao = image("detail_%s_%s_ao.png" % (kind, face))
    material = bpy.data.materials.new("Bake target material")
    material.use_nodes = True
    node = material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = normal
    low.data.materials.append(material)
    bpy.context.scene.render.bake.use_selected_to_active = True
    bpy.context.scene.render.bake.cage_extrusion = 0.14
    bpy.context.scene.render.bake.margin = 8
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.context.scene.render.bake.normal_space = "TANGENT"
    bpy.ops.object.bake(type="NORMAL")
    normal.save()
    node.image = ao
    bpy.context.scene.world.color = (0.0, 0.0, 0.0)
    bpy.context.scene.render.bake.use_pass_direct = False
    bpy.context.scene.render.bake.use_pass_indirect = False
    bpy.ops.object.bake(type="AO")
    # Cavity is inverted AO. Convex curvature comes from baked normal divergence;
    # both are derived from the actual Cycles selected-to-active surface bake.
    normal_pixels = list(normal.pixels[:])
    ao_pixels = list(ao.pixels[:])
    packed = image("detail_%s_%s_masks.png" % (kind, face))
    data = [0.0] * (SIZE * SIZE * 4)
    for pixel in range(SIZE * SIZE):
        offset = pixel * 4
        column, row = pixel % SIZE, pixel // SIZE
        left = max(0, column - 1) + row * SIZE
        right = min(SIZE - 1, column + 1) + row * SIZE
        down = column + max(0, row - 1) * SIZE
        up = column + min(SIZE - 1, row + 1) * SIZE
        def normal_component(index, channel):
            return normal_pixels[index * 4 + channel] * 2.0 - 1.0
        # Positive divergence marks outward-convex relief. This is a finite
        # derivative of the selected-to-active baked normal, not a slope mask.
        convex = min(1.0, max(0.0, (normal_component(right, 0) - normal_component(left, 0) + normal_component(up, 1) - normal_component(down, 1)) * 14.0))
        ao_value = ao_pixels[offset]
        data[offset:offset + 4] = (ao_value, 1.0 - ao_value, convex, 1.0)
    packed.pixels.foreach_set(data)
    packed.save()
    # Keep both meshes in the source .blend. They are the editable relief and
    # selected-to-active target for a later rebake.
    high.hide_render = True
    low.hide_render = True


def build(kind):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for face in ("side", "top"):
        bake(kind, face)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / ("detail_%s_source.blend" % kind)))


if __name__ == "__main__":
    ASSETS.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 128
    scene.cycles.use_denoising = False
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    build("ceramic")
    build("jade")

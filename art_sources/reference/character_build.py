"""Build the editable reference traveller and its self-contained GLB export.

The Blender source uses Z-up and faces -Y. The glTF exporter converts that
once to Godot's Y-up, +Z-forward convention.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

SOURCE_DIR = Path(__file__).resolve().parent
ASSET_DIR = SOURCE_DIR.parents[1] / "assets/reference"
OUT_BLEND = str(SOURCE_DIR / "character.blend")
OUT_GLB = str(ASSET_DIR / "character.glb")
ATLAS_PATH = str(ASSET_DIR / "character_cloak_atlas.png")


def material(name, color, roughness=0.6):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*color, 1.0)
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    return value


def make_cloak_material():
    atlas = bpy.data.images.new("Cloak Hem Atlas", 512, 512, alpha=False)
    pixels = []
    # Image pixels are stored as sRGB.  These values decode to the same dark
    # charcoal range as the procedural material under the game renderer.
    band = (0.56, 0.525, 0.455, 1.0)
    charcoal = (0.18, 0.19, 0.21, 1.0)
    for y in range(512):
        v = y / 511.0
        for x in range(512):
            u = x / 511.0
            cell = (u * 12.0) % 1.0
            triangle_top = 0.045 + 0.105 * (1.0 - abs(cell - 0.5) * 2.0)
            is_hem = v < 0.045
            is_triangle_edge = 0.045 <= v <= 0.155 and abs(v - triangle_top) < 0.012
            pixels.extend(band if is_hem or is_triangle_edge else charcoal)
    atlas.pixels.foreach_set(pixels)
    atlas.filepath_raw = ATLAS_PATH
    atlas.file_format = "PNG"
    atlas.save()
    atlas.pack()
    cloak = material("Cloak Charcoal with Grey Beige Triangle Hem", (0.026, 0.029, 0.034), 0.71)
    nodes = cloak.node_tree.nodes
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "Continuous Hem Pattern"
    texture.image = atlas
    cloak.node_tree.links.new(texture.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    return cloak


BLACK = material("Cloak Inner Charcoal", (0.023, 0.025, 0.030), 0.82)
FACE = material("Recessed Ivory Face", (0.72, 0.68, 0.57), 0.54)
SOLE = material("Soft Charcoal Feet", (0.022, 0.024, 0.029), 0.62)


def smooth(obj):
    for face in obj.data.polygons:
        face.use_smooth = True


def uv_sphere(name, location, scale, mat, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def cone(name, radius1, radius2, depth, location, mat, vertices=24):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def mesh_object(name, verts, faces, mat, loop_uvs=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    if loop_uvs is not None:
        layer = mesh.uv_layers.new(name="UVMap")
        for polygon in mesh.polygons:
            for loop_index, uv in zip(polygon.loop_indices, loop_uvs[polygon.index]):
                layer.data[loop_index].uv = uv
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def folded_ring(count, radius_x, radius_y, height, fold_amount, center_y=0.0):
    ring = []
    for index in range(count):
        angle = math.tau * index / count
        fold = 1.0 + fold_amount * math.cos(angle * 6.0 + 0.28)
        ring.append((math.cos(angle) * radius_x * fold, center_y + math.sin(angle) * radius_y * fold, height))
    return ring


def cloak_mesh(cloak_material):
    count = 40
    # Wide lower rows make the clean bell silhouette.  The two lower rows
    # reserve vertical space for the atlas hem instead of a thin edge decal.
    profile = ((0.145, 0.245, 0.183, 0.038), (0.175, 0.253, 0.190, 0.038), (0.215, 0.249, 0.186, 0.035), (0.285, 0.230, 0.173, 0.031), (0.355, 0.205, 0.156, 0.027), (0.420, 0.178, 0.139, 0.022), (0.505, 0.145, 0.117, 0.018), (0.555, 0.118, 0.102, 0.015))
    verts = [point for row in profile for point in folded_ring(count, row[1], row[2], row[0], row[3])]
    faces = []
    loop_uvs = []
    cloak_height = profile[-1][0] - profile[0][0]
    for row in range(len(profile) - 1):
        for index in range(count):
            current = row * count + index
            faces.append((current, row * count + (index + 1) % count, (row + 1) * count + (index + 1) % count, (row + 1) * count + index))
            next_u = 1.0 if index == count - 1 else (index + 1) / count
            lower_v = (profile[row][0] - profile[0][0]) / cloak_height
            upper_v = (profile[row + 1][0] - profile[0][0]) / cloak_height
            loop_uvs.append(((index / count, lower_v), (next_u, lower_v), (next_u, upper_v), (index / count, upper_v)))
    cloak = mesh_object("Cloak", verts, faces, cloak_material, loop_uvs)
    smooth(cloak)
    basis = cloak.shape_key_add(name="Basis")
    hem_x = cloak.shape_key_add(name="HemX")
    hem_z = cloak.shape_key_add(name="HemZ")
    hem_twist = cloak.shape_key_add(name="HemTwist")
    for index, point in enumerate(basis.data):
        strength = max(0.0, 1.0 - (point.co.z - 0.145) / 0.410) ** 1.7
        hem_x.data[index].co = point.co + Vector((0.032 * strength, 0.0, 0.0))
        hem_z.data[index].co = point.co + Vector((0.0, -0.032 * strength, 0.0))
        angle = math.radians(6.0) * strength
        hem_twist.data[index].co = Vector((
            point.co.x * math.cos(angle) - point.co.y * math.sin(angle),
            point.co.x * math.sin(angle) + point.co.y * math.cos(angle),
            point.co.z,
        ))
    for key in cloak.data.shape_keys.key_blocks[1:]:
        key.slider_min = -1.0
        key.slider_max = 1.0
    return cloak


def rounded_hood():
    count = 40

    def oval_ring(y, center_z, radius_x, radius_z):
        return [(math.cos(math.tau * index / count) * radius_x, y, center_z + math.sin(math.tau * index / count) * radius_z) for index in range(count)]

    # Ring zero is the actual opening boundary.  The crown peaks just behind
    # its brow, then each rear ring lowers to form the reference's hood tail.
    cowl = ((-0.100, 0.650, 0.074, 0.106), (-0.064, 0.673, 0.110, 0.137), (-0.028, 0.680, 0.132, 0.136), (0.015, 0.666, 0.163, 0.132), (0.055, 0.645, 0.180, 0.126), (0.132, 0.604, 0.174, 0.096), (0.188, 0.570, 0.112, 0.057))
    outer = oval_ring(*cowl[0])
    rings = [outer] + [oval_ring(*row) for row in cowl[1:]]
    # This inset ring shares the outer boundary and turns it into a real,
    # recessed opening.  It replaces the separate disc-like rim.
    inner = [(x * 0.78, -0.094, 0.650 + (z - 0.650) * 0.78) for x, _, z in outer]
    verts = [point for ring in rings for point in ring] + inner
    faces = []
    for row in range(len(rings) - 1):
        for index in range(count):
            current = row * count + index
            faces.append(((row + 1) * count + index, (row + 1) * count + (index + 1) % count, row * count + (index + 1) % count, current))
    inner_start = len(rings) * count
    for index in range(count):
        faces.append((index, (index + 1) % count, inner_start + (index + 1) % count, inner_start + index))
    cap_index = len(verts)
    verts.append((0.0, 0.215, 0.555))
    last_start = (len(rings) - 1) * count
    for index in range(count):
        faces.append((cap_index, last_start + (index + 1) % count, last_start + index))
    hood = mesh_object("RoundedDrapedHood", verts, faces, BLACK)
    smooth(hood)
    return hood


def hood_opening():
    uv_sphere("OvalFace", (0.0, -0.084, 0.660), (0.030, 0.006, 0.042), FACE, segments=16, rings=10)


def make_rig():
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    rig = bpy.context.object
    rig.name = "ReferenceRig"
    root = rig.data.edit_bones[0]
    root.name = "Root"
    root.head, root.tail = (0, 0, 0), (0, 0, 0.52)
    for name, x in (("LegLeft", -0.075), ("LegRight", 0.075)):
        bone = rig.data.edit_bones.new(name)
        bone.head, bone.tail = (x, 0, 0.12), (x, -0.015, 0.025)
        bone.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    cloak_material = make_cloak_material()
    rig = make_rig()
    cloak_mesh(cloak_material)
    rounded_hood()
    hood_opening()
    for name, x in (("FootLeft", -0.075), ("FootRight", 0.075)):
        cone(name.replace("Foot", "Leg"), 0.034, 0.028, 0.135, (x, 0.010, 0.105), BLACK, vertices=16)
        uv_sphere(name, (x, -0.047, 0.027), (0.049, 0.066, 0.027), SOLE, segments=16, rings=10)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    bpy.ops.object.select_all(action="SELECT")
    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_materials="EXPORT", export_yup=True, export_apply=True)


if __name__ == "__main__":
    main()

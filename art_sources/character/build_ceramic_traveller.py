"""Build the editable ceramic traveller source and its Godot GLB export.

Run with: blender --background --python art_sources/character/build_ceramic_traveller.py
"""
from pathlib import Path
import math
import bpy


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "art_sources" / "character"
ASSET_DIR = ROOT / "assets" / "character"
ATLAS_PATH = ASSET_DIR / "ceramic_traveller_cloak_atlas.png"
BLEND_PATH = SOURCE_DIR / "ceramic_traveller.blend"
GLB_PATH = ASSET_DIR / "ceramic_traveller.glb"


def make_atlas():
    """A small painted fabric field with a scalloped, triangular hem band."""
    image = bpy.data.images.new("CeramicTravellerCloakAtlas", 1024, 1024)
    pixels = [0.0] * (1024 * 1024 * 4)
    for y in range(1024):
        for x in range(1024):
            weave = 0.003 * math.sin(x * 1.9) * math.sin(y * 1.4)
            border = y < 188
            local_x = (x % 128) / 128.0
            local_y = y / 188.0
            triangle_edge = abs(local_y - (1.0 - abs(local_x - 0.5) * 2.0)) < 0.045
            inner_edge = abs(local_y - (0.67 - abs(local_x - 0.5) * 1.35)) < 0.035
            base = (0.105 + weave, 0.082 + weave, 0.13 + weave, 1.0)
            if border:
                base = (0.105 + weave, 0.082 + weave, 0.13 + weave, 1.0)
                if triangle_edge or inner_edge:
                    base = (0.59, 0.53, 0.42, 1.0)
            index = (y * 1024 + x) * 4
            pixels[index:index + 4] = base
    image.pixels = pixels
    image.filepath_raw = str(ATLAS_PATH)
    image.file_format = "PNG"
    image.save()
    return image


def material(name, color, roughness, image=None):
    result = bpy.data.materials.new(name)
    if bpy.app.version < (5, 0, 0):
        result.use_nodes = True
    principled = result.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Roughness"].default_value = roughness
    if image:
        texture = result.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image = image
        result.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
    return result


def lathe(name, profile, material_slot, parent, folds=0.0):
    smooth = []
    for index in range(len(profile) - 1):
        a, b = profile[max(0, index - 1)], profile[index]
        c, d = profile[index + 1], profile[min(len(profile) - 1, index + 2)]
        for step in range(4):
            t = step / 4
            radius = 0.5 * (2*b[0] + (-a[0]+c[0])*t + (2*a[0]-5*b[0]+4*c[0]-d[0])*t*t + (-a[0]+3*b[0]-3*c[0]+d[0])*t*t*t)
            smooth.append((max(0, radius), b[1] + (c[1]-b[1])*t))
    smooth.append(profile[-1])
    profile = smooth
    sides = 48
    vertices = []
    faces = []
    for radius, height in profile:
        for side in range(sides):
            angle = side * math.tau / sides
            variation = 1.0 + folds * math.sin(angle * 3.0 + height * 17.0) \
                        + folds * 0.45 * math.sin(angle * 5.0 - height * 11.0)
            vertices.append((radius * variation * math.cos(angle), radius * variation * math.sin(angle), height))
    for ring in range(len(profile) - 1):
        for side in range(sides):
            next_side = (side + 1) % sides
            faces.append((ring * sides + side, ring * sides + next_side,
                          (ring + 1) * sides + next_side, (ring + 1) * sides + side))
    if profile[0][0] > 0.0:
        vertices.append((0.0, 0.0, profile[0][1]))
        centre = len(vertices) - 1
        for side in range(sides):
            faces.append((centre, side, (side + 1) % sides))
    if profile[-1][0] > 0.0:
        vertices.append((0.0, 0.0, profile[-1][1]))
        centre = len(vertices) - 1
        offset = (len(profile) - 1) * sides
        for side in range(sides):
            faces.append((centre, offset + (side + 1) % sides, offset + side))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material_slot)
    object_3d = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(object_3d)
    object_3d.parent = parent
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    uv = mesh.uv_layers.new(name="CloakUV")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            angle = math.atan2(vertex.y, vertex.x) / math.tau + 0.5
            uv.data[loop_index].uv = (angle, max(0.0, (vertex.z - 0.145) / 0.47) if name == "Cloak" else 0.4 + vertex.z * 0.5)
    return object_3d


def uv_sphere(name, location, scale, material_slot, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=location)
    object_3d = bpy.context.object
    object_3d.name = name
    object_3d.scale = scale
    object_3d.data.materials.append(material_slot)
    object_3d.parent = parent
    bpy.ops.object.shade_smooth()
    return object_3d


def build():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    atlas = make_atlas()
    cloak_material = material("Cloak fabric", (0.11, 0.08, 0.13), 0.67, atlas)
    ceramic = material("Ivory ceramic face", (0.88, 0.82, 0.67), 0.31)
    shoe = material("Dark glazed feet", (0.055, 0.045, 0.065), 0.42)
    aperture = material("Hood aperture", (0.025, 0.02, 0.035), 0.72)
    root = bpy.data.objects.new("CeramicTraveller", None)
    bpy.context.collection.objects.link(root)
    rig = bpy.data.objects.new("CloakRig", None)
    bpy.context.collection.objects.link(rig)
    rig.parent = root
    cloak = lathe("Cloak", [(0.0, 0.105), (0.09, 0.12), (0.175, 0.155),
                           (0.172, 0.20), (0.154, 0.36), (0.135, 0.52),
                           (0.105, 0.59), (0.0, 0.62)], cloak_material, rig, 0.035)
    cloak.shape_key_add(name="Basis")
    for name, axis, sign in [("HemX", 0, 1), ("HemZ", 1, -1)]:
        key = cloak.shape_key_add(name=name)
        key.slider_min = -1.0
        for vertex in key.data:
            weight = max(0.0, min(1.0, (0.53 - vertex.co.z) / 0.4)) ** 2
            vertex.co[axis] += sign * 0.035 * weight
    lathe("Hood", [(0.0, 0.505), (0.13, 0.54), (0.157, 0.64),
                   (0.126, 0.73), (0.06, 0.79), (0.0, 0.805)], cloak_material, rig, 0.018)
    uv_sphere("HoodAperture", (0.0, -0.145, 0.632), (0.040, 0.014, 0.055), aperture, rig)
    uv_sphere("Face", (0.0, -0.159, 0.632), (0.020, 0.012, 0.0275), ceramic, rig)
    uv_sphere("FootLeft", (-0.066, -0.014, 0.045), (0.055, 0.075, 0.045), shoe, root)
    uv_sphere("FootRight", (0.066, -0.014, 0.045), (0.055, 0.075, 0.045), shoe, root)
    bpy.context.view_layer.objects.active = root
    root.select_set(True)
    atlas.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(GLB_PATH), export_format="GLB", export_materials="EXPORT",
                              export_image_format="AUTO", export_apply=True, export_yup=True)


if __name__ == "__main__":
    build()

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
    pale = (0.77, 0.71, 0.58, 1.0)
    black = (0.0003, 0.0004, 0.0007, 1.0)
    for y in range(512):
        v = y / 511.0
        for x in range(512):
            u = x / 511.0
            cell = (u * 18.0) % 1.0
            triangle_top = 0.035 + 0.075 * (1.0 - abs(cell - 0.5) * 2.0)
            is_baseline = v < 0.035
            is_triangle_edge = v < 0.115 and abs(v - triangle_top) < 0.008
            pixels.extend(pale if is_baseline or is_triangle_edge else black)
    atlas.pixels.foreach_set(pixels)
    atlas.filepath_raw = ATLAS_PATH
    atlas.file_format = "PNG"
    atlas.save()
    atlas.pack()
    cloak = material("Cloak Black with Pale Scallop Hem", (0.0003, 0.0004, 0.0007), 0.71)
    nodes = cloak.node_tree.nodes
    texture = nodes.new("ShaderNodeTexImage")
    texture.name = "Continuous Hem Pattern"
    texture.image = atlas
    cloak.node_tree.links.new(texture.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    return cloak


BLACK = material("Cloak Inner Black", (0.0001, 0.0001, 0.0002), 0.82)
FACE = material("Warm Porcelain Face", (0.88, 0.69, 0.49), 0.54)
SOLE = material("Soft Black Feet", (0.018, 0.020, 0.026), 0.62)


def smooth(obj):
    for face in obj.data.polygons:
        face.use_smooth = True


def uv_sphere(name, location, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=location)
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


def folded_ring(count, radius_x, radius_y, height, fold_amount):
    ring = []
    for index in range(count):
        angle = math.tau * index / count
        fold = 1.0 + fold_amount * math.cos(angle * 6.0 + 0.28)
        ring.append((math.cos(angle) * radius_x * fold, math.sin(angle) * radius_y * fold, height))
    return ring


def cloak_mesh(cloak_material):
    count = 48
    profile = ((0.105, 0.255, 0.190, 0.060), (0.130, 0.270, 0.200, 0.058), (0.170, 0.265, 0.196, 0.056), (0.225, 0.245, 0.182, 0.052), (0.290, 0.220, 0.165, 0.049), (0.355, 0.195, 0.148, 0.045), (0.415, 0.173, 0.132, 0.041), (0.465, 0.153, 0.120, 0.035), (0.505, 0.137, 0.111, 0.029), (0.525, 0.132, 0.108, 0.025))
    # Shorter, narrower cloak leaves the small legs visible at the stage camera angle.
    profile = tuple((0.18 + (row[0] - 0.105) * (0.345 / 0.420), row[1] * 0.86, row[2] * 0.86, row[3]) for row in profile)
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
    for index, point in enumerate(basis.data):
        strength = max(0.0, 1.0 - point.co.z / 0.53) ** 1.7
        hem_x.data[index].co = point.co + Vector((0.032 * strength, 0.0, 0.0))
        hem_z.data[index].co = point.co + Vector((0.0, -0.026 * strength, 0.0))
    return cloak


def rounded_hood():
    count = 64
    profile = ((0.470, 0.155, 0.125, 0.028), (0.515, 0.164, 0.134, 0.030), (0.555, 0.168, 0.138, 0.030), (0.590, 0.166, 0.137, 0.029), (0.625, 0.162, 0.133, 0.028), (0.660, 0.155, 0.128, 0.026), (0.695, 0.145, 0.120, 0.023), (0.730, 0.130, 0.110, 0.020), (0.765, 0.105, 0.090, 0.016), (0.795, 0.065, 0.058, 0.008), (0.812, 0.018, 0.018, 0.000))
    verts = [point for row in profile for point in folded_ring(count, row[1], row[2], row[0], row[3])]
    faces = []
    for row in range(len(profile) - 1):
        for index in range(count):
            angle = math.tau * (index + 0.5) / count
            x = math.cos(angle) * (profile[row][1] + profile[row + 1][1]) * 0.5
            z = (profile[row][0] + profile[row + 1][0]) * 0.5
            # The front panel is removed as an oval, so the rim shares a real
            # opening instead of concealing a rectangular slit.
            if (x / 0.067) ** 2 + ((z - 0.640) / 0.087) ** 2 < 1.0 and math.sin(angle) < -0.70:
                continue
            current = row * count + index
            faces.append((current, row * count + (index + 1) % count, (row + 1) * count + (index + 1) % count, (row + 1) * count + index))
    cap_index = len(verts)
    verts.append((0.0, 0.0, 0.816))
    for index in range(count):
        faces.append(((len(profile) - 1) * count + index, (len(profile) - 1) * count + (index + 1) % count, cap_index))
    hood = mesh_object("RoundedDrapedHood", verts, faces, BLACK)
    smooth(hood)
    subdivision = hood.modifiers.new("Soft Hood Surface", "SUBSURF")
    subdivision.levels = 2
    subdivision.render_levels = 2
    return hood


def hood_opening():
    def front_surface(x, z):
        samples = ((0.515, 0.164, 0.134), (0.555, 0.168, 0.138), (0.625, 0.162, 0.133), (0.660, 0.155, 0.128), (0.730, 0.130, 0.110))
        lower, upper = samples[0], samples[-1]
        for candidate in samples[1:]:
            if z <= candidate[0]:
                upper = candidate
                break
            lower = candidate
        blend = (z - lower[0]) / (upper[0] - lower[0]) if upper[0] != lower[0] else 0.0
        radius_x = lower[1] + (upper[1] - lower[1]) * blend
        radius_y = lower[2] + (upper[2] - lower[2]) * blend
        return -radius_y * math.sqrt(max(0.0, 1.0 - (x / radius_x) ** 2))

    count = 48
    outer = []
    inner = []
    for index in range(count):
        angle = math.tau * index / count
        for ring, radius_x, radius_z in ((outer, 0.078, 0.096), (inner, 0.055, 0.071)):
            x = math.cos(angle) * radius_x
            z = 0.640 + math.sin(angle) * radius_z
            ring.append((x, front_surface(x, z) - 0.002, z))
    uv_sphere("HoodOpeningRecess", (0.0, -0.065, 0.640), (0.130, 0.060, 0.145), BLACK)
    rim = mesh_object("HoodOpeningRim", outer + inner, [(index, (index + 1) % count, count + (index + 1) % count, count + index) for index in range(count)], BLACK)
    smooth(rim)
    uv_sphere("OvalFace", (0.0, -0.128, 0.640), (0.034, 0.008, 0.046), FACE)


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
        cone(name.replace("Foot", "Leg"), 0.037, 0.030, 0.175, (x, 0.015, 0.117), BLACK)
        uv_sphere(name, (x, -0.042, 0.026), (0.052, 0.071, 0.026), SOLE)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    bpy.ops.object.select_all(action="SELECT")
    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_materials="EXPORT", export_yup=True, export_apply=True)


if __name__ == "__main__":
    main()

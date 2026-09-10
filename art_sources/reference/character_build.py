"""Build the editable reference traveller and its self-contained GLB export."""
import bpy
import math
from pathlib import Path
from mathutils import Matrix, Vector

SOURCE_DIR = Path(__file__).resolve().parent
OUT_BLEND = str(SOURCE_DIR / "character.blend")
OUT_GLB = str(SOURCE_DIR.parents[1] / "assets/reference/character.glb")


def material(name, color, metallic=0.0, roughness=0.6):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*color, 1.0)
    node = value.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1.0)
    node.inputs["Roughness"].default_value = roughness
    node.inputs["Metallic"].default_value = metallic
    return value


BLACK = material("Cloak Black", (0.008, 0.010, 0.016), 0.05, 0.70)
HEM = material("Pale Hem", (0.78, 0.71, 0.57), 0.0, 0.75)
FACE = material("Warm Porcelain Face", (0.88, 0.69, 0.49), 0.0, 0.57)
SOLE = material("Soft Black Feet", (0.018, 0.020, 0.026), 0.0, 0.62)


def smooth(obj):
    for face in obj.data.polygons:
        face.use_smooth = True


def uv_sphere(name, location, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def cone(name, radius1, radius2, depth, location, mat, vertices=32):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def mesh_object(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return obj


def cloak_mesh():
    count = 36
    verts = []
    for y, rx, rz in ((0.12, 0.235, 0.185), (0.155, 0.222, 0.176), (0.48, 0.145, 0.115), (0.56, 0.105, 0.088)):
        for i in range(count):
            angle = math.tau * i / count
            # A slim forward-facing flare with soft longitudinal folds.
            fold = 1.0 + 0.045 * math.cos(angle * 6.0)
            verts.append((math.sin(angle) * rx * fold, y, math.cos(angle) * rz * fold))
    faces = []
    face_materials = []
    hem_triangles = {0, 4, 32}
    for ring in range(3):
        for i in range(count):
            lower = ring * count + i
            lower_next = ring * count + (i + 1) % count
            upper = (ring + 1) * count + i
            upper_next = (ring + 1) * count + (i + 1) % count
            if ring == 0:
                faces.extend(((lower, lower_next, upper_next), (lower, upper_next, upper)))
                face_materials.extend((1 if i in hem_triangles else 0, 0))
            else:
                faces.append((lower, lower_next, upper_next, upper))
                face_materials.append(0)
    faces.append(tuple(range(count - 1, -1, -1)))
    face_materials.append(0)
    cloak = mesh_object("Cloak", verts, faces, BLACK)
    cloak.data.materials.append(HEM)
    for index, material_index in enumerate(face_materials):
        cloak.data.polygons[index].material_index = material_index
    smooth(cloak)
    # Small reversible cloth motion for Godot; it only changes the rear hem.
    key = cloak.shape_key_add(name="Basis")
    sway_x = cloak.shape_key_add(name="HemX")
    sway_z = cloak.shape_key_add(name="HemZ")
    for index in range(count):
        point = cloak.data.shape_keys.key_blocks["Basis"].data[index].co
        sway_x.data[index].co = point + Vector((0.028, 0.0, 0.0))
        sway_z.data[index].co = point + Vector((0.0, 0.0, -0.020))
    return cloak


def pointed_hood():
    count = 32
    verts = []
    # Bottom hood ring, shoulder ring, then a forward-directed apex.
    for y, rx, rz, z_shift in ((0.56, 0.145, 0.108, 0.0), (0.70, 0.126, 0.100, -0.010)):
        for i in range(count):
            angle = math.tau * i / count
            verts.append((math.sin(angle) * rx, y, math.cos(angle) * rz + z_shift))
    verts.append((0.0, 0.795, 0.205))
    faces = []
    for i in range(count):
        faces.append((i, (i + 1) % count, count + (i + 1) % count, count + i))
        faces.append((count + i, count + (i + 1) % count, count * 2))
    hood = mesh_object("PointedForwardHood", verts, faces, BLACK)
    smooth(hood)
    return hood


def make_rig():
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    rig = bpy.context.object
    rig.name = "ReferenceRig"
    rig.data.name = "ReferenceRig"
    root = rig.data.edit_bones[0]
    root.name = "Root"
    root.head, root.tail = (0, 0.05, 0), (0, 0.57, 0)
    for name, x in (("LegLeft", -0.075), ("LegRight", 0.075)):
        bone = rig.data.edit_bones.new(name)
        bone.head, bone.tail = (x, 0.12, 0), (x, 0.025, 0.025)
        bone.parent = root
    hem_bone = rig.data.edit_bones.new("Hem")
    hem_bone.head, hem_bone.tail = (0, 0.13, -0.04), (0, 0.27, -0.04)
    hem_bone.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = False
    return rig


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    rig = make_rig()
    cloak = cloak_mesh()
    pointed_hood()
    # Face is deliberately small and recessed in the hood opening, on +Z.
    uv_sphere("OvalFace", (0, 0.607, 0.122), (0.042, 0.053, 0.013), FACE)
    for name, x, bone in (("FootLeft", -0.075, "LegLeft"), ("FootRight", 0.075, "LegRight")):
        leg = cone(name.replace("Foot", "Leg"), 0.038, 0.031, 0.105, (x, 0.092, 0.005), BLACK, 16)
        foot = uv_sphere(name, (x, 0.026, 0.041), (0.055, 0.025, 0.077), SOLE)
    # The compact rig is retained for DCC edits. Named nodes remain independent
    # because Godot drives the restrained gait and the cloth shape keys directly.
    # Blender is Z-up while Godot is Y-up. Apply one complete coordinate conversion
    # to both mesh data and object translations so attached details do not separate.
    bpy.ops.object.select_all(action="SELECT")
    coordinate_conversion = Matrix.Rotation(math.pi * 0.5, 4, "X")
    for obj in bpy.context.selected_objects:
        obj.matrix_world = coordinate_conversion @ obj.matrix_world
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    bpy.ops.object.select_all(action="SELECT")
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_materials="EXPORT", export_yup=True, export_apply=True)


if __name__ == "__main__":
    main()

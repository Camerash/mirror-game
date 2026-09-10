"""Build the rounded ceramic and jade reference blocks.

Run with: blender --background --python art_sources/reference/build_reference_blocks.py
"""
from pathlib import Path
import bpy


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_sources" / "reference"
ASSETS = ROOT / "assets" / "reference"


def material(name, colour, roughness):
    result = bpy.data.materials.new(name)
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = 0.55
    return result


def rounded_core(name, surface):
    # Blender is Z-up; the GLB exporter maps this to Godot's Y-up space.
    bpy.ops.mesh.primitive_cube_add(location=(0.0, 0.0, 0.35))
    block = bpy.context.object
    block.name = name
    block.dimensions = (1.0, 1.0, 0.7)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    block.data.materials.append(surface)
    bevel = block.modifiers.new("Soft 0.09 bevel", "BEVEL")
    bevel.width = 0.09
    bevel.segments = 5
    bevel.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = block
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for face in block.data.polygons:
        face.use_smooth = True
    weighted = block.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    weighted.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    return block


def build(kind):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    colour = (0.82, 0.75, 0.61) if kind == "ceramic" else (0.27, 0.47, 0.34)
    surface = material("%s reference glaze" % kind.title(), colour, 0.24 if kind == "ceramic" else 0.31)
    root = bpy.data.objects.new("%sReferenceBlock" % kind.title(), None)
    bpy.context.collection.objects.link(root)
    core = rounded_core("%s block core" % kind.title(), surface)
    core.parent = root
    bpy.context.view_layer.objects.active = root
    root.select_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (kind + "_block.blend")))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(ASSETS / (kind + "_block.glb")), export_format="GLB",
                              export_materials="EXPORT", export_apply=True, export_yup=True)


if __name__ == "__main__":
    ASSETS.mkdir(parents=True, exist_ok=True)
    build("ceramic")
    build("jade")

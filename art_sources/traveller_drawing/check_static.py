"""Focused construction checks. --raised checks only the initial cloth fit."""
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def mesh_surface(obj, evaluated=False, key_name=None):
    data = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).data if evaluated else obj.data
    points = [v.co.copy() for v in (data.shape_keys.key_blocks[key_name].data
              if key_name and data.shape_keys else data.vertices)]
    faces = [tuple(p.vertices) for p in data.polygons]
    return points, faces, BVHTree.FromPolygons(points, faces)


def inspect_pose(cloth, pose):
    if cloth.data.shape_keys and "HoodLowered" in cloth.data.shape_keys.key_blocks:
        cloth.data.shape_keys.key_blocks["HoodLowered"].value = float(pose == "HoodLowered")
    bpy.context.view_layer.update()
    _, faces, outer = mesh_surface(cloth, key_name=pose)
    self_pairs = [(a, b) for a, b in outer.overlap(outer)
                  if a < b and not set(faces[a]).intersection(faces[b])]
    _, shell_faces, shell = mesh_surface(cloth, True)
    shell_pairs = [(a, b) for a, b in shell.overlap(shell)
                   if a < b and not set(shell_faces[a]).intersection(shell_faces[b])]
    results = {"outer_self_crossings": len(self_pairs)}
    results["shell_self_crossings"] = len(shell_pairs)
    for name in ("Head", "Hair", "Body"):
        results[name+"_crossings"] = len(shell.overlap(mesh_surface(bpy.data.objects[name])[2]))
    return results


def cloth_metrics(cloth, region):
    keys = cloth.data.shape_keys.key_blocks
    raised = np.array([v.co[:] for v in keys["Basis"].data])
    lowered = np.array([v.co[:] for v in keys["HoodLowered"].data])
    changed = np.linalg.norm(lowered-raised, axis=1) > 1e-7
    selected = [p for p in cloth.data.polygons if region == "whole" or
                p.index < cloth["hood_triangles"] or
                (region == "moving" and any(changed[i] for i in p.vertices))]
    triangles = np.array([p.vertices[:] for p in selected])
    edges = np.array(sorted({tuple(sorted((a, b))) for face in triangles
                            for a, b in zip(face, np.roll(face, -1))}))
    length = lambda p: np.linalg.norm(p[edges[:, 1]]-p[edges[:, 0]], axis=1)
    areas = lambda p: np.linalg.norm(np.cross(p[triangles[:, 1]]-p[triangles[:, 0]],
                                             p[triangles[:, 2]]-p[triangles[:, 0]]), axis=1)/2
    strain = abs(length(lowered)/length(raised)-1)
    return {"raised_area": float(areas(raised).sum()), "lowered_area": float(areas(lowered).sum()),
            "area_change": float(areas(lowered).sum()/areas(raised).sum()-1),
            "edge_strain_p95": float(np.percentile(strain, 95)), "edge_strain_max": float(strain.max()),
            "minimum_triangle_area": float(min(areas(raised).min(), areas(lowered).min())),
            "edges_checked": len(edges)}


def components(data):
    parent = list(range(len(data.vertices)))
    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for edge in data.edges:
        a, b = edge.vertices
        parent[root(a)] = root(b)
    return len({root(i) for i in range(len(parent))})


def main():
    cloth = bpy.data.objects["Garment"]
    if cloth.data.shape_keys and "HoodLowered" in cloth.data.shape_keys.key_blocks:
        cloth.data.shape_keys.key_blocks["HoodLowered"].value = 0
    bpy.context.view_layer.update()
    result = {"Basis": inspect_pose(cloth, "Basis"), "stage": cloth["stage"],
              "check_scope": "raised draft" if "--raised" in sys.argv else "both endpoints"}
    points, faces, _ = mesh_surface(cloth)
    triangles = np.array(faces)
    points = np.array(points)
    areas = np.linalg.norm(np.cross(points[triangles[:, 1]]-points[triangles[:, 0]],
                                    points[triangles[:, 2]]-points[triangles[:, 0]]), axis=1)/2
    result["outer_triangles"] = len(faces)
    result["outer_area"] = float(areas.sum())
    result["minimum_triangle_area"] = float(areas.min())
    failures = []
    objects = [bpy.data.objects[name] for name in ("Head", "Hair", "Body", "Boots", "Garment")]
    counts = {}
    for obj in objects:
        data = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
        data.calc_loop_triangles()
        counts[obj.name] = len(data.loop_triangles)
    result["triangles"] = counts
    result["total_triangles"] = sum(counts.values())
    if result["total_triangles"] > 8000:
        failures.append("Triangle limit")
    result["components"] = {name: components(bpy.data.objects[name].data)
                            for name in ("Hair", "Boots", "Garment")}
    if result["components"] != {"Hair": 1, "Boots": 2, "Garment": 1}:
        failures.append("Hair, shoes, or sewn garment is disconnected")
    result["deformation_keys"] = {obj.name: len(obj.data.shape_keys.key_blocks)
                                  if obj.data.shape_keys else 0 for obj in objects}
    source = Path(__file__).resolve().parents[1]/"traveller_full/traveller_full.blend"
    with bpy.data.libraries.load(str(source), link=False) as (_, loaded):
        loaded.objects = ["Hair"]
    original = loaded.objects[0]
    current = bpy.data.objects["Hair"]
    result["hair_coordinates_preserved"] = (len(original.data.vertices) == len(current.data.vertices) and
        all(a.co == b.co for a, b in zip(original.data.vertices, current.data.vertices)))
    bpy.data.objects.remove(original)
    if not result["hair_coordinates_preserved"]:
        failures.append("The full hairstyle changed")
    materials = {material for obj in objects for material in obj.data.materials}
    images = {node.image for material in materials for node in material.node_tree.nodes
              if node.type == "TEX_IMAGE"}
    result["materials"] = sorted(material.name for material in materials)
    result["atlas_sizes"] = [list(image.size) for image in images]
    if len(materials) != 2 or len(images) != 1 or any(tuple(image.size) != (1024, 1024) for image in images):
        failures.append("Material or atlas contract")
    result["opaque_materials"] = all(node.inputs["Alpha"].default_value == 1 and
        not node.inputs["Alpha"].is_linked for material in materials
        for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    if not result["opaque_materials"]:
        failures.append("Non-opaque material")
    body = bpy.data.objects["Body"]
    arm_group = body.vertex_groups.get("ConcealedArms")
    arm_points = [v.co for v in body.data.vertices if arm_group and
                  any(g.group == arm_group.index for g in v.groups)]
    result["concealed_arm_vertices"] = len(arm_points)
    if not arm_points or len(arm_points) != body.get("concealed_arm_vertices", 0):
        failures.append("Concealed arms are absent")
    _, _, outer = mesh_surface(cloth)
    arm_indices = {v.index for v in body.data.vertices if arm_group and
                   any(g.group == arm_group.index for g in v.groups)}
    torso = BVHTree.FromPolygons([v.co for v in body.data.vertices],
                [tuple(p.vertices) for p in body.data.polygons if not arm_indices.intersection(p.vertices)])
    directions = [Vector((np.cos(a), np.sin(a), 0)) for a in np.arange(8)*np.pi/4]
    misses = sum(outer.ray_cast(point, direction, 3)[0] is None and
                 torso.ray_cast(point, direction, 3)[0] is None
                 for point in arm_points for direction in directions)
    result["arm_coverage_rays"] = len(arm_points)*len(directions)
    result["arm_coverage_misses"] = misses
    if misses:
        failures.append("Arms are visible through the cloth opening")
    for name, value in result["Basis"].items():
        if value:
            failures.append("Basis: "+name)
    has_lowered = bool(cloth.data.shape_keys and "HoodLowered" in cloth.data.shape_keys.key_blocks)
    result["lowered_pose_available"] = has_lowered
    if "--raised" not in sys.argv and not has_lowered:
        failures.append("Lowered endpoint is not delivered; this is a raised-only draft")
    if "--raised" not in sys.argv and has_lowered:
        result["HoodLowered"] = inspect_pose(cloth, "HoodLowered")
        for name, value in result["HoodLowered"].items():
            if value:
                failures.append("HoodLowered: "+name)
        for name, region in (("hood_cloth", "hood"), ("moving_cloth", "moving"), ("whole_cloth", "whole")):
            metrics = cloth_metrics(cloth, region)
            result[name] = metrics
            if abs(metrics["area_change"]) > .05 or metrics["edge_strain_p95"] > .10 or metrics["edge_strain_max"] > .20:
                failures.append(name+": area or edge limit")
        keys = cloth.data.shape_keys.key_blocks
        shift = max((a.co-b.co).length for a, b in zip(keys["Basis"].data, keys["HoodLowered"].data))
        result["maximum_pose_shift"] = shift
        if shift < .25:
            failures.append("Folded endpoint is absent")
        seam_shift = max((keys["Basis"].data[i].co-keys["HoodLowered"].data[i].co).length
                         for i in cloth["neckline_indices"])
        result["neckline_shift"] = seam_shift
        clasp = (0, 20, cloth["hood_vertices"], cloth["hood_vertices"]+len(cloth["neckline_indices"])-1)
        clasp_shift = max((keys["Basis"].data[i].co-keys["HoodLowered"].data[i].co).length for i in clasp)
        result["clasp_shift"] = clasp_shift
        if clasp_shift > .0001:
            failures.append("Clasp moves")
    result["failures"] = failures
    print(json.dumps(result, indent=2))
    report = "raised_checks.json" if "--raised" in sys.argv else "static_checks.json"
    Path(bpy.data.filepath).with_name(report).write_text(json.dumps(result, indent=2)+"\n")
    assert not failures, "; ".join(failures)


if __name__ == "__main__":
    main()

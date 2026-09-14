"""Focused construction checks. --raised checks only the initial cloth fit."""
import json
from pathlib import Path
import sys
import struct

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
    indices = set(cloth["hood_face_indices"] if region == "hood" else
                  cloth["collar_face_indices"] if region == "collar" else
                  range(len(cloth.data.polygons)))
    selected = [p for p in cloth.data.polygons if p.index in indices]
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


def group_indices(obj, name):
    group = obj.vertex_groups.get(name)
    assert group is not None, "Missing semantic group: "+name
    indices = [v.index for v in obj.data.vertices
               if any(g.group == group.index and g.weight > 0 for g in v.groups)]
    assert indices, "Empty semantic group: "+name
    return indices


def inspect_export():
    path = Path(__file__).resolve().parents[2]/"assets/studies/traveller_drawing.glb"
    data = path.read_bytes()
    assert data[:4] == b"glTF", "Invalid GLB header"
    length, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4e4f534a, "Missing GLB JSON chunk"
    document = json.loads(data[20:20+length])
    nodes = {n["name"]: n for n in document["nodes"] if "mesh" in n}
    target_counts = {name: [len(p.get("targets", [])) for p in
                     document["meshes"][node["mesh"]]["primitives"]]
                     for name, node in nodes.items()}
    accessors = document["accessors"]
    counts = {}
    for name, node in nodes.items():
        counts[name] = []
        for primitive in document["meshes"][node["mesh"]]["primitives"]:
            attributes = primitive["attributes"]
            entry = {key: accessors[attributes[key]]["count"] for key in ("POSITION", "NORMAL")}
            entry["morphs"] = [{key: accessors[index]["count"] for key, index in target.items()}
                               for target in primitive.get("targets", [])]
            counts[name].append(entry)
    return {"skins": len(document.get("skins", [])),
            "animations": len(document.get("animations", [])),
            "mesh_targets": target_counts, "accessor_counts": counts,
            "no_node_skin": all("skin" not in node for node in document["nodes"])}


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
    if result["components"]["Hair"] not in (1, 2) or result["components"]["Boots"] != 2 or result["components"]["Garment"] != 1:
        failures.append("Unexpected hair, shoe, or garment components")
    result["deformation_keys"] = {obj.name: len(obj.data.shape_keys.key_blocks)
                                  if obj.data.shape_keys else 0 for obj in objects}
    hair = bpy.data.objects["Hair"]
    hair_positions = []
    for value in (0, 1):
        cloth.data.shape_keys.key_blocks["HoodLowered"].value = value
        bpy.context.view_layer.update()
        hair_positions.append([tuple(v.co) for v in hair.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices])
    result["hair_fixed_between_poses"] = hair_positions[0] == hair_positions[1]
    cloth.data.shape_keys.key_blocks["HoodLowered"].value = 0
    bpy.context.view_layer.update()
    edge_heights = [hair.data.vertices[i].co.z for i in group_indices(hair, "SideHairEdge")]
    nape_heights = [hair.data.vertices[i].co.z for i in group_indices(hair, "NapeEdge")]
    result["side_hair_edge_height"] = [min(edge_heights), max(edge_heights)]
    result["nape_edge_height"] = [min(nape_heights), max(nape_heights)]
    if not result["hair_fixed_between_poses"]:
        failures.append("Hair moves between poses")
    if not .04 < max(edge_heights)-min(edge_heights) < .10:
        failures.append("The side hair edge is not a soft shallow curve")
    hair_points, hair_faces, hair_surface = mesh_surface(hair)
    pairs = [(a, b) for a, b in hair_surface.overlap(hair_surface)
             if a < b and not set(hair_faces[a]).intersection(hair_faces[b])]
    scalp_indices = set(group_indices(hair, "Scalp"))
    contact_indices = set(group_indices(hair, "BunContact"))
    allowed = [(a, b) for a, b in pairs if
               (set(hair_faces[a]) <= scalp_indices and set(hair_faces[b]) <= contact_indices) or
               (set(hair_faces[b]) <= scalp_indices and set(hair_faces[a]) <= contact_indices)]
    result["hair_self_crossings"] = len(pairs)
    result["intentional_bun_scalp_crossings"] = len(allowed)
    result["unexpected_hair_self_crossings"] = len(pairs)-len(allowed)
    outer_indices = set(group_indices(hair, "ScalpOuter"))
    scalp_outer = BVHTree.FromPolygons(hair_points, [f for f in hair_faces if set(f) <= outer_indices])
    penetration = 0.0
    for index in group_indices(hair, "Bun"):
        point = hair_points[index]
        nearest, normal, _, _ = scalp_outer.find_nearest(point)
        penetration = max(penetration, -(point-nearest).dot(normal))
    result["bun_scalp_maximum_vertex_penetration"] = penetration
    result["hair_head_crossings"] = len(hair_surface.overlap(mesh_surface(bpy.data.objects["Head"])[2]))
    if result["unexpected_hair_self_crossings"] or result["hair_head_crossings"] or penetration > .006:
        failures.append("Hair surface crossing")
    bun_points = np.array([hair.data.vertices[i].co[:] for i in group_indices(hair, "Bun")])
    result["bun_bounds"] = [bun_points.min(axis=0).tolist(), bun_points.max(axis=0).tolist()]
    body = bpy.data.objects["Body"]
    ear_tips = [max((v.co for v in body.data.vertices if 2.50 < v.co.z < 2.64 and abs(v.co.y-.01) < .06),
                    key=lambda point: side*point.x) for side in (-1, 1)]
    result["ear_tips_visible"] = all(hair_surface.ray_cast(point, Vector((side, 0, 0)), 1)[0] is None
                                      for side, point in zip((-1, 1), ear_tips))
    if not result["ear_tips_visible"]:
        failures.append("Hair covers the ear tips")
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
    result["cloth_metric_rule"] = "Area and edge strain are diagnostics only; approved appearance and clearance gate."
    result["unit_object_scales"] = all(max(abs(value-1) for value in obj.scale) < 1e-6 for obj in objects)
    result["runtime_armature_modifiers"] = sum(mod.type == "ARMATURE" for obj in objects for mod in obj.modifiers)
    if not result["unit_object_scales"] or result["runtime_armature_modifiers"]:
        failures.append("Static export has an object scale or an armature modifier")
    if "--export" in sys.argv:
        result["export"] = inspect_export()
        export = result["export"]
        if export["skins"] or export["animations"] or not export["no_node_skin"]:
            failures.append("Static GLB contains skin or animation data")
        if set(export["mesh_targets"]) != {"Head", "Hair", "Body", "Boots", "Garment"} or any(
                any(count != int(name == "Garment") for count in counts)
                for name, counts in export["mesh_targets"].items()):
            failures.append("Static GLB mesh or morph contract")
        for entries in export["accessor_counts"].values():
            for entry in entries:
                if entry["NORMAL"] != entry["POSITION"] or any(
                        target.get("POSITION") != entry["POSITION"] or
                        target.get("NORMAL") != entry["POSITION"] for target in entry["morphs"]):
                    failures.append("GLB position or normal accessor count")
    if "--raised" not in sys.argv and not has_lowered:
        failures.append("Lowered endpoint is not delivered; this is a raised-only draft")
    if "--raised" not in sys.argv and has_lowered:
        result["HoodLowered"] = inspect_pose(cloth, "HoodLowered")
        for name, value in result["HoodLowered"].items():
            if value:
                failures.append("HoodLowered: "+name)
        for name, region in (("hood_cloth", "hood"), ("moving_collar", "collar"), ("whole_cloth", "whole")):
            metrics = cloth_metrics(cloth, region)
            result[name] = metrics
            if metrics["minimum_triangle_area"] < 1e-8:
                failures.append(name+": degenerate triangle")
        keys = cloth.data.shape_keys.key_blocks
        shift = max((a.co-b.co).length for a, b in zip(keys["Basis"].data, keys["HoodLowered"].data))
        result["maximum_pose_shift"] = shift
        if shift < .25:
            failures.append("Folded endpoint is absent")
        seam_shift = max((keys["Basis"].data[i].co-keys["HoodLowered"].data[i].co).length
                         for i in cloth["neckline_indices"])
        result["neckline_shift"] = seam_shift
        if seam_shift > .0001:
            failures.append("Neckline moves")
        for group_name in ("Clasp", "FixedCloak"):
            indices = group_indices(cloth, group_name)
            shift = max((keys["Basis"].data[i].co-keys["HoodLowered"].data[i].co).length for i in indices)
            result[group_name+"_vertices"] = len(indices)
            result[group_name+"_shift"] = shift
            if shift > .0001:
                failures.append(group_name+" moves")
        if set(keys.keys()) != {"Basis", "HoodLowered"} or any(
                obj.data.shape_keys for obj in objects if obj != cloth):
            failures.append("Unexpected shape keys")
        keys["HoodLowered"].value = 0
        bpy.context.view_layer.update()
    result["failures"] = failures
    print(json.dumps(result, indent=2))
    report = "raised_checks.json" if "--raised" in sys.argv else "static_checks.json"
    Path(bpy.data.filepath).with_name(report).write_text(json.dumps(result, indent=2)+"\n")
    assert not failures, "; ".join(failures)


if __name__ == "__main__":
    main()

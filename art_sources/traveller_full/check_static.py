"""Focused checks for the two static full-traveller hood endpoints.

Run: Blender -b traveller_full.blend --python check_static.py
No claim is made about the unapproved transition between these endpoints.
"""
import json
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree


def surface(obj, key_name=None, outer_only=False):
    data = obj.data
    points = [v.co.copy() for v in (data.shape_keys.key_blocks[key_name].data
              if key_name else data.vertices)]
    count = obj["single_surface_vertices"] if outer_only else len(points)
    faces = [tuple(p.vertices) for p in data.polygons if max(p.vertices) < count]
    return points, faces, BVHTree.FromPolygons(points, faces)


def cloth_metrics(hood):
    count = hood["single_surface_vertices"]
    keys = hood.data.shape_keys.key_blocks
    raised = np.array([v.co[:] for v in keys["Basis"].data])
    lowered = np.array([v.co[:] for v in keys["HoodLowered"].data])
    hood.data.calc_loop_triangles()
    triangles = np.array([t.vertices[:] for t in hood.data.loop_triangles if max(t.vertices) < count])
    # Include each triangulation diagonal so a sheared quad cannot pass.
    edges = sorted({tuple(sorted((a, b))) for triangle in triangles
                    for a, b in zip(triangle, np.roll(triangle, -1))})
    edges = np.array(edges)
    lengths = lambda p: np.linalg.norm(p[edges[:, 1]]-p[edges[:, 0]], axis=1)
    areas = lambda p: np.linalg.norm(np.cross(p[triangles[:, 1]]-p[triangles[:, 0]],
                                             p[triangles[:, 2]]-p[triangles[:, 0]]), axis=1)/2
    strain = np.abs(lengths(lowered)/lengths(raised)-1)
    area_raised, area_lowered = areas(raised), areas(lowered)
    result = {
        "single_surface_area_raised": float(area_raised.sum()),
        "single_surface_area_lowered": float(area_lowered.sum()),
        "area_change": float(area_lowered.sum()/area_raised.sum()-1),
        "edge_strain_p95": float(np.percentile(strain, 95)),
        "edge_strain_max": float(strain.max()),
        "edges_checked": len(edges),
        "minimum_triangle_area": float(min(area_raised.min(), area_lowered.min())),
    }
    failures = []
    if abs(result["area_change"]) > .05:
        failures.append("Cloth area changes by more than 5%")
    if result["edge_strain_p95"] > .10:
        failures.append("More than 5% of cloth edges change length by over 10%")
    if result["edge_strain_max"] > .20:
        failures.append("A cloth edge changes length by over 20%")
    if result["minimum_triangle_area"] < 1e-8:
        failures.append("Cloth has a collapsed triangle")
    return result, failures


def geometry_checks(hood):
    results, failures = {}, []
    keys = hood.data.shape_keys.key_blocks
    group = hood.vertex_groups["HoodAttachment"]
    count = hood["single_surface_vertices"]
    seam = [v.index for v in hood.data.vertices if v.index < count
            and any(g.group == group.index and g.weight > .5 for g in v.groups)]
    seam_shift = max((keys["Basis"].data[i].co-keys["HoodLowered"].data[i].co).length for i in seam)
    cape = surface(bpy.data.objects["Garment"])[2]
    distance = max(cape.find_nearest(keys["Basis"].data[i].co)[3] for i in seam)
    results.update(seam_vertices=len(seam), seam_shift=seam_shift, garment_seam_distance=distance)
    if seam_shift > .0001 or distance > .0001:
        failures.append("Hood neckline does not remain on the cape seam")
    for pose in ("Basis", "HoodLowered"):
        points, faces, outer = surface(hood, pose, True)
        crossings = [(a, b) for a, b in outer.overlap(outer)
                     if a < b and not set(faces[a]).intersection(faces[b])]
        results[pose] = {"outer_self_crossings": len(crossings)}
        if crossings:
            failures.append(pose+": outer hood crosses itself")
        hood_tree = surface(hood, pose)[2]
        for name in ("Head", "Hair"):
            count = len(hood_tree.overlap(surface(bpy.data.objects[name])[2]))
            results[pose][name+"_crossings"] = count
            if count:
                failures.append(pose+": hood crosses "+name)
    return results, failures


def component_counts(obj):
    """Check closed connected parts and crossings between separate faces."""
    adjacent = [set() for _ in obj.data.vertices]
    uses = {tuple(sorted(edge.vertices)): 0 for edge in obj.data.edges}
    for polygon in obj.data.polygons:
        for edge in polygon.edge_keys:
            uses[tuple(sorted(edge))] += 1
    for a, b in uses:
        adjacent[a].add(b)
        adjacent[b].add(a)
    remaining = set(range(len(adjacent)))
    count = 0
    while remaining:
        count += 1
        pending = [remaining.pop()]
        while pending:
            for neighbor in adjacent[pending.pop()] & remaining:
                remaining.remove(neighbor)
                pending.append(neighbor)
    _, faces, tree = surface(obj)
    crossings = [(a, b) for a, b in tree.overlap(tree)
                 if a < b and not set(faces[a]).intersection(faces[b])]
    return {"components": count, "non_manifold_edges": sum(n != 2 for n in uses.values()),
            "self_crossings": len(crossings)}


def main():
    objects = [o for o in bpy.data.objects if o.type == "MESH"]
    triangles = {o.name: sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects}
    total = sum(triangles.values())
    materials = {m for o in objects for m in o.data.materials}
    images = {n.image for m in materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE"}
    failures = []
    if total > 8000:
        failures.append("Full character exceeds 8,000 triangles")
    if len(materials) != 2 or len(images) != 1 or next(iter(images)).size[:] != (1024, 1024):
        failures.append("Expected two materials and one 1024 atlas")
    if bpy.data.objects["Hair"].data.shape_keys:
        failures.append("Hair must remain fixed in this study")
    if any(o.animation_data for o in objects):
        failures.append("Static study must not contain animation clips")
    construction = {name: component_counts(bpy.data.objects[name]) for name in ("Hair", "Boots")}
    for name, expected in (("Hair", 1), ("Boots", 2)):
        if construction[name]["components"] != expected:
            failures.append(name+": unexpected disconnected parts")
        if construction[name]["non_manifold_edges"]:
            failures.append(name+": mesh must be closed with two faces per edge")
        if construction[name]["self_crossings"]:
            failures.append(name+": mesh crosses itself")
    metrics, metric_failures = cloth_metrics(bpy.data.objects["Hood"])
    geometry, geometry_failures = geometry_checks(bpy.data.objects["Hood"])
    failures.extend(metric_failures+geometry_failures)
    result = {"triangles": triangles, "total_triangles": total, "construction": construction,
              "cloth": metrics, "geometry": geometry, "failures": failures}
    print(json.dumps(result, indent=2))
    Path(__file__).with_name("static_checks.json").write_text(json.dumps(result, indent=2)+"\n")
    assert not failures, "; ".join(failures)


if __name__ == "__main__":
    main()

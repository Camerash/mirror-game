"""Check the authored hair poses against the head and hood in world space.

Run in a separate background Blender process with the study blend loaded.
This checks static endpoints, not the later hood transition or hair motion.
"""
import bpy
from mathutils.bvhtree import BVHTree


def world_surface(obj, deps):
    evaluated = obj.evaluated_get(deps)
    data = evaluated.to_mesh()
    vertices = [obj.matrix_world @ vertex.co for vertex in data.vertices]
    faces = [list(face.vertices) for face in data.polygons]
    result = BVHTree.FromPolygons(vertices, faces)
    evaluated.to_mesh_clear()
    return result, vertices


def check_pose(lowered, hair):
    bpy.data.objects["Hood"].data.shape_keys.key_blocks["HoodLowered"].value = lowered
    for obj in hair:
        obj.data.shape_keys.key_blocks["HairTucked"].value = 1 - lowered
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    hood, _ = world_surface(bpy.data.objects["Hood"], deps)
    head, _ = world_surface(bpy.data.objects["Head"], deps)
    failures = []
    for obj in hair:
        surface, vertices = world_surface(obj, deps)
        crossings = len(hood.overlap(surface)) + len(head.overlap(surface))
        inside = 0
        for point in vertices:
            location, normal, _, _ = head.find_nearest(point)
            inside += normal.dot(point - location) < -0.002
        if crossings or inside:
            failures.append((obj.name, crossings, inside))
    assert not failures, ("Hood lowered", lowered, failures)
    print(f"Hood lowered={lowered}: {len(hair)} hair meshes clear of head and hood")


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run clearance checks in a separate background Blender process.")
    for collection in bpy.data.collections:
        collection.hide_viewport = False
    hair = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("Hair")]
    assert hair, "Study hair meshes are missing"
    for lowered in (0, 1):
        check_pose(lowered, hair)

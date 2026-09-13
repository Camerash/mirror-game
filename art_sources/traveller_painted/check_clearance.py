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


def check_hood_attachment():
    hood = bpy.data.objects["Hood"]
    group = hood.vertex_groups.get("HoodAttachment")
    assert group is not None, "Hood garment seam is missing"
    seam = [v.index for v in hood.data.vertices
            if any(g.group == group.index and g.weight > 0.5 for g in v.groups)]
    assert len(seam) >= 2, "Hood needs a sewn edge, not a single attachment point"
    keys = hood.data.shape_keys.key_blocks
    assert all((keys["Basis"].data[i].co - keys["HoodLowered"].data[i].co).length < 0.0001
               for i in seam), "Hood garment seam moves when lowered"
    neighbours = [set() for _ in hood.data.vertices]
    for edge in hood.data.edges:
        a, b = edge.vertices
        neighbours[a].add(b)
        neighbours[b].add(a)
    visited, pending = set(), [seam[0]]
    while pending:
        index = pending.pop()
        if index not in visited:
            visited.add(index)
            pending.extend(neighbours[index] - visited)
    assert len(visited) == len(hood.data.vertices), "Hood contains detached cloth pieces"
    bpy.context.view_layer.update()
    body, _ = world_surface(bpy.data.objects["TravellerBody"], bpy.context.evaluated_depsgraph_get())
    distance = max(body.find_nearest(hood.matrix_world @ keys["Basis"].data[i].co)[3]
                   for i in seam)
    assert distance < 0.065, ("Hood seam is detached from clothing", distance)
    print(f"Hood attachment: {len(seam)} fixed vertices, connected cloth, garment distance {distance:.4f}")


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run clearance checks in a separate background Blender process.")
    for collection in bpy.data.collections:
        collection.hide_viewport = False
    hair = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("Hair")]
    assert hair, "Study hair meshes are missing"
    for lowered in (0, 1):
        check_pose(lowered, hair)
    check_hood_attachment()

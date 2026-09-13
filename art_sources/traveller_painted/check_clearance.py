"""Check the authored hair poses against the head and hood in world space.

Run in a separate background Blender process with the study blend loaded.
This checks static endpoints, not the later hood transition or hair motion.
"""
import bpy
import heapq
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
    body, body_vertices = world_surface(bpy.data.objects["TravellerBody"], bpy.context.evaluated_depsgraph_get())
    neckline_height = max(point.z for point in body_vertices)
    assert all((hood.matrix_world @ keys["Basis"].data[i].co).z >= neckline_height - 0.12
               for i in seam), "Hood must join the neckline, not the lower shoulders"
    distance = max(body.find_nearest(hood.matrix_world @ keys["Basis"].data[i].co)[3]
                   for i in seam)
    assert distance < 0.065, ("Hood seam is detached from clothing", distance)
    print(f"Hood attachment: {len(seam)} fixed vertices, connected cloth, garment distance {distance:.4f}")


def group_vertices(obj, name):
    group = obj.vertex_groups.get(name)
    assert group is not None, (obj.name, "Missing hair landmark", name)
    indices = [v.index for v in obj.data.vertices
               if any(g.group == group.index and g.weight > 0.5 for g in v.groups)]
    assert indices, (obj.name, "Empty hair landmark", name)
    return indices


def check_hair_connections():
    assert not any(obj.type == "MESH" and obj.name.startswith(("HairLock", "HairCheek"))
                   for obj in bpy.data.objects), "Side locks must be part of the scalp mesh"
    for style in ("Long", "Bob", "Bun"):
        obj = bpy.data.objects["HairCap." + style]
        neighbours = [set() for _ in obj.data.vertices]
        for edge in obj.data.edges:
            a, b = edge.vertices
            neighbours[a].add(b)
            neighbours[b].add(a)
        roots = group_vertices(obj, "HairRootLeft") + group_vertices(obj, "HairRootRight")
        visited, pending = set(), [roots[0]]
        while pending:
            index = pending.pop()
            if index not in visited:
                visited.add(index)
                pending.extend(neighbours[index] - visited)
        assert len(visited) == len(obj.data.vertices), (style, "Hair has disconnected mesh islands")
        edge_faces = {tuple(sorted(edge.vertices)): 0 for edge in obj.data.edges}
        for face in obj.data.polygons:
            for a, b in face.edge_keys:
                edge_faces[tuple(sorted((a, b)))] += 1
        assert all(count == 2 for count in edge_faces.values()), (style, "Hair has open or non-manifold edges")
        assert all(len(neighbours[i]) >= 3 for i in roots), (style, "Root needs a surface join")
    print("Side locks: three connected, closed hair surfaces with shared roots")


def rear_path_length(obj, coordinates, roots, tips):
    neighbours = [[] for _ in coordinates]
    for edge in obj.data.edges:
        a, b = edge.vertices
        length = (coordinates[a].co - coordinates[b].co).length
        neighbours[a].append((b, length))
        neighbours[b].append((a, length))
    queue = [(0.0, root) for root in roots]
    heapq.heapify(queue)
    distances = {root: 0.0 for root in roots}
    while queue:
        distance, index = heapq.heappop(queue)
        if distance > distances[index]:
            continue
        if index in tips:
            return distance
        for neighbour, length in neighbours[index]:
            candidate = distance + length
            if candidate < distances.get(neighbour, float("inf")):
                distances[neighbour] = candidate
                heapq.heappush(queue, (candidate, neighbour))
    raise AssertionError("Rear hair has no connected root-to-tip path")


def check_long_hair_length():
    obj = bpy.data.objects["HairCap.Long"]
    keys = obj.data.shape_keys.key_blocks
    roots = group_vertices(obj, "LongRearRoot")
    tips = set(group_vertices(obj, "LongRearTip"))
    lowered = rear_path_length(obj, keys["Basis"].data, roots, tips)
    raised = rear_path_length(obj, keys["HairTucked"].data, roots, tips)
    assert lowered > 1.0, "Rear landmarks must span the long hair"
    assert abs(raised / lowered - 1.0) <= 0.10, ("Rear hair changes length", lowered, raised)
    tip_shift = max(abs(keys["Basis"].data[i].co.z - keys["HairTucked"].data[i].co.z) for i in tips)
    assert tip_shift <= 0.10, ("Raised hood shortens rear hair", tip_shift)
    print(f"Long rear hair: path {lowered:.3f} / {raised:.3f}, tip height shift {tip_shift:.3f}")


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
    check_hair_connections()
    check_long_hair_length()

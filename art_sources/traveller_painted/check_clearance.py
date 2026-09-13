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


def check_pose(lowered, hair, hood_obj):
    hood_obj.data.shape_keys.key_blocks["HoodLowered"].value = lowered
    for obj in hair:
        obj.data.shape_keys.key_blocks["HairTucked"].value = 1 - lowered
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    hood, _ = world_surface(hood_obj, deps)
    head, _ = world_surface(bpy.data.objects["Head"], deps)
    assert not hood.overlap(head), (hood_obj.name, lowered, "Hood crosses the head")
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
    print(f"{hood_obj.name} lowered={lowered}: {len(hair)} hair meshes clear of head and hood")


def check_hood_attachment(hood):
    group = hood.vertex_groups.get("HoodAttachment")
    assert group is not None, "Hood garment seam is missing"
    seam = [v.index for v in hood.data.vertices
            if any(g.group == group.index and g.weight > 0.5 for g in v.groups)]
    assert len(seam) >= 2, "Hood needs a sewn edge, not a single attachment point"
    seam_x=[hood.data.vertices[i].co.x for i in seam]
    assert min(seam_x) < -.20 and max(seam_x) > .20, "Hood seam must span both neckline sides"
    edge_faces = {tuple(sorted(edge.vertices)): 0 for edge in hood.data.edges}
    for face in hood.data.polygons:
        assert face.area > 1e-8, (hood.name, "Hood has a collapsed face")
        for a,b in face.edge_keys:
            edge_faces[tuple(sorted((a,b)))] += 1
    assert all(count == 2 for count in edge_faces.values()), (hood.name, "Hood shell is open or non-manifold")
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
    assert all(neighbours[i].intersection(seam) for i in seam), "Hood seam contains isolated contact points"
    bpy.context.view_layer.update()
    body, body_vertices = world_surface(bpy.data.objects["TravellerBody"], bpy.context.evaluated_depsgraph_get())
    neckline_height = max(point.z for point in body_vertices)
    assert all((hood.matrix_world @ keys["Basis"].data[i].co).z >= neckline_height - 0.12
               for i in seam), "Hood must join the neckline, not the lower shoulders"
    distance = max(body.find_nearest(hood.matrix_world @ keys["Basis"].data[i].co)[3]
                   for i in seam)
    assert distance < 0.05, ("Hood seam is detached from clothing", distance)
    print(f"{hood.name} attachment: {len(seam)} fixed vertices, width {max(seam_x)-min(seam_x):.3f}, closed connected cloth, garment distance {distance:.4f}")


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


def check_long_hair_surface():
    """Check the visible outer surface; the old inner shell is a separate issue."""
    obj=bpy.data.objects["HairCap.Long"]
    count=len(obj.data.vertices)//2
    faces=[list(face.vertices) for face in obj.data.polygons if max(face.vertices)<count]
    for name in ("Basis","HairTucked"):
        points=[vertex.co for vertex in obj.data.shape_keys.key_blocks[name].data]
        surface=BVHTree.FromPolygons(points,faces)
        crossings=[(a,b) for a,b in surface.overlap(surface)
                   if a<b and not set(faces[a]).intersection(faces[b])]
        assert not crossings,(name,"Long outer hair folds through itself",crossings)
    print("Long outer hair: no self-crossings in either pose")


def check_long_hair_length():
    obj = bpy.data.objects["HairCap.Long"]
    keys = obj.data.shape_keys.key_blocks
    # Authored path lengths in source commit 84d513a, before the local bend.
    paths=(("Left","HairRootLeft","HairTipLeft",1.406860798,1.447959483),
           ("Right","HairRootRight","HairTipRight",1.438831020,1.481253531),
           ("Rear","LongRearRoot","LongRearTip",1.679053316,1.679053316))
    for label,root_name,tip_name,basis_length,raised_length in paths:
        roots=group_vertices(obj,root_name)
        tips=set(group_vertices(obj,tip_name))
        lowered=rear_path_length(obj,keys["Basis"].data,roots,tips)
        raised=rear_path_length(obj,keys["HairTucked"].data,roots,tips)
        assert abs(lowered-basis_length)<1e-6,(label,"Lowered hair changed",lowered)
        assert abs(raised/raised_length-1.0)<=.02,(label,"Hair length changed",raised,raised_length)
        tip_shift=max(abs(keys["Basis"].data[i].co.z-keys["HairTucked"].data[i].co.z) for i in tips)
        assert tip_shift<1e-6,(label,"Hair tip height changed",tip_shift)
        assert all((keys["Basis"].data[i].co-keys["HairTucked"].data[i].co).length<.0001 for i in roots), (label,"Hair root moved")
        print(f"Long {label}: path {lowered:.6f} / {raised:.6f}, raised change {(raised/raised_length-1)*100:.2f}%, tip height shift {tip_shift:.6f}")


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run clearance checks in a separate background Blender process.")
    for collection in bpy.data.collections:
        collection.hide_viewport = False
    hair = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name.startswith("Hair")]
    assert hair, "Study hair meshes are missing"
    for style in ("Long", "Bob", "Bun"):
        hood=bpy.data.objects["Hood."+style]
        style_hair=[obj for obj in hair if obj.name.endswith("."+style)]
        for lowered in (0,1):
            check_pose(lowered,style_hair,hood)
        check_hood_attachment(hood)
    check_hair_connections()
    check_long_hair_length()
    check_long_hair_surface()

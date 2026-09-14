"""A supporting cape row for the temporary hand opening, with unchanged rest surfaces."""
import bpy
from mathutils import Vector


def add_support_row(cloth, height=1.795):
    old = cloth.data
    group_names = [group.name for group in cloth.vertex_groups]
    coordinates = {key.name: [v.co.copy() for v in key.data] for key in old.shape_keys.key_blocks}
    points = coordinates['Basis']
    weights = [{g.group: g.weight for g in v.groups} for v in old.vertices]
    edges, faces, texture, origins = {}, [], [], []
    def split_vertex(a, b):
        edge = tuple(sorted((a, b)))
        if edge not in edges:
            t = (height-points[a].z)/(points[b].z-points[a].z)
            edges[edge] = len(points)
            for values in coordinates.values():
                values.append(values[a].lerp(values[b], t))
            weights.append({group: min(weights[a][group], weights[b][group])
                            for group in weights[a].keys() & weights[b].keys()})
        return edges[edge]
    for polygon in old.polygons:
        original = [(i, Vector(old.uv_layers.active.data[loop].uv)) for i, loop in zip(polygon.vertices, polygon.loop_indices)]
        heights = [points[i].z for i, _ in original]
        split = min(heights) < height < max(heights) and min(heights) > 1.5 and max(heights) < 1.86
        polygons = []
        for above in ((True, False) if split else (True,)):
            result = []
            for (a, uv_a), (b, uv_b) in zip(original, original[1:]+original[:1]):
                keep_a = points[a].z >= height if above else points[a].z <= height
                keep_b = points[b].z >= height if above else points[b].z <= height
                if not split or keep_a:
                    result.append((a, uv_a))
                if split and keep_a != keep_b:
                    t = (height-points[a].z)/(points[b].z-points[a].z)
                    result.append((split_vertex(a, b), uv_a.lerp(uv_b, t)))
            polygons.append(result)
        for result in polygons:
            for j in range(1, len(result)-1):
                triangle = (result[0], result[j], result[j+1])
                faces.append(tuple(item[0] for item in triangle))
                texture.append(tuple(item[1] for item in triangle))
                origins.append(polygon.index)
    data = bpy.data.meshes.new('GarmentWithOpeningRow')
    data.from_pydata(points, [], faces)
    for material in old.materials:
        data.materials.append(material)
    uv = data.uv_layers.new(name='UVMap')
    for polygon, values in zip(data.polygons, texture):
        polygon.use_smooth = True
        for loop, value in zip(polygon.loop_indices, values):
            uv.data[loop].uv = value
    cloth.shape_key_clear()
    cloth.data = data
    cloth.vertex_groups.clear()
    for name in group_names:
        cloth.vertex_groups.new(name=name)
    for index, groups in enumerate(weights):
        for group, weight in groups.items():
            cloth.vertex_groups[group].add([index], weight, 'REPLACE')
    for name, values in coordinates.items():
        key = cloth.shape_key_add(name=name)
        for vertex, point in zip(key.data, values):
            vertex.co = point
    for name in ('hood_face_indices', 'collar_face_indices'):
        source = set(cloth[name])
        cloth[name] = [i for i, origin in enumerate(origins) if origin in source]
    cloth['single_surface_vertices'] = len(points)
    cloth['opening_support_height'] = height
    cloth['source_face_indices'] = origins

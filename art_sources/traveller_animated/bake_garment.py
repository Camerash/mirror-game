"""Bake fixed shell connectivity for the static and authored motion targets."""
import bpy


def bake_targets(cloth):
    original = cloth.data
    keys = original.shape_keys.key_blocks
    names = [key.name for key in keys]
    groups = {group.name: [v.index for v in original.vertices
                           if any(item.group == group.index for item in v.groups)]
              for group in cloth.vertex_groups}
    shell = next(mod for mod in cloth.modifiers if mod.type == 'SOLIDIFY')
    triangulate = next(mod for mod in cloth.modifiers if mod.type == 'TRIANGULATE')
    triangulate.quad_method = 'FIXED'
    shapes = {}
    mesh = None
    for name in names:
        for key in list(keys)[1:]:
            key.value = float(key.name == name)
        # Keep both approved shell endpoints exact. Motion targets use the
        # native thickness limit at the tight folds in the temporary opening.
        shell.thickness_clamp = 1 if name in ('CloakOpen', 'HoodSettle', 'HoodTurnHigh', 'HoodTurnLow') else 0
        shell.use_thickness_angle_clamp = False
        shell.thickness = .006 if name in ('HoodTurnHigh', 'HoodTurnLow', 'HoodSettle') else .018
        bpy.context.view_layer.update()
        evaluated = cloth.evaluated_get(bpy.context.evaluated_depsgraph_get())
        shapes[name] = [v.co.copy() for v in evaluated.data.vertices]
        if mesh is None:
            mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True,
                                                   depsgraph=bpy.context.evaluated_depsgraph_get())
    assert all(len(points) == len(mesh.vertices) for points in shapes.values())
    for index in range(int(cloth['hood_vertices'])):
        for vertex in (index, index+len(original.vertices)):
            shapes['CloakOpen'][vertex] = shapes['Basis'][vertex].copy()
    for name in names:
        if name in ('Basis', 'HoodLowered', 'CloakOpen'):
            continue
        for index in range(int(cloth['hood_vertices']), len(original.vertices)):
            for vertex in (index, index+len(original.vertices)):
                shapes[name][vertex] = shapes['Basis'][vertex].copy()
    original.name = 'GarmentAuthoredOuter'
    original.use_fake_user = True
    cloth.modifiers.clear()
    cloth.data = mesh
    cloth.vertex_groups.clear()
    outer_count = len(original.vertices)
    for name, indices in groups.items():
        group = cloth.vertex_groups.new(name=name)
        group.add(indices+[index+outer_count for index in indices], 1, 'REPLACE')
    for name, points in shapes.items():
        key = cloth.shape_key_add(name=name)
        for vertex, point in zip(key.data, points):
            vertex.co = point
    cloth['baked_shell_vertices'] = len(mesh.vertices)
    cloth['authoring_outer_mesh'] = original.name
    return cloth

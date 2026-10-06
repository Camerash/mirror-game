"""Shared helpers for the headless Blender (bpy 5.0.1) asset generators.

Blender is Z-up; the glTF exporter converts to Y-up. 1 unit = 1 game block.
Geometry is built in world coordinates with identity object transforms, so the
world origin is the asset's base centre and modifier widths are true sizes.
"""
import math
import os
import sys

import bpy  # must come first: the pip bpy module provides bmesh/mathutils
import bmesh
from mathutils import Vector


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_linear(code):
    code = code.lstrip('#')
    return tuple(_lin(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def material(name, hex_color, roughness, metallic=0.0):
    """Principled BSDF material; the hex colour is sRGB, stored linear."""
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except (AttributeError, TypeError):
        pass
    tree = mat.node_tree
    bsdf = next((n for n in tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is None:
        tree.nodes.clear()
        bsdf = tree.nodes.new('ShaderNodeBsdfPrincipled')
        out = tree.nodes.new('ShaderNodeOutputMaterial')
        tree.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    rgb = hex_linear(hex_color)
    bsdf.inputs['Base Color'].default_value = (*rgb, 1.0)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    mat.diffuse_color = (*rgb, 1.0)
    mat.roughness = roughness
    mat.metallic = metallic
    return mat


def link(name, bm, mat, parent=None, location=(0.0, 0.0, 0.0)):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    if mat is not None:
        mesh.materials.append(mat)
    if parent is not None:
        obj.parent = parent
    return obj


def root_empty(name):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def hard_surface(obj, width, segments, angle=30.0):
    """Bevel every hard edge, then weighted normals: flat faces stay crisp,
    bevels carry a soft rounded highlight."""
    obj.data.shade_smooth()
    bevel = obj.modifiers.new('Bevel', 'BEVEL')
    bevel.width = width
    bevel.segments = segments
    bevel.limit_method = 'ANGLE'
    bevel.angle_limit = math.radians(angle)
    bevel.use_clamp_overlap = True
    bevel.miter_outer = 'MITER_ARC'
    weighted = obj.modifiers.new('WeightedNormal', 'WEIGHTED_NORMAL')
    weighted.mode = 'FACE_AREA'
    weighted.weight = 50
    weighted.keep_sharp = True
    return obj


def box(name, size, centre, mat, bevel=0.03, segments=3, parent=None):
    bm = bmesh.new()
    bm.loops.layers.uv.new('UVMap')
    bmesh.ops.create_cube(bm, size=1.0, calc_uvs=True)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0] + centre[0], v.co.y * size[1] + centre[1], v.co.z * size[2] + centre[2]))
    obj = link(name, bm, mat, parent)
    return hard_surface(obj, bevel, segments)


def prism_strip(name, inner, outer, y0, y1, mat, bevel=0.02, segments=2, parent=None):
    """Closed prism extruded along Y (y0..y1) from a band between two XZ
    polylines of equal length. Caps are quad strips, not n-gons: the Bevel
    modifier's UV interpolation on n-gons varied run to run (ULP level)."""
    bm = bmesh.new()
    points = list(inner) + list(reversed(outer))
    front = [bm.verts.new((x, y0, z)) for x, z in points]
    back = [bm.verts.new((x, y1, z)) for x, z in points]
    n, m = len(points), len(inner)
    for ring in (front, back):
        for i in range(m - 1):
            bm.faces.new((ring[i], ring[i + 1], ring[n - 2 - i], ring[n - 1 - i]))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = link(name, bm, mat, parent)
    return hard_surface(obj, bevel, segments)


def lathe(name, profile, steps, mat, location=(0.0, 0.0, 0.0), parent=None):
    """Revolve an (r, z) profile around the local Z axis with the Screw
    modifier (kept live, so the profile stays editable in the .blend)."""
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for r, z in profile]
    for a, b in zip(verts, verts[1:]):
        bm.edges.new((a, b))
    obj = link(name, bm, mat, parent, location)
    obj.data.uv_layers.new(name='UVMap')
    screw = obj.modifiers.new('Lathe', 'SCREW')
    screw.axis = 'Z'
    screw.angle = 2.0 * math.pi
    screw.steps = steps
    screw.render_steps = steps
    screw.screw_offset = 0.0
    screw.use_merge_vertices = True
    screw.merge_threshold = 1e-5
    screw.use_smooth_shade = True
    screw.use_normal_calculate = True
    screw.use_stretch_u = True
    screw.use_stretch_v = True
    weighted = obj.modifiers.new('WeightedNormal', 'WEIGHTED_NORMAL')
    weighted.mode = 'FACE_AREA'
    weighted.weight = 50
    weighted.keep_sharp = True
    if signed_volume(obj) < 0.0:
        screw.use_normal_flip = True
    return obj


def evaluated_mesh(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    ev = obj.evaluated_get(deps)
    return ev, ev.to_mesh()


def signed_volume(obj):
    ev, mesh = evaluated_mesh(obj)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    ev.to_mesh_clear()
    vol = bm.calc_volume(signed=True)
    bm.free()
    return vol


def smart_uv(obj, angle=66.0):
    """Native Smart UV Project on the base mesh (modifiers interpolate it)."""
    for other in bpy.context.selected_objects:
        other.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)


def report(tag):
    """Evaluated stats: triangles, open (non-manifold) edges, bounds, UVs."""
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    total = 0
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    problems = []
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        ev = obj.evaluated_get(deps)
        mesh = ev.to_mesh()
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)
        total += tris
        bm = bmesh.new()
        bm.from_mesh(mesh)
        open_edges = sum(1 for e in bm.edges if not e.is_manifold)
        vol = bm.calc_volume(signed=True)
        bm.free()
        for v in mesh.vertices:
            co = obj.matrix_world @ v.co
            lo = Vector(map(min, lo, co))
            hi = Vector(map(max, hi, co))
        if open_edges or vol <= 0 or not mesh.uv_layers:
            problems.append(f'{obj.name}: open_edges={open_edges} volume={vol:.5f} uv={len(mesh.uv_layers)}')
        ev.to_mesh_clear()
    print(f'[{tag}] triangles={total} bounds_min={tuple(round(c, 4) for c in lo)} bounds_max={tuple(round(c, 4) for c in hi)}')
    print(f'[{tag}] size x={hi.x - lo.x:.3f} y(depth)={hi.y - lo.y:.3f} z(height)={hi.z - lo.z:.3f}')
    for p in problems:
        print(f'[{tag}] CHECK {p}')
    if not problems:
        print(f'[{tag}] all parts closed, outward, with UVs')
    return total


def join_for_export(name):
    """Apply all modifiers and join every part into one mesh (one surface per
    material in the glTF). Runs after the editable .blend is saved."""
    scene = bpy.context.scene
    meshes = sorted((o for o in scene.objects if o.type == 'MESH'), key=lambda o: o.name)
    for obj in scene.objects:
        obj.select_set(obj in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    # Unwrap on final geometry: Skin / voxel Remesh output has no UVs, and the
    # Bevel modifier's UV interpolation jitters by 1 ULP between runs.
    unwrap = [o for o in meshes if not o.data.uv_layers or any(m.type == 'BEVEL' for m in o.modifiers)]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    for obj in unwrap:
        smart_uv(obj)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = joined.data.name = name
    for obj in [o for o in scene.objects if o.type == 'EMPTY']:
        bpy.data.objects.remove(obj)
    return joined


def export(glb_path, blend_path, join_name=None):
    os.makedirs(os.path.dirname(glb_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, compress=False)
    if join_name:
        join_for_export(join_name)
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format='GLB',
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=False,
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=False,
        use_selection=False,
    )
    print('exported', glb_path, 'and', blend_path)


def out_arg(default):
    """--out <path.glb> after '--' on the command line."""
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    return argv[argv.index('--out') + 1] if '--out' in argv else default

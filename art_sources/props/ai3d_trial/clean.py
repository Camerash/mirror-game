"""Cleanup: normalise, voxel remesh, smooth, decimate, smooth shading, flat 5-colour palette + light AO.
## AI 3D cleanup from the 2026-11-09 trial: remesh, smooth, decimate, repaint in the
## palette with a light Cycles AO bake. Usage: blender -b --python clean.py -- <args>.
blender -b --python clean.py -- <input.glb> <out_prefix> <prop rock|tree> [voxel] [target_faces]
Writes <out_prefix>.blend and <out_prefix>.glb.
"""
import bpy, bmesh, sys, math, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, outp, prop = argv[:3]
VOXEL = float(argv[3]) if len(argv) > 3 else (0.012 if prop == "rock" else 0.006)
TARGET = int(argv[4]) if len(argv) > 4 else (2500 if prop == "rock" else 3000)
scene = bpy.context.scene
log = {"voxel": VOXEL, "target": TARGET}

for o in list(scene.objects): bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=src)
ms = [o for o in scene.objects if o.type == "MESH"]
for o in ms:
    mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
for o in list(scene.objects):
    if o.type != "MESH": bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in ms: o.select_set(True)
bpy.context.view_layer.objects.active = ms[0]
if len(ms) > 1: bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = obj.data
pts = [v.co for v in me.vertices]
mn = Vector([min(p[i] for p in pts) for i in range(3)]); mx = Vector([max(p[i] for p in pts) for i in range(3)])
size = mx - mn
s = 1.0 / max(size.x, size.y) if prop == "rock" else 1.4 / size.z
c = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
for v in me.vertices: v.co = (v.co - c) * s
me.update()
log["in_faces"] = len(me.polygons)

# 0. sample the vendor base-colour texture brightness per vertex (snow vs stone/bark hint), KD-tree for transfer
import numpy as np
from mathutils.kdtree import KDTree
img = None
for mt in me.materials:
    if mt and mt.node_tree:
        for n in mt.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image: img = n.image
W, Hh = img.size
px = np.empty(W * Hh * 4, dtype=np.float32); img.pixels.foreach_get(px); px = px.reshape(Hh, W, 4)
lum_px = 0.2126 * px[..., 0] + 0.7152 * px[..., 1] + 0.0722 * px[..., 2]
uv = me.uv_layers.active.data
acc = np.zeros(len(me.vertices)); cnt = np.zeros(len(me.vertices))
for lp in me.loops:
    u, v = uv[lp.index].uv
    x = int((u % 1.0) * (W - 1)); y = int((v % 1.0) * (Hh - 1))
    acc[lp.vertex_index] += lum_px[y, x]; cnt[lp.vertex_index] += 1
vlum = acc / np.maximum(cnt, 1)
kd = KDTree(len(me.vertices))
for i, vv in enumerate(me.vertices): kd.insert(vv.co, i)
kd.balance()
log["tex_lum_p10_p50_p90"] = [round(float(np.percentile(vlum, q)), 3) for q in (10, 50, 90)]

# drop vendor texture, UVs
me.materials.clear()
while me.uv_layers: me.uv_layers.remove(me.uv_layers[0])
for a in list(me.color_attributes): me.color_attributes.remove(a)

def apply(mod):
    bpy.ops.object.modifier_apply(modifier=mod.name)

# 1. voxel remesh: one watertight shell, removes holes, overlaps and fine ripples below voxel size
if VOXEL > 0:
    m = obj.modifiers.new("remesh", "REMESH"); m.mode = "VOXEL"; m.voxel_size = VOXEL; m.use_smooth_shade = True
    apply(m)
else:  # thin parts thinner than any sane voxel: weld UV-split verts only, keep the vendor shell
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5); bm.to_mesh(me); bm.free()
log["remesh_faces"] = len(me.polygons)
# 2. drop tiny floating pieces
bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
seen = set(); groups = []
for f in bm.faces:
    if f.index in seen: continue
    g = [f]; seen.add(f.index); i = 0
    while i < len(g):
        for e in g[i].edges:
            for h in e.link_faces:
                if h.index not in seen: seen.add(h.index); g.append(h)
        i += 1
    groups.append(g)
big = max(len(g) for g in groups)
kill = [f for g in groups if len(g) < 0.02 * big for f in g]
bmesh.ops.delete(bm, geom=kill, context="FACES"); log["parts_removed"] = sum(1 for g in groups if len(g) < 0.02 * big)
bm.to_mesh(me); bm.free()
# 3. volume-preserving Laplacian smooth: irons out lumps and ripples
m = obj.modifiers.new("lap", "LAPLACIANSMOOTH"); m.iterations = 6 if prop == "rock" else 3
m.lambda_factor = 0.6 if prop == "rock" else 0.3; m.use_volume_preserve = True
apply(m)
# 4. decimate to budget
m = obj.modifiers.new("dec", "DECIMATE"); m.decimate_type = "COLLAPSE"; m.ratio = min(1.0, TARGET / sum(len(q.vertices) - 2 for q in me.polygons))
m.use_collapse_triangulate = True
apply(m); log["out_faces"] = len(me.polygons)
# 5. smooth shading with modest auto-smooth and weighted normals
bpy.ops.object.shade_smooth()
try:
    bpy.ops.object.shade_auto_smooth(angle=math.radians(40));
    for md in list(obj.modifiers): apply(md)
except Exception as e: log["autosmooth_err"] = str(e)
m = obj.modifiers.new("wn", "WEIGHTED_NORMAL"); m.keep_sharp = True; m.weight = 50
apply(m)

# 6. palette: snow vs stone/bark from the vendor texture brightness (nearest original verts),
#    shading role (shadow snow, dark stone) from direction/height; per-vertex labels, one mode-filter pass
PAL = {"snow": "EEF1F5", "snow_sh": "B8C4D6", "stone": "8A8580", "stone_dk": "5E5A60", "bark": "4A4246"}
srgb = {k: tuple(int(v[i:i+2], 16) / 255 for i in (0, 2, 4)) for k, v in PAL.items()}
H = max(v.co.z for v in me.vertices)
THR = 0.7 if prop == "rock" else 0.6
lab = []
for vv in me.vertices:
    lum = sum(vlum[i] for _, i, _ in kd.find_n(vv.co, 4)) / 4
    nz = vv.normal.z; h = vv.co.z / H
    if lum > THR: k = "snow" if nz > 0.25 else "snow_sh"
    elif prop == "rock": k = "stone_dk" if (nz < -0.3 or h < 0.08) else "stone"
    else: k = "bark"
    lab.append(k)
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
new = list(lab)
for vv in bm.verts:
    c = {}
    for e in vv.link_edges:
        o = e.other_vert(vv).index; c[lab[o]] = c.get(lab[o], 0) + 1
    if c and c.get(lab[vv.index], 0) == 0: new[vv.index] = max(c, key=c.get)
lab = new; bm.free()
log["palette_verts"] = {k: lab.count(k) for k in PAL}

# 7. bake a little AO (Cycles) into a point colour attribute, ground plane for contact shadow
ao = me.color_attributes.new("AO", "FLOAT_COLOR", "POINT")
me.color_attributes.active_color = ao
bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, -0.002)); plane = bpy.context.active_object
bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active = obj
tmp = bpy.data.materials.new("tmp"); me.materials.append(tmp)
scene.render.engine = "CYCLES"; scene.cycles.samples = 128; scene.cycles.device = "CPU"
scene.world = scene.world or bpy.data.worlds.new("w")
scene.render.bake.target = "VERTEX_COLORS"
try:
    scene.world.light_settings.distance = 0.35
except Exception: pass
bpy.ops.object.bake(type="AO")
bpy.data.objects.remove(plane, do_unlink=True)
aov = [ao.data[i].color[0] for i in range(len(me.vertices))]
log["ao_min_mean"] = (round(min(aov), 3), round(sum(aov) / len(aov), 3))

col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
STRENGTH = 0.25
for p in me.polygons:
    for li, vi in zip(p.loop_indices, p.vertices):
        base = srgb[lab[vi]]
        a = 1 - STRENGTH * (1 - aov[vi])
        col.data[li].color_srgb = (base[0] * a, base[1] * a, base[2] * a, 1)
me.color_attributes.remove(me.color_attributes["AO"])
me.color_attributes.active_color = me.color_attributes["Col"]
me.color_attributes.render_color_index = 0

# 8. material reading the colour attribute
me.materials.clear()
mat = bpy.data.materials.new("palette"); mat.use_nodes = True
nt = mat.node_tree; b = nt.nodes["Principled BSDF"]
ca = nt.nodes.new("ShaderNodeVertexColor"); ca.layer_name = "Col"
nt.links.new(ca.outputs["Color"], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.95
b.inputs["Specular IOR Level"].default_value = 0.2
me.materials.append(mat)
obj.name = "prop_" + prop
bpy.data.materials.remove(tmp) if tmp.users == 0 else None
bpy.ops.wm.save_as_mainfile(filepath=outp + ".blend")
bpy.ops.export_scene.gltf(filepath=outp + ".glb", export_format="GLB", use_selection=False,
                          export_vertex_color="ACTIVE", export_texcoords=False, export_materials="EXPORT")
json.dump(log, open(outp + "_clean.json", "w"), indent=1)
print("CLEAN", json.dumps(log))

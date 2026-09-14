"""Build the static full traveller. Run with Blender's bundled Python.

The cloth solver is an authoring tool for one folded endpoint. It is removed
before export. The GLB has two static pose controls and no animation clips.
"""
import math
import os
from pathlib import Path
import shutil

import bpy
import bmesh
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BLEND = HERE / "traveller_full.blend"
ATLAS = HERE / "traveller_full_atlas.png"
GLB = ROOT / "assets/studies/traveller_full.glb"
EVIDENCE = ROOT / "docs/art/traveller-full-01"
SKIN = (.875, .56)
HAIR = (.125, .56)
TUNIC = (.375, .56)
CAPE = (.625, .56)


def smooth(obj):
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def paint(obj, swatch):
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
    for loop in obj.data.uv_layers.active.data:
        loop.uv = swatch


def mesh(name, vertices, faces, material, swatch):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.materials.append(material)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    smooth(obj)
    paint(obj, swatch)
    return obj


def materials():
    shutil.copyfile(ROOT / "art_sources/traveller_painted/traveller_painted_atlas.png", ATLAS)
    source = bpy.data.images.load(str(ATLAS), check_existing=False)
    source.pack()
    result = []
    for name in ("TravellerFullFace", "TravellerFullBody"):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = source
        bsdf = nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = .83
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        result.append(mat)
    return result


def ellipsoid(name, center, radius, material, swatch, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = radius
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    obj.data.materials.append(material)
    smooth(obj)
    paint(obj, swatch)
    return obj


def join_objects(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = name
    return objects[0]


def head(face_material, body_material):
    obj = ellipsoid("Head", (0, 0, 2.62), (.48, .425, .54), face_material, SKIN, 24, 14)
    uv = obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        for index in polygon.loop_indices:
            co = obj.data.vertices[obj.data.loops[index].vertex_index].co
            angle = max(-math.pi/2, min(math.pi/2, math.atan2(co.x, -co.y)))
            uv.data[index].uv = ((.125 + angle/math.pi*.25, .88+(co.z-2.62)/.54*.11)
                                  if polygon.center.y < 0 else (.008, .86))
    ears = [ellipsoid("Ear", (side*.475, .01, 2.57), (.065, .08, .105), body_material, SKIN, 10, 6)
            for side in (-1, 1)]
    return obj, ears


def hair(material):
    vertices, faces = [], []
    columns, rows = 28, 8
    # Keep the saved study's scalp contour. Only the nape patch becomes the bun.
    hairline = (2.890000, 2.905576, 2.920372, 2.397868, 2.248268, 2.381332, 2.460000,
                2.460000, 2.427871, 2.352137, 2.276402, 2.200667, 2.190000, 2.190000,
                2.190000, 2.190000, 2.190000, 2.200667, 2.276402, 2.352137, 2.427871,
                2.460000, 2.460000, 2.381332, 2.248268, 2.397868, 2.859628, 2.874424)
    for row in range(rows):
        for column in range(columns):
            angle = math.tau*column/columns
            polar = math.acos((hairline[column]-2.62)/.575) * row/(rows-1)
            vertices.append((.51*math.sin(polar)*math.sin(angle),
                             .015-.46*math.sin(polar)*math.cos(angle),
                             2.62+.575*math.cos(polar)))
    # The bun grows from a removed nape patch. Its first ring uses scalp
    # vertices, so the cap and gathered hair have one continuous surface.
    patch_rows, patch_columns = range(5, 6), range(12, 16)
    side_midpoints = {}
    for column in (12, 16):
        a, b = 5*columns+column, 6*columns+column
        side_midpoints[tuple(sorted((a, b)))] = len(vertices)
        vertices.append(tuple((Vector(vertices[a])+Vector(vertices[b]))/2))
    for row in range(rows-1):
        for col in range(columns):
            if row in patch_rows and col in patch_columns:
                continue
            nxt = (col+1) % columns
            corners = (row*columns+col, row*columns+nxt,
                       (row+1)*columns+nxt, (row+1)*columns+col)
            face = []
            for a, b in zip(corners, corners[1:]+corners[:1]):
                face.append(a)
                midpoint = side_midpoints.get(tuple(sorted((a, b))))
                if midpoint is not None:
                    face.append(midpoint)
            faces.append(tuple(face))
    root = [5*columns+col for col in range(12, 17)]
    root += [side_midpoints[(5*columns+16, 6*columns+16)]]
    root += [6*columns+col for col in range(16, 11, -1)]
    root += [side_midpoints[(5*columns+12, 6*columns+12)]]
    bun_rings(vertices, faces, root)
    close_hair_mass(vertices, faces, columns, rows)
    obj = mesh("Hair", vertices, faces, material, HAIR)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.0001)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj["construction"] = "Scalp grid with a shared nape loop and six authored bun profile rings"
    return obj


def close_hair_mass(vertices, faces, columns, rows):
    """Close the volume with an inner scalp, without a cavity inside the bun."""
    start = len(vertices)
    for point in vertices[:columns*rows]:
        x, y, z = point
        normal = Vector((x/.51**2, (y-.015)/.46**2, (z-2.62)/.575**2)).normalized()
        vertices.append(tuple(Vector(point)-.014*normal))
    for row in range(rows-1):
        for column in range(columns):
            nxt = (column+1) % columns
            faces.append((start+row*columns+column, start+(row+1)*columns+column,
                          start+(row+1)*columns+nxt, start+row*columns+nxt))
    for column in range(columns):
        a = (rows-1)*columns+column
        b = (rows-1)*columns+(column+1) % columns
        faces.append((a, b, start+b, start+a))


def bun_rings(vertices, faces, root):
    """Bridge the scalp into a low gathered bun with a shallow rolled end."""
    points = [Vector(vertices[i]) for i in root]
    center_z = (max(p.z for p in points)+min(p.z for p in points))/2
    radius_z = (max(p.z for p in points)-min(p.z for p in points))/2
    angles = [math.atan2((p.z-center_z)/radius_z, p.x/.22) for p in points]
    previous = root
    profiles = ((.470, 2.230, .250, .190), (.520, 2.220, .243, .196),
                (.600, 2.220, .190, .155), (.650, 2.225, .130, .105),
                (.675, 2.230, .065, .052), (.660, 2.235, .030, .025))
    for y, z, rx, rz in profiles:
        ring = []
        for angle in angles:
            ring.append(len(vertices))
            vertices.append((rx*math.cos(angle), y, z+rz*math.sin(angle)))
        for i in range(len(root)):
            j = (i+1) % len(root)
            faces.append((previous[i], previous[j], ring[j], ring[i]))
        previous = ring
    faces.append(tuple(reversed(previous)))


def tube_geometry(path, radii, segments=10):
    points = [Vector(point) for point in path]
    verts, faces = [], []
    for i, center in enumerate(points):
        tangent = (points[min(i+1, len(points)-1)]-points[max(0, i-1)]).normalized()
        across = tangent.cross(Vector((0, 1, 0))).normalized()
        depth = tangent.cross(across).normalized()
        for j in range(segments):
            a = math.tau*j/segments
            verts.append(center+radii[i]*(math.cos(a)*across+math.sin(a)*depth))
    for i in range(len(points)-1):
        for j in range(segments):
            k = (j+1) % segments
            faces.append((i*segments+j, i*segments+k, (i+1)*segments+k, (i+1)*segments+j))
    faces.extend((tuple(range(segments-1, -1, -1)),
                  tuple((len(points)-1)*segments+j for j in range(segments))))
    return verts, faces


def body(material, ears):
    verts, faces = [], []
    n = 20
    for z, rx, ry in ((2.10, .31, .21), (1.92, .43, .255), (1.55, .35, .235), (1.08, .46, .30)):
        for j in range(n):
            a = math.tau*j/n
            verts.append((rx*math.sin(a), -.015-ry*math.cos(a), z))
    for row in range(3):
        for j in range(n):
            k = (j+1) % n
            faces.append((row*n+j, row*n+k, (row+1)*n+k, (row+1)*n+j))
    faces.extend((tuple(range(n-1, -1, -1)), tuple(3*n+j for j in range(n))))
    tunic = mesh("Body", verts, faces, material, TUNIC)
    neck = ellipsoid("Neck", (0, .005, 2.07), (.18, .16, .15), material, SKIN, 14, 8)
    legs = []
    for side in (-1, 1):
        v, f = tube_geometry([(side*.22, 0, 1.18), (side*.225, -.015, .78), (side*.24, -.015, .32)], [.165, .14, .13])
        legs.append(mesh("Leg", v, f, material, CAPE))
    return join_objects([tunic, neck]+ears+legs, "Body"), boots(material)


def boots(material):
    """One closed shoe per foot, with shared sole, vamp, shaft and cuff loops."""
    outline = ((0, -.40), (.10, -.385), (.17, -.32), (.185, -.18),
               (.16, .08), (.12, .16), (0, .18), (-.12, .16),
               (-.16, .08), (-.185, -.18), (-.17, -.32), (-.10, -.385))
    vertices, faces = [], []
    count = len(outline)
    for side in (-1, 1):
        start = len(vertices)
        for ring in range(9):
            for i, (x, y) in enumerate(outline):
                angle = math.tau*i/count
                ankle = Vector((.148*math.sin(angle), -.015-.145*math.cos(angle)))
                if ring < 3:
                    scale, z = ((.95, 0), (1, .035), (1, .075))[ring]
                    point = Vector((x*scale, y*scale))
                elif ring == 3:
                    point = Vector((x*.94, y*.93))
                    z = .165+.070*max(0, min(1, (y+.40)/.58))
                elif ring == 4:
                    point = Vector((x, y)).lerp(ankle, .78)
                    z = .285
                else:
                    scale, z = ((1, .395), (1.10, .455), (.94, .455), (.89, .365))[ring-5]
                    point = Vector((ankle.x*scale, -.015+(ankle.y+.015)*scale))
                vertices.append((side*.24+point.x, point.y, z))
        for ring in range(8):
            for i in range(count):
                j = (i+1) % count
                a, b = start+ring*count, start+(ring+1)*count
                faces.append((a+i, a+j, b+j, b+i))
        faces.extend((tuple(start+i for i in range(count-1, -1, -1)),
                      tuple(start+8*count+i for i in range(count))))
    obj = mesh("Boots", vertices, faces, material, HAIR)
    # A level sole must keep a crisp lower edge when the upper is smooth.
    for polygon in obj.data.polygons:
        if max(obj.data.vertices[i].co.z for i in polygon.vertices) < .076:
            polygon.use_smooth = False
    obj["construction"] = "Two closed profile shoes; each sole, toe, heel and cuff shares vertices"
    return obj


def arms(material):
    verts, pose, faces, swatches = [], [], [], []
    for side in (-1, 1):
        rest = [(side*.39, .005, 1.99), (side*.54, -.01, 1.86),
                (side*.64, -.075, 1.59), (side*.69, -.10, 1.37)]
        reach = [(side*.39, .005, 1.99), (side*.61, -.07, 2.10),
                 (side*.85, -.24, 2.35), (side*.65, -.44, 2.67)]
        for path_a, path_b, radii, color in (
            (rest, reach, [.185, .175, .15, .125], TUNIC),
            ([rest[-1], (side*.70, -.105, 1.27), (side*.71, -.11, 1.18)],
             [reach[-1], (side*.60, -.455, 2.75), (side*.55, -.46, 2.81)], [.105, .12, .08], SKIN),
            ([(side*.65, -.18, 1.30), (side*.63, -.19, 1.24)],
             [(side*.58, -.53, 2.71), (side*.55, -.52, 2.77)], [.06, .055], SKIN),
        ):
            a, f = tube_geometry(path_a, radii, 10)
            b, _ = tube_geometry(path_b, radii, 10)
            offset = len(verts)
            verts.extend(a)
            pose.extend(b)
            faces.extend(tuple(offset+i for i in face) for face in f)
            swatches.extend([color]*len(f))
    obj = mesh("Arms", verts, faces, material, TUNIC)
    for poly, color in zip(obj.data.polygons, swatches):
        for li in poly.loop_indices:
            obj.data.uv_layers.active.data[li].uv = color
    obj.shape_key_add(name="Basis")
    key = obj.shape_key_add(name="ArmsReach")
    for item, point in zip(key.data, pose):
        item.co = point
    return obj


def hood_surface(material):
    # Rows run from the face opening to the rear neckline. Columns run over
    # the crown. All three remaining boundary edges form the sewn neckline.
    profiles = ((-.44, 1.18, .66, -.23, .37),
                (-.03, 1.22, .71, -.10, .44),
                (.38, 1.14, .71, .10, .45),
                (.72, .82, .59, .27, .36),
                (.71, 0, .30, .30, .30))
    nu, nv = 25, 17
    verts, faces = [], []
    for row in range(nv):
        t = row/(nv-1)*(len(profiles)-1)
        k = min(int(t), len(profiles)-2)
        f = t-k
        y, height, width, side_y, side_x = [a*(1-f)+b*f for a, b in zip(profiles[k], profiles[k+1])]
        for column in range(nu):
            a = -math.pi/2+math.pi*column/(nu-1)
            taper = (abs(a)/(math.pi/2))**6
            x = math.sin(a)*(width*(1-taper)+side_x*taper)
            verts.append((x, side_y+(y-side_y)*math.cos(a), 2.12+height*math.cos(a)))
    for row in range(nv-1):
        for col in range(nu-1):
            a = row*nu+col
            faces.extend(((a, a+1, a+nu+1), (a, a+nu+1, a+nu)))
    obj = mesh("Hood", verts, faces, material, CAPE)
    seam = [row*nu for row in range(nv)]
    seam += [(nv-1)*nu+col for col in range(1, nu)]
    seam += [row*nu+nu-1 for row in range(nv-2, -1, -1)]
    group = obj.vertex_groups.new(name="HoodAttachment")
    group.add(seam, 1, "REPLACE")
    obj["single_surface_vertices"] = len(verts)
    return obj, seam, nu, nv


def cape(hood, seam, material):
    upper = [hood.data.vertices[i].co.copy() for i in seam]
    verts, faces = [], []
    n = len(upper)
    for row in range(4):
        t = row/3
        for point in upper:
            a = math.atan2(point.x/.45, (point.y-.10)/.61)
            target = Vector((.67*math.sin(a), .04+.43*math.cos(a), 1.12))
            verts.append(point.lerp(target, t))
    for row in range(3):
        for i in range(n-1):
            a = row*n+i
            faces.append((a, a+1, a+n+1, a+n))
    obj = mesh("Garment", verts, faces, material, CAPE)
    solid = obj.modifiers.new("Cape thickness", "SOLIDIFY")
    solid.thickness = .022
    solid.offset = -1
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=solid.name)
    return obj


def authoring_collider(objects):
    """One closed head/hair envelope avoids collisions with inner hair faces."""
    bm = bmesh.new()
    for obj in objects:
        for vertex in obj.data.vertices:
            bm.verts.new(obj.matrix_world @ vertex.co)
    bmesh.ops.convex_hull(bm, input=list(bm.verts))
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    data = bpy.data.meshes.new("AuthorHeadEnvelope")
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new("AuthorHeadEnvelope", data)
    bpy.context.collection.objects.link(obj)
    return obj


def author_fold(hood, seam, nu, nv, colliders):
    """Settle the static down pose from unstrained cloth with two rim grips.

    The temporary guide keys and cloth cache are authoring data only. They
    are replaced by one endpoint shape key before saving the study.
    """
    raised = [vertex.co.copy() for vertex in hood.data.vertices]
    hood.shape_key_add(name="Basis")
    lift = hood.shape_key_add(name="AuthorLift")
    lower = hood.shape_key_add(name="AuthorLower")
    grips = (8, nu-9)
    pins = hood.vertex_groups.new(name="AuthorPins")
    pins.add(seam+list(grips), 1, "REPLACE")
    for index in grips:
        point = raised[index]
        lift.data[index].co = (point.x, .12, 3.30)
        lower.data[index].co = (math.copysign(.40, point.x), .79, 1.72)
    for key, values in ((lift, ((1, 0), (65, 1), (145, 0))),
                        (lower, ((1, 0), (65, 0), (145, 1)))):
        for frame, value in values:
            key.value = value
            key.keyframe_insert(data_path="value", frame=frame)
    for obj in colliders:
        obj.modifiers.new("Authoring collision", "COLLISION")
        obj.collision.thickness_outer = .008
    lift.value = lower.value = 0
    bpy.context.scene.frame_set(1)
    cloth = hood.modifiers.new("Author folded cloth", "CLOTH")
    settings = cloth.settings
    settings.quality = 18
    settings.mass = .10
    settings.air_damping = 4
    settings.tension_stiffness = 200
    settings.compression_stiffness = 200
    settings.shear_stiffness = 200
    settings.bending_stiffness = .3
    settings.vertex_group_mass = "AuthorPins"
    settings.rest_shape_key = hood.data.shape_keys.key_blocks["Basis"]
    settings.pin_stiffness = 100
    collision = cloth.collision_settings
    collision.use_self_collision = True
    collision.self_distance_min = .004
    collision.distance_min = .010
    collision.collision_quality = 5
    cloth.point_cache.frame_start = 1
    cloth.point_cache.frame_end = 220
    scene = bpy.context.scene
    scene.gravity = (0, 0, -3)
    for frame in range(1, 221):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        evaluated = hood.evaluated_get(bpy.context.evaluated_depsgraph_get())
        _ = evaluated.data.vertices[0].co.x
        if frame in (1, 2, 30, 65, 100, 145, 220):
            edges = np.array([e.vertices[:] for e in hood.data.edges])
            original = np.array([v[:] for v in raised])
            points = np.array([v.co[:] for v in evaluated.data.vertices])
            length = lambda p: np.linalg.norm(p[edges[:, 1]]-p[edges[:, 0]], axis=1)
            print("FRAME", frame, "STRAIN", np.percentile(abs(length(points)/length(original)-1), [50, 95, 100]), flush=True)
    evaluated = hood.evaluated_get(bpy.context.evaluated_depsgraph_get())
    lowered = [v.co.copy() for v in evaluated.data.vertices]
    hood.modifiers.remove(cloth)
    hood.shape_key_clear()
    hood.vertex_groups.remove(pins)
    hood.shape_key_add(name="Basis")
    key = hood.shape_key_add(name="HoodLowered")
    for item, point in zip(key.data, lowered):
        item.co = point
    for obj in colliders:
        obj.modifiers.remove(obj.modifiers["Authoring collision"])
    scene.frame_set(1)
    return raised, lowered


def add_hood_thickness(obj):
    """Bake each endpoint with the same solidify topology and vertex order."""
    key = obj.data.shape_keys.key_blocks["HoodLowered"]
    solid = obj.modifiers.new("Cloth thickness", "SOLIDIFY")
    solid.thickness = .022
    solid.offset = -1
    endpoints = []
    for value in (0, 1):
        key.value = value
        bpy.context.view_layer.update()
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        endpoints.append(bpy.data.meshes.new_from_object(evaluated))
    obj.modifiers.remove(solid)
    old = obj.data
    obj.data = endpoints[0]
    obj.shape_key_add(name="Basis")
    key = obj.shape_key_add(name="HoodLowered")
    for item, vertex in zip(key.data, endpoints[1].vertices):
        item.co = vertex.co
    bpy.data.meshes.remove(endpoints[1])
    bpy.data.meshes.remove(old)


def setup_review():
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = "ReviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.9
    scene = bpy.context.scene
    scene.camera = camera
    for location, power, size in (((-4, -5, 6), 850, 4), ((4, -3, 4), 450, 4), ((1, 4, 5), 650, 3)):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.data.energy = power
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (Vector((0, 0, 1.6))-light.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (.055, .065, .08)
    return camera


def render_views(camera, draft=False):
    views = {"front": (0, -7, 1.7), "side": (7, 0, 1.7), "back": (0, 7, 1.7),
             "three-quarter": (4.8, -5.2, 2.7), "elevated": (4.8, -5.2, 5.5)}
    for pose, lowered, reach in (("raised", 0, 0), ("lowered", 1, 0), ("reach", 0, 1)):
        bpy.data.objects["Hood"].data.shape_keys.key_blocks["HoodLowered"].value = lowered
        bpy.data.objects["Arms"].data.shape_keys.key_blocks["ArmsReach"].value = reach
        for name, location in views.items():
            if draft and name not in ("side", "three-quarter", "back"):
                continue
            camera.location = location
            camera.rotation_euler = (Vector((0, 0, 1.65))-camera.location).to_track_quat("-Z", "Y").to_euler()
            output = EVIDENCE / pose
            output.mkdir(parents=True, exist_ok=True)
            bpy.context.scene.render.filepath = str(output / (name+".png"))
            bpy.ops.render.render(write_still=True)


def save_export(objects):
    bpy.data.objects["Hood"].data.shape_keys.key_blocks["HoodLowered"].value = 0
    bpy.data.objects["Arms"].data.shape_keys.key_blocks["ArmsReach"].value = 0
    root = bpy.data.objects.get("TravellerFull")
    if root is None:
        root = bpy.data.objects.new("TravellerFull", None)
        bpy.context.collection.objects.link(root)
    for obj in objects:
        obj.parent = root
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", use_selection=True,
                              export_animations=False, export_morph=True, export_yup=True)


def refresh_character():
    """Update the authored hair and shoes without rerunning the hood study."""
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
    material = bpy.data.materials["TravellerFullBody"]
    for name, create in (("Hair", hair), ("Boots", boots)):
        previous = bpy.data.objects[name]
        previous.name = name+"Previous"
        data = previous.data
        create(material)
        bpy.data.objects.remove(previous, do_unlink=True)
        if not data.users:
            bpy.data.meshes.remove(data)
    objects = [bpy.data.objects[name] for name in
               ("Head", "Hair", "Body", "Boots", "Arms", "Hood", "Garment")]
    save_export(objects)


def main():
    if os.environ.get("TRAVELLER_FULL_REFRESH_CHARACTER"):
        refresh_character()
        return
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    face_material, material = materials()
    head_obj, ears = head(face_material, material)
    hair_obj = hair(material)
    body_obj, boots = body(material, ears)
    arms_obj = arms(material)
    hood_obj, seam, nu, nv = hood_surface(material)
    cape_obj = cape(hood_obj, seam, material)
    collider = authoring_collider([head_obj, hair_obj])
    author_fold(hood_obj, seam, nu, nv, [collider])
    bpy.data.objects.remove(collider, do_unlink=True)
    add_hood_thickness(hood_obj)
    camera = setup_review()
    objects = [head_obj, hair_obj, body_obj, boots, arms_obj, hood_obj, cape_obj]
    save_export(objects)
    if not os.environ.get("TRAVELLER_FULL_NO_RENDER"):
        render_views(camera, draft=bool(os.environ.get("TRAVELLER_FULL_DRAFT")))


if __name__ == "__main__":
    main()

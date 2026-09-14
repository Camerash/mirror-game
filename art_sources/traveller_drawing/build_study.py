"""Build the drawing-based static study with Blender's bundled Python.

The prior study supplies only the fixed head, complete hair and concealed body.
The cloak and hood share one authored surface and one neckline vertex loop.
"""
import math
import os
import shutil
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
EVIDENCE = ROOT / "docs/art/traveller-drawing-02"
BLEND = Path(os.environ.get("TRAVELLER_BLEND", HERE / "traveller_drawing.blend"))
ATLAS = HERE / "traveller_drawing_atlas.png"
GLB = ROOT / "assets/studies/traveller_drawing.glb"
CLOTH_UV = (.625, .56)


def reference_parts():
    source = ROOT / "art_sources/traveller_full/traveller_full.blend"
    with bpy.data.libraries.load(str(source), link=False) as (_, loaded):
        loaded.objects = ["Head", "Hair", "Body", "Boots", "Arms"]
    for obj in loaded.objects:
        bpy.context.collection.objects.link(obj)
        obj.parent = None
    for vertex in bpy.data.objects["Body"].data.vertices:
        if vertex.co.z < 2.3:
            vertex.co.x *= .84
            vertex.co.y *= .9
    for vertex in bpy.data.objects["Boots"].data.vertices:
        side = 1 if vertex.co.x > 0 else -1
        vertex.co.x = side*.18+(vertex.co.x-side*.24)*.67
        vertex.co.y *= .76
        vertex.co.z *= .75
    materials = {m for obj in loaded.objects for m in obj.data.materials}
    arms = bpy.data.objects["Arms"]
    rest = [v.co.copy() for v in arms.data.shape_keys.key_blocks["Basis"].data]
    arms.shape_key_clear()
    for vertex, point in zip(arms.data.vertices, rest):
        rearward = .04+.18*max(0, min(1, (1.90-point.z)/.5))
        vertex.co = (point.x*.60, point.y+rearward, point.z-.14)
    group = arms.vertex_groups.new(name="ConcealedArms")
    group.add(list(range(len(arms.data.vertices))), 1, "REPLACE")
    body = bpy.data.objects["Body"]
    body["concealed_arm_vertices"] = len(arms.data.vertices)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arms.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    for material in materials:
        material.name = material.name.replace("TravellerFull", "TravellerDrawing")
    image = bpy.data.images.load(str(ATLAS), check_existing=False)
    for material in materials:
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE":
                node.image = image
    image.name = ATLAS.name
    image.filepath_raw = str(ATLAS)
    image.pack()
    return [bpy.data.objects[name] for name in ("Head", "Hair", "Body", "Boots")], bpy.data.materials["TravellerDrawingBody"]


def profile(points, value):
    index = min(int(value), len(points)-2)
    t = value-index
    p0, p1 = np.array(points[max(0, index-1)]), np.array(points[index])
    p2, p3 = np.array(points[index+1]), np.array(points[min(index+2, len(points)-1)])
    return .5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)


def hood_surface():
    # Each rib gives crown Y/Z, side width, and the two neckline endpoints.
    ribs = ((-.49, 3.08, .57, -.34, .17, 2.15),
            (-.31, 3.27, .76, -.20, .30, 2.10),
            (.00, 3.31, .86, -.04, .37, 2.10),
            (.30, 3.23, .87, .10, .38, 2.10),
            (.51, 3.05, .91, .22, .35, 2.10),
            (.64, 2.70, .92, .30, .30, 2.08),
            (.74, 2.33, .67, .36, .25, 2.06),
            (.71, 2.04, .40, .395, .18, 2.03),
            (.45, 1.98, .12, .42, .12, 2.01))
    columns, rows = 21, 17
    vertices, faces = [], []
    for row in range(rows):
        y, z, width, side_y, side_x, side_z = profile(ribs, row/(rows-1)*(len(ribs)-1))
        for column in range(columns):
            angle = -math.pi/2+math.pi*column/(columns-1)
            c, s = math.cos(angle), math.sin(angle)
            vertices.append((s*(side_x+(width-side_x)*c**.72), side_y+(y-side_y)*c,
                             side_z+(z-side_z)*c))
    for row in range(rows-1):
        for column in range(columns-1):
            a = row*columns+column
            faces.extend(((a, a+1, a+columns+1), (a, a+columns+1, a+columns)))
    seam = [row*columns for row in range(rows)]
    seam += [(rows-1)*columns+column for column in range(1, columns)]
    seam += [row*columns+columns-1 for row in range(rows-2, -1, -1)]
    return vertices, faces, seam


def lowered_hood(raised, faces, seam, hood_faces):
    """Place one broad hood drape on the cape, with a softly turned free rim.

    The rows form nested curves in the cape's angle/height chart. This makes
    the artist-authored return continuous; there is no physical fold solver.
    The seam is shared and the entire lower cloak remains fixed.
    """
    cape = BVHTree.FromPolygons([Vector(p) for p in raised], faces[hood_faces:])
    points = []
    for row in range(17):
        t = row/16
        side = Vector(raised[row*21])
        side_angle = math.atan2(-side.x, -(side.y+.04))
        middle_z = 1.30+.68*t**.8
        for column in range(21):
            angle = -math.pi/2+math.pi*column/20
            c, sine = math.cos(angle), math.sin(angle)
            around = math.pi+math.copysign(abs(sine)**1.8, sine)*(math.pi-side_angle)
            z = side.z+(middle_z-side.z)*c
            direction = Vector((-math.sin(around), -math.cos(around), 0))
            origin = Vector((0, -.04, z))
            hit = cape.ray_cast(origin, direction, 2)[0]
            assert hit is not None or row == 16 or column in (0, 20), "Hood drape misses cape"
            gap = (.045+.018*math.sin(math.pi*min(row/3, 1)))*(1-t**8)*c**.6
            # The broad collar turn keeps the inward lining clear of the cape.
            seam_step = min(column, 20-column, 16-row)
            if seam_step > 0:
                gap += .075*math.exp(-.5*(seam_step-1)**2)
            points.append(tuple(hit+direction*gap) if hit else raised[row*21+column])
    for index in seam:
        points[index] = raised[index]
    return points


def cloak_surface(vertices, faces, seam):
    top = np.array([vertices[index] for index in seam])
    distance = np.r_[0, np.cumsum(np.linalg.norm(np.diff(top, axis=0), axis=1))]
    previous = seam
    rows = (.12, .26, .45, .66, .84, .94, 1.0)
    paint_rows, clasp_faces = {}, []
    for row, t in enumerate(rows):
        ring = []
        rx, ry = .34+.54*t**.65, .31+.32*t**.65
        opening = .015+.045*max(0, t-.12)/.88
        for column in range(len(seam)):
            # The U seam runs down the left side, across the back, then right.
            fraction = distance[column]/distance[-1]
            angle = opening+(math.tau-2*opening)*fraction
            p = (-rx*math.sin(angle), -.04-ry*math.cos(angle),
                 2.07-1.85*t-.025*math.cos(2*angle)*t**4)
            ring.append(len(vertices))
            vertices.append(tuple(p))
            paint_rows[ring[-1]] = (column/(len(seam)-1), t)
        for a, b, c, d in zip(previous, previous[1:], ring[1:], ring):
            faces.extend(((a, b, c), (a, c, d)))
        if row == 0:
            clasp_faces = [len(faces), len(faces)+1]
            faces.extend(((previous[-1], previous[0], ring[0]),
                          (previous[-1], ring[0], ring[-1])))
        previous = ring
    return previous, paint_rows, clasp_faces


def garment(material):
    vertices, faces, seam = hood_surface()
    hood_count, hood_faces = len(vertices), len(faces)
    hem, paint_rows, clasp_faces = cloak_surface(vertices, faces, seam)
    data = bpy.data.meshes.new("Garment")
    data.from_pydata(vertices, [], faces)
    data.materials.append(material)
    data.update()
    obj = bpy.data.objects.new("Garment", data)
    bpy.context.collection.objects.link(obj)
    for polygon in data.polygons:
        polygon.use_smooth = True
    uv = data.uv_layers.new(name="UVMap")
    for loop in uv.data:
        loop.uv = CLOTH_UV
    for polygon in data.polygons:
        if polygon.index in clasp_faces:
            for index in polygon.loop_indices:
                point = data.vertices[data.loops[index].vertex_index].co
                uv.data[index].uv = (.625+point.x*.4, .20+(point.z-1.96)*.5)
        elif all(paint_rows.get(i, (0, 0))[1] >= .94 for i in polygon.vertices):
            for index in polygon.loop_indices:
                u, t = paint_rows[data.loops[index].vertex_index]
                uv.data[index].uv = (.01+u*.98, .02+(1-t)/.06*.085)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj["hood_vertices"] = hood_count
    obj["hood_triangles"] = hood_faces
    obj["single_surface_vertices"] = len(vertices)
    obj["neckline_indices"] = seam
    obj["hem_indices"] = hem
    # Semantic regions survive revisions without hard-coded clasp offsets.
    regions = {
        "HoodSurface": list(range(hood_count)),
        "MovingCollar": seam + list(range(hood_count, hood_count+len(seam))),
        "Clasp": sorted({i for face in clasp_faces for i in faces[face]}),
        "FixedCloak": list(range(hood_count, len(vertices))),
    }
    for name, indices in regions.items():
        obj.vertex_groups.new(name=name).add(indices, 1, "REPLACE")
    obj["hood_face_indices"] = list(range(hood_faces))
    obj["collar_face_indices"] = list(range(hood_faces, hood_faces+2*(len(seam)-1)))
    obj["stage"] = "Authored static hood endpoints; appearance and clearance gate."
    obj["cloth_metric_rule"] = "Area and edge strain are diagnostics, not acceptance gates."
    obj["lowered_pose_available"] = True
    obj.shape_key_add(name="Basis")
    lowered = obj.shape_key_add(name="HoodLowered")
    for vertex, point in zip(lowered.data, lowered_hood(vertices, faces, seam, hood_faces)):
        vertex.co = point
    solid = obj.modifiers.new("Cloth thickness", "SOLIDIFY")
    solid.thickness = .018
    solid.offset = -1
    solid.use_quality_normals = True
    solid.use_even_offset = True
    triangulate = obj.modifiers.new("Fixed shell triangles", "TRIANGULATE")
    triangulate.quad_method = "FIXED"
    return obj


def setup_review():
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = "ReviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.9
    bpy.context.scene.camera = camera
    for location, power, size in (((-4, -5, 6), 850, 4), ((4, -3, 4), 450, 4), ((1, 4, 5), 650, 3)):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.data.energy, light.data.shape, light.data.size = power, "DISK", size
        light.rotation_euler = (Vector((0, 0, 1.6))-light.location).to_track_quat("-Z", "Y").to_euler()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (.055, .065, .08)
    camera.location = (4.8, -5.2, 2.7)
    camera.rotation_euler = (Vector((0, 0, 1.68))-camera.location).to_track_quat("-Z", "Y").to_euler()
    return camera


def render_draft(camera):
    key = bpy.data.objects["Garment"].data.shape_keys.key_blocks["HoodLowered"]
    folder = EVIDENCE / "authored-shapes"
    folder.mkdir(parents=True, exist_ok=True)
    for pose, value in (("raised", 0), ("lowered", 1)):
        key.value = value
        bpy.context.view_layer.update()
        for name, location in (("front", (0, -7, 1.7)), ("side", (7, 0, 1.7)),
                               ("three-quarter", (4.8, -5.2, 2.7)), ("back", (0, 7, 1.7))):
            camera.location = location
            camera.rotation_euler = (Vector((0, 0, 1.68))-camera.location).to_track_quat("-Z", "Y").to_euler()
            bpy.context.scene.render.filepath = str(folder/(pose+"-"+name+".png"))
            bpy.ops.render.render(write_still=True)
    key.value = 0
    bpy.context.view_layer.update()


def export_static(parts, cloth, root):
    """Bake the lining and fixed triangles into both morph endpoints once."""
    key = cloth.data.shape_keys.key_blocks["HoodLowered"]
    dependency_graph = bpy.context.evaluated_depsgraph_get()
    key.value = 0
    bpy.context.view_layer.update()
    data = bpy.data.meshes.new_from_object(cloth.evaluated_get(dependency_graph),
               preserve_all_data_layers=True, depsgraph=dependency_graph)
    key.value = 1
    bpy.context.view_layer.update()
    lowered = cloth.evaluated_get(dependency_graph).data
    assert len(data.vertices) == len(lowered.vertices), "Shell vertex order changed"
    assert [tuple(p.vertices) for p in data.polygons] == [tuple(p.vertices) for p in lowered.polygons], "Shell triangles changed"
    lowered_points = [v.co.copy() for v in lowered.vertices]
    key.value = 0
    bpy.context.view_layer.update()
    cloth.name = "GarmentAuthoring"
    baked = bpy.data.objects.new("Garment", data)
    bpy.context.collection.objects.link(baked)
    baked.parent = root
    baked.shape_key_add(name="Basis")
    lowered_key = baked.shape_key_add(name="HoodLowered")
    for vertex, point in zip(lowered_key.data, lowered_points):
        vertex.co = point
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts+[baked, root]:
        obj.select_set(True)
    GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", use_selection=True,
                             export_apply=False, export_animations=False, export_extras=True)
    bpy.data.objects.remove(baked, do_unlink=True)
    bpy.data.meshes.remove(data)
    cloth.name = "Garment"
    shutil.copyfile(ATLAS, GLB.with_name("traveller_drawing_atlas.png"))


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    parts, material = reference_parts()
    cloth = garment(material)
    root = bpy.data.objects.new("TravellerDrawing", None)
    bpy.context.collection.objects.link(root)
    for obj in parts+[cloth]:
        obj.parent = root
    camera = setup_review()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    if not os.environ.get("TRAVELLER_PREVIEW"):
        import runpy
        runpy.run_path(str(HERE/"check_static.py"), run_name="__main__")
        export_static(parts, cloth, root)
    if not os.environ.get("TRAVELLER_NO_RENDER"):
        render_draft(camera)


if __name__ == "__main__":
    main()

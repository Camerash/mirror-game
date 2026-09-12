import math
from pathlib import Path

import bpy
import bmesh
import sys
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


ROOT = Path(__file__).resolve().parents[2]
BASE_FILE = ROOT / ".local/head-study-base/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend"
SOURCE_FILE = ROOT / "art_sources/traveller_head/traveller_head_study.blend"
EXPORT_FILE = ROOT / "assets/studies/traveller_head.glb"
RENDER_DIR = ROOT / "docs/art/traveller-head-study-01"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for item in block:
            if item.users == 0:
                block.remove(item)


def material(name, color):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1.0)
    result.use_nodes = True
    bsdf = result.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.82
    return result


def smooth(obj):
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def make_mesh(name, vertices, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    smooth(obj)
    return obj


def add_uv_sphere(name, location, scale, mat, segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def append_head():
    with bpy.data.libraries.load(str(BASE_FILE), link=False) as (source, target):
        target.objects = ["Head - Generic Topology"]
    head = target.objects[0]
    bpy.context.collection.objects.link(head)
    head.name = "Head"
    head.matrix_world = Matrix.Identity(4)
    toon = head.data.shape_keys.key_blocks["Toon_Anime_Kid"]
    coordinates = [point.co.copy() for point in toon.data]
    bpy.context.view_layer.objects.active = head
    head.select_set(True)
    bpy.ops.object.shape_key_remove(all=True)
    for index, vertex in enumerate(head.data.vertices):
        co = coordinates[index]
        height = (co.z + 0.076) / 0.221
        lower_face = max(0.0, min(1.0, (0.58 - height) / 0.58))
        upper_skull = max(0.0, min(1.0, (height - 0.42) / 0.58))
        co.x *= 5.85 + 0.35 * upper_skull - 0.35 * lower_face
        co.y = co.y * 5.0 - 0.25
        co.z = co.z * 5.15 + 2.33 + 0.06 * upper_skull
        vertex.co = co
    head.data.update()
    head.data.materials.append(SKIN)
    smooth(head)
    return head


def make_hood(mat):
    # Front opening is authored in the face plane, from crown around the right
    # cheek to the neckline and back up the left. One connected cloth shell.
    half = [(0,-.32,3.37),(.30,-.35,3.30),(.56,-.40,3.08),
            (.68,-.32,2.78),(.76,-.22,2.42),(.77,-.12,2.06),
            (.65,-.10,1.76),(.36,-.23,1.60),(0,-.36,1.64)]
    outline = half + [(-x,y,z) for x,y,z in reversed(half[1:-1])]
    rings = [outline]
    for depth, width, vertical in [(0.12,1.06,1.01),(.43,.97,.94),(.66,.62,.70)]:
        rings.append([(x*width, depth + .10*(1-(z-1.54)/1.78),
                       2.34+(z-2.34)*vertical) for x,y,z in outline])
    n=len(outline)
    verts=[p for ring in rings for p in ring]
    faces=[]
    for r in range(len(rings)-1):
        for i in range(n):
            j=(i+1)%n
            faces.append((r*n+i,r*n+j,(r+1)*n+j,(r+1)*n+i))
    verts.append((0,.82,2.30))
    for i in range(n):
        faces.append(((len(rings)-1)*n+i,(len(rings)-1)*n+(i+1)%n,len(verts)-1))
    hood=make_mesh("Hood",verts,faces,mat)
    sub=hood.modifiers.new("Broad cloth form","SUBSURF")
    sub.levels=1; sub.render_levels=1
    solid=hood.modifiers.new("Joined opening rim","SOLIDIFY")
    solid.thickness=.045; solid.offset=-1
    return hood


def strand(name, sections, mat):
    # Authored broad cross-sections, not strand detail or cloth simulation.
    sides=8; verts=[]; faces=[]
    for x,y,z,width,depth,twist in sections:
        for j in range(sides):
            a=math.tau*j/sides
            u=width*math.cos(a); v=depth*math.sin(a)
            verts.append((x+u*math.cos(twist),y+v+u*math.sin(twist),z))
    for r in range(len(sections)-1):
        for j in range(sides):
            k=(j+1)%sides
            faces.append((r*sides+j,r*sides+k,(r+1)*sides+k,(r+1)*sides+j))
    faces += [tuple(range(sides-1,-1,-1)),tuple((len(sections)-1)*sides+j for j in range(sides))]
    return make_mesh(name,verts,faces,mat)


def make_hair(mat):
    for sign,name in [(-1,"L"),(1,"R")]:
        sections=[(.39,-.19,2.93,.12,.10,.0),(.48,-.26,2.68,.13,.10,.12),
                  (.51,-.33,2.42,.12,.10,.22),(.53,-.37,2.12,.12,.09,.18),
                  (.55,-.45,1.85,.15,.09,-.12),(.50,-.52,1.55,.17,.08,-.22),
                  (.44,-.55,1.24,.15,.065,-.05),(.46,-.55,.93,.095,.05,.15),
                  (.39,-.53,.74,.015,.015,0)]
        strand("Hair."+name,[(x*sign,y,z,w,d,t*sign) for x,y,z,w,d,t in sections],mat)
    # Unequal swept fringe joins into the crown under the hood.
    strand("Hair.Fringe.L",[(.12,-.35,3.11,.08,.05,0),(.04,-.50,2.99,.14,.06,0),
        (-.12,-.58,2.84,.17,.065,-.2),(-.27,-.55,2.68,.13,.055,-.35),
        (-.43,-.44,2.59,.014,.015,0)],mat)
    strand("Hair.Fringe.R",[(.15,-.32,3.10,.07,.06,0),(.25,-.45,2.99,.14,.06,.2),
        (.34,-.48,2.79,.12,.06,.35),(.45,-.41,2.61,.015,.015,0)],mat)


def make_shoulders(mat):
    # Collar, rounded shoulder break, then a short chest crop.
    n=24
    rows=[(1.12,.53,.45),(.96,.49,.92),(.78,.44,1.36),(.48,.32,1.67),(.29,.23,1.91)]
    verts=[]; faces=[]
    for rx,ry,z in rows:
        for j in range(n):
            a=math.tau*j/n
            front=max(0,-math.sin(a))
            # The small V neckline sits under the chin, exposing a short neck.
            neckline=.23*front if z>1.90 else 0
            fold=.018*math.cos(5*a)*(1.91-z)
            verts.append(((rx+fold)*math.cos(a),(ry+fold)*math.sin(a)-.015,z-neckline))
    for r in range(len(rows)-1):
        for j in range(n):
            k=(j+1)%n
            faces.append((r*n+j,r*n+k,(r+1)*n+k,(r+1)*n+j))
    faces.append(tuple(range(n-1,-1,-1)))
    shoulders=make_mesh("Shoulders",verts,faces,mat)
    solid=shoulders.modifiers.new("Cloth thickness","SOLIDIFY")
    solid.thickness=.035; solid.offset=-1
    return shoulders


def add_face_details(head):
    # Keep the base eye caps continuous with the head. Conform the plain eye
    # and brow shapes to that surface instead of adding protruding eyeballs.
    bpy.context.view_layer.update()
    surface = BVHTree.FromObject(head, bpy.context.evaluated_depsgraph_get())

    def on_face(x, z, offset=.003):
        point, normal, _, _ = surface.ray_cast(Vector((x,-2,z)), Vector((0,1,0)))
        if point is None:
            raise RuntimeError("Facial shape leaves the head surface")
        return point + normal * offset

    for sign, name in [(-1,"L"),(1,"R")]:
        x=sign*.232; z=2.435
        vertices=[on_face(x,z)]
        for j in range(16):
            a=math.tau*j/16
            vertices.append(on_face(x+.042*math.cos(a),z+.045*math.sin(a)))
        make_mesh("Iris."+name, vertices,
                  [(0,j+1,(j+1)%16+1) for j in range(16)], HAIR)
        for feature, profile in [
            ("Upper lid",[(.146,2.438),(.180,2.471),(.229,2.485),(.279,2.479),(.321,2.452)]),
            ("Brow",[(.145,2.578),(.183,2.600),(.236,2.607),(.284,2.596),(.317,2.580)])]:
            vertices=[]
            for j,(px,pz) in enumerate(profile):
                thickness=(.007 if feature=="Upper lid" else .016)*math.sin(math.pi*(j+.4)/(len(profile)-.2))
                vertices.extend([on_face(sign*px,pz-thickness),on_face(sign*px,pz+thickness)])
            make_mesh(feature+"."+name, vertices,
                      [(j*2,j*2+1,j*2+3,j*2+2) for j in range(len(profile)-1)],HAIR)


def setup_camera():
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = "ReviewCamera"
    bpy.context.scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.8
    return camera


def point_camera(camera, location, target):
    camera.location = location
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def setup_lights():
    for name, location, energy, size in (
        ("Key", (-4.0, -5.0, 5.0), 850, 4.0),
        ("Fill", (4.0, -3.0, 2.5), 350, 3.0),
        ("Rim", (0.0, 3.0, 4.5), 500, 3.0),
    ):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        direction = Vector((0.0, 0.0, 1.7)) - light.location
        light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_views(camera):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.view_settings.view_transform="AgX"
    scene.view_settings.exposure=-1.0
    scene.render.resolution_x = 700
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.color = (0.055, 0.055, 0.055)
    views = {
        "front": (0.0, -7.0, 1.85),
        "side": (7.0, 0.0, 1.85),
        "back": (0.0, 7.0, 1.85),
        "three-quarter": (4.8, -5.2, 2.4),
        "elevated": (4.8, -5.2, 5.2),
    }
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    for name, location in views.items():
        point_camera(camera, location, (0.0, 0.0, 1.85))
        scene.render.filepath = str(RENDER_DIR / f"{name}.png")
        bpy.ops.render.render(write_still=True)


def export_study():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["Head"]
    EXPORT_FILE.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_FILE))
    bpy.ops.export_scene.gltf(filepath=str(EXPORT_FILE), export_format="GLB", use_selection=True, export_yup=True, export_apply=True)


if __name__ == "__main__":
    # Only use this builder in a separate factory-startup Blender process.
    if not bpy.app.background:
        raise RuntimeError("Use a separate background Blender process; preserve open work.")
    clear_scene()
    SKIN = material("ClayGrey", (0.56, 0.55, 0.52))
    CLOTH = material("ClothGrey", (0.37, 0.38, 0.40))
    HAIR = material("HairGrey", (0.16, 0.15, 0.14))
    head=append_head()
    make_hood(CLOTH)
    make_hair(HAIR)
    make_shoulders(CLOTH)
    add_uv_sphere("Neck", (0,-.11,1.85),(.245,.205,.32),SKIN,12,6)
    add_face_details(head)
    camera=setup_camera()
    setup_lights()
    render_views(camera)
    export_study()

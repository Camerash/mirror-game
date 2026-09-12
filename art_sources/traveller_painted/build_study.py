"""Build the small painted traveller study in a clean Blender process."""
import math
import os
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
ATLAS = HERE / "traveller_painted_atlas.png"
BLEND = HERE / "traveller_painted_study.blend"
GLB = ROOT / "assets/studies/traveller_painted.glb"
RENDERS = ROOT / "docs/art/traveller-painted-study-01"


def clean():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def atlas_materials():
    image = bpy.data.images.load(str(ATLAS), check_existing=False)
    image.name = "traveller_painted_atlas.png"
    image.pack()
    result = []
    for name in ("TravellerFace", "TravellerBody"):
        mat = bpy.data.materials.new(name); mat.use_nodes = True
        nodes = mat.node_tree.nodes; links = mat.node_tree.links
        bsdf = nodes.get("Principled BSDF"); tex = nodes.new("ShaderNodeTexImage"); coords = nodes.new("ShaderNodeTexCoord")
        tex.image = image; tex.interpolation = "Linear"
        links.new(coords.outputs["UV"], tex.inputs["Vector"])
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = .82
        result.append(mat)
    return result


def smooth(obj):
    for face in obj.data.polygons: face.use_smooth = True


def uv_field(obj, box):
    while obj.data.uv_layers: obj.data.uv_layers.remove(obj.data.uv_layers[0])
    uv = obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = box


def head(skin):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=(0, 0, 2.48))
    obj = bpy.context.object; obj.name = "Head"; obj.scale = (.56, .49, .68)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); obj.data.materials.append(skin); smooth(obj)
    for vertex in obj.data.vertices:
        lower=max(0,min(1,(-vertex.co.z-.18)/.50))
        vertex.co.x *= 1-.06*lower
    obj.data.update()
    while obj.data.uv_layers: obj.data.uv_layers.remove(obj.data.uv_layers[0])
    uv = obj.data.uv_layers.new(name="UVMap")
    # All surfaces fit in neutral tile. The front maps to its painted face.
    for p in obj.data.polygons:
        rear = p.center.y > 0.0001
        for li in p.loop_indices:
            co = obj.data.vertices[obj.data.loops[li].vertex_index].co
            angle = max(-math.pi / 2, min(math.pi / 2, math.atan2(co.x, -co.y)))
            u = .125 + angle / math.pi * .25
            v = .88 + (co.z / .68) * .11
            uv.data[li].uv = (.008, .86) if rear else (max(.008, min(.242, u)), max(.77, min(.99, v)))
    return obj


def mesh(name, verts, faces, material, uvbox):
    data = bpy.data.meshes.new(name); data.from_pydata(verts, [], faces); data.materials.append(material); data.update()
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    obj = bpy.data.objects.new(name, data); bpy.context.collection.objects.link(obj)
    uv_field(obj, uvbox); smooth(obj)
    return obj


def tube(name, points, width, depth, material):
    # Broad curved hair volumes. Cubic centre-lines remove angular changes;
    # twelve vertices around each section keep the silhouette round.
    controls=[Vector(p) for p in points]; samples=[]
    for i in range(len(controls)-1):
        a=controls[max(0,i-1)]; b=controls[i]
        c=controls[i+1]; d=controls[min(len(controls)-1,i+2)]
        for step in range(2):
            t=step/2
            samples.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    samples.append(controls[-1])
    sides=12; vertices=[]; faces=[]
    for i, sample in enumerate(samples):
        centre=Vector(sample[:3]); size=max(.02,sample.w)
        tangent=(Vector(samples[min(i+1,len(samples)-1)][:3])-Vector(samples[max(i-1,0)][:3])).normalized()
        across=(Vector((1,0,0))-tangent*tangent.x).normalized()
        depth_axis=tangent.cross(across).normalized()
        for j in range(sides):
            angle=math.tau*j/sides
            vertices.append(centre+across*(width*size*math.cos(angle))+depth_axis*(depth*size*math.sin(angle)))
    for i in range(len(samples)-1):
        for j in range(sides):
            k=(j+1)%sides
            faces.append((i*sides+j,i*sides+k,(i+1)*sides+k,(i+1)*sides+j))
    faces += [tuple(range(sides-1,-1,-1)),tuple((len(samples)-1)*sides+j for j in range(sides))]
    return mesh(name,vertices,faces,material,(.125,.56))


def hair(body):
    # One continuous scalp and long rear curtain. The open front follows a
    # quiet hairline; it is not a cut sphere with separate rear columns.
    n=16; rows=7; vertices=[]; faces=[]
    profile=[(3.23,.015,.015),(3.18,.24,.20),(3.06,.43,.37),
             (2.84,.565,.48),(2.56,.59,.525),(2.22,.60,.52),
             (1.80,.60,.48),(1.32,.54,.42),(.98,.43,.35)]
    for row in range(rows):
        for j in range(n):
            angle=math.tau*j/n
            distance=abs(math.atan2(math.sin(angle),math.cos(angle)))
            curtain=max(0,min(1,(distance-.66)/.86))
            curtain=curtain*curtain*(3-2*curtain)
            end=2.76*(1-curtain)+.98*curtain
            # Resample each column onto its own final height.
            z=profile[row][0] if row<4 else 2.84+(end-2.84)*(row-3)/(rows-4)
            for k in range(len(profile)-1):
                high, low=profile[k],profile[k+1]
                if high[0]>=z>=low[0]:
                    t=(high[0]-z)/(high[0]-low[0])
                    rx=high[1]*(1-t)+low[1]*t; ry=high[2]*(1-t)+low[2]*t
                    break
            x=rx*math.sin(angle); y=.05-ry*math.cos(angle)
            vertices.append((x,y,z))
    for r in range(rows-1):
        for j in range(n):
            k=(j+1)%n
            faces.append((r*n+j,r*n+k,(r+1)*n+k,(r+1)*n+j))
    faces.append(tuple(range(n-1,-1,-1)))
    cap=mesh("HairCap",vertices,faces,body,(.125,.56))
    # A low cage plus one baked subdivision rounds only the silhouette.
    sub=cap.modifiers.new("Rounded hair volume","SUBSURF")
    sub.levels=1; sub.render_levels=1
    bpy.context.view_layer.objects.active=cap
    bpy.ops.object.modifier_apply(modifier=sub.name)
    for vertex in cap.data.vertices:
        vertex.co.x *= 1.08
        vertex.co.y = .05+(vertex.co.y-.05)*1.08
    # The tiny rolled edge is only for a clean silhouette, not strand detail.
    solid=cap.modifiers.new("Hair edge thickness","SOLIDIFY")
    solid.thickness=.014; solid.offset=-1
    bpy.context.view_layer.objects.active=cap
    bpy.ops.object.modifier_apply(modifier=solid.name)
    for side in (-1,1):
        tube("HairLock.L" if side<0 else "HairLock.R",
             [(side*.34,-.23,3.01,.20),(side*.46,-.35,2.73,.84),
              (side*.51,-.40,2.38,1.0),(side*.53,-.43,1.98,1.03),
              (side*.47,-.48,1.56,1.0),(side*.39,-.46,1.17,.66),
              (side*.38,-.43,1.04,.05)],.15,.10,body)
    tube("HairFringe",[(.16,-.23,3.14,.45),(.08,-.34,3.07,.90),
         (-.12,-.46,2.95,1.0),(-.31,-.46,2.78,.82),
         (-.43,-.39,2.68,.15)],.145,.17,body)


def body(bodymat, skin):
    # Closed, low-poly chest shape and a short visible neck.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, location=(0, .03, 1.72))
    neck = bpy.context.object; neck.name = "Neck"; neck.scale = (.23,.21,.38); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); neck.data.materials.append(bodymat); smooth(neck); uv_field(neck, (.875,.56))
    verts=[]; faces=[]; n=20
    for z, rx, ry in [(1.58,.42,.26),(1.25,.78,.38),(.91,1.05,.48)]:
        for i in range(n):
            a=math.tau*i/n; verts.append((rx*math.cos(a), ry*math.sin(a)+.11, z))
    for r in range(2):
        for i in range(n):
            j=(i+1)%n; faces.append((r*n+i,r*n+j,(r+1)*n+j,(r+1)*n+i))
    faces.append(tuple(range(n-1,-1,-1))); faces.append(tuple(2*n+i for i in range(n)))
    mesh("TravellerBody",verts,faces,bodymat,(.375,.56))
    # A low rear collar joins the hood seat to the shoulder mass in both poses.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, location=(0, .34, 1.38))
    seat = bpy.context.object; seat.name = "HoodSeat"; seat.scale = (.74, .18, .17)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); seat.data.materials.append(bodymat); smooth(seat); uv_field(seat, (.625,.56))


def hood(bodymat):
    # The approved raised hood cage, copied from the earlier study before the
    # shape key is made. Its central neck point is behind the visible neck.
    outline=[(0,-.32,3.37),(.30,-.35,3.30),(.56,-.40,3.08),(.68,-.32,2.78),(.76,-.22,2.42),(.77,-.12,2.06),(.65,-.10,1.76),(.36,-.23,1.60),(0,.18,1.56)]
    outline += [(-x,y,z) for x,y,z in reversed(outline[1:-1])]
    rings=[outline]
    for depth, width, vertical in [(0.12,1.06,1.01),(.43,.97,.94),(.66,.62,.70)]:
        rings.append([(x*width, depth + .10*(1-(z-1.54)/1.78), 2.34+(z-2.34)*vertical) for x,y,z in outline])
    n=len(outline); verts=[p for r in rings for p in r]; faces=[]
    for r in range(len(rings)-1):
        for i in range(n):
            j=(i+1)%n; faces.append((r*n+i,r*n+j,(r+1)*n+j,(r+1)*n+i))
    verts.append((0,.82,2.30))
    for i in range(n):
        faces.append(((len(rings)-1)*n+i,(len(rings)-1)*n+(i+1)%n,len(verts)-1))
    hood=mesh("Hood",verts,faces,bodymat,(.625,.56))
    sub=hood.modifiers.new("BroadClothForm","SUBSURF"); sub.levels=1; sub.render_levels=1
    bpy.context.view_layer.objects.active=hood; bpy.ops.object.modifier_apply(modifier=sub.name)
    solid=hood.modifiers.new("ClothThickness","SOLIDIFY"); solid.thickness=.05; solid.offset=-1
    bpy.context.view_layer.objects.active=hood; bpy.ops.object.modifier_apply(modifier=solid.name)
    hood.shape_key_add(name="Basis")
    lowered=hood.shape_key_add(name="HoodLowered")
    # Fold the same hood shell behind the neck so it rests on the shoulder top.
    for i, key in enumerate(lowered.data):
        x,y,z=hood.data.vertices[i].co
        # Turn the opening upward and fold its length onto the back collar.
        # The positive determinant keeps the shell's inside/outside unchanged.
        key.co = (x*.73, .32+(z-1.56)*.26, 1.52-(y-.18)*.28)
    return hood


def assert_study():
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    triangles=sum(len(o.data.polygons) if all(len(p.vertices)==3 for p in o.data.polygons) else sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    assert triangles <= 5000, triangles
    assert bpy.data.objects["Hood"].data.shape_keys.key_blocks.get("HoodLowered")
    used_materials = {slot.material for obj in meshes for slot in obj.material_slots if slot.material}
    assert len(used_materials) == 2
    headobj=bpy.data.objects["Head"]
    assert all(0 <= item.uv.x <= .25 and 0 <= item.uv.y <= 1 for item in headobj.data.uv_layers[0].data)
    for mat in bpy.data.materials:
        assert mat.node_tree.links, mat.name
    print(f"traveller_painted_triangles={triangles}")


def setup_review():
    bpy.ops.object.camera_add(); camera=bpy.context.object; camera.data.type="ORTHO"; camera.data.ortho_scale=4.0; bpy.context.scene.camera=camera
    for location, power, size in [((-4,-5,5),900,4),((4,-3,3),400,3),((1,4,5),600,3)]:
        bpy.ops.object.light_add(type="AREA", location=location); light=bpy.context.object; light.data.energy=power; light.data.shape="DISK"; light.data.size=size; light.rotation_euler=(Vector((0,0,2.0))-light.location).to_track_quat("-Z","Y").to_euler()
    scene=bpy.context.scene; scene.render.engine="BLENDER_EEVEE"; scene.render.resolution_x=700; scene.render.resolution_y=700; scene.render.resolution_percentage=100; scene.render.image_settings.file_format="PNG"; scene.world.color=(.045,.055,.07)
    return camera


def aim(camera, location): camera.location=location; camera.rotation_euler=(Vector((0,0,2.05))-camera.location).to_track_quat("-Z","Y").to_euler()


def renders(camera):
    views={"front":(0,-7,2.15),"side":(7,0,2.15),"back":(0,7,2.15),"three-quarter":(4.8,-5.2,2.6),"elevated":(4.8,-5.2,5.2)}
    if os.environ.get("TRAVELLER_EARLY"):
        views={name: views[name] for name in ("front", "three-quarter")}
    hoodobj=bpy.data.objects["Hood"]; key=hoodobj.data.shape_keys.key_blocks["HoodLowered"]
    for pose, value in (("raised",0), ("lowered",1)):
        key.value=value
        for name, location in views.items():
            aim(camera,location); bpy.context.scene.render.filepath=str(RENDERS / pose / f"{name}.png"); (RENDERS / pose).mkdir(parents=True,exist_ok=True); bpy.ops.render.render(write_still=True)


def save_export():
    bpy.data.objects["Hood"].data.shape_keys.key_blocks["HoodLowered"].value = 0.0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND)); bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type=="MESH": obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(GLB),export_format="GLB",use_selection=True,export_yup=True,export_image_format="AUTO")


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Use a separate background Blender process with factory startup.")
    clean(); skin, bodymat=atlas_materials(); head(skin); hair(bodymat); body(bodymat,skin); hood(bodymat); assert_study(); cam=setup_review(); renders(cam); save_export()

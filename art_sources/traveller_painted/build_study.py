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
GLBS = {
    "Long": ROOT / "assets/studies/traveller_painted.glb",
    "Bob": ROOT / "assets/studies/traveller_painted_bob.glb",
    "Bun": ROOT / "assets/studies/traveller_painted_bun.glb",
}
RENDERS = ROOT / "docs/art/traveller-hair-study-02"


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
    obj = bpy.context.object; obj.name = "Head"; obj.data.name = "Head"; obj.scale = (.56, .49, .68)
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


def add_hair_tuck(obj):
    obj.shape_key_add(name="Basis")
    tucked=obj.shape_key_add(name="HairTucked")
    inverse=obj.matrix_world.inverted()
    for vertex, key in zip(obj.data.vertices, tucked.data):
        x,y,z=obj.matrix_world @ vertex.co
        if obj.name == "HairCap.Long":
            # The lower hood opening clears the whole long curtain.  The
            # raised endpoint keeps its length and broad downward shape.
            contact=math.exp(-((z-1.76)/.32)**2)*max(0.0,min(1.0,(-y-.10)/.15))
            y += .18*contact
            radial=Vector((x/.56, y/.49, (z-2.48)/.68))
            if .001 < radial.length < 1.07:
                radial *= 1.07/radial.length
                x,y,z=radial.x*.56,radial.y*.49,2.48+radial.z*.68
            key.co=inverse @ Vector((x, y, z))
            continue
        if obj.name.startswith("HairCap") and y > -.12:
            # The raised hood covers the rear cap. Gather that covered hair
            # near the crown; leave the open front hairline unchanged.
            z=2.66+(z-2.66)*.16
            y=-.03+(y+.03)*.32
        elif obj.name.startswith("HairBun"):
            # A compact raised bun stays inside the rounded shell.
            x *= .45
            y = .44+(y-.48)*.30
            z = 2.64+(z-1.80)*.25
        # Front locks ease inward where their upper shoulders pass the rim.
        radial=Vector((x/.56, y/.49, (z-2.48)/.68))
        if radial.length < 1.058:
            radial *= 1.058/radial.length
            x,y,z=radial.x*.56,radial.y*.49,2.48+radial.z*.68
        key.co=inverse @ Vector((x,y,z))
    tucked.value=1.0


def hair_cap(name, body, end_height):
    """One continuous scalp mesh, including its forehead fringe and side locks."""
    n=24; rows=7; vertices=[]; faces=[]
    profile=[(3.23,.015,.015),(3.18,.24,.20),(3.06,.43,.37),
             (2.84,.565,.48),(2.56,.59,.525),(2.22,.60,.52),
             (1.80,.60,.48),(1.32,.54,.42),(.98,.43,.35)]
    for row in range(rows):
        for j in range(n):
            angle=math.atan2(math.sin(math.tau*j/n), math.cos(math.tau*j/n))
            distance=abs(angle)
            curtain=max(0,min(1,(distance-.66)/.86))
            curtain=curtain*curtain*(3-2*curtain)
            end=2.76*(1-curtain)+end_height*curtain
            # Shape the single cap front hem into the swept fringe. It sits
            # on the scalp, so there is no separate raised fringe volume.
            fringe=max(0,min(1,(.95-distance)/.35))
            fringe=fringe*fringe*(3-2*fringe)
            sweep=2.96+.12*math.sin(angle)-.22*max(0, -math.sin(angle))
            end=end*(1-fringe)+sweep*fringe
            # The two low side hem regions are the locks.  They are columns
            # of this scalp mesh, so their roots share faces and vertices with
            # the fringe and scalp instead of meeting as separate panels.
            lock_left=max(0, 1-abs(angle + .76)/.38)
            lock_right=max(0, 1-abs(angle - .76)/.38)
            lock=max(lock_left, lock_right)
            lock=lock*lock*(3-2*lock)
            lock_end={"Long":1.08, "Bob":2.02, "Bun":2.06}[name.rsplit(".", 1)[1]]
            end=end*(1-lock)+lock_end*lock
            if end_height > 1.5:
                # Lift the side hem to make the short styles round, not square.
                end += .11 * curtain * math.sin(angle)**2
            # Resample every column from crown to hem. The front sweep can
            # sit higher than the old fixed third row, so partial resampling
            # would fold the column back over itself.
            z=3.23+(end-3.23)*row/(rows-1)
            for k in range(len(profile)-1):
                high, low=profile[k],profile[k+1]
                if high[0]>=z>=low[0]:
                    t=(high[0]-z)/(high[0]-low[0])
                    rx=high[1]*(1-t)+low[1]*t; ry=high[2]*(1-t)+low[2]*t
                    break
            if name.endswith(".Bun") and z < 2.30:
                gather=max(0,min(1,(2.30-z)/.60))
                rx *= 1-.60*gather
                ry *= 1-.20*gather
            x=rx*math.sin(angle); y=.05-ry*math.cos(angle)
            vertices.append((x,y,z))
    for r in range(rows-1):
        for j in range(n):
            k=(j+1)%n
            faces.append((r*n+j,r*n+k,(r+1)*n+k,(r+1)*n+j))
    faces.append(tuple(range(n-1,-1,-1)))
    cap=mesh(name,vertices,faces,body,(.125,.56))
    # A low cage plus one baked subdivision rounds only the silhouette.
    sub=cap.modifiers.new("Rounded hair volume","SUBSURF")
    sub.levels=1; sub.render_levels=1
    bpy.context.view_layer.objects.active=cap
    bpy.ops.object.modifier_apply(modifier=sub.name)
    for vertex in cap.data.vertices:
        vertex.co.x *= 1.08
        vertex.co.y = .05+(vertex.co.y-.05)*1.08
    # The tiny rolled edge keeps a coherent silhouette at the open hairline.
    solid=cap.modifiers.new("Hair edge thickness","SOLIDIFY")
    solid.thickness=.014; solid.offset=-1
    bpy.context.view_layer.objects.active=cap
    bpy.ops.object.modifier_apply(modifier=solid.name)
    add_hair_landmarks(cap)
    return cap


def add_hair_landmarks(obj):
    """Store sparse root and long-rear landmarks after final subdivision."""
    vertices=obj.data.vertices
    for group_name, target in (("HairRootLeft", Vector((-.34,-.40,2.82))),
                               ("HairRootRight", Vector((.34,-.40,2.82)))):
        group=obj.vertex_groups.new(name=group_name)
        index=min(vertices, key=lambda vertex: (vertex.co-target).length).index
        group.add([index], 1.0, "REPLACE")
    if obj.name == "HairCap.Long":
        root=obj.vertex_groups.new(name="LongRearRoot")
        tip=obj.vertex_groups.new(name="LongRearTip")
        root_index=min(vertices, key=lambda vertex: (vertex.co-Vector((0,.46,2.72))).length).index
        tip_index=min(vertices, key=lambda vertex: (vertex.co-Vector((0,.48,1.02))).length).index
        root.add([root_index], 1.0, "REPLACE")
        tip.add([tip_index], 1.0, "REPLACE")


def style_hair(style, body):
    collection=bpy.data.collections.new(f"Hair Style {style}")
    bpy.context.scene.collection.children.link(collection)
    objects=[hair_cap(f"HairCap.{style}", body, {"Long":1.02,"Bob":1.92,"Bun":1.72}[style])]
    if style == "Bun":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8, location=(0,.48,1.80))
        bun=bpy.context.object; bun.name="HairBun.Bun"; bun.data.name=bun.name; bun.scale=(.34,.20,.21); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); bun.data.materials.append(body); smooth(bun); uv_field(bun,(.125,.56)); objects.append(bun)
    for obj in objects:
        bpy.context.collection.objects.unlink(obj); collection.objects.link(obj)
        # Keep the entire hair surface outside the smooth head, including
        # flat face chords between cage vertices. This is an authoring step.
        bpy.context.view_layer.update()
        inverse=obj.matrix_world.inverted()
        for vertex in obj.data.vertices:
            point=obj.matrix_world @ vertex.co
            radial=Vector((point.x/.56, point.y/.49, (point.z-2.48)/.68))
            if .001 < radial.length < 1.055:
                radial *= 1.055/radial.length
                vertex.co=inverse @ Vector((radial.x*.56, radial.y*.49, 2.48+radial.z*.68))
        obj.data.update()
        add_hair_tuck(obj)
    return collection


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


def hood(bodymat, style):
    # The same crown and face opening end at two front-neck points. Build the
    # lower opening in the cage, so its edges cannot become a separate strap.
    outline=[(0,-.32,3.37),(.30,-.35,3.30),(.56,-.40,3.08),(.68,-.32,2.78),(.76,-.22,2.42),(.77,-.28,2.06),(.65,-.43,1.86),(.23,-.48,1.68),(.27,-.05,1.58),(0,.34,1.58)]
    outline += [(-x,y,z) for x,y,z in reversed(outline[1:-1])]
    rings=[outline]
    for depth, width, vertical in [(0.12,1.06,1.01),(.43,.97,.94),(.66,.62,.70)]:
        rings.append([(x*width, depth + .10*(1-(z-1.54)/1.78), 2.34+(z-2.34)*vertical) for x,y,z in outline])
    for i in (5,6,7,11,12,13):
        x,y,z=rings[1][i]
        rings[1][i]=(x,{5:-.05,6:-.28,7:-.34,11:-.34,12:-.28,13:-.05}[i],z)
    for i,x,y in ((8,.34,.09),(9,0,.34),(10,-.34,.09)):
        rings[1][i]=(x,y,1.55)
    for r,x,y,z in ((1,.79,-.12,1.98),(2,.68,.45,2.00)):
        rings[r][5]=(x,y,z)
        rings[r][13]=(-x,y,z)
    for i in (7,11):
        x,y,z=rings[1][i]
        rings[1][i]=(x,y,1.88)
    for i,x,y,z in ((7,.29,-.12,1.70),(8,.26,.25,1.55),(9,0,.34,1.55),
                    (10,-.26,.25,1.55),(11,-.29,-.12,1.70)):
        rings[2][i]=(x,y,z)
    # Short raised hair leaves this lower area empty. Let the cloth fall to
    # the seam there; Long needs the larger exit behind its connected locks.
    if style != "Long":
        for i,sign in ((7,1),(11,-1)):
            rings[1][i]=(sign*.38,.10,1.68)
            rings[2][i]=(sign*.37,.50,1.76)
    for i,x,y,z in ((6,.40,.74,2.02),(7,.30,.77,1.98),(8,.15,.78,1.94),(9,0,.78,1.92),
                    (10,-.15,.78,1.94),(11,-.30,.77,1.98),(12,-.40,.74,2.02)):
        rings[3][i]=(x,y,z)
    n=len(outline); verts=[p for r in rings for p in r]; faces=[]
    for r in range(len(rings)-1):
        for i in range(n):
            if (r == 0 and i in (8,9)) or (style == "Long" and r >= 1 and 5 <= i <= 12 and not (r == 1 and 7 <= i <= 10)):
                continue
            j=(i+1)%n; faces.append((r*n+i,r*n+j,(r+1)*n+j,(r+1)*n+i))
    verts.append((0,.82,2.30))
    for i in range(n):
        faces.append(((len(rings)-1)*n+i,(len(rings)-1)*n+(i+1)%n,len(verts)-1))
    hood=mesh("Hood."+style,verts,faces,bodymat,(.625,.56))
    attachment=hood.vertex_groups.new(name="HoodAttachment")
    attachment.add([r*n+i for r in (0,1,2) for i in (8,9,10)],1.0,"REPLACE")
    attachment_index=attachment.index
    hood_bm=bmesh.new(); hood_bm.from_mesh(hood.data)
    loose=[vertex for vertex in hood_bm.verts if not vertex.link_edges]
    if loose: bmesh.ops.delete(hood_bm,geom=loose,context="VERTS")
    hood_bm.to_mesh(hood.data); hood_bm.free(); hood.data.update()
    sub=hood.modifiers.new("BroadClothForm","SUBSURF"); sub.levels=1; sub.render_levels=1
    bpy.context.view_layer.objects.active=hood; bpy.ops.object.modifier_apply(modifier=sub.name)
    # Embed the fixed sewn edge in the garment's top volume. Subdivision
    # rounds the adjoining cloth; the seam stays fixed in both authored poses.
    for vertex in hood.data.vertices:
        if any(g.group == attachment_index and g.weight > .5 for g in vertex.groups):
            vertex.co.z=1.55
    solid=hood.modifiers.new("ClothThickness","SOLIDIFY"); solid.thickness=.05; solid.offset=-1
    bpy.context.view_layer.objects.active=hood; bpy.ops.object.modifier_apply(modifier=solid.name)
    uv_field(hood,(.625,.56))
    hood.shape_key_add(name="Basis")
    lowered=hood.shape_key_add(name="HoodLowered")
    attachment_indices=[vertex.index for vertex in hood.data.vertices
                        if any(g.group == attachment_index and g.weight > .5 for g in vertex.groups)]
    assert len(attachment_indices) >= 2, attachment_indices
    # Fold the same shell into a compact back collar without changing the hair.
    for i,key in enumerate(lowered.data):
        x,y,z=hood.data.vertices[i].co
        if i in attachment_indices:
            key.co=(x,y,z)
        else:
            key.co=(x*.42,.12+(z-1.56)*.11+(y-.18)*.06,1.68-(y-.18)*.18)
    collection=bpy.data.collections["Hair Style "+style]
    bpy.context.collection.objects.unlink(hood)
    collection.objects.link(hood)
    return hood


def fit_lowered_hair():
    """Keep the lowered cap clear of the head and collar without a flare."""
    for name in ("HairCap.Long", "HairBun.Bun"):
        obj=bpy.data.objects[name]
        inverse=obj.matrix_world.inverted()
        basis=obj.data.shape_keys.key_blocks["Basis"]
        for vertex, key in zip(obj.data.vertices, basis.data):
            point=obj.matrix_world @ vertex.co
            if name == "HairCap.Long":
                radial=Vector((point.x/.56, point.y/.49, (point.z-2.48)/.68))
                if .001 < radial.length < 1.07:
                    radial *= 1.07/radial.length
                    point=Vector((radial.x*.56, radial.y*.49, 2.48+radial.z*.68))
            else:
                point.y += .12
                point.z += .13
            vertex.co=inverse @ point
            key.co=vertex.co
        obj.data.update()


def triangle_count(objects):
    return sum(sum(len(p.vertices)-2 for p in obj.data.polygons) for obj in objects)


def assert_study(styles):
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    common=[obj for obj in meshes if not obj.name.startswith(("Hair","Hood"))]
    counts={style: triangle_count(common + list(collection.objects)) for style, collection in styles.items()}
    assert all(count <= 5000 for count in counts.values()), counts
    assert all(bpy.data.objects["Hood."+style].data.shape_keys.key_blocks.get("HoodLowered")
               for style in styles)
    for obj in meshes:
        if obj.name.startswith("Hair"):
            assert obj.data.shape_keys and obj.data.shape_keys.key_blocks.get("HairTucked"), obj.name
    used_materials = {slot.material for obj in meshes for slot in obj.material_slots if slot.material}
    assert len(used_materials) == 2
    headobj=bpy.data.objects["Head"]
    assert all(0 <= item.uv.x <= .25 and 0 <= item.uv.y <= 1 for item in headobj.data.uv_layers[0].data)
    for mat in bpy.data.materials:
        assert mat.node_tree.links, mat.name
    print(f"traveller_painted_triangles={counts}")


def setup_review():
    bpy.ops.object.camera_add(); camera=bpy.context.object; camera.data.type="ORTHO"; camera.data.ortho_scale=4.0; bpy.context.scene.camera=camera
    for location, power, size in [((-4,-5,5),900,4),((4,-3,3),400,3),((1,4,5),600,3)]:
        bpy.ops.object.light_add(type="AREA", location=location); light=bpy.context.object; light.data.energy=power; light.data.shape="DISK"; light.data.size=size; light.rotation_euler=(Vector((0,0,2.0))-light.location).to_track_quat("-Z","Y").to_euler()
    scene=bpy.context.scene; scene.render.engine="BLENDER_EEVEE"; scene.render.resolution_x=700; scene.render.resolution_y=700; scene.render.resolution_percentage=100; scene.render.image_settings.file_format="PNG"; scene.world.color=(.045,.055,.07)
    return camera


def aim(camera, location): camera.location=location; camera.rotation_euler=(Vector((0,0,2.05))-camera.location).to_track_quat("-Z","Y").to_euler()


def set_pose(collection, lowered):
    for obj in collection.objects:
        keys=obj.data.shape_keys.key_blocks
        if obj.name.startswith("Hood"):
            keys["HoodLowered"].value=lowered
        else:
            keys["HairTucked"].value=1-lowered


def renders(camera, styles):
    views={"front":(0,-7,2.15),"side":(7,0,2.15),"back":(0,7,2.15),"three-quarter":(4.8,-5.2,2.6),"elevated":(4.8,-5.2,5.2)}
    if os.environ.get("TRAVELLER_EARLY"):
        views={name: views[name] for name in ("front", "three-quarter")}
    for style, collection in styles.items():
        for other in styles.values():
            other.hide_render = other != collection
        for pose, value in (("raised",0), ("lowered",1)):
            set_pose(collection,value)
            for name, location in views.items():
                aim(camera,location)
                output=RENDERS / style.lower() / pose
                bpy.context.scene.render.filepath=str(output / f"{name}.png")
                output.mkdir(parents=True,exist_ok=True)
                bpy.ops.render.render(write_still=True)


def save_export(styles):
    for collection in styles.values():
        set_pose(collection,0)
    for style, collection in styles.items():
        collection.hide_render = style != "Long"
        collection.hide_viewport = style != "Long"
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    # Export selections even for the comparison collections hidden in the file.
    for collection in styles.values():
        collection.hide_viewport = False
    common=[obj for obj in bpy.context.scene.objects if obj.type=="MESH" and not obj.name.startswith(("Hair","Hood"))]
    for style, collection in styles.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in common + list(collection.objects): obj.select_set(True)
        hoodobj=bpy.data.objects["Hood."+style]
        name=hoodobj.name
        try:
            hoodobj.name="Hood"
            bpy.ops.export_scene.gltf(filepath=str(GLBS[style]), export_format="GLB", use_selection=True, export_yup=True, export_image_format="AUTO")
        finally:
            hoodobj.name=name


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Use a separate background Blender process with factory startup.")
    clean(); skin, bodymat=atlas_materials(); head(skin); body(bodymat,skin)
    styles={style: style_hair(style, bodymat) for style in ("Long", "Bob", "Bun")}
    fit_lowered_hair()
    for style in styles: hood(bodymat,style)
    assert_study(styles); cam=setup_review(); renders(cam, styles); save_export(styles)

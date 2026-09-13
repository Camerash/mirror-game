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


def swept_panel(name, points, material):
    """A shallow, tapered hair mass, wide across the face and never a tube."""
    controls=[Vector(p) for p in points]
    verts=[]; faces=[]
    for i, control in enumerate(controls):
        centre=Vector(control[:3]); half_width=control.w
        tangent=(Vector(controls[min(i+1,len(controls)-1)][:3])-Vector(controls[max(i-1,0)][:3])).normalized()
        across=(Vector((1,0,0))-tangent*tangent.x).normalized()
        # Two rounded front corners and a rear skin form a small coherent volume.
        for offset, depth in ((-1,.025),(-.55,-.055),(.55,-.055),(1,.025)):
            verts.append(centre + across * (half_width * offset) + Vector((0, depth, 0)))
    for i in range(len(controls)-1):
        for j in range(3):
            a=i*4+j; faces.append((a,a+1,a+5,a+4))
        faces.append((i*4, (i+1)*4, (i+1)*4+3, i*4+3))
    faces += [(0,1,2,3), tuple(range((len(controls)-1)*4, len(controls)*4))]
    obj=mesh(name, verts, faces, material, (.125,.56))
    rounded=obj.modifiers.new("Soft hair mass", "SUBSURF")
    rounded.levels=1; rounded.render_levels=1
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=rounded.name)
    return obj


def add_hair_tuck(obj):
    obj.shape_key_add(name="Basis")
    tucked=obj.shape_key_add(name="HairTucked")
    inverse=obj.matrix_world.inverted()
    for vertex, key in zip(obj.data.vertices, tucked.data):
        x,y,z=obj.matrix_world @ vertex.co
        if obj.name.startswith("HairCap") and (y > -.12 or (obj.name.endswith(".Long") and z < 2.50)):
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
        if obj.name.startswith("HairLock"):
            blend=max(0,min(1,(z-1.08)/1.85))
            x_limit=.34+.16*blend
            key.co=inverse @ Vector((max(-x_limit,min(x_limit,x)), y, z))
        else:
            radial=Vector((x/.56, y/.49, (z-2.48)/.68))
            if radial.length < 1.058:
                radial *= 1.058/radial.length
                x,y,z=radial.x*.56,radial.y*.49,2.48+radial.z*.68
            key.co=inverse @ Vector((x,y,z))
    tucked.value=1.0


def conform_fringe(obj):
    """Keep the shallow sweep against the scalp instead of floating above it."""
    for vertex in obj.data.vertices:
        # A smooth depth bend preserves the broad sweep and its rounded volume.
        blend=max(0,min(1,(vertex.co.z-2.70)/.50))
        vertex.co.y += .17*blend
        radial=Vector((vertex.co.x/.56,vertex.co.y/.49,(vertex.co.z-2.48)/.68))
        if radial.length < 1.055:
            radial *= 1.055/radial.length
            vertex.co=Vector((radial.x*.56,radial.y*.49,2.48+radial.z*.68))
    obj.data.update()


def hair_cap(name, body, end_height):
    """A single scalp-to-back mass; the front remains open for the face."""
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
            end=2.76*(1-curtain)+end_height*curtain
            if end_height > 1.5:
                # Lift the side hem to make the short styles round, not square.
                end += .11 * curtain * math.sin(angle)**2
            # Resample each column onto its own final height.
            z=profile[row][0] if row<4 else 2.84+(end-2.84)*(row-3)/(rows-4)
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
    return cap


def fringe(style, body):
    # A large sweep and small supporting sweep share one right crown root.
    # They overlap the cap's upper hairline and keep the painted forehead clear.
    left=swept_panel(f"HairFringe.L.{style}", [
        (.20,-.22,3.19,.075),(.11,-.34,3.17,.15),(-.06,-.45,3.10,.20),(-.27,-.49,2.93,.19),(-.43,-.43,2.74,.018)], body)
    right=swept_panel(f"HairFringe.R.{style}", [
        (.25,-.22,3.17,.045),(.18,-.32,3.14,.085),(.05,-.42,3.04,.11),(-.16,-.46,2.84,.014)], body)
    return [left,right]


def style_hair(style, body):
    collection=bpy.data.collections.new(f"Hair Style {style}")
    bpy.context.scene.collection.children.link(collection)
    objects=[hair_cap(f"HairCap.{style}", body, {"Long":1.02,"Bob":1.92,"Bun":1.72}[style])]
    objects.extend(fringe(style, body))
    if style == "Long":
        objects.extend([
            swept_panel("HairLock.L.Long", [(-.34,-.43,2.94,.18),(-.48,-.42,2.54,.22),(-.52,-.38,2.03,.23),(-.45,-.30,1.40,.18),(-.36,-.23,1.08,.025)], body),
            swept_panel("HairLock.R.Long", [(.30,-.42,2.94,.15),(.45,-.40,2.53,.20),(.49,-.35,1.96,.22),(.42,-.26,1.38,.17),(.33,-.20,1.10,.025)], body)])
    elif style == "Bob":
        objects.extend([
            swept_panel("HairCheek.L.Bob", [(-.37,-.42,2.92,.14),(-.46,-.39,2.58,.16),(-.43,-.34,2.20,.12),(-.34,-.29,2.02,.025)], body),
            swept_panel("HairCheek.R.Bob", [(.31,-.42,2.93,.12),(.40,-.39,2.59,.14),(.38,-.34,2.23,.10),(.30,-.29,2.05,.025)], body)])
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8, location=(0,.48,1.80))
        bun=bpy.context.object; bun.name="HairBun.Bun"; bun.data.name=bun.name; bun.scale=(.34,.20,.21); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); bun.data.materials.append(body); smooth(bun); uv_field(bun,(.125,.56)); objects.append(bun)
        objects.extend([
            swept_panel("HairCheek.L.Bun", [(-.36,-.42,2.92,.13),(-.44,-.39,2.58,.14),(-.39,-.32,2.22,.10),(-.31,-.26,2.06,.025)], body),
            swept_panel("HairCheek.R.Bun", [(.31,-.42,2.93,.11),(.39,-.39,2.60,.12),(.35,-.32,2.25,.09),(.28,-.26,2.09,.025)], body)])
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
        if obj.name.startswith("HairFringe"):
            conform_fringe(obj)
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


def hood(bodymat):
    # The approved rounded raised hood cage. Its low rear point meets the
    # garment neckline; keep this external cage unchanged.
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
    uv_field(hood, (.625,.56))
    hood.shape_key_add(name="Basis")
    lowered=hood.shape_key_add(name="HoodLowered")
    attachment=hood.vertex_groups.new(name="HoodAttachment")
    # The applied shell gives the genuine rear neck contact a thin inner and
    # outer pair. It is the sewn neckline, not a suspended shoulder panel.
    attachment_indices=[vertex.index for vertex in hood.data.vertices
                        if vertex.co.z <= 1.585 and abs(vertex.co.x) < .08]
    attachment.add(attachment_indices, 1.0, "REPLACE")
    assert len(attachment_indices) >= 2, attachment_indices
    # Fold the same shell behind the neck. The sewn neckline remains fixed.
    for i, key in enumerate(lowered.data):
        x,y,z=hood.data.vertices[i].co
        if i in attachment_indices:
            key.co = (x,y,z)
        else:
            key.co = (x*.80, .18+(z-1.56)*.30+(y-.18)*.15, 1.56-(y-.18)*.30)
    return hood


def fit_lowered_hair():
    """Lay rear hair over the folded collar with one broad, smooth bend."""
    for name in ("HairCap.Long", "HairBun.Bun"):
        obj=bpy.data.objects[name]
        inverse=obj.matrix_world.inverted()
        basis=obj.data.shape_keys.key_blocks["Basis"]
        for vertex, key in zip(obj.data.vertices, basis.data):
            point=obj.matrix_world @ vertex.co
            if name == "HairCap.Long":
                weight=max(0.0, min(1.0, (2.80-point.z)/1.40))
                weight=weight*weight*(3.0-2.0*weight)
                rear=max(0.0, min(1.0, (point.y+.12)/.30))
                point.x *= 1.0+.48*weight*rear
                point.y += .49*weight*rear
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
    common=[obj for obj in meshes if not obj.name.startswith("Hair")]
    counts={style: triangle_count(common + list(collection.objects)) for style, collection in styles.items()}
    assert all(count <= 5000 for count in counts.values()), counts
    assert bpy.data.objects["Hood"].data.shape_keys.key_blocks.get("HoodLowered")
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


def renders(camera, styles):
    views={"front":(0,-7,2.15),"side":(7,0,2.15),"back":(0,7,2.15),"three-quarter":(4.8,-5.2,2.6),"elevated":(4.8,-5.2,5.2)}
    if os.environ.get("TRAVELLER_EARLY"):
        views={name: views[name] for name in ("front", "three-quarter")}
    hoodobj=bpy.data.objects["Hood"]; hood_key=hoodobj.data.shape_keys.key_blocks["HoodLowered"]
    for style, collection in styles.items():
        for other in styles.values():
            other.hide_render = other != collection
        for pose, value in (("raised",0), ("lowered",1)):
            hood_key.value=value
            for obj in collection.objects:
                obj.data.shape_keys.key_blocks["HairTucked"].value = 1 - value
            for name, location in views.items():
                aim(camera,location)
                output=RENDERS / style.lower() / pose
                bpy.context.scene.render.filepath=str(output / f"{name}.png")
                output.mkdir(parents=True,exist_ok=True)
                bpy.ops.render.render(write_still=True)


def save_export(styles):
    hood=bpy.data.objects["Hood"]
    hood.data.shape_keys.key_blocks["HoodLowered"].value = 0.0
    for collection in styles.values():
        for obj in collection.objects:
            obj.data.shape_keys.key_blocks["HairTucked"].value = 1.0
    for style, collection in styles.items():
        collection.hide_render = style != "Long"
        collection.hide_viewport = style != "Long"
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    # Export selections even for the comparison collections hidden in the file.
    for collection in styles.values():
        collection.hide_viewport = False
    common=[obj for obj in bpy.context.scene.objects if obj.type=="MESH" and not obj.name.startswith("Hair")]
    for style, collection in styles.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in common + list(collection.objects): obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(GLBS[style]), export_format="GLB", use_selection=True, export_yup=True, export_image_format="AUTO")


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Use a separate background Blender process with factory startup.")
    clean(); skin, bodymat=atlas_materials(); head(skin); body(bodymat,skin); hood(bodymat)
    styles={style: style_hair(style, bodymat) for style in ("Long", "Bob", "Bun")}
    fit_lowered_hair()
    assert_study(styles); cam=setup_review(); renders(cam, styles); save_export(styles)

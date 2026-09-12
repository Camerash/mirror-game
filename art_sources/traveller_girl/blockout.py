"""Create the editable Traveller Girl shape blockout in the active Blender scene.

The model uses Blender Z-up and faces -Y.  Run directly in Blender, or load
this file with ``runpy.run_path`` and call ``build_character()``.
"""
import math

import bpy


COLLECTION_NAME = "TravellerGirl"


def _material(name, colour):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = (*colour, 1.0)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Roughness"].default_value = 0.78
    return material


def _collection():
    old = bpy.data.collections.get(COLLECTION_NAME)
    if old:
        owned_meshes = [object_3d.data for object_3d in old.all_objects
                        if object_3d.type == "MESH"]
        for object_3d in list(old.all_objects):
            other_collections = [linked for linked in object_3d.users_collection if linked != old]
            if other_collections:
                old.objects.unlink(object_3d)
            else:
                bpy.data.objects.remove(object_3d, do_unlink=True)
        bpy.data.collections.remove(old, do_unlink=True)
        for mesh in owned_meshes:
            if mesh.users == 0:
                bpy.data.meshes.remove(mesh)
    collection = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(collection)
    return collection


def _mesh(name, vertices, faces, material, collection, parent):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    object_3d = bpy.data.objects.new(name, mesh)
    collection.objects.link(object_3d)
    object_3d.parent = parent
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return object_3d


def _sphere(name, location, scale, material, collection, parent, segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    object_3d = bpy.context.object
    for linked in list(object_3d.users_collection):
        linked.objects.unlink(object_3d)
    collection.objects.link(object_3d)
    object_3d.name = name
    object_3d.scale = scale
    object_3d.data.materials.append(material)
    object_3d.parent = parent
    for polygon in object_3d.data.polygons:
        polygon.use_smooth = True
    return object_3d


def _lathe_cloak(material, collection, parent):
    sides = 32
    opening = 0.07
    profile = ((0.30, 0.32), (0.38, 0.32), (0.60, 0.285),
               (0.83, 0.245), (1.03, 0.195), (1.12, 0.13))
    vertices = []
    for height, radius in profile:
        for index in range(sides):
            row_opening = opening * max(0, min(1, (.85-height)/.5))
            theta = -math.pi / 2 + row_opening + index * (math.tau - row_opening * 2) / (sides - 1)
            fold = 1.0 + 0.018 * math.cos(theta * 3.0 + height * 4.0)
            vertices.append((radius * fold * math.cos(theta), 0.82 * radius * fold * math.sin(theta), height))
    faces = []
    for row in range(len(profile) - 1):
        for index in range(sides - 1):
            current = row * sides + index
            faces.append((current, current + 1, current + sides + 1, current + sides))
    return _mesh("TG_Cloak", vertices, faces, material, collection, parent)


def _hood_shell(material, collection, parent):
    """Loft a rounded shell from its face aperture to the closed rear."""
    sides = 32
    profiles = ((-0.235, .255, .28, 1.34), (-0.16, .28, .285, 1.34),
                (-0.025, .286, .285, 1.34), (.10, .25, .26, 1.35),
                (.19, .17, .205, 1.36), (.235, .075, .10, 1.37),
                (.25, .005, .008, 1.37))
    vertices = []
    for inner in (False, True):
        for y, rx, rz, cz in profiles:
            thickness = .012 if inner else 0
            for i in range(sides):
                theta = math.tau * i / sides
                vertices.append((max(.002, rx-thickness)*math.sin(theta),
                                 y - (.014 if inner else 0) + .16*max(0,-math.cos(theta))**2*max(0,(-y+.10)/.335),
                                 cz + max(.004, rz-thickness)*math.cos(theta)))
    faces = []
    offset = len(profiles) * sides
    for row in range(len(profiles)-1):
        for i in range(sides):
            a = row*sides+i; b = row*sides+(i+1)%sides
            faces.extend(((a, b, b+sides, a+sides),
                          (a+offset, a+sides+offset, b+sides+offset, b+offset)))
    for i in range(sides):
        j = (i+1)%sides
        faces.append((i, i+offset, j+offset, j))
    faces.append(tuple((len(profiles)-1)*sides+i for i in range(sides)))
    faces.append(tuple(offset+(len(profiles)-1)*sides+i for i in reversed(range(sides))))
    return _mesh("TG_Hood_OpenShell", vertices, faces, material, collection, parent)


def _hair_volume(name, centers, radii, material, collection, parent):
    sides = 8
    vertices = []
    for (x, y, z), (width, depth) in zip(centers, radii):
        for index in range(sides):
            angle = math.tau * index / sides
            vertices.append((x + width * math.cos(angle), y + depth * math.sin(angle), z))
    faces = []
    for row in range(len(centers) - 1):
        for index in range(sides):
            next_index = (index + 1) % sides
            faces.append((row * sides + index, row * sides + next_index,
                          (row + 1) * sides + next_index, (row + 1) * sides + index))
    faces.append(tuple(range(sides - 1, -1, -1)))
    faces.append(tuple((len(centers) - 1) * sides + index for index in range(sides)))
    return _mesh(name, vertices, [tuple(reversed(face)) for face in faces], material, collection, parent)


def _hair_cap(material, collection, parent):
    rows, sides = 9, 18
    vertices = []
    for row in range(rows):
        latitude = -0.9 + (math.pi / 2 + 0.86) * row / (rows - 1)
        aperture = 0.78 * max(0.0, math.cos(latitude))
        for side in range(sides):
            theta = -math.pi / 2 + aperture + side * (math.tau - aperture * 2) / (sides - 1)
            vertices.append((0.212 * math.cos(latitude) * math.cos(theta),
                             -0.005 + 0.197 * math.cos(latitude) * math.sin(theta),
                             1.365 + 0.212 * math.sin(latitude)))
    faces = []
    for row in range(rows - 1):
        for side in range(sides - 1):
            current = row * sides + side
            faces.append((current, current + 1, current + sides + 1, current + sides))
    return _mesh("TG_HairCap", vertices, faces, material, collection, parent)


def _hair_locks(material, collection, parent):
    for side, name in ((-1, "TG_HairLock_L"), (1, "TG_HairLock_R")):
        centers = ((side * 0.155, -0.105, 1.43), (side * 0.17, -0.16, 1.36),
                   (side * 0.17, -0.185, 1.27), (side * 0.185, -0.205, 1.17),
                   (side * 0.17, -0.215, 1.07), (side * 0.16, -0.225, 0.97),
                   (side * 0.155, -0.23, 0.87), (side * 0.145, -0.225, 0.78),
                   (side * 0.135, -0.215, 0.71))
        radii = ((0.056, 0.045), (0.065, 0.05), (0.062, 0.047), (0.058, 0.045),
                 (0.055, 0.043), (0.05, 0.04), (0.042, 0.035), (0.025, 0.022), (0.004, 0.004))
        _hair_volume(name, centers, radii, material, collection, parent)
        bangs = ((side * 0.045, -0.175, 1.525), (side * 0.085, -0.195, 1.49),
                 (side * 0.115, -0.2, 1.455), (side * 0.13, -0.195, 1.43))
        _hair_volume("TG_Bang_L" if side < 0 else "TG_Bang_R", bangs,
                     ((0.045, 0.026), (0.043, 0.025), (0.03, 0.021), (0.004, 0.004)),
                     material, collection, parent)


HEAD_PROFILE = ((1.165, .025, .03), (1.19, .09, .08), (1.24, .155, .12),
                (1.31, .19, .15), (1.39, .195, .17), (1.46, .18, .17),
                (1.52, .14, .135), (1.565, .04, .045))


def _head_section(z):
    for (z0, x0, y0), (z1, x1, y1) in zip(HEAD_PROFILE, HEAD_PROFILE[1:]):
        if z <= z1:
            t = max(0, min(1, (z-z0)/(z1-z0)))
            return x0+(x1-x0)*t, y0+(y1-y0)*t
    return HEAD_PROFILE[-1][1:]


def _face_y(x, z):
    rx, depth = _head_section(z)
    front = -.025-depth*math.sqrt(max(0, 1-(x/rx)**2))
    nose = .038*math.exp(-((x/.026)**2 + ((z-1.345)/.033)**2))
    bridge = .014*math.exp(-((x/.021)**2 + ((z-1.38)/.055)**2))
    return front-nose-bridge


def _head(skin, collection, parent):
    rows, sides = 29, 40
    vertices = []
    for row in range(rows):
        z = 1.165 + .40*row/(rows-1)
        rx, depth = _head_section(z)
        for i in range(sides):
            angle = math.tau*i/sides
            x = rx*math.cos(angle)
            y = -.025+depth*math.sin(angle)
            if math.sin(angle) < 0:
                y = _face_y(x,z)
            vertices.append((x,y,z))
    faces = []
    for row in range(rows-1):
        for i in range(sides):
            a=row*sides+i; b=row*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend((tuple(reversed(range(sides))), tuple((rows-1)*sides+i for i in range(sides))))
    return _mesh("TG_Head",vertices,faces,skin,collection,parent)


def _face_patch(name, cx, cz, width, height, material, collection, parent, lift=.003, almond=False):
    sides=20
    vertices=[(cx,_face_y(cx,cz)-lift,cz)]
    for i in range(sides):
        angle=math.tau*i/sides
        x=cx+width*math.cos(angle)
        z=cz+height*math.sin(angle)*(abs(math.sin(angle))**.35 if almond else 1)
        vertices.append((x,_face_y(x,z)-lift,z))
    faces=[(0,i+1,(i+1)%sides+1) for i in range(sides)]
    return _mesh(name,vertices,faces,material,collection,parent)


def _face_line(name, points, thickness, material, collection, parent):
    vertices=[]
    for x,z in points:
        for dz in (-thickness/2,thickness/2):
            vertices.append((x,_face_y(x,z+dz)-.006,z+dz))
    faces=[(i+2,i+3,i+1,i) for i in range(0,len(vertices)-2,2)]
    return _mesh(name,vertices,faces,material,collection,parent)


def _features(materials, collection, parent):
    skin, white, iris, mouth = materials
    _head(skin,collection,parent)
    _sphere("TG_Neck", (0, 0, 1.13), (.065,.065,.10), skin,collection,parent,12,8)
    for side, suffix in ((-1,"L"),(1,"R")):
        cx=side*.073; cz=1.397
        _face_patch("TG_Eye_"+suffix,cx,cz,.039,.019,white,collection,parent,almond=True)
        _face_patch("TG_Iris_"+suffix,cx-.003,cz,.014,.017,iris,collection,parent,lift=.006)
        upper=[(cx+.039*math.cos(t),cz+.019*math.sin(t)**1.35) for t in [math.pi*i/12 for i in range(13)]]
        _face_line("TG_Lid_"+suffix,upper,.003,iris,collection,parent)
        brow=[(cx+dx,1.446+.009*(1-(dx/.038)**2)) for dx in [-.038,-.025,0,.025,.038]]
        _face_line("TG_Brow_"+suffix,brow,.008,mouth,collection,parent)
    lip=[(x,1.278-.004*(1-(x/.035)**2)) for x in [-.035,-.022,0,.022,.035]]
    _face_line("TG_Mouth",lip,.003,mouth,collection,parent)


def _legs_and_boots(materials, collection, parent):
    trousers, boots = materials
    for side in (-1, 1):
        _sphere("TG_Trouser_L" if side < 0 else "TG_Trouser_R", (side * 0.095, 0.015, 0.28),
                (0.10, 0.105, 0.18), trousers, collection, parent, 12, 8)
        _sphere("TG_Boot_L" if side < 0 else "TG_Boot_R", (side * 0.095, -0.055, 0.075),
                (0.105, 0.15, 0.075), boots, collection, parent, 12, 8)


def build_character():
    """Rebuild and return only the dedicated ``TravellerGirl`` collection root."""
    collection = _collection()
    root = bpy.data.objects.new("TG_Root", None)
    collection.objects.link(root)
    skin = _material("TG_Skin", (0.56, 0.31, 0.18))
    hood = _material("TG_BlueGreyCloth", (0.22, 0.30, 0.40))
    hair = _material("TG_ChestnutHair", (0.105, 0.045, 0.022))
    white = _material("TG_EyeWhite", (0.72, 0.70, 0.61))
    iris = _material("TG_DarkIris", (0.025, 0.018, 0.014))
    mouth = _material("TG_MouthColour", (0.07, 0.035, 0.022))
    trousers = _material("TG_Trousers", (0.07, 0.075, 0.09))
    boots = _material("TG_Boots", (0.055, 0.04, 0.035))
    _lathe_cloak(hood, collection, root)
    _hood_shell(hood, collection, root)
    _features((skin, white, iris, mouth), collection, root)
    _hair_cap(hair, collection, root)
    _hair_locks(hair, collection, root)
    _legs_and_boots((trousers, boots), collection, root)
    return root


def self_check():
    """Check that a repeat build owns one stable character collection."""
    build_character()
    first_objects = list(bpy.data.collections[COLLECTION_NAME].objects)
    first_triangles = sum(sum(len(face.vertices) - 2 for face in object_3d.data.polygons)
                          for object_3d in first_objects if object_3d.type == "MESH")
    root = build_character()
    objects = list(bpy.data.collections[COLLECTION_NAME].objects)
    triangles = sum(sum(len(face.vertices) - 2 for face in object_3d.data.polygons)
                    for object_3d in objects if object_3d.type == "MESH")
    assert len([object_3d for object_3d in objects if object_3d.name == "TG_Root"]) == 1
    assert len(objects) == len(first_objects) and triangles == first_triangles
    assert not any(object_3d.name.endswith(".001") for object_3d in objects)
    assert triangles <= 8000
    cloak = bpy.data.objects["TG_Cloak"]
    assert sum(len(face.vertices)-2 for face in cloak.data.polygons) <= 1500
    bpy.context.view_layer.update()
    from mathutils import Vector
    heights = [(obj.matrix_world @ Vector(corner)).z for obj in objects
               if obj.type == "MESH" for corner in obj.bound_box]
    assert min(heights) >= -.001 and max(heights) <= 1.65
    print(f"Traveller girl: {len(objects)-1} meshes, {triangles} triangles, "
          f"height {max(heights)-min(heights):.3f}; repeat build passed")
    return root


if __name__ == "__main__":
    build_character()

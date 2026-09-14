"""Small standing body rig with Blender IK for the two authored hand contacts."""
import math

import bpy
import bmesh
from mathutils import Matrix, Vector

from hood_shapes import GRIP_VERTICES, GRIP_FRACTION, phase_vertices


ARM_BONES = [part+'.'+side for side in ('L', 'R')
             for part in ('Clavicle', 'UpperArm', 'Forearm', 'Hand', 'Thumb', 'Fingers')]


def create_rig(root):
    data = bpy.data.armatures.new('Rig')
    rig = bpy.data.objects.new('Rig', data)
    bpy.context.collection.objects.link(rig)
    rig.parent = root
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    def bone(name, head, tail, parent=None):
        item = data.edit_bones.new(name)
        item.head, item.tail = head, tail
        if parent:
            item.parent = data.edit_bones[parent]
        return item
    bone('Root', (0, 0, 0), (0, 0, .2))
    bone('Pelvis', (0, 0, 1.1), (0, 0, 1.3), 'Root')
    bone('Spine', (0, 0, 1.3), (0, 0, 1.6), 'Pelvis')
    bone('Chest', (0, 0, 1.6), (0, 0, 1.94), 'Spine')
    bone('Neck', (0, 0, 1.94), (0, 0, 2.15), 'Chest')
    bone('Head', (0, 0, 2.15), (0, 0, 2.8), 'Neck')
    for side, sign in (('L', -1), ('R', 1)):
        shoulder = (sign*.19, 0, 1.82)
        elbow = (sign*.18, -.06, 1.32)
        wrist = (sign*.31, -.08, .52)
        bone('Clavicle.'+side, (sign*.03, 0, 1.94), shoulder, 'Chest')
        bone('UpperArm.'+side, shoulder, elbow, 'Clavicle.'+side)
        bone('Forearm.'+side, elbow, wrist, 'UpperArm.'+side)
        bone('Hand.'+side, wrist, (sign*.31, -.08, .36), 'Forearm.'+side)
        bone('Fingers.'+side, (sign*.31, -.08, .42), (sign*.31, -.08, .30), 'Hand.'+side)
        bone('Thumb.'+side, (sign*.31-sign*.045, -.08, .45),
             (sign*.31-sign*.105, -.09, .39), 'Hand.'+side)
        bone('Thigh.'+side, (sign*.185, 0, 1.15), (sign*.185, 0, .7), 'Pelvis')
        bone('Shin.'+side, (sign*.185, 0, .7), (sign*.185, 0, .25), 'Thigh.'+side)
        bone('Foot.'+side, (sign*.185, 0, .25), (sign*.185, -.18, .08), 'Shin.'+side)
    bpy.ops.object.mode_set(mode='OBJECT')
    for side, sign in (('L', -1), ('R', 1)):
        for prefix, location in (('Grip', (sign*.31, -.08, .52)), ('ElbowPole', (sign*.1, -.8, 1.3))):
            target = bpy.data.objects.new(prefix+'.'+side, None)
            bpy.context.collection.objects.link(target)
            target.location = location
            target.empty_display_size = .04
            target.hide_render = True
        ik = rig.pose.bones['Forearm.'+side].constraints.new('IK')
        ik.name = 'Wrist contact IK'
        ik.target = bpy.data.objects['Grip.'+side]
        ik.pole_target = bpy.data.objects['ElbowPole.'+side]
        ik.chain_count = 2
        ik.use_stretch = False
        rotation = rig.pose.bones['Hand.'+side].constraints.new('COPY_ROTATION')
        rotation.name = 'Palm contact orientation'
        rotation.target = bpy.data.objects['Grip.'+side]
    return rig


def fit_arms(body, rig):
    old = body.data
    group = body.vertex_groups['ConcealedArms']
    removed = {v.index for v in old.vertices if any(g.group == group.index for g in v.groups)}
    kept = [v.index for v in old.vertices if v.index not in removed]
    mapping = {index: new for new, index in enumerate(kept)}
    vertices = [tuple(old.vertices[i].co) for i in kept]
    faces, uvs = [], []
    for face in old.polygons:
        if removed.intersection(face.vertices):
            continue
        faces.append(tuple(mapping[i] for i in face.vertices))
        uvs.append([tuple(old.uv_layers.active.data[i].uv) for i in face.loop_indices])
    weights = body_bindings(vertices, faces)
    arm_start = len(vertices)
    for side, sign in (('L', -1), ('R', 1)):
        append_arm(vertices, faces, uvs, weights, side, sign)
    data = bpy.data.meshes.new('ArticulatedBody')
    data.from_pydata(vertices, [], faces)
    data.materials.append(old.materials[0])
    uv = data.uv_layers.new(name='UVMap')
    for polygon, values in zip(data.polygons, uvs):
        polygon.use_smooth = len(polygon.vertices) < 12
        for loop, value in zip(polygon.loop_indices, values):
            uv.data[loop].uv = value
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    body.data = data
    body.vertex_groups.clear()
    for name in rig.data.bones.keys():
        body.vertex_groups.new(name=name)
    for index, item in enumerate(weights):
        for name, value in item.items():
            body.vertex_groups[name].add([index], value, 'REPLACE')
    body.vertex_groups.new(name='AnimatedArms').add(list(range(arm_start, len(vertices))), 1, 'REPLACE')
    modifier = body.modifiers.new('Body skin', 'ARMATURE')
    modifier.object = rig
    body['animated_arm_start'] = arm_start


def append_arm(vertices, faces, uvs, weights, side, sign):
    shoulder = Vector((sign*.19, 0, 1.82))
    elbow = Vector((sign*.18, -.06, 1.32))
    wrist = Vector((sign*.31, -.08, .52))
    sections = []
    for t in (0, .2, .45, .72, .90, 1):
        sections.append((shoulder.lerp(elbow, t), .090-.010*t, .070-.005*t,
                         {'UpperArm.'+side: 1}, (.375, .56)))
    for t in (.10, .28, .55, .82, 1):
        sections.append((elbow.lerp(wrist, t), .080-.020*t, .065-.015*t,
                         {'Forearm.'+side: 1}, (.375, .56)))
    for distance, pad, rx, ry, bone in ((.012, 0, .068, .054, 'Hand'), (.055, 0, .074, .044, 'Hand'),
                                       (.105, 0, .069, .042, 'Hand'), (.16, 0, .061, .022, 'Fingers'),
                                       (.185, 0, .031, .015, 'Fingers')):
        sections.append((wrist+Vector((0, pad, -distance)), rx, ry, {bone+'.'+side: 1}, (.875, .56)))
    rings = []
    for center, rx, ry, binding, _ in sections:
        ring = []
        for column in range(10):
            angle = math.tau*column/10
            ring.append(len(vertices))
            vertices.append(tuple(center+Vector((rx*math.cos(angle), ry*math.sin(angle), 0))))
            weights.append(binding.copy())
        rings.append(ring)
    thumb_columns = (4, 5) if sign > 0 else (9, 0)
    for row in range(len(rings)-1):
        for column in range(10):
            if row == 12 and column in thumb_columns:
                continue
            next_column = (column+1)%10
            faces.append((rings[row][column], rings[row][next_column], rings[row+1][next_column], rings[row+1][column]))
            uvs.append([sections[row+1][4]]*4)
    faces.extend((tuple(reversed(rings[0])), tuple(rings[-1])))
    uvs.extend(([sections[0][4]]*10, [sections[-1][4]]*10))
    first = thumb_columns[0]
    cols = [first, (first+1)%10, (first+2)%10]
    root = [rings[12][i] for i in cols]+[rings[13][i] for i in reversed(cols)]
    center = sum((Vector(vertices[i]) for i in root), Vector())/len(root)
    previous = root
    for distance, scale in ((.032, .85), (.064, .50)):
        ring = []
        for index in root:
            point = center+(Vector(vertices[index])-center)*scale+Vector((-sign*distance, -.005, -distance*.45))
            ring.append(len(vertices))
            vertices.append(tuple(point))
            weights.append({'Thumb.'+side: 1})
        for i in range(6):
            j = (i+1)%6
            faces.append((previous[i], previous[j], ring[j], ring[i]))
            uvs.append([(.875, .56)]*4)
        previous = ring
    faces.append(tuple(previous))
    uvs.append([(.875, .56)]*6)


def pose_grip(cloth, rig, frame, phases, amount=1.0):
    for side, sign in (('L', -1), ('R', 1)):
        clavicle = rig.pose.bones['Clavicle.'+side]
        rest = clavicle.bone.matrix_local.to_quaternion()
        direction = clavicle.bone.tail_local-clavicle.bone.head_local
        forward = Vector((sign*.13, -.12, -.10))
        rotation = direction.rotation_difference(forward)
        clavicle.rotation_mode = 'QUATERNION'
        clavicle.rotation_quaternion = rest.inverted()@rotation@rest
    bpy.context.view_layer.update()
    points = phase_vertices(cloth, frame, phases)
    data = cloth.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
    for side, sign in (('L', -1), ('R', 1)):
        first, second = GRIP_VERTICES[side]
        point = Vector(points[first]).lerp(Vector(points[second]), GRIP_FRACTION)
        # The palm follows the rim normal. A forward approach keeps the
        # forearm on the opening side of the cloth, away from the clasp.
        surface_normal = data.vertices[first].normal.lerp(data.vertices[second].normal, GRIP_FRACTION).normalized()
        normal = surface_normal.lerp(Vector((0, -1, .60)).normalized(), .90).normalized()
        up = Vector((0, 0, 1))
        across = up.cross(normal).normalized()
        up = normal.cross(across).normalized()
        if phases[0][1] == 'HoodLowered':
            keys = cloth.data.shape_keys.key_blocks
            low = min(1, sum(keys[name].value*weight for name, weight in
                            (('HoodLowered', 1), ('HoodSettle', 1),
                             ('HoodTurnLow', 1), ('HoodTurnHigh', .35))))
            turn = Matrix.Rotation(-sign*math.pi*low, 3, 'Y')
            normal, up = turn@normal, turn@up
            across = up.cross(normal).normalized()
        target = bpy.data.objects['Grip.'+side]
        target.location = point+normal*.10-up*.15
        target.rotation_mode = 'QUATERNION'
        target.rotation_quaternion = Matrix((across, up, normal)).transposed().to_quaternion()
        finger = rig.pose.bones['Fingers.'+side]
        finger.rotation_mode = 'XYZ'
        finger.rotation_euler.x = -.9*amount
    bpy.context.view_layer.update()
    set_elbow_planes(rig)


def set_elbow_planes(rig, preferred_width=.16):
    """Place each elbow on its IK reach circle, in front of the split."""
    for side, sign in (('L', -1), ('R', 1)):
        upper = rig.pose.bones['UpperArm.'+side]
        fore = rig.pose.bones['Forearm.'+side]
        start = upper.head
        target = bpy.data.objects['Grip.'+side].location
        delta = target-start
        distance = delta.length
        axis = delta.normalized()
        first, second = upper.bone.length, fore.bone.length
        along = (first*first-second*second+distance*distance)/(2*distance)
        center = start+axis*along
        radius = math.sqrt(max(0, first*first-along*along))
        front = Vector((0, -1, 0))
        front = (front-axis*front.dot(axis)).normalized()
        lateral = axis.cross(front).normalized()
        magnitude = math.hypot(front.x, lateral.x)
        phase = math.atan2(lateral.x, front.x)
        cosine = max(-1, min(1, (sign*preferred_width-center.x)/max(1e-8, radius*magnitude)))
        candidates = [center+radius*(front*math.cos(a)+lateral*math.sin(a))
                      for a in (phase+math.acos(cosine), phase-math.acos(cosine))]
        bpy.data.objects['ElbowPole.'+side].location = min(candidates, key=lambda p: p.z)
        fore.constraints['Wrist contact IK'].pole_angle = 0
    bpy.context.view_layer.update()
    calibrate_poles(rig)


def calibrate_poles(rig):
    """Set each mirrored IK plane from its actual solved elbow direction."""
    for side in ('L', 'R'):
        upper = rig.pose.bones['UpperArm.'+side]
        fore = rig.pose.bones['Forearm.'+side]
        axis = (fore.tail-upper.head).normalized()
        current = fore.head-upper.head
        current = (current-axis*current.dot(axis)).normalized()
        desired = bpy.data.objects['ElbowPole.'+side].location-upper.head
        desired = (desired-axis*desired.dot(axis)).normalized()
        angle = math.atan2(axis.dot(current.cross(desired)), current.dot(desired))
        fore.constraints['Wrist contact IK'].pole_angle = angle
    bpy.context.view_layer.update()


def body_bindings(points, faces):
    """Bind each retained anatomical component without changing its rest surface."""
    neighbours = [set() for _ in points]
    for face in faces:
        for index in face:
            neighbours[index].update(face)
    pending, weights = set(range(len(points))), [{} for _ in points]
    while pending:
        queue, component = [pending.pop()], []
        while queue:
            index = queue.pop()
            component.append(index)
            found = neighbours[index]&pending
            pending -= found
            queue.extend(found)
        low = min(points[index][2] for index in component)
        high = max(points[index][2] for index in component)
        for index in component:
            x, _, z = points[index]
            if low < .40:
                side = 'L' if x < 0 else 'R'
                upper = max(0, min(1, (z-.60)/.20))
                binding = {'Thigh.'+side: upper, 'Shin.'+side: 1-upper}
            elif high > 2.40:
                binding = {'Head': 1}
            elif low > 1.80:
                binding = {'Neck': 1}
            else:
                chest = max(0, min(1, (z-1.45)/.40))
                binding = {'Spine': 1-chest, 'Chest': chest}
            weights[index] = {name: weight for name, weight in binding.items() if weight > 0}
    return weights


def attach_parts(rig):
    for name, bone in (('Head', 'Head'), ('Hair', 'Head'), ('Garment', 'Chest')):
        obj = bpy.data.objects[name]
        world = obj.matrix_world.copy()
        obj.parent = rig
        obj.parent_type = 'BONE'
        obj.parent_bone = bone
        bpy.context.view_layer.update()
        obj.matrix_world = world
    boots = bpy.data.objects['Boots']
    boots.vertex_groups.clear()
    for side in ('L', 'R'):
        boots.vertex_groups.new(name='Foot.'+side)
    for vertex in boots.data.vertices:
        boots.vertex_groups['Foot.'+('L' if vertex.co.x < 0 else 'R')].add([vertex.index], 1, 'REPLACE')
    modifier = boots.modifiers.new('Foot skin', 'ARMATURE')
    modifier.object = rig
    bpy.context.view_layer.update()

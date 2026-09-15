"""Local native B-Bone trial. Run only on the isolated curved-arm copy."""
import math
import bpy
from mathutils import Matrix, Vector, Quaternion
import check_pose
import pose_tools
import grip_controls


def configure():
    assert bpy.data.filepath.endswith('/traveller_curved_arm_trial.blend')
    pose_tools.author_pose('Trial_Rest')
    body = bpy.data.objects['Body']
    rig = bpy.data.objects['TrialRig']
    for modifier in list(body.modifiers):
        if modifier.type == 'CORRECTIVE_SMOOTH':
            body.modifiers.remove(modifier)
    names = ['DEF-upper_arm.R', 'DEF-upper_arm.R.001',
             'DEF-forearm.R', 'DEF-forearm.R.001']
    for name in names:
        rig.data.bones[name].bbone_segments = 6
    for name in ('upper_arm_tweak.R.001', 'forearm_tweak.R', 'forearm_tweak.R.001'):
        rig.pose.bones[name]['rubber_tweak'] = 1.0
    deform = [g for g in body.vertex_groups if g.name.startswith('DEF-')]
    seam = check_pose.members(body, 'TrialShoulderSeam')
    for index in seam:
        for group in deform:
            group.remove([index])
        body.vertex_groups['DEF-chest'].add([index], 1.0, 'REPLACE')
    shoulder = rig.data.bones[names[0]].head_local.copy()
    elbow = rig.data.bones[names[2]].head_local.copy()
    wrist = rig.data.bones['DEF-hand.R'].head_local.copy()
    upper = elbow - shoulder
    lower = wrist - elbow
    lengths = [upper.length / 2, upper.length, upper.length + lower.length / 2]
    for index in check_pose.members(body, 'TrialSleeve') - seam:
        point = body.data.vertices[index].co
        a = max(0, min(1, (point - shoulder).dot(upper) / upper.length_squared))
        b = max(0, min(1, (point - elbow).dot(lower) / lower.length_squared))
        near_upper = (point - shoulder - a * upper).length < (point - elbow - b * lower).length
        distance = a * upper.length if near_upper else upper.length + b * lower.length
        weights = {names[sum(distance > end for end in lengths)]: 1.0}
        for i, end in enumerate(lengths):
            if abs(distance - end) < .055:
                fraction = (distance - end + .055) / .11
                weights = {names[i]: 1 - fraction, names[i + 1]: fraction}
        # The open cuff is a rigid continuation of the wrist, not the curve tip.
        hand_weight = max(0, min(1, (distance - 1.06) / .13))
        weights = {n: w * (1 - hand_weight) for n, w in weights.items()}
        weights['DEF-hand.R'] = hand_weight
        chest_weight = .70 if distance < .12 else max(0, (.30 - distance) / .35)
        weights = {n: w * (1 - chest_weight) for n, w in weights.items()}
        weights['DEF-chest'] = chest_weight
        for group in deform:
            group.remove([index])
        for name, weight in weights.items():
            if weight > 0:
                body.vertex_groups[name].add([index], weight, 'REPLACE')
    for name in ('DEF-elbow_support.R', 'ElbowSurface'):
        if body.vertex_groups.get(name):
            body.vertex_groups.remove(body.vertex_groups[name])
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    if rig.data.edit_bones.get('DEF-elbow_support.R'):
        rig.data.edit_bones.remove(rig.data.edit_bones['DEF-elbow_support.R'])
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.update_tag()
    bpy.context.view_layer.update()


def rear_controls(rig):
    """Place a circular bend and rigid finger pad on the real free hood edge."""
    bpy.data.objects['Garment'].data.shape_keys.key_blocks['RearGripClearance'].value = 1
    bpy.context.view_layer.update()
    grip_controls.pinch_thumb(rig)
    garment = bpy.data.objects['Garment'].evaluated_get(bpy.context.evaluated_depsgraph_get())
    point = garment.matrix_world @ garment.data.vertices[14].co.lerp(garment.data.vertices[13].co, .35)
    surface, _ = check_pose.surface(bpy.data.objects['Body'])
    roll = Quaternion((0, 1, 0), math.radians(70))
    pad = roll @ ((rig.matrix_world @ rig.pose.bones['DEF-hand.R'].matrix).inverted() @ surface[662])
    names = ['DEF-upper_arm.R', 'DEF-upper_arm.R.001', 'DEF-forearm.R', 'DEF-forearm.R.001']
    lengths = [rig.data.bones[n].length for n in names]
    start = rig.pose.bones['upper_arm_tweak.R'].matrix.translation.copy()
    chord = point - start
    axis = chord.normalized()
    normal = axis.cross(Vector((0, -1, 0))).normalized()
    if normal.dot(rig.data.bones[names[0]].matrix_local.to_3x3().col[0]) < 0:
        normal.negate()
    slope = pad.x / chord.length
    normal = normal * math.sqrt(1 - slope * slope) + axis * slope
    planar = chord - normal * pad.x
    axis = planar.normalized()
    cross = normal.cross(axis)
    low, high = max(lengths) / 2 + 1e-7, sum(lengths) * 100
    for _ in range(64):
        radius = (low + high) / 2
        angles = [2 * math.asin(length / (2 * radius)) for length in lengths]
        directions = [sum(angles[:i]) + angles[i] / 2 for i in range(4)]
        vector = sum(length * complex(math.cos(a), math.sin(a)) for length, a in zip(lengths, directions))
        vector += complex(pad.y, pad.z) * complex(math.cos(directions[-1]), math.sin(directions[-1]))
        if sum(angles) > 2 * math.pi or abs(vector) < planar.length:
            low = radius
        else:
            high = radius
    offset = -math.atan2(vector.imag, vector.real)
    matrices = []
    position = start.copy()
    for i, (length, angle) in enumerate(zip(lengths, directions)):
        tangent = axis * math.cos(angle + offset) + cross * math.sin(angle + offset)
        matrix = Matrix((normal, tangent, normal.cross(tangent))).transposed().to_4x4()
        matrix = matrix @ Quaternion((0, 1, 0), math.radians(70) * i / 3).to_matrix().to_4x4()
        matrix.translation = position
        matrices.append(matrix)
        position += tangent * length
    matrix = matrices[-1].copy()
    matrix.translation = position
    rig.pose.bones['hand_ik.R'].matrix = matrix
    bpy.context.view_layer.update()
    return matrices


def broad_arc(name):
    """Place existing Rigify tweaks on a single arc of fixed chord lengths."""
    pose_tools.author_pose(name)
    if name == 'Trial_Rest':
        return
    rig = bpy.data.objects['TrialRig']
    names = ['upper_arm_tweak.R', 'upper_arm_tweak.R.001', 'forearm_tweak.R',
             'forearm_tweak.R.001', 'hand_tweak.R']
    if name == 'Trial_RearPickup':
        matrices = rear_controls(rig)
        for i in (0, 2, 1, 3):
            rig.pose.bones[names[i]].matrix = matrices[i]
            bpy.context.view_layer.update()
        return
    positions = [rig.pose.bones[n].matrix.translation.copy() for n in names]
    lengths = [(b - a).length for a, b in zip(positions, positions[1:])]
    chord = positions[-1] - positions[0]
    axis = chord.normalized()
    bulge = positions[2] - positions[0]
    bulge = (bulge - axis * bulge.dot(axis)).normalized()
    normal = axis.cross(bulge).normalized()
    low, high = max(lengths) / 2, sum(lengths) * 100
    for _ in range(64):
        radius = (low + high) / 2
        angle = sum(2 * math.asin(length / (2 * radius)) for length in lengths)
        distance = 2 * radius * math.sin(angle / 2)
        if angle > 2 * math.pi or distance < chord.length:
            low = radius
        else:
            high = radius
    half = angle / 2
    theta = -half
    matrices = []
    for i, control in enumerate(names[:-1]):
        point = positions[0] + radius * (axis * (math.sin(theta) + math.sin(half))
                                        + bulge * (math.cos(theta) - math.cos(half)))
        tangent = axis * math.cos(theta) - bulge * math.sin(theta)
        matrix = Matrix((normal, tangent, normal.cross(tangent))).transposed().to_4x4()
        matrix.translation = point
        matrices.append(matrix)
        theta += 2 * math.asin(lengths[i] / (2 * radius))
    # Intermediate controls inherit the two end tweaks; set their parents first.
    for i in (0, 2, 1, 3):
        rig.pose.bones[names[i]].matrix = matrices[i]
        bpy.context.view_layer.update()
    rig.update_tag()
    bpy.context.view_layer.update()


if __name__ == '__main__':
    configure()

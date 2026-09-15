"""Native thumb pose and a local active-pickup cloth shape."""
import math
import bpy
from mathutils import Vector
import check_pose


def add_clearance():
    assert bpy.data.filepath.endswith('/traveller_curved_arm_trial.blend')
    garment = bpy.data.objects['Garment']
    keys = garment.data.shape_keys.key_blocks
    key = keys.get('RearGripClearance') or garment.shape_key_add(name='RearGripClearance')
    basis = keys['Basis']
    for vertex, original in zip(key.data, basis.data):
        vertex.co = original.co
    affected = []
    for row in range(4):
        depth = (1 - row / 4)**2
        for column in range(11, 18):
            across = max(0, math.cos(min(1, abs(column - 13.65) / 3.5) * math.pi / 2))**2
            delta = Vector((.070, .006, .010)) * depth * across
            for index in (row * 21 + column, 833 + row * 21 + column):
                key.data[index].co += delta
                if delta.length > 1e-7:
                    affected.append(index)
    garment['rear_grip_edge'] = [14, 13]
    garment['rear_grip_fraction'] = .35
    garment['rear_grip_affected_vertices'] = affected
    return len(affected)


def pinch_thumb(rig):
    hand = rig.pose.bones['DEF-hand.R'].matrix.copy()
    rest = rig.data.bones['DEF-hand.R'].matrix_local.to_3x3()
    width = rest.inverted() @ Vector((1, 0, 0))
    palm_normal = rest.inverted() @ Vector((0, 1, 0))
    # Oppose the curled distal finger pad without changing either digit's length.
    target = hand @ (width * -.055 + Vector((0, .130, 0)) - palm_normal * .012)
    first = rig.pose.bones['thumb.01.R']
    second = rig.pose.bones['thumb.02.R']
    root = first.matrix.translation.copy()
    chord = target - root
    axis = chord.normalized()
    a, b = first.bone.length, second.bone.length
    assert abs(a - b) < chord.length < a + b, 'Thumb target is outside its fixed reach'
    along = (a*a - b*b + chord.length_squared) / (2 * chord.length)
    outward = -(hand.to_3x3() @ width)
    outward = (outward - axis * outward.dot(axis)).normalized()
    middle = root + axis * along + outward * math.sqrt(a*a - along*along)
    for control, position, end in ((first, root, middle), (second, middle, target)):
        rotation = control.matrix.to_3x3().col[1].rotation_difference((end-position).normalized()) @ control.matrix.to_quaternion()
        matrix = rotation.to_matrix().to_4x4()
        matrix.translation = position
        control.matrix = matrix
        bpy.context.view_layer.update()

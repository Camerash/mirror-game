"""Author her actions in girl.blend: Idle, Walk, Wake, Lift, Raise, Lower, Wave.

    blender -b art_sources/girl/girl.blend --python art_sources/girl/animate.py

Each action is a function of time. Every frame (60 fps) is solved and keyed:
torso and head by rotations, legs and reaching arms by two-bone IK, so planted
feet stay planted and the walk's stance foot moves back at exactly the ground
speed. Re-running replaces these seven actions; nothing else is touched.

Rotations are written in armature axes relative to the parent (X pitch: on an
upright bone + leans forward, on a hanging limb + swings back; Y roll: + tips
the top of an upright bone towards +X, her left; Z yaw: + turns her face to
her left). Her front is -Y, her left is +X.
"""
import math

import bpy
from mathutils import Euler, Quaternion, Vector
from mathutils.bvhtree import BVHTree

FPS = 60
WALK_SPEED = 1.1            # ground speed the Walk is authored for, units/s
WALK_FRAMES = 26            # one cycle: 0.433 s, two steps (4.6 steps/s)
STRIDE = WALK_SPEED * WALK_FRAMES / FPS / 2   # one step = stance travel, 0.238
ANKLE_Z = 0.045
FOOT_X = 0.040

rig = bpy.data.objects['Girl']
REST = {}
for b in rig.data.bones:
    REST[b.name] = (b.head_local.copy(), b.tail_local.copy(),
                    b.matrix_local.to_3x3().to_quaternion(),
                    b.parent.name if b.parent else None)
ORDER = [b.name for b in rig.data.bones]
I = Quaternion()


def E(x=0.0, y=0.0, z=0.0):
    return Euler((math.radians(x), math.radians(y), math.radians(z)), 'XYZ').to_quaternion()


def smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def rest_dir(b):
    return (REST[b][1] - REST[b][0]).normalized()


def length(b):
    return (REST[b][1] - REST[b][0]).length


def two_bone(root, l1, l2, target, pole):
    d = target - root
    dist = d.length
    reach = dist / (l1 + l2)
    dist = min(dist, (l1 + l2) * 0.9995)
    dn = d.normalized()
    cos_a = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    a = math.acos(max(-1.0, min(1.0, cos_a)))
    p = (pole - dn * pole.dot(dn)).normalized()
    return root + l1 * (math.cos(a) * dn + math.sin(a) * p), reach


def aim(parent_world, bone, head, point):
    cur = parent_world @ rest_dir(bone)
    new = (point - head).normalized()
    return cur.rotation_difference(new) @ parent_world


def solve(spec):
    """spec: loc (hips offset), rel {bone: quat}, legs/arms {side: dict}.
    A limb dict has 'target' (ankle or wrist point), 'pole', and either 'quat'
    (end bone world rotation) or 'dir' (end bone direction)."""
    loc = spec.get('loc', Vector())
    rel = spec.get('rel', {})
    limbs = {}
    for side, d in spec.get('legs', {}).items():
        limbs['UpperLeg.' + side] = ('LowerLeg.' + side, 'Foot.' + side, d)
    for side, d in spec.get('arms', {}).items():
        limbs['UpperArm.' + side] = ('LowerArm.' + side, 'Hand.' + side, d)
    world, heads, out_rel, reach = {}, {}, {}, {}
    aim_at, end_spec = {}, {}
    for b in ORDER:
        h, _, _, par = REST[b]
        if par is None:
            world[b] = rel.get(b, I)
            heads[b] = h.copy()
            out_rel[b] = world[b]
            continue
        pw = world[par]
        heads[b] = heads[par] + pw @ (h - REST[par][0])
        if b == 'Hips':
            heads[b] = heads[b] + loc
        if b in limbs:
            lower, end, d = limbs[b]
            mid, r = two_bone(heads[b], length(b), length(lower), d['target'], d['pole'])
            reach[b] = r
            world[b] = aim(pw, b, heads[b], mid)
            aim_at[lower] = d['target']
            end_spec[end] = d
        elif b in aim_at:
            world[b] = aim(pw, b, heads[b], aim_at[b])
        elif b in end_spec and 'quat' in end_spec[b]:
            world[b] = end_spec[b]['quat']
        elif b in end_spec and 'dir' in end_spec[b]:
            world[b] = aim(pw @ rel.get(b, I), b, heads[b], heads[b] + end_spec[b]['dir'])
        else:
            world[b] = pw @ rel.get(b, I)
        out_rel[b] = pw.inverted() @ world[b]
    return {'rel': out_rel, 'loc': loc.copy(), 'heads': heads, 'world': world, 'reach': reach}


def blend(a, b, u):
    rel = {k: a['rel'][k].slerp(b['rel'][k], u) for k in a['rel']}
    return {'rel': rel, 'loc': a['loc'].lerp(b['loc'], u)}


def planted(side, quat=None):
    s = 1 if side == 'L' else -1
    return {'target': Vector((s * FOOT_X, 0.004, ANKLE_Z)), 'pole': Vector((0, -1, 0)),
            'quat': quat or I}


def with_feet(pose):
    """Re-solve the legs of a (blended) pose with both feet planted at rest."""
    rel = {k: v for k, v in pose['rel'].items() if not k.startswith(('UpperLeg', 'LowerLeg', 'Foot'))}
    return solve({'loc': pose['loc'], 'rel': rel, 'legs': {'L': planted('L'), 'R': planted('R')}})


# --------------------------------------------------------------------------
# Idle: 3 s loop, two soft breaths and a slow head tilt.
IDLE_FRAMES = 180


def idle(t):
    b = math.sin(math.tau * t / 1.5)
    w = math.tau * t / 3.0
    tilt = 3.5 * math.sin(w)
    rel = {
        'Spine': E(0.4 * b), 'Chest': E(-0.8 * b),
        'Neck': E(0.3 * b, 0.4 * tilt, 0.5 * 4 * math.sin(w + 1.0)),
        'Head': E(0.5 * b, tilt, 4 * math.sin(w + 1.0)),
        'Hair': E(0, -0.5 * math.sin(w - 0.8)),
        'Pompom': E(-1.5 * b, -2.5 * math.sin(w - 1.2)),
        'UpperArm.L': E(2 + 0.6 * b, 0.5 * b), 'UpperArm.R': E(2 + 0.6 * b, -0.5 * b),
        'LowerArm.L': E(-9), 'LowerArm.R': E(-9),
        'Hand.L': E(-6), 'Hand.R': E(-6),
    }
    return solve({'loc': Vector((0.0015 * math.sin(w), 0, -0.004 + 0.0015 * b)), 'rel': rel,
                  'legs': {'L': planted('L'), 'R': planted('R')}})


# --------------------------------------------------------------------------
# Walk: a careful child's walk in snow on bent knees, 0.433 s a cycle.

def walk_foot(ph, side):
    s = 1 if side == 'L' else -1
    if ph < 0.5:                                  # stance: moves back at ground speed
        y = -STRIDE / 2 + STRIDE * (ph / 0.5)
        z, pitch = ANKLE_Z, 0.0
    else:                                         # swing: lifted clear of the snow
        u = (ph - 0.5) / 0.5
        e = u * u * (3 - 2 * u)
        y = STRIDE / 2 - STRIDE * e
        z = ANKLE_Z + 0.032 * math.sin(math.pi * u) ** 1.2
        pitch = 22 * math.sin(math.pi * u) * (0.45 - u) * 2
    return {'target': Vector((s * FOOT_X, 0.004 + y, z)), 'pole': Vector((0, -1, 0)),
            'quat': E(pitch)}


def walk(t):
    ph = (t * FPS / WALK_FRAMES) % 1.0
    a = math.tau * ph
    side_sway = math.sin(a)                      # + over the left foot
    bob = math.sin(a) ** 2                       # high at mid-stance
    rel = {
        'Hips': E(3, 2.0 * side_sway, -4 * math.cos(a)),
        'Spine': E(2, -1.0 * side_sway, 2.5 * math.cos(a)),
        'Chest': E(1, -0.8 * side_sway, 1.5 * math.cos(a)),
        'Neck': E(-2, -0.3 * side_sway),
        'Head': E(-3 + 1.5 * math.cos(2 * a), -0.6 * side_sway),
        'Hair': E(2 * math.sin(2 * a - 1.0), -1.5 * math.sin(a - 0.7)),
        'Pompom': E(5 * math.sin(2 * a - 1.2), -3 * math.sin(a - 1.0)),
        'UpperArm.L': E(6 * math.cos(a) - 2), 'UpperArm.R': E(-6 * math.cos(a) - 2),
        'LowerArm.L': E(-14 + 4 * math.cos(a)), 'LowerArm.R': E(-14 - 4 * math.cos(a)),
        'Hand.L': E(-8), 'Hand.R': E(-8),
    }
    loc = Vector((0.006 * side_sway, 0.0, -0.038 + 0.008 * bob))
    return solve({'loc': loc, 'rel': rel,
                  'legs': {'L': walk_foot(ph, 'L'), 'R': walk_foot((ph + 0.5) % 1.0, 'R')}})


# --------------------------------------------------------------------------
# Raise / Lower: her LEFT hand holds a hand mirror up in front of her.
RAISE_FRAMES, LOWER_FRAMES = 36, 24


def raise_pose(u):
    base = idle(0)
    wrist0 = base['heads']['Hand.L']
    target = wrist0.lerp(Vector((0.070, -0.185, 0.395)), u)
    rel = dict(idle(0)['rel'])
    rel.update({'Chest': E(-2 * u, 0, 3 * u), 'Neck': E(-1 * u, 0, 3 * u),
                'Head': E(1 * u, 2 * u, 6 * u)})
    arm = {'target': target, 'pole': Vector((0.6, 0.6, -0.5)),
           'dir': rest_dir('Hand.L').lerp(Vector((-0.05, -0.15, 1.0)).normalized(), u).normalized()}
    return solve({'loc': Vector((-0.004 * u, 0, -0.004)), 'rel': rel,
                  'legs': {'L': planted('L'), 'R': planted('R')}, 'arms': {'L': arm}})


def raise_(t):
    f = t * FPS
    return raise_pose(smooth(0, 30, f))


def lower(t):
    u = smooth(0, LOWER_FRAMES, t * FPS)
    return with_feet(blend(raise_pose(1.0), idle(0), u))


# --------------------------------------------------------------------------
# Lift: bend, pick something small up with the LEFT mitten, look at it.
LIFT_FRAMES = 72
LIFT_GROUND = Vector((0.085, -0.100, 0.065))      # wrist, just above the snow
LIFT_HOLD = Vector((0.040, -0.120, 0.400))        # wrist, at chest height


def lift(t):
    f = t * FPS
    down = smooth(0, 30, f) * (1 - smooth(38, 64, f))
    up = smooth(40, 68, f)
    rel = dict(idle(0)['rel'])
    rel.update({
        'Hips': E(20 * down), 'Spine': E(20 * down), 'Chest': E(12 * down, 0, 4 * down),
        'Neck': E(-8 * down + 6 * up, 0, 4 * up), 'Head': E(-10 * down + 10 * up, 3 * up, 6 * up),
        'UpperArm.R': E(-14 * down, 4 * down), 'LowerArm.R': E(-20 * down - 9),
    })
    wrist0 = idle(0)['heads']['Hand.L']
    if f < 38:
        target = wrist0.lerp(LIFT_GROUND, smooth(4, 30, f))
        hdir = rest_dir('Hand.L').lerp(Vector((0, -0.35, -1)).normalized(), smooth(4, 30, f))
    else:
        target = LIFT_GROUND.lerp(LIFT_HOLD, smooth(38, 68, f))
        hdir = Vector((0, -0.35, -1)).normalized().lerp(Vector((-0.2, -0.4, 1)).normalized(), smooth(40, 64, f))
    arm = {'target': target, 'pole': Vector((0.5, 0.8, -0.2)), 'dir': hdir.normalized()}
    loc = Vector((0.0, 0.035 * down, -0.004 - 0.150 * down))
    return solve({'loc': loc, 'rel': rel, 'legs': {'L': planted('L'), 'R': planted('R')},
                  'arms': {'L': arm}})


# --------------------------------------------------------------------------
# Wave: her LEFT hand, about two and a half waves, back to Idle.
WAVE_FRAMES = 90


def wave(t):
    f = t * FPS
    up = smooth(0, 18, f) * (1 - smooth(70, 90, f))
    wag = math.sin(math.tau * (f - 18) / 22) * smooth(14, 24, f) * (1 - smooth(64, 74, f))
    pose = idle(t)
    rel = dict(pose['rel'])
    rel.update({
        'UpperArm.L': E(-18 * up, -80 * up), 'LowerArm.L': E(-10 * up, -42 * up + 16 * wag),
        'Hand.L': E(0, -6 * up + 10 * wag),
        'Chest': E(0, -2 * up), 'Head': pose['rel']['Head'] @ E(0, 4 * up, 6 * up),
    })
    return solve({'loc': pose['loc'] + Vector((-0.003 * up, 0, 0)), 'rel': rel,
                  'legs': {'L': planted('L'), 'R': planted('R')}})


# --------------------------------------------------------------------------
# Wake: lying on her right side in the snow, sits up, crouches, stands.
WAKE_FRAMES = 150


def wake_keys():
    lying = solve({'loc': Vector((0.12, 0.0, -0.15)), 'rel': {
        'Hips': E(0, -90), 'Spine': E(12), 'Chest': E(8), 'Neck': E(6, 6), 'Head': E(6, 8),
        'UpperLeg.L': E(-38, -4), 'UpperLeg.R': E(-30, 4), 'LowerLeg.L': E(58), 'LowerLeg.R': E(50),
        'Foot.L': E(-8), 'Foot.R': E(-8),
        'UpperArm.R': E(-80, -12), 'LowerArm.R': E(-35), 'Hand.R': E(-10),
        'UpperArm.L': E(-28, 12), 'LowerArm.L': E(-30), 'Hand.L': E(-10),
        'Hair': E(0, 8), 'Pompom': E(0, 10)}})
    propped = solve({'loc': Vector((0.05, 0.02, -0.17)), 'rel': {
        'Hips': E(-10, -35, 8), 'Spine': E(8, 8), 'Chest': E(6, 6), 'Neck': E(4, 4), 'Head': E(8, 4),
        'UpperLeg.L': E(-70, -10), 'UpperLeg.R': E(-60, 6), 'LowerLeg.L': E(115), 'LowerLeg.R': E(110),
        'Foot.L': E(-30), 'Foot.R': E(-30),
        'UpperArm.R': E(-20, 30), 'LowerArm.R': E(-10), 'Hand.R': E(-50),
        'UpperArm.L': E(-35, 0), 'LowerArm.L': E(-40), 'Hand.L': E(-10)}})
    squat_rel = dict(idle(0)['rel'])
    squat_rel.update({'Hips': E(18), 'Spine': E(14), 'Chest': E(6), 'Neck': E(-8), 'Head': E(-6),
                      'UpperArm.L': E(-30, -4), 'UpperArm.R': E(-30, 4),
                      'LowerArm.L': E(-25), 'LowerArm.R': E(-25)})
    squat = solve({'loc': Vector((0, 0.035, -0.130)), 'rel': squat_rel,
                   'legs': {'L': planted('L'), 'R': planted('R')}})
    return lying, propped, squat


def wake(t, keys):
    lying, propped, squat = keys
    f = t * FPS
    breath = math.sin(math.tau * t / 1.6)
    if f <= 34:
        pose = {'rel': dict(lying['rel']), 'loc': lying['loc'].copy()}
        pose['rel']['Chest'] = lying['rel']['Chest'] @ E(-1.0 * breath)
        return pose
    if f <= 66:
        return blend(lying, propped, smooth(34, 66, f))
    if f <= 92:
        return blend(propped, squat, smooth(66, 92, f))
    if f <= 102:
        return with_feet(blend(squat, squat, 0))
    stand = idle(0)
    return with_feet(blend(squat, stand, smooth(102, WAKE_FRAMES, f)))


# --------------------------------------------------------------------------
# Keying.

def apply_pose(pose):
    for b, rel in pose['rel'].items():
        pb = rig.pose.bones[b]
        qr = REST[b][2]
        pb.rotation_quaternion = qr.inverted() @ rel @ qr
    hips = rig.pose.bones['Hips']
    hips.location = REST['Hips'][2].inverted() @ pose['loc']


def lowest_point(dg):
    low = 1e9
    for obj in bpy.data.collections['Girl'].objects:
        if obj.type != 'MESH':
            continue
        ev = obj.evaluated_get(dg)
        me = ev.to_mesh()
        m = ev.matrix_world
        low = min(low, min((m @ v.co).z for v in me.vertices))
        ev.to_mesh_clear()
    return low


def key_action(name, frames, fn, ground=None, loop=False):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    prev = {}
    worst_reach, lowest = 0.0, 1e9
    for f in range(frames + 1):
        t = (f % frames if loop else f) / FPS
        pose = fn(t)
        if 'reach' in pose and pose['reach']:
            worst_reach = max(worst_reach, max(pose['reach'].values()))
        apply_pose(pose)
        if ground and ground(f):
            bpy.context.view_layer.update()
            low = lowest_point(bpy.context.evaluated_depsgraph_get())
            # On the floor she rests on the snow: lowest point exactly at 0.001.
            pose['loc'] = pose['loc'] + Vector((0, 0, 0.001 - low))
            apply_pose(pose)
        for pb in rig.pose.bones:
            q = pb.rotation_quaternion.copy()
            if pb.name in prev and prev[pb.name].dot(q) < 0:
                q.negate()
                pb.rotation_quaternion = q
            prev[pb.name] = q
            pb.keyframe_insert('rotation_quaternion', frame=f, group=pb.name)
            if pb.name == 'Hips':
                pb.keyframe_insert('location', frame=f, group=pb.name)
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for kp in fc.keyframe_points:
                        kp.interpolation = 'LINEAR'
    act.use_frame_range = True
    act.frame_start, act.frame_end = 0, frames
    print('### %-6s %3d frames (%.2f s)  worst limb reach %.3f' % (name, frames, frames / FPS, worst_reach))
    return act


def reset():
    for pb in rig.pose.bones:
        pb.rotation_quaternion = I
        pb.location = Vector()


def main():
    scene = bpy.context.scene
    scene.render.fps = FPS
    keys = wake_keys()
    key_action('Idle', IDLE_FRAMES, idle, loop=True)
    key_action('Walk', WALK_FRAMES, walk, loop=True)
    key_action('Wake', WAKE_FRAMES, lambda t: wake(t, keys), ground=lambda f: f <= 92)
    key_action('Lift', LIFT_FRAMES, lift)
    key_action('Raise', RAISE_FRAMES, raise_)
    key_action('Lower', LOWER_FRAMES, lower)
    key_action('Wave', WAVE_FRAMES, wave)
    rig.animation_data.action = None
    reset()
    bpy.ops.wm.save_mainfile()
    print('### actions saved')


if __name__ == '__main__':
    main()

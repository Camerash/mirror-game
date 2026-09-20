"""Author the clips on the single source: the two hood actions and the walk.

The clips this replaces were inherited and had stopped meaning anything: 2.0 s
against a viewer that expects 1.0 s, keys on twelve bones of which two no longer
exist, `location` keyed on a skinned chain, and not one channel on the hood they
are named after.

The arm is posed as a circular arc, not by inverse kinematics.
`build_traveller.extend_rig` gives each arm four deform segments and aligns all
four rolls to one axis, because bendy bones do not survive glTF export and the
curve has to come from real joints. Turn all four by the same angle and the chain
*is* an arc, so its chord length falls monotonically with that angle and one
bisection finds it. Aim the chord at the wrist target afterwards. "No visible
elbow" then holds by construction instead of by tuning, and there is nothing to
solve iteratively and nothing to converge.

The idle pose comes out of the same solver. `pose_idle` drops the straight arm by
78 degrees about Y, which is a chord at full reach, so the solver returns a turn
of zero and the identical pose. One posing path, no seam at the ends of a clip.
"""
import math

import bpy
from mathutils import Matrix, Vector

import hood_motion as motion
import walk_motion as walk

ARM = ['UpperArm.%s', 'UpperArm.%s.001', 'Forearm.%s', 'Forearm.%s.001']
WRIST = ['Hand.%s', 'Fingers.%s']
BODY = {'Chest': motion.CHEST_TILT, 'Head': motion.HEAD_TILT}
CLIPS = {'HoodDown': (motion.DOWN_PHASES, motion.DOWN_WRIST),
         'HoodUp': (motion.UP_PHASES, motion.UP_WRIST)}


def chain(rig, side):
    """Each arm bone's rest head, direction and length, in armature space."""
    out = []
    for template in ARM + WRIST:
        bone = rig.data.bones[template % side]
        out.append((bone.name, bone.head_local.copy(),
                    (bone.tail_local - bone.head_local).normalized(), bone.length))
    return out


def arc_chord(lengths, turn):
    """Where a chain of these lengths ends when every joint turns by `turn`.

    Returned in the arc's own plane, with the first segment along x.
    """
    point = Vector((0, 0, 0))
    for index, length in enumerate(lengths):
        point += length * Vector((math.cos(index * turn), math.sin(index * turn), 0))
    return point


def arc_turn(lengths, span):
    """The per-joint turn whose chord is `span` long.

    The chord shrinks from the chain's full length at zero turn, so a bisection
    is enough and always converges. A target further away than the arm can reach
    comes back straight rather than stretched.

    The bound is a quarter turn at every joint. Past about a third of the arm's
    reach the arc has to coil rather than bend, which is not an arm any more, so
    a path that asks for that is a fault in the path and shows up as an error.
    """
    if span >= sum(lengths):
        return 0.0
    low, high = 0.0, math.pi / 2
    for _ in range(60):
        middle = (low + high) / 2
        if arc_chord(lengths, middle).length > span:
            low = middle
        else:
            high = middle
    return (low + high) / 2


def arc_directions(lengths, span, aim, bulge):
    """Unit directions for every segment of the arc that reaches `span` along `aim`.

    The arc is planar. Its plane holds the aim and the bulge, and the sign of the
    turn decides which side of the chord the elbow stands on, so both are tried
    and the one that lifts the elbow toward the bulge is kept.
    """
    across = bulge - aim * bulge.dot(aim)
    if across.length < 1e-6:
        across = aim.cross(Vector((0, 0, 1)))
    across.normalize()
    turn = arc_turn(lengths, min(span, sum(lengths)))
    best = None
    for sign in (1, -1):
        angles = [sign * index * turn for index in range(len(lengths))]
        chord = arc_chord(lengths, sign * turn)
        lead = -math.atan2(chord.y, chord.x)
        directions = [aim * math.cos(lead + a) + across * math.sin(lead + a)
                      for a in angles]
        elbow = sum((lengths[i] * directions[i] for i in range(2)), Vector())
        score = elbow.dot(across)
        if best is None or score > best[0]:
            best = (score, directions, sign * turn)
    return best[1], best[2]


def pose_arm(rig, side, target):
    """Put the wrist on `target`, with the arm curved along one arc.

    Returns how far the wrist actually landed from the target, so a path that
    asks for more than the arm has shows up as a number rather than as a stretch.
    """
    bones = chain(rig, side)
    lengths = [length for _, _, _, length in bones[:len(ARM)]]
    shoulder = bones[0][1]
    span = (target - shoulder).length
    aim = (target - shoulder).normalized()
    bulge = Vector((motion.BULGE.x * (1 if side == 'R' else -1),
                    motion.BULGE.y, motion.BULGE.z)).normalized()
    directions, turn = arc_directions(lengths, span, aim, bulge)
    # The hand and the fingers carry the curve on, so the palm follows the arm
    # instead of hinging off the end of it.
    across = bulge - aim * bulge.dot(aim)
    across = across.normalized() if across.length > 1e-6 else aim.cross(Vector((0, 0, 1)))
    lead = math.atan2(directions[0].dot(across), directions[0].dot(aim))
    for step in range(len(WRIST)):
        angle = lead + (len(ARM) + step) * turn
        directions.append(aim * math.cos(angle) + across * math.sin(angle))
    head = shoulder.copy()
    for index, (name, rest_head, rest_dir, length) in enumerate(bones):
        rotation = rest_dir.rotation_difference(directions[index])
        turn_matrix = (Matrix.Translation(head)
                       @ rotation.to_matrix().to_4x4()
                       @ Matrix.Translation(-rest_head))
        rig.pose.bones[name].matrix = turn_matrix @ rig.data.bones[name].matrix_local
        bpy.context.view_layer.update()
        head = head + directions[index] * length
    wrist = rig.pose.bones[WRIST[0] % side].head
    return (wrist - target).length


def idle_wrist(rig, side):
    """Where the wrist rests. Read off the rig, not written down twice."""
    sign = 1 if side == 'R' else -1
    bones = chain(rig, side)
    shoulder = bones[0][1]
    reach = sum(length for _, _, _, length in bones[:len(ARM)])
    drop = Matrix.Rotation(math.radians(motion.IDLE_ARM_ANGLE * sign), 3, 'Y')
    return shoulder + (drop @ bones[0][2]) * reach


def clear_pose(rig):
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def pose_frame(rig, path, frame, rests):
    """The whole upper body at one frame. Returns the worst wrist error."""
    clear_pose(rig)
    for name, keys in BODY.items():
        angle = motion.tilt(keys, frame)
        rig.pose.bones[name].rotation_quaternion = Matrix.Rotation(
            angle, 3, 'X').to_quaternion()
    bpy.context.view_layer.update()
    worst = 0.0
    # The path is written for the right hand only, so the left is its mirror.
    # It has to be mirrored whole: feeding the left rest point into a right-hand
    # path and flipping the result afterwards crosses the two and puts the left
    # wrist where the right one belongs.
    target = motion.wrist(path, frame, rests['R'])
    for side in ('R', 'L'):
        here = target if side == 'R' else Vector((-target.x, target.y, target.z))
        worst = max(worst, pose_arm(rig, side, here))
    return worst


# The axes a walk turns about, in world terms. The character faces -y, so a leg
# swings about world x and the body twists about world z.
SIDEWAYS = Vector((1, 0, 0))
UPRIGHT = Vector((0, 0, 1))
FORWARD = Vector((0, -1, 0))
LEGS = ['Thigh.%s', 'Shin.%s', 'Foot.%s']
WALK_BONES = ['Pelvis', 'Chest', 'Head'] + [t % s for s in ('L', 'R')
                                            for t in LEGS + ['UpperArm.%s']]


def local_axis(rig, name, world_axis):
    """`world_axis` written in this bone's own rest space.

    A pose rotation is read in the bone's space, and these bones do not share an
    orientation: the spine points up, a thigh points down, an arm points out. So
    the axis is converted rather than named, and 'twist about z' means the same
    thing on every one of them. Converting from the rest matrix is right for a
    chain as well: once a parent turns, the child's axes turn with it, which is
    what makes a knee bend against its own thigh.
    """
    matrix = rig.data.bones[name].matrix_local.to_3x3().inverted()
    return (matrix @ world_axis).normalized()


def turn(rig, name, angle, world_axis):
    """Turn one bone about a world axis, replacing any turn it already has."""
    rig.pose.bones[name].rotation_quaternion = Matrix.Rotation(
        angle, 3, local_axis(rig, name, world_axis)).to_quaternion()


def pose_idle_arms(rig):
    """The resting arms, as a body-relative pose.

    `idle_wrist` gives the same pose as a world point, which is right for the
    hood clips because they aim the arm at world targets. It is wrong here: the
    pelvis moves under the walk, and an arm aimed at a fixed world point would
    counter-move against its own body. A straight arm dropped by the idle angle
    is a chord at full reach, so the solver's answer for it is a turn of zero on
    every joint, which is one rotation on `UpperArm` and nothing below it.
    """
    for side in ('L', 'R'):
        sign = 1 if side == 'R' else -1
        turn(rig, 'UpperArm.' + side,
             math.radians(motion.IDLE_ARM_ANGLE * sign), Vector((0, 1, 0)))


def pose_walk(rig, frame):
    """The whole body at one frame of the walk."""
    clear_pose(rig)
    pelvis = rig.pose.bones['Pelvis']
    # Two turns on one bone, so they are composed rather than assigned.
    twist = Matrix.Rotation(walk.tilt(walk.PELVIS_TWIST, frame), 3,
                            local_axis(rig, 'Pelvis', UPRIGHT)).to_quaternion()
    lean = Matrix.Rotation(walk.tilt(walk.PELVIS_SIDE, frame), 3,
                           local_axis(rig, 'Pelvis', FORWARD)).to_quaternion()
    pelvis.rotation_quaternion = twist @ lean
    pelvis.location = local_axis(rig, 'Pelvis', UPRIGHT) * walk.at(
        walk.PELVIS_RISE, frame)
    turn(rig, 'Chest', walk.tilt(walk.CHEST_TWIST, frame), UPRIGHT)
    turn(rig, 'Head', walk.tilt(walk.HEAD_TWIST, frame), UPRIGHT)
    for side in ('L', 'R'):
        for template, angle in zip(LEGS, walk.leg(frame, side)):
            turn(rig, template % side, math.radians(angle), SIDEWAYS)
    pose_idle_arms(rig)
    bpy.context.view_layer.update()


def build_walk(rig):
    """One looping walk cycle, as a bone action under its own NLA track.

    Bones only. The three cloak deformations the design asks for are driven at
    runtime from movement and turning, not keyed here, so that they can be
    damped and clamped against what the character is actually doing.
    """
    action = action_for(rig, 'Walk.Rig')
    for frame in range(walk.LAST + 1):
        pose_walk(rig, frame)
        for name in WALK_BONES:
            rig.pose.bones[name].keyframe_insert('rotation_quaternion', frame=frame)
        rig.pose.bones['Pelvis'].keyframe_insert('location', frame=frame)
    linear(action)
    track(rig, action, 'Walk')
    clear_pose(rig)
    return walk.LAST / walk.FPS


def action_for(owner, name):
    """A fresh action on this owner, replacing any inherited one of that name."""
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    if not owner.animation_data:
        owner.animation_data_create()
    owner.animation_data.action = action
    return action


def linear(action):
    """glTF carries linear keys only, so author them that way."""
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'LINEAR'


def track(owner, action, name):
    """One muted NLA track per clip, which is what the export merges on."""
    owner.animation_data.action = None
    for existing in list(owner.animation_data.nla_tracks):
        if existing.name == name:
            owner.animation_data.nla_tracks.remove(existing)
    strip_track = owner.animation_data.nla_tracks.new()
    strip_track.name = name
    strip_track.strips.new(name, 0, action)
    strip_track.mute = True


def build(rig, garment):
    """Both clips, as bone and shape key tracks under one NLA name each."""
    keys = garment.data.shape_keys
    blocks = keys.key_blocks
    rests = {'R': idle_wrist(rig, 'R')}
    report = {}
    for name, (phases, path) in CLIPS.items():
        bone_action = action_for(rig, name + '.Rig')
        shape_action = action_for(keys, name + '.Garment')
        worst = 0.0
        for frame in range(motion.LAST + 1):
            worst = max(worst, pose_frame(rig, path, frame, rests))
            for side in ('R', 'L'):
                for template in ARM + WRIST:
                    rig.pose.bones[template % side].keyframe_insert(
                        'rotation_quaternion', frame=frame)
            for bone in BODY:
                rig.pose.bones[bone].keyframe_insert('rotation_quaternion', frame=frame)
            weights = motion.phase_weights(phases, frame)
            weights['CloakOpen'] = motion.at(motion.OPEN, frame)
            weights['CloakArms'] = motion.at(motion.ARMS, frame)
            for block in blocks[1:]:
                block.value = weights.get(block.name, 0.0)
                block.keyframe_insert('value', frame=frame)
        linear(bone_action)
        linear(shape_action)
        track(rig, bone_action, name)
        track(keys, shape_action, name)
        report[name] = round(worst, 4)
    clear_pose(rig)
    for block in blocks[1:]:
        block.value = 0.0
    return report

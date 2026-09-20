"""The walk cycle, as data.

The same 0 to 60 frame space at 60 fps that the hood clips use, so one second is
one full cycle: two steps, with the right foot landing at frame 0 and the left
at frame 30. Frame 60 repeats frame 0, so the clip loops without a seam.

`GAME_DESIGN.md` line 102 asks for a restrained gait, shoulders pinned, sway
under 0.032 units and twist under 6 degrees, with three authored cloak
deformations damped at runtime. Line 100 adds small steps and no arm swing.

Two measurements shape the numbers below.

**Only `Pelvis` reaches the hem.** Turning `Spine` or `Chest` moves the cloak's
waist and chest and leaves the hem and the knee at exactly 0.0000, because
`skin_body.cloak` clamps those bands to `Pelvis`. So the gait's hem motion is
the pelvis channels here and nothing else.

**The skin already over-drives the hem.** Two degrees of pelvis lean moves the
hem 0.0291, which is nearly the whole 0.032 budget, and two degrees of pelvis
twist moves it 0.0417, which is over. That is why the pelvis angles here are
near one degree rather than the three or four a walk usually carries. The cloak
gets its travel from the damped morphs instead, where it can be clamped and can
lag, which a rigid skin rotation cannot do.

Angles are degrees. About X, a positive turn swings a downward bone's tail to
+y, and the front of the character is -y, so **positive X is backward**: a leg
swings forward on a negative angle and a knee bends on a positive one.
"""
import hood_motion as motion

FPS = 60
LAST = 60                       # one full cycle, so exactly one second
HALF = 30                       # the other leg runs half a cycle behind

# The right thigh, through one cycle. Contact at 0 with the leg forward, the
# body passing over the foot to toe-off at 30, then the swing back to contact.
THIGH = ((0, -13.0), (15, -1.0), (30, 11.0), (40, 5.0), (50, -9.0), (60, -13.0))

# The knee. It stays nearly straight through stance and folds through the swing,
# which is what keeps the foot off the ground without lifting the whole leg.
SHIN = ((0, 3.0), (12, 10.0), (30, 8.0), (40, 32.0), (52, 10.0), (60, 3.0))

# The foot is not authored as an angle. There is no toe bone, so the foot is a
# stub, and an authored angle drifts out of step with the two above it as soon
# as either changes. The generator holds it level against the thigh and the
# knee instead, and this table is only the lift on top of that: toe up as the
# foot leaves the ground, flat again before it lands.
FOOT_LIFT = ((0, 0.0), (12, -4.0), (30, 6.0), (42, 8.0), (54, 2.0), (60, 0.0))

# The pelvis. Rise is metres, not degrees: it lifts at each mid-stance, so twice
# per cycle, and sits lowest at the two contacts where both feet are down.
PELVIS_RISE = ((0, 0.0), (15, 0.012), (30, 0.0), (45, 0.012), (60, 0.0))
# Leaning over the standing leg. The right foot carries 0 to 30.
PELVIS_SIDE = ((0, 0.0), (15, 1.5), (30, 0.0), (45, -1.5), (60, 0.0))
# Turning with the swinging leg. Held near one degree by the hem measurement
# above, not by taste.
PELVIS_TWIST = ((0, -1.2), (15, 0.0), (30, 1.2), (45, 0.0), (60, -1.2))

# The chest turns against the pelvis and the head against the chest, which is
# what stops the walk reading as one rigid block. Both stay inside the 2 and 4
# degree caps the hood clips already work to.
CHEST_TWIST = ((0, 1.2), (15, 0.0), (30, -1.2), (45, 0.0), (60, 1.2))
HEAD_TWIST = ((0, -0.6), (15, 0.0), (30, 0.6), (45, 0.0), (60, -0.6))


def at(keys, frame):
    """The value these keys carry at this frame."""
    return motion.at(keys, frame)


def tilt(keys, frame):
    """The same, in radians."""
    return motion.tilt(keys, frame)


def leg(frame, side):
    """Thigh, knee and foot angles in degrees, for one side at one frame.

    The left leg is the right leg half a cycle later. Nothing is mirrored in x:
    both legs swing in the same plane, so the same angles apply to both and only
    the phase differs.
    """
    phase = (frame + (HALF if side == 'L' else 0)) % LAST
    thigh = at(THIGH, phase)
    shin = at(SHIN, phase)
    # Level against the two above it, plus the authored lift.
    foot = -(thigh + shin) + at(FOOT_LIFT, phase)
    return thigh, shin, foot

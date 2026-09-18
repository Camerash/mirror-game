"""The two hood clips, as data.

Everything here is in a 0 to 60 frame space at 60 fps, so a clip is exactly one
second and the phases land on the approved budget without any retiming:

    frame 12   0.20 s   both hands have reached the rim
    frame 45   0.55 s   the hood has finished moving
    frame 60   0.25 s   the hands are back under the cloak

The phase tables come across unchanged from the retired
`traveller_animated/hood_shapes.py`. `UP_PHASES` is deliberately not the reverse
of `DOWN_PHASES`: the turn cluster sits at 15 to 21 instead of 37 to 43, so the
fold happens early on the way up and late on the way down.

The hand paths are authored against measurements, not guessed. The arm reaches
0.663 from the shoulder at (0.282, -0.013, 1.878), and the raised hood's rim runs
from 0.414 away at the throat to 1.294 at the crown. Only the rim below z 2.48 is
reachable at all, so the grips sit at z 2.42 going up and z 1.99 at the collar.
The design asks for a grip near eye height; on this head, eye height is z 2.73
and the highest rim the hand can hold is 0.25 below it. The arm reach wins, as
the same paragraph says it should.
"""
import math

from mathutils import Vector

FPS = 60
LAST = 60                       # the clip's last frame, so exactly one second
CONTACT = 12                    # both hands on the rim
SETTLED = 45                    # the hood has arrived
IDLE_ARM_ANGLE = 78             # matches proportions.IDLE_ARM_ANGLE

DOWN_PHASES = ((0, 'Basis'), (12, 'Basis'), (20, 'HoodLift'), (30, 'HoodClear'),
               (37, 'HoodBack'), (39, 'HoodTurnHigh'), (41, 'HoodTurnLow'),
               (43, 'HoodSettle'), (45, 'HoodLowered'), (60, 'HoodLowered'))
UP_PHASES = ((0, 'HoodLowered'), (12, 'HoodLowered'), (15, 'HoodSettle'),
             (17, 'HoodTurnLow'), (19, 'HoodTurnHigh'), (21, 'HoodBack'),
             (31, 'HoodClear'), (39, 'HoodLift'), (45, 'Basis'), (60, 'Basis'))

# Where the right wrist goes, by frame. The left is the mirror. These are wrist
# points, not grips: each one is its rim point pulled 0.12 back toward the
# shoulder, which is where the wrist sits when the palm is on the cloth.
#
# Frame 0 and frame 60 are left out. The clip starts and ends at the idle pose,
# and `build_animation` fills those two frames from the rig itself rather than
# from a number written here that could drift away from it.
RAISED = Vector((0.309, -0.313, 2.321))     # on the raised hood's rim, 0.81 of reach
SWEPT = Vector((0.452, -0.330, 2.285))      # carried out and back, 0.85
LOOSE = Vector((0.470, -0.300, 2.120))      # where the hand leaves the cloth, 0.70
THROUGH = Vector((0.150, -0.520, 1.640))    # clear of the seam, in front of the chest

# The hands do not follow the hood all the way down. Folded, its rim sits 0.42 of
# the arm's reach from the shoulder, and no arc of one curvature reaches that far
# in without coiling: at that range the arm would have to turn 68 degrees at
# every joint, which is a scroll and not an arm. So the hands take the rim back
# and outward, let go while they are still comfortable, and the hood finishes
# folding on its own. That is what the design's release-and-settle phase is for,
# and it is how a hood is actually pushed back.
DOWN_WRIST = ((4, THROUGH), (CONTACT, RAISED), (26, SWEPT), (38, LOOSE), (52, THROUGH))
UP_WRIST = ((4, THROUGH), (CONTACT, LOOSE), (26, SWEPT), (SETTLED, RAISED), (52, THROUGH))

# The elbow lifts away from the body and a little forward, so the arm curves
# outward instead of folding across the chest.
BULGE = Vector((0.55, -0.45, -0.70)).normalized()

# Small body rotations, in degrees, by frame. The design caps the head at 4 and
# the chest at 2; these stay inside that. The chest leads the reach and the head
# follows the hands.
CHEST_TILT = ((0, 0.0), (CONTACT, -1.6), (SETTLED, -2.0), (LAST, 0.0))
HEAD_TILT = ((0, 0.0), (CONTACT, 3.2), (SETTLED, 4.0), (LAST, 0.0))

# `CloakOpen` parts the front so the hands can come out. It must be back at zero
# on the last frame: the tests require every shape except `HoodLowered` to be
# clear at both ends.
#
# `CloakArms` is left at zero. It was authored to stand the cloth off a lifting
# arm, on a cloak whose front was a broad slit, and on this one it does the
# opposite: driven to 1 it splits the garment open and the legs show through,
# while the crossings it is meant to remove stay where they are. Rendered side by
# side at 0 and at 1, the reach reads as a figure raising its hands at 0 and as
# an inflating cloak at 1.
OPEN = ((0, 0.0), (3, 1.0), (SETTLED, 1.0), (55, 1.0), (LAST, 0.0))
ARMS = ((0, 0.0), (LAST, 0.0))


def at(keys, x):
    """Smooth interpolation through key rows, which must ascend in x.

    The same Catmull-Rom as `cloak_profile.at`. It is copied rather than
    imported because it works on vectors here as well as on numbers, and the
    cloak's copy is documented against its own tables.
    """
    xs = [k[0] for k in keys]
    if x <= xs[0]:
        return keys[0][1]
    if x >= xs[-1]:
        return keys[-1][1]
    index = max(i for i, value in enumerate(xs) if value <= x)
    index = min(index, len(keys) - 2)
    p1, p2 = keys[index][1], keys[index + 1][1]
    p0 = keys[index - 1][1] if index else p1
    p3 = keys[index + 2][1] if index + 2 < len(keys) else p2
    t = (x - xs[index]) / (xs[index + 1] - xs[index])
    return (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
            + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3) / 2


def phase_weights(phases, frame):
    """The shape key weights this phase table asks for, as {name: value}.

    The table names one key per phase and crossfades linearly between the two
    that bracket the frame. Every other key is zero, which is what keeps the
    eight hood shapes from ever being summed together.
    """
    frames = [f for f, _ in phases]
    if frame <= frames[0]:
        return {phases[0][1]: 1.0}
    if frame >= frames[-1]:
        return {phases[-1][1]: 1.0}
    index = max(i for i, f in enumerate(frames) if f <= frame)
    index = min(index, len(phases) - 2)
    (first, low), (second, high) = phases[index], phases[index + 1]
    if second == first or low == high:
        return {low: 1.0}
    share = (frame - first) / (second - first)
    return {low: 1 - share, high: share}


def wrist(path, frame, rest):
    """The right wrist at this frame, with the idle position at both ends."""
    keys = ((0, rest),) + tuple(path) + ((LAST, rest),)
    return at(keys, frame)


def tilt(keys, frame):
    return math.radians(at(keys, frame))

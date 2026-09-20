"""The cloak's shape, as curves fitted once to the accepted cloak.

The old generator projected a grid onto the inherited mesh with a ray per
vertex, then corrected the result: 336 of its 921 lines did nothing else. Every
fault traced back to that. A horizontal ray cannot see a near-horizontal rim, so
the hood's throat jumped from closed to 55 degrees wide over 0.01 of height. The
old split wanders, 0.008 at the clasp and 0.001 at z 1.40, so following it gave a
slit that pinched in the middle. A grazing ray on the collar yoke left a step
that read as a bar across the chest.

These tables are the same cloak, measured once. Everything below is data: change
a number and the shape changes, with nothing to correct afterwards.
"""
import math

FRONT = 3 * math.tau / 4

# The hem is not level. It falls from 0.241 at the sides to 0.193 at the back,
# by column, starting at world +x and going round.
HEM = [0.241, 0.233, 0.220, 0.208, 0.199, 0.195, 0.193, 0.195, 0.199, 0.208,
       0.220, 0.233, 0.241, 0.237, 0.224, 0.211, 0.202, 0.196, 0.194, 0.196,
       0.202, 0.211, 0.224, 0.237]
TRIM_HEIGHT = .145              # the painted border's band, above each hem point

# Radius by height and by azimuth, every 30 degrees from world +x. Azimuth 90 is
# the back and 270 the front. The front entries of the cape carry the value
# beside them, because the split means no ray ever lands there; the hood's front
# entries carry its rim radius for the same reason.
RADIUS = [
    (0.36, [0.852, 0.735, 0.613, 0.572, 0.613, 0.735, 0.852, 0.795, 0.685, 0.670, 0.685, 0.795]),
    (0.55, [0.813, 0.704, 0.589, 0.550, 0.589, 0.704, 0.813, 0.762, 0.661, 0.646, 0.661, 0.762]),
    (0.80, [0.760, 0.660, 0.556, 0.520, 0.556, 0.660, 0.760, 0.717, 0.627, 0.613, 0.627, 0.717]),
    (1.05, [0.703, 0.612, 0.519, 0.486, 0.519, 0.612, 0.703, 0.669, 0.590, 0.576, 0.590, 0.668]),
    (1.30, [0.642, 0.561, 0.479, 0.450, 0.479, 0.561, 0.642, 0.617, 0.551, 0.538, 0.551, 0.617]),
    (1.55, [0.573, 0.504, 0.435, 0.410, 0.434, 0.504, 0.573, 0.558, 0.506, 0.494, 0.506, 0.558]),
    (1.78, [0.497, 0.441, 0.385, 0.364, 0.385, 0.440, 0.496, 0.493, 0.456, 0.446, 0.456, 0.493]),
    (1.92, [0.444, 0.425, 0.398, 0.405, 0.397, 0.425, 0.447, 0.436, 0.417, 0.409, 0.399, 0.427]),
    (2.02, [0.405, 0.419, 0.429, 0.655, 0.429, 0.421, 0.411, 0.388, 0.383, 0.379, 0.383, 0.378]),
    (2.12, [0.389, 0.427, 0.697, 0.734, 0.697, 0.430, 0.389, 0.371, 0.375, 0.349, 0.370, 0.371]),
    (2.26, [0.479, 0.575, 0.752, 0.743, 0.752, 0.579, 0.479, 0.450, 0.436, 0.430, 0.436, 0.451]),
    (2.45, [0.548, 0.665, 0.751, 0.714, 0.751, 0.666, 0.548, 0.517, 0.508, 0.505, 0.508, 0.517]),
    (2.65, [0.579, 0.681, 0.704, 0.656, 0.704, 0.682, 0.578, 0.553, 0.544, 0.542, 0.544, 0.554]),
    (2.85, [0.560, 0.634, 0.638, 0.593, 0.638, 0.633, 0.560, 0.552, 0.542, 0.540, 0.542, 0.552]),
    (3.02, [0.496, 0.534, 0.553, 0.523, 0.553, 0.534, 0.496, 0.501, 0.511, 0.500, 0.511, 0.503]),
    (3.14, [0.407, 0.419, 0.434, 0.431, 0.433, 0.419, 0.407, 0.420, 0.438, 0.444, 0.439, 0.421]),
    (3.22, [0.307, 0.311, 0.310, 0.316, 0.310, 0.311, 0.307, 0.330, 0.366, 0.366, 0.367, 0.331]),
    (3.28, [0.177, 0.161, 0.150, 0.166, 0.150, 0.161, 0.177, 0.192, 0.244, 0.270, 0.244, 0.194]),
]

# The hood's face opening: half angle either side of the front, and the radius at
# its rim. The rim curls inward, so it is measured rather than taken from the
# surface beside it.
#
# The opening runs the whole way down to the brooch and closes there on one
# vertex, so the throat is a V and not the flat bib it used to end on. Below
# 2.145 the opening is a plain cut in the cape, so its edge follows the cape's
# own front radius; above it the hood's roll starts and the rim carries its own.
# The apex sits at 1.88, which is 0.010 above the gem's top corners, so the gem
# covers the point where the two edges meet.
FACE_APEX = 1.88
FACE = [(FACE_APEX, 0.0), (1.96, 8.2), (2.04, 16.3), (2.11, 23.4), (2.145, 27.0),
        (2.16, 27.5), (2.20, 30.2), (2.30, 36.8), (2.45, 40.2),
        (2.60, 40.8), (2.75, 38.5), (2.90, 33.0), (2.98, 26.0), (3.03, 18.2),
        (3.06, 8.5), (3.08, 0.0)]
RIM = [(FACE_APEX, 0.419), (1.96, 0.397), (2.04, 0.371), (2.11, 0.355),
       (2.145, 0.378), (2.16, 0.385), (2.20, 0.398), (2.30, 0.444), (2.45, 0.508),
       (2.60, 0.544), (2.75, 0.544), (2.90, 0.540), (2.98, 0.514), (3.03, 0.495),
       (3.06, 0.479), (3.08, 0.470)]

# The front opening: half width by height. Authored, not measured. The accepted
# cloak's own split is no use as a curve, because its panels wander: 0.008 wide
# at the clasp, 0.001 at z 1.40 and 0.101 at the hem, so following it gives a
# slit that pinches in the middle. It starts at a point under the brooch and
# opens quickly, which is the shape the user cut by hand.
#
# The two panels nearly touch. The opening is real, because the arms come out
# through it, but at rest it must read as a line: 1.1 percent of the cloak's
# width under the brooch, 2.4 percent at the hem. It is dark without any paint,
# because the space behind it is 0.22 deep at the chest and 0.57 at the legs, so
# a slot this narrow lets in almost no light and the near edge hides it from any
# angle but head on.
SPLIT_APEX = 1.74
SPLIT = [(0.19, .020), (0.50, .018), (0.90, .015), (1.30, .012), (1.60, .009),
         (1.70, .006), (SPLIT_APEX, 0.0)]


def at(keys, x):
    """Smooth interpolation through key rows, which must ascend in x."""
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


def hem_at(angle):
    """The hem's height at an azimuth, smooth around the ring."""
    share = (angle % math.tau) / math.tau * len(HEM)
    low = int(share) % len(HEM)
    blend = share - int(share)
    return HEM[low] * (1 - blend) + HEM[(low + 1) % len(HEM)] * blend


def opening_half(z):
    """Half the angle of whatever opening this height has: the split, the hood's
    face, or nothing. The two never meet, so one number covers both."""
    face = face_half(z)
    if face > 0:
        return face
    half = split_half(z)
    if half <= 0:
        return 0.0
    across = max(radius(z, FRONT), 1e-6)
    return math.asin(max(-1.0, min(1.0, half / across)))


def edge_radius(z):
    """The radius at an opening's edge. The hood's rim curls inward, so it is
    measured; the split's edges sit on the cape like everything else."""
    return rim_radius(z) if face_half(z) > 0 else radius(z, FRONT)


def radius(z, angle):
    """The cloak's radius at a height and an azimuth, smooth in both."""
    share = (angle % math.tau) / math.tau * 12
    low = int(share) % 12
    blend = share - int(share)
    rows = [(height, values[low] * (1 - blend) + values[(low + 1) % 12] * blend)
            for height, values in RADIUS]
    return at(rows, z)


def face_half(z):
    """Half the hood opening's angle at this height, in radians. 0 where shut."""
    if z < FACE[0][0] or z > FACE[-1][0]:
        return 0.0
    return math.radians(at(FACE, z))


def rim_radius(z):
    return at(RIM, z)


def split_half(z):
    """Half the front opening's width at this height. 0 at and above the apex."""
    return 0.0 if z >= SPLIT_APEX else at(SPLIT, z)

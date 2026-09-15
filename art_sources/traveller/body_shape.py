"""Geometry helpers for the Traveller body: smooth spines, stable frames, rings.

The previous body was built from hand-written ring tables. That produced an
uneven, bumpy arm: ring spacing varied by 4x, the radius dipped and bulged
before the cuff, and every ring recomputed its own frame from a world axis so
orientation drifted and kinked where the upper arm met the forearm. These
helpers replace the table with four properties that cannot express those
defects: one smooth spine, even arc-length sampling, a monotone radius, and a
parallel-transported frame.
"""
import math

from mathutils import Matrix, Vector

TAU = math.tau


def bezier(p0, p1, p2, t, p3=None):
    """Point on the quadratic (or cubic, with p3) Bezier."""
    if p3 is None:
        return p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t ** 2
    u = 1 - t
    return p0 * u ** 3 + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t ** 3


def even_samples(p0, p1, p2, count, resolution=512, p3=None):
    """Return `count` points spaced evenly by arc length along the curve.

    Even spacing is what keeps the tube from banding: the old arm put gaps of
    0.04 and 0.23 next to each other along the same 1.3-long sleeve.
    """
    fine = [bezier(p0, p1, p2, i / resolution, p3) for i in range(resolution + 1)]
    lengths = [0.0]
    for a, b in zip(fine, fine[1:]):
        lengths.append(lengths[-1] + (b - a).length)
    total = lengths[-1]
    points, index = [], 0
    for step in range(count):
        target = total * step / (count - 1)
        while index < resolution and lengths[index + 1] < target:
            index += 1
        span = lengths[index + 1] - lengths[index]
        fraction = 0.0 if span <= 0 else (target - lengths[index]) / span
        points.append(fine[index].lerp(fine[index + 1], fraction))
    return points


def parallel_frames(points, first_normal):
    """Carry one frame along a polyline by minimum rotation between tangents.

    Rebuilding each frame from a fixed world axis, as the old generator did,
    makes the ring orientation jump wherever the tangent turns. Rotating the
    previous frame onto the next tangent cannot jump, so the tube stays smooth
    through the elbow.
    """
    tangents = []
    for index in range(len(points)):
        if index == 0:
            tangent = points[1] - points[0]
        elif index == len(points) - 1:
            tangent = points[-1] - points[-2]
        else:
            tangent = points[index + 1] - points[index - 1]
        tangents.append(tangent.normalized())
    normal = (first_normal - tangents[0] * first_normal.dot(tangents[0])).normalized()
    frames = []
    for index, tangent in enumerate(tangents):
        if index:
            previous = tangents[index - 1]
            axis = previous.cross(tangent)
            if axis.length > 1e-9:
                angle = math.atan2(axis.length, previous.dot(tangent))
                normal = Matrix.Rotation(angle, 3, axis.normalized()) @ normal
            normal = (normal - tangent * normal.dot(tangent)).normalized()
        frames.append((tangent, normal.copy(), tangent.cross(normal).normalized()))
    return frames


def ring(centre, normal, binormal, radius_a, radius_b, columns, phase=0.5):
    """One closed cross-section. `phase` offsets columns off the axis planes."""
    return [centre + normal * (radius_a * math.cos((column + phase) * TAU / columns))
            + binormal * (radius_b * math.sin((column + phase) * TAU / columns))
            for column in range(columns)]


def catmull_rom(keys, x):
    """Smooth monotone-ish interpolation through (x, value) key rows."""
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

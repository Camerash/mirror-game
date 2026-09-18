"""Part-restricted, chain-blended skin weights.

Blender's heat weighting bleeds between surfaces that nearly touch: the hands
hang beside the shins, so automatic weights gave hand vertices `Shin` influence
and tore the mesh apart under a pose. Every vertex here already knows which body
part built it, so weights are solved only against that part's own bone chain and
cannot bleed across the gap.

Within a chain, weight follows arc length with a smooth window at each joint,
so segments blend instead of creasing.
"""
import bpy
from mathutils import Vector

JOINT_BLEND = .45   # fraction of the shorter adjacent bone that cross-fades


def chain_points(rig, chain):
    """Head of each bone plus the final tail, in armature space."""
    points = [rig.data.bones[chain[0]].head_local.copy()]
    for name in chain:
        points.append(rig.data.bones[name].tail_local.copy())
    return points


def chain_weights(point, points, chain):
    """Blend the two bones nearest the point's arc position along the chain."""
    lengths = [(b - a).length for a, b in zip(points, points[1:])]
    bounds, total = [0.0], 0.0
    for length in lengths:
        total += length
        bounds.append(total)
    best = None
    for index in range(len(lengths)):
        start, end = points[index], points[index + 1]
        span = end - start
        t = max(0.0, min(1.0, (point - start).dot(span) / max(span.length_squared, 1e-12)))
        closest = start + span * t
        distance = (point - closest).length
        if best is None or distance < best[0]:
            best = (distance, bounds[index] + t * lengths[index])
    position = best[1]
    weights = {}
    for index, name in enumerate(chain):
        start, end = bounds[index], bounds[index + 1]
        if start <= position <= end:
            weights[name] = 1.0
            window = JOINT_BLEND * min(lengths[index],
                                       lengths[index - 1] if index else lengths[index])
            if index and position - start < window:
                share = .5 * (1 - (position - start) / window)
                weights[name] = 1 - share
                weights[chain[index - 1]] = share
            window = JOINT_BLEND * min(lengths[index],
                                       lengths[index + 1] if index + 1 < len(lengths)
                                       else lengths[index])
            if index + 1 < len(chain) and end - position < window:
                share = .5 * (1 - (end - position) / window)
                weights[name] = weights.get(name, 1.0) - share
                weights[chain[index + 1]] = share
            break
    if not weights:
        weights = {chain[0] if position < bounds[0] else chain[-1]: 1.0}
    return weights


def cloak(garment, rig):
    """Weight the cloak along the spine, so the body's lean reaches it.

    The cloak used to be a rigid child of the `Chest` bone, which made it a cone
    hanging off one joint: a 2 degree chest rotation swung the whole garment
    about z 1.60, and the hem sits 1.4 below that, so it travelled 0.049 - more
    than the 0.032 the design allows, and the wrong way, because the hem is under
    the pivot.

    The same chain blender the body uses gives the gradient for free. Everything
    from the chest up clamps to `Chest` at 1.0, so the hood deforms exactly as it
    did and the eight accepted hood keys are untouched.
    """
    chain = ['Pelvis', 'Spine', 'Chest']
    points = chain_points(rig, chain)
    into_rig = rig.matrix_world.inverted() @ garment.matrix_world
    garment.vertex_groups.clear()
    for name in chain:
        garment.vertex_groups.new(name=name)
    widest = 0
    for index, vertex in enumerate(garment.data.vertices):
        weights = chain_weights(into_rig @ vertex.co, points, chain)
        weights = {k: v for k, v in weights.items() if v > 1e-4}
        total = sum(weights.values())
        for name, value in weights.items():
            garment.vertex_groups[name].add([index], value / total, 'REPLACE')
        widest = max(widest, len(weights))
    return widest


def apply(body, rig, build):
    """Write one weight set per vertex, restricted to that vertex's own part."""
    chains = {'torso': ['Pelvis', 'Spine', 'Chest'], 'neck': ['Neck', 'Head']}
    for side in ('L', 'R'):
        chains['leg' + side] = ['Thigh.' + side, 'Shin.' + side, 'Foot.' + side]
        # Clavicle is deliberately not in the chain. With it first, the rings
        # nearest the shoulder took most of their weight from a bone that does
        # not move with the arm, so a raised arm tore away from its own deltoid.
        chains['arm' + side] = ['UpperArm.' + side, 'UpperArm.%s.001' % side,
                                'Forearm.' + side, 'Forearm.%s.001' % side]
        # The cuff hangs off the wrist end of the same chain.
        chains['cuff' + side] = chains['arm' + side]
    body.vertex_groups.clear()
    for bone in rig.data.bones:
        body.vertex_groups.new(name=bone.name)
    shoulders = {side: rig.data.bones['UpperArm.' + side].head_local.copy()
                 for side in ('L', 'R')}
    resolved = []
    for index in build.kept:
        point = build.points[index]
        part = build.parts[index]
        if part.startswith('hand'):
            # The accepted hand keeps its authored weights; only the forearm it
            # hangs from was renamed by the split.
            side = part[-1]
            weights = {('Forearm.%s.001' % side) if name == 'Forearm.' + side else name: value
                       for name, value in build.weights[index].items()}
        elif part.startswith('shoulder'):
            # The armhole ring is the deltoid: it belongs to the arm, with
            # enough chest to keep the seam attached to the body.
            side = part[-1]
            weights = {'UpperArm.' + side: .62, 'Chest': .38}
        else:
            weights = chain_weights(point, chain_points(rig, chains[part]), chains[part])
            if part == 'torso':
                # Let the torso around each armhole follow the arm a little, so
                # the armpit opens and closes instead of creasing.
                for side, centre in shoulders.items():
                    near = max(0.0, 1 - (point - centre).length / .40)
                    if near > 0:
                        share = .68 * near * near
                        weights = {k: v * (1 - share) for k, v in weights.items()}
                        name = 'UpperArm.' + side
                        weights[name] = weights.get(name, 0) + share
        # The old body carried helper groups such as AnimatedArms; keep bones only.
        weights = {k: v for k, v in weights.items()
                   if v > 1e-4 and k in rig.data.bones}
        total = sum(weights.values())
        resolved.append({k: v / total for k, v in weights.items()})
    for index, weights in enumerate(resolved):
        for name, value in weights.items():
            body.vertex_groups[name].add([index], value, 'REPLACE')
    return max(len(w) for w in resolved)

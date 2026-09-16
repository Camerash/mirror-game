"""Proportion charts for the Traveller.

The body is modelled in **T-pose**: the upper body and both arms form one clean
horizontal tube, with no bend anywhere in the mesh. The arms-down silhouette is
a rig pose, not modelled geometry. Building the arm pointing down instead made
the armhole normal and the arm direction meet at ninety degrees, and that corner
showed as a cave-in at the shoulder.

The first build measured 2.96 heads tall with the arm at 48% of height, so the
fingertips reached the boots. That reads as an ape. These charts set the body
against the two references the user gave: Link's Awakening chibi Link for style,
Toon Link for build.

Height is not fixed by gameplay. The traveller is not wired into the game yet and
the walker capsule is RADIUS .18 / HEIGHT .8 in game units, so the model is scaled
at integration and only ratios here matter.
"""

# Measured off the current model, and the same in both charts.
SHOULDER_Z = 1.90       # armhole centre
HAND_DROP = .297        # wrist ring to fingertip, inside the kept hand assembly
HAND_RIM_DROP = .1238   # wrist ring to the hand's own top ring
IDLE_ARM_ANGLE = 78     # degrees the rig drops the arms for the resting look

CHARTS = {
    # Head unchanged. The head was never the defect: a large head on a chunky
    # body is chibi, on a thin body it is a bobblehead. Widen the chest, shorten
    # and thicken the limbs, and the large head becomes an asset at game size.
    'chibi': {
        'head_scale': 1.00,
        # A straight tube, not a vase. Constant radius from chest to hip means
        # the arm clears the body everywhere by construction, so no clearance
        # clamp is needed and no canyon gets carved under the shoulder.
        'torso': (.300, .235),
        'leg_keys': [(.32, .170, .126, .129), (.78, .166, .134, .137),
                     (1.18, .164, .140, .143)],
        'arm_length': .960,      # shoulder to fingertip
        'sleeve_radius': (.122, .104),
    },
    # Head shrinks 18% about its base, which also drops total height to ~3.0, so
    # the head lands near 28% without lengthening the legs.
    'toon': {
        'head_scale': .82,
        'torso': (.305, .240),
        'leg_keys': [(.32, .170, .126, .129), (.78, .166, .134, .137),
                     (1.18, .164, .140, .143)],
        'arm_length': 1.010,
        'sleeve_radius': (.120, .102),
    },
}


def summary(name):
    """Predicted ratios, so the chart can be checked before anything is built."""
    chart = CHARTS[name]
    head = 1.080 * chart['head_scale']
    total = 2.115 + head          # hair base plus head height
    arm = chart['arm_length']
    fingertip = SHOULDER_Z - arm   # where the fingers land once the arms drop
    return {
        'heads_tall': round(total / head, 2),
        'head_pct': round(head / total * 100),
        'arm_pct': round(arm / total * 100),
        'leg_pct': round(1.150 / total * 100),
        'fingertip_z': round(fingertip, 3),
        'head_over_chest': round(1.074 * chart['head_scale']
                                 / (2 * chart['torso'][0]), 2),
    }


if __name__ == '__main__':
    for name in CHARTS:
        print(name, summary(name))

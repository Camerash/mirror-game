# Traveller continuous-arm study

## Approved work

Correct the upper-body region in a separate copy of the failed Rigify trial. Preserve previous sources, unfinished animation work, and gameplay assets. The user approved this work after reviewing the disconnected-looking shoulder. During the study, the user changed the arm direction to a continuous cartoon curve with no visible anatomical elbow.

Use the [character drawing](traveller-drawing-02/character-and-hood-action.jpeg) and [face and movement drawing](traveller-drawing-02/face-and-movement.jpeg). Keep the accepted head, chestnut hair, blue-grey clothing, hood endpoints, feet, and resting cloak silhouette.

## Review order

1. Correct torso, shoulder, sleeve, cuff, and hand construction. Keep the right arm under test and the opposite arm at rest. Use native Rigify controls in Blender Lab.
2. Review uncovered rest, eye-level grip, and rear pickup from front, side, and three-quarter views. Require a smooth shoulder, continuous curved sleeve, solid hand, open cuff, and no body or sleeve self-crossings. Check evaluated deformation scale as well as pose scale channels.
3. Fit the cloak around the working poses. Arms must use the front opening. Check real rim contact, head/hair clearance, and cloth clearance. Preserve both accepted resting hood endpoints.
4. Save static review evidence and measured results. No animation, game export, or full-rig migration is included.

Keep the complete character within 8,000 triangles, two opaque materials, one 1024 atlas, and four normalized bone weights per vertex.

## Rig diagnosis

The initial failed trial attributed evaluated scale changes to generated deform constraints. A new isolation check found that native IK still allowed stretch, including nonzero per-bone `ik_stretch`, despite the visible Rigify stretch control being zero. Disabling native IK stretch removed the measured eye-pose scale change. The final report must check all three poses; the earlier cause claim is superseded by this finding.

## Status

Work is in progress. The main review accepted the continuous curve in the uncovered eye-grip pose. The native curve no longer uses the custom elbow-support bone or CorrectiveSmooth. Rest, rear pickup, and clothed contact still need final checks. This is not approval for animation.

## Curved-arm direction

The anatomical elbow experiment is preserved as a checkpoint. The next arm treatment follows the user's request for a slight continuous curve that suggests an elbow only when bent. Use restrained curvature, stable thickness, and existing reach. Keep the cuff and hand shape stable. Do not add elastic extension, large gloves, or exaggerated body movement.

References:

- [SouthernShotty: Simple Rubber Hose Character Rig in Blender](https://www.youtube.com/watch?v=bQCmlZAl_Os): a relevant 3D modeling and rigging tutorial. The search index and tutorial description were reviewed; the full video was not watched.
- [Studio MDHR character artwork](https://studiomdhr.com/cuphead-goes-double-platinum/): reference for continuous cartoon limb curves. The traveller keeps its own proportions, colours, and clothing.
- [Blender Bendy Bones](https://docs.blender.org/manual/en/3.4/animation/armatures/bones/properties/bendy_bones.html?highlight=bendy+bones): native curved bone deformation.
- [Blender Rigify Rubber Tweak](https://docs.blender.org/manual/vi/4.4/addons/rigging/rigify/rig_features.html): native joint smoothness control.
- [Blender Spline IK](https://docs.blender.org/manual/en/4.3/animation/constraints/tracking/spline_ik.html): a native curve-driven bone-chain option with separate length and width scale controls.

The method must be checked in the installed Blender version. Smooth authoring controls do not prove a smaller game rig or lower runtime cost. This stage does not export gameplay assets.

The rear pickup must use a movable opening edge. A tested upper neckline fold was rejected because it was part of the fixed hood-to-collar attachment. Contact checks must include the whole hand and cloth, not only finger-pad distance to a target.

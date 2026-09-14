# Rigify arm and hand trial

## Purpose

Test bundled Rigify controls and the native Pose Library on a separate traveller copy before a full rig migration. This trial covers the right arm and three static poses: concealed rest, eye-level raised grip, and pickup from the folded rear rim. It does not complete or replace the current hood animations.

Use the user's [character and hood drawing](traveller-drawing-02/character-and-hood-action.jpeg) and [face and movement drawing](traveller-drawing-02/face-and-movement.jpeg). Preserve the head, chestnut hair, blue-grey clothing, approved hood endpoints, loose sleeves, and open cuffs.

## Construction and review rules

- Fit the native Rigify arm sample to the current upper-arm and forearm lengths. Add chest and clavicle anchors, plus simple thumb and grouped-finger rotation controls. Do not add a facial rig.
- Bind the trial body once to generated deform bones. Use normalized weights with at most four influences, no IK stretch, and unit bone scales.
- Correct the shoulder connection and hand volume locally. Review the uncovered body before the clothing. Keep the opposite arm and torso at rest.
- Check arm/torso, arm/arm, hand/body, hand/hood, and head/hair clearance. Exclude only true shared seam adjacency.
- Review front, side, rear, three-quarter, and game views. Numeric clearance alone does not establish a good pose.
- Save three native pose assets with fixed IK and parent settings. Record hood morph values in their descriptions; arm pose assets do not restore garment morphs.
- Keep the complete character within 8,000 triangles, two opaque materials, and one shared 1024 atlas. Authoring rig complexity is not a game-performance result.

## Decision gate

Stop after the three-pose comparison. Full-body migration, one-second actions, game export, and physical-device checks require a later stage. MPFB is not part of this trial.

## Result

**Failed trial. Do not migrate or export this rig.** The controls can place the arm at both hood contact regions, and the three native pose assets restore with no measured drift. The mesh does not meet the clearance or shoulder-deformation requirements.

The right shoulder has ten shared seam vertices. This is a mesh connection, but it is not a sound shoulder deformation. The opposite arm retains its baseline construction. The uncovered body needs a separate shoulder and sleeve correction before further hood animation.

| Check | Rest | Eye grip | Rear pickup |
| --- | ---: | ---: | ---: |
| Arm/torso triangle pairs | 43 | 0 | 2 |
| Arm/garment triangle pairs | 6 | 123 | 312 |
| Arm self-intersection pairs | 82 | 103 | 105 |
| Pose reapplication drift | 0 | 0 | 0 |
| Evaluated deform-matrix scale error | <0.001% | 3.13% | 3.45% |

Triangle-pair counts are diagnostic intersections, not counts of separate visible faults. The checker excludes shared-vertex adjacency. Zero surface intersections do not prove full volume clearance or a correct grip.

The complete trial has 6,868 triangles. The body has one Armature modifier and at most two deform weights per vertex. Weight normalization error is below 0.000001. Pose scale channels are effectively one, and IK Stretch is zero. However, generated deform-bone `STRETCH_TO` constraints with volume preservation still change evaluated scale. Thus the unit-scale requirement does not pass.

No new gameplay asset or finished animation was produced. The original animation source remains unchanged by this trial. Rigify controls are useful for authoring; their presence is not a game-performance result.

## Files and review

- [Matched source/trial comparison and fault views](traveller-rigify-trial/review.html).
- [Editable trial with three embedded Pose Library assets](../../art_sources/traveller_rigify_trial/traveller_rigify_trial.blend).
- [Measured checks](../../art_sources/traveller_rigify_trial/trial_checks.json).

The three assets are `Trial_Rest`, `Trial_EyeGrip`, and `Trial_RearPickup`. Their descriptions specify `HoodLowered`, `CloakOpen`, IK settings, and contact references. Apply the stated garment values separately when using the native Pose Library.

Main review confirmed a pinched shoulder join, sleeve/cloak penetration, and a failed rear grip. The rear hand has four hand/cloth triangle intersections. Measured grip gaps are 0.0130 scene units at the eye and 0.0366 at the rear. These are not accepted contacts.

The character uses two opaque materials and one shared 1024×1024 atlas. The optional grey inspection material is a review override. There are 11 deform bones and 65 total authoring bones.

The saved captures cover matched side and three-quarter source comparisons, front and rear fault views, and uncovered grey shoulder views. The HTML also displays reduced-size copies. A complete elevated game-camera and all-pose view matrix was not completed after the trial failed. No Godot or device performance test was run.

## Next decision

Keep Rigify as an authoring candidate. Do not carry this mesh or these grips into animation. A later proposal should first establish a sound torso-to-shoulder mesh, sleeve clearance, hand volume, and deform-bone scale behavior in uncovered static poses. Then test the same poses with the garment. This trial does not authorize that next stage.

## Work and checks

Astra at `xhigh` used Blender Lab in a persistent session. The trial took about 24 minutes 25 seconds through the final geometry report, including setup and review. It used two local mesh passes. Token measurements are unavailable. See the [setup and correction record](../../art_sources/traveller_rigify_trial/README.md).

Main checks passed for trial-script syntax, report consistency, capture links, original source preservation, and absence of the temporary Godot bridge. Geometry and grip checks failed as listed above. Pose restoration checks cover repeated evaluated geometry; they did not perturb every custom control property independently. The source/trial images have matched cameras, but different arm poses and local mesh edits, so they are not a controlled rig-only comparison.

# Rigify right-arm trial — failed

This is a static inspection artifact. It is not suitable for animation or export. No production asset was replaced. No animation was baked and no GLB was exported.

Open `traveller_rigify_trial.blend`. The saved scene shows `Trial_Rest`, with the garment visible and no active animation. The editable source is authoritative. The setup scripts record the local trial edits; do not run them again on this file.

## Source and tools

- Source: `../traveller_animated/traveller_animated.blend`.
- Original SHA256, checked again after the trial: `75472b1c77560f7ed4f9f4a83343686c4a228885e5e8065749b615b19a0ae153`.
- Model: `gpt-6-astra`, effort `xhigh`.
- Blender 5.2.1 LTS, persistent Blender Lab connection, bundled Rigify and Pose Library.
- Native Rigify arm sample and generation, native BMesh seam operations, explicit weights, and native pose assets. Short Python scripts supplied operations that the inspection tools did not provide. Blender Lab tools produced the renders.
- Rigify first failed because its preferences entry was absent. A partial-registration retry also failed. One clean trial-session restart and native `addon_enable` resolved setup. No add-on installation was needed.
- Two local mesh passes: arm/hand binding, then the planned shoulder seam and rounded hand ends. No further geometry tuning followed the failed checks. Two pose-selection API/context errors were corrected before asset creation.
- Start: 2026-09-14 19:02:35 UTC. Final check: 19:26:59 UTC, about 24 minutes 25 seconds. This elapsed time includes setup and review. Token usage is unavailable.

## What changed

The right arm uses one generated Rigify rig with 65 total bones and 11 DEF bones. Upper-arm and forearm lengths are 0.690 and 0.6244. The shoulder uses a shared ten-edge opening. All ten seam edges have two adjacent faces. This establishes topology connectivity; it does not establish a correct shoulder contour or clean deformation.

The palm has more depth, grouped finger and thumb controls, and rounded ends. The wide sleeve and cuff remain. The left arm keeps the old mesh at rest, including its separate shoulder construction. The head, hair, hood, torso, and lower body were not remodelled.

## Pose assets

The file contains exactly three static pose assets:

| Asset | HoodLowered | CloakOpen | Result |
|---|---:|---:|---|
| `Trial_Rest` | 0 | 0 | Failed |
| `Trial_EyeGrip` | 0 | 1 | Failed |
| `Trial_RearPickup` | 1 | 1 | Failed |

Each asset description records the hood values, IK mode, `IK_Stretch=0`, and fixed `clavicle.R` IK and pole parents. Pose Library applies bone data; set the garment values separately. `pose_tools.apply_pose(name)` applies both for inspection.

For each asset, author-to-asset and repeated-apply evaluated Body vertex errors were **0.0**. This verifies the stored static geometry. The test did not independently perturb every custom control property.

## Check result

`trial_checks.json` records the focused checks. `failure_locations.json` records exact triangle vertex pairs and bounds. It excludes only triangle pairs with shared vertices. It does not exclude hidden regions. `TrialOppositeArm` contains all 202 unchanged source left-arm vertices, selected from their original deform weights; the checker no longer uses a coordinate heuristic.

| Pose | Arm/torso | Arm/self | Arm/garment | Hand/garment |
|---|---:|---:|---:|---:|
| Rest | 43 | 82 | 6 | 0 |
| Eye grip | 0 | 103 | 123 | 0 |
| Rear pickup | 2 | 105 | 312 | 4 |

Arm/opposite arm, hand/body, arm/head, arm/hair, cloth/self, cloth/head, and cloth/hair returned zero pairs in these three samples. This is not a full-body or motion clearance pass.

- Rest arm/torso crossings are beside the tunic, at Z 0.988–1.704. The cuff return crosses its outer sleeve at Z 0.592–0.829: the 0.279-wide inner return exceeds the 0.25-wide adjacent sleeve.
- Eye grip cloth crossings are at the upper-arm exit, Z 1.722–2.027. Rear pickup crosses the shoulder and folded cloth, Z 1.349–1.920, with two nonadjacent torso pairs near Z 1.647–1.700.
- The shared shoulder seam still has a poor contour. In the cloth views, the arm appears to emerge through the cape. The left shoulder is old, separate construction.
- The target-to-hand surface gap is 0.0130 at eye grip and 0.0366 at rear pickup. These are not completed pinch contacts.
- Pose scale channels remain unit within 1.2e-7. Evaluated DEF matrix scales differ by **3.13% at eye grip and 3.45% at rear pickup**. Generated `STRETCH_TO` constraints with `VOLUME_XZX` between tweak controls cause this. `IK_Stretch=0` does not disable those constraints. This is not a unit-scale deformation pass.

The character has **6,868 triangles**, two opaque materials (`TravellerDrawingFace`, `TravellerDrawingBody`), and one shared 1024 × 1024 atlas. Body has one Armature modifier, at most two DEF weights per vertex, and maximum weight-sum error 2.98e-8.

Run the focused report in the open trial file with its folder on Python's path:

```python
import report_trial
report_trial.run()
```

## Evidence and decision

Open `../../docs/art/traveller-rigify-trial/review.html`. It contains matching color/gray camera comparisons, three failed poses, a close uncovered shoulder view, side/rear fault views, and small display previews. The source comparison uses the original saved two-arm grip; the trial tests only the right arm. It is not a controlled rig-only comparison.

Native controls and pose storage work. The present body/sleeve construction does not. Correct the uncovered shoulder, torso clearance, and cuff lining before another hood-motion trial. Do not proceed to motion from this artifact.

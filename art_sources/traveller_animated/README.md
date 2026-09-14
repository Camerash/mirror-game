# Standing hood actions

This study uses the approved drawing model at `fcf08c5`. The prior drawing and full studies remain unchanged. The builder uses Blender 5.2.1 LTS and its native IK, shape keys, skinning, Solidify and glTF exporter. It uses no cloth simulation.

Run from the project root:

```sh
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender -b -t 4 --python-exit-code 1 -P art_sources/traveller_animated/build_study.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender -b art_sources/traveller_animated/traveller_animated.blend -t 4 --python-exit-code 1 -P art_sources/traveller_animated/check_animation.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender -b art_sources/traveller_animated/traveller_animated.blend -t 4 --python-exit-code 1 -P art_sources/traveller_animated/check_endpoints.py
rtk proxy /Applications/Blender.app/Contents/MacOS/Blender -b -t 4 --python-exit-code 1 -P art_sources/traveller_animated/check_export.py
```

`build_study.py` saves the editable blend and exports the self-contained GLB. `check_animation.py` writes the global and per-mesh local bounds in Godot coordinates. Run it before `check_export.py`, which checks those bounds against the exported geometry.

The five render meshes are `Head`, `Hair`, `Body`, `Boots`, and `Garment`. They use the existing two opaque materials and one 1024 atlas. `Head` and `Hair` are rigid children of the `Head` bone. `Garment` is a rigid child of `Chest`; its hood motion uses morphs, with no second hood bone deformation. Boots use `Foot.L/R` weights. The retained body has spine, chest, neck, head, thigh and shin weights. Only the arm bones move in these clips.

`HoodDown` and `HoodUp` each last 2 seconds. Both use a 0.4-second reach and a 1.1-second hood action. Down releases at 1.3 seconds so the hands can return while the hood settles. Up keeps contact until 1.5 seconds. Both end with concealed arms. The clips have separate authored paths and 60 Hz baked keys. The Blender file keeps the muted IK constraints and grip controls for editing; the builder reconstructs their authored paths.

The garment has eight morphs: `HoodLowered`, `HoodLift`, `HoodClear`, `HoodBack`, `HoodSettle`, `HoodTurnHigh`, `HoodTurnLow`, and `CloakOpen`. One local cape support row preserves the endpoint surface and permits the temporary front opening. The hood and its lining have fixed triangle connectivity. Native shell thickness is baked separately for the endpoints and the tight moving folds.

The checks evaluate both clips at 120 Hz, including times between baked keys. They test cloth self-intersection, cloth against head/hair/body, arms against head/hair, fixed head/hair/feet, stationary bones, unit scales, and the export limits. The exported check reads the actual glTF animation, sparse morph accessors, skin weights and inverse bind matrices. These are sampled checks, not a proof of continuous collision clearance between samples.

The grip follows the same rim material point. The measured rim-midpoint-to-skin gap is about 0.026 scene units. This is a visible-shape review limit, not exact surface contact. The wide held turn and the simple sleeve/elbow silhouette need review in the native motion view. No physical cloth area or edge-length claim is made; the approved artistic morph rule applies.

Use `render_review.py` for fixed front, side and three-quarter captures of the baked clips. Temporary frame sequences are written outside the repository. The runtime viewer and native review are owned by the main task.

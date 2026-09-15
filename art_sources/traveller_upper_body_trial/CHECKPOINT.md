# Paused upper-body trial

The saved `traveller_upper_body_trial.blend` is the authoritative checkpoint. It opens in the uncovered rest pose with no active action. Model and effort: `gpt-6-astra`, `xhigh`.

The new torso, shared right shoulder, open cuff, and hand are preserved. The left arm is unchanged. Body has 856 vertices and 1,684 triangles; the full character has 7,028 triangles. No cloak fitting, animation bake, or GLB export was done.

Body uses one Armature modifier and a local CorrectiveSmooth modifier. The latter is a Blender authoring dependency, not a verified game deformation. The final local smoothing passed the eye-pose uncovered crossing check. Rest and rear were clear before that modifier, but were not checked again after it. Cloth clearance and final grip contact remain incomplete.

The native IK stretch settings caused the prior measured DEF scale changes. With native IK stretch disabled, the measured maximum DEF scale errors were 0.000000715 (rest), 0.00000107 (eye), and 0.00000113 (rear). This supersedes the earlier cause attributed only to generated STRETCH_TO constraints. Arm reach remains 0.690 plus 0.624427.

Current direction: replace the visible elbow with a restrained continuous cartoon arm curve. Work is paused for a separate native-control trial. No new curve rig is present in this checkpoint.

The local scripts record individual edits and experiments. Do not rerun them as a rebuild pipeline: `support_elbow.py` contains a superseded weight field. The saved blend includes the retained short support weighting and local CorrectiveSmooth. Old pose assets also need renewal before any delivery claim.

Preserved source SHA-256 values:

- Prior Rigify trial: `0c360cac2633206422df852280174e24ad6674b6e19d2640aa31a4c9b2f77436`.
- Original animated source: `75472b1c77560f7ed4f9f4a83343686c4a228885e5e8065749b615b19a0ae153`.

Captures in `docs/art/traveller-upper-body-trial/` are provisional. Some show the superseded elbow crease. This is an inspection checkpoint, not a passed production asset.

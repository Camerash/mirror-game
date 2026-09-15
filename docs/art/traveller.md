# Traveller character source

`art_sources/traveller/traveller.blend` is the single source of truth for the
character. Build it with:

```sh
rtk /Applications/Blender.app/Contents/MacOS/Blender --background --python art_sources/traveller/build_traveller.py
```

The build reads `art_sources/traveller_animated/traveller_animated.blend`, keeps
the accepted assets, rebuilds the body and the arm bones, and saves the result.

## What the build keeps and what it replaces

Kept unchanged: `Garment` with its nine hood shape keys, `Head`, `Hair`, `Boots`,
the two-material 1024 atlas, and the hand assembly of 102 vertices per arm (the
folded open cuff, the hand and the thumb).

Rebuilt: the `Body` mesh and the arm bones.

## Why the body was rebuilt

The inherited body was eight overlapping shells: an 80-vertex torso box with two
arm tubes, a neck capsule, two ear capsules and two leg tubes that only
intersected it. `GAME_DESIGN.md` requires connected surfaces without overlapping
primitive shells.

The arms were also bumpy. The cause was the hand-written ring table in the old
`edit_upper_body.py`: ring spacing varied between 0.04 and 0.23 along the same
sleeve, the radius dipped to .255 and rose again before the cuff, each ring
rebuilt its frame from a world axis so orientation drifted, and the upper arm and
forearm used different axes so the frame kinked at the elbow.

## How the new body is built

- **20-column torso, 10-column limbs.** 20 = 2 x 10, so every junction is 1:1.
  Each limb hole is a 3-wide by 2-tall block of torso faces, whose boundary is
  exactly ten vertices.
- **Arms** come from four properties that cannot express the old defects: one
  smooth spine, even arc-length sampling, a monotone radius and a
  parallel-transported frame. Ring spacing is constant at 0.0994 and the radius
  falls monotonically from 0.138 to 0.118.
- **Shoulders** leave the armhole outward before turning down, so the sleeve
  clears the torso and reads as a deltoid.
- **Ears** moved to `Head`, which now has a second material slot for the body
  material. They cannot join the torso: they sit inside the head volume.

## Rig

28 bones, all deform, all exportable. Each arm has four segments:
`UpperArm`, `UpperArm.001`, `Forearm`, `Forearm.001`, each 0.298 long, with the
same roll. One rotation value on all four gives an even arc; the measured
inter-segment angles are 23.0, 22.7 and 22.7 degrees, matched on both sides.

**Bendy bones are not used.** Blender's glTF exporter has no support for them, so
a bendy-bone curve exists only in Blender and flattens on export. The continuous
curve must come from posing the four real segments.

The two-bone IK and its elbow pole target were removed. A two-bone IK bends one
elbow, which is the hinge this design rejects. `Grip.L` and `Grip.R` remain as
contact targets.

## Measured results

| check | result |
|---|---|
| Body islands | 1 (was 8) |
| non-manifold / boundary edges | 0 / 0 |
| ngons | 4, all end caps inside the accepted hand |
| self-intersections | **0** (inherited source had 567) |
| Garment clearance, hood up and down | 0 overlaps |
| max bone influences | 3 |
| rest-pose drift | 0.0 |
| triangles | 7,306 of the 8,000 ceiling |

Export and re-check the result with:

```sh
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/export.py
```

## Defects found in the inherited file

These were fixed here. They also exist in `traveller_animated.blend`.

- The file was saved mid-pose, so any rebind inherited that pose and tore the mesh.
- `Forearm.L/R` carried an IK constraint that fought a four-segment arm.
- The cuff folds back up wider than the sleeve around it, so its return wall
  poked through. The build draws it inwards.
- The torso was wider than the arms hanging beside it, so they could only ever
  intersect.

## Not done yet

- **Animation.** `HoodUp` and `HoodDown` still hold their old rotations. The arm
  bones changed, so the actions need re-authoring before they mean anything.
- **Clip length.** The actions are two seconds. `art_trial/animated_traveller_study.gd`
  and `tests/animated_traveller_tests.gd` were already changed to expect one
  second, so the viewer and the asset disagree.
- **Garment topology.** 3,332 triangles, no quads, edge lengths ranging 258:1 and
  face areas 999:1. It is 47% of the character budget and carries all nine hood
  morphs. Retopologising it is where the 6,000-triangle target is recovered, and
  it needs a shape-key transfer step.
- **Retiring the old trials.** `traveller_rigify_trial` and
  `traveller_upper_body_trial` are superseded. Remove them once this file is
  accepted.

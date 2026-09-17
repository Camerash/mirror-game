# Traveller character source

`art_sources/traveller/traveller.blend` is the single source of truth for the
character. Build it with:

```sh
rtk /Applications/Blender.app/Contents/MacOS/Blender --background --python art_sources/traveller/build_traveller.py
```

The build reads `art_sources/traveller_animated/traveller_animated.blend`, keeps
the accepted assets, rebuilds the body and the arm bones, and saves the result.

## What the build keeps and what it replaces

Kept unchanged: `Head`, `Boots`, the two-material 1024 atlas, and the hand
assembly of 102 vertices per arm (the folded open cuff and the hand).

Rebuilt: the `Body` mesh, the arm bones, the `Garment` (the cloak) and the
`Hair`. The cloak keeps its accepted shape and its eight hood keys, and gains a
ninth, `CloakArms`. The hair keeps its accepted hairline and its bun.

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

## How the cloak is built

`build_cloak.py` replaces the cloak with a quad grid, and keeps the accepted
shape by construction: it does not model the shape, it samples the old one.

- **Projection.** A ray is cast inward at each row and column and stops at the
  axis, so it reads the outer wall and never the far panel from inside. The hit
  gives the point and the atlas value together. A nearest-point search cannot be
  used: the old cloak is a double wall, so the nearest point often belongs to the
  inner wall and the painted hem border breaks up.
- **The hem border follows the hem.** The hem falls from z 0.241 at the sides to
  0.193 at the front. The first two rows follow each column's own hem, so one
  face row carries the whole border and its atlas gradient stays unbroken.
- **The openings are real openings.** The front split is a true gap in the old
  cloak, 0.008 wide at the clasp and 0.050 at the hem. A ray down the front
  centre passes through it and finds nothing, which is what leaves the grid open
  there. Nothing is welded and then torn.
- **Opening edges sit on the real rim.** Every row of one opening is widened to
  the same columns first, because a row that stops one column short of its
  neighbour loses the cell between them and leaves a tooth in the rim. Each row's
  edge vertex is then found by bisection on the true rim angle.
- **Shape keys move across by barycentric position** on the old triangles, so
  large movement such as the hood folding down (2.1 units) stays correct. A new
  key does not reliably start at zero, so each one is set to zero explicitly.

## How the hair is built

`build_hair.py` replaces the hair cap. The inherited cap was a smooth
double-walled helmet: 964 triangles, 10 ngons, two 28-valence poles at the crown,
one flat atlas point and no shape.

- **The style comes from the accepted Low bun**, `HairCap.Bun` in
  [the painted bust study](../../art_sources/traveller_painted/traveller_painted_study.blend),
  whose direction is recorded in [study 02](traveller-hair-study-02.md). The head
  has changed shape since then, 1.360 tall and 0.980 deep against 1.080 and
  0.850 now, so the style is read in each head's own frame and re-fitted rather
  than copied vertex for vertex. Nothing about the shape is invented here.
- **The cap is fitted to the skull.** Every sample is a ray cast out of the
  head's centre onto the head itself. The ear islands are left out of that cast:
  a ray that hit an ear would stand the cap 0.08 further out and bulge over it.
- **The hairline is found by casting at the accepted silhouette** and bisecting
  for the angle where the hair stops. Reading it as the lowest hair vertex per
  azimuth does not work: near the face one bin holds both the edge of the face
  opening and the side hair behind it, so the lowest wins and drags a wedge down
  the cheek.
- **The volume is measured, not carved.** Each sample takes its offset from the
  accepted hair along the same ray, then the field is blurred twice. Carving the
  locks with a wave was guesswork and read as nothing; the raw measured field
  keeps the study's own step at the side lock and folds the cap at 159 degrees.
  Blurring keeps the volume and loses the crease.
- **The lock tufts are swept off the cap's own hairline** and taper to a point,
  by the same ring method the arms use. Each shares its first ring with the cap,
  so the hair stays one island. A lock stops above the shoulders, is not grown at
  all where there is no room, and never crosses the face, where the window is
  narrow enough that any tuft falls across an eye.
- **The borrowed datablocks are purged.** Loading objects from the study pulls
  in their meshes and materials, and left behind they sit in the saved file with
  no users. The purge runs after the new mesh is on the object, because until
  then the new mesh has no users either.

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
| Cloak triangles | 1,720 (was 3,332) |
| Cloak quads | 97% (was 0%) |
| Cloak edge / face ratios | 27:1 and 71:1 (were 258:1 and 999:1) |
| Cloak clearance, all nine keys | 0 overlaps |
| Hair triangles | 728 (was 964) |
| Hair ngons / crown poles | 0 / none (were 10 / two 28-valence) |
| Hair against the hood, all nine keys | 0 overlaps |
| Hair against the body | 0 overlaps |
| Hair against the head | 44, all of them the ears (was 136, 6 of them not) |
| triangles | 5,326, under the 6,000 target |

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
- **The arm cannot leave the cloak above the chest.** `CloakArms` pushes the
  cloth out along its own normal over the sector and the heights a reaching arm
  passes through. It removes every crossing at the lowest waypoint (48 to 0) and
  lowers the rest. It cannot clear the upper arm, which starts at the shoulder
  under the cloth: at the collar and the hood rim, 47 and 50 arm/cloth triangle
  pairs remain. Movement that slides the cloth around the body was measured at
  swings from 25 to 95 degrees and is worse in every case, because the cape is
  fitted to the body with no margin. Full clearance needs the front panels
  weighted to the arm bones, which belongs with the animation work.
- **The hair still simplifies the accepted style.** 32 columns by 8 rings cannot
  hold the study's separated side lock, so the cap reads its volume as a swell
  rather than a parted lock. The fringe, the forehead line and the back volume do
  carry across. Going further means more rows and columns at the side, or the
  side lock built as its own tuft aimed at the study's own measurement.
- **Retiring the old trials.** `traveller_rigify_trial` and
  `traveller_upper_body_trial` are superseded. Remove them once this file is
  accepted.

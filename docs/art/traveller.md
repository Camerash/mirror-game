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
- **Opening edges sit on the real rim.** Each row's edge vertex is found by
  bisection on the true rim angle, searching up to four columns out, because
  where an opening narrows quickly the rim is several columns from the last
  vertex that found cloth.
- **Rows of different width are stitched, not squared.** A row that reaches a
  column its neighbour does not gets a triangle instead of a quad. Widening every
  row of an opening to the same columns also closes the surface, but it forced
  the hood's face opening to stay as wide at its top as at its middle: 74 degrees
  where the truth is 38, which squared off its corners.
- **An opening's apex is capped by a fan, and only its apex.** A cell needs
  three of its four corners to become a triangle, so where an opening ends, the
  columns in the middle of it have two corners and nothing is built: the hood's
  opening finished in a spike with a hole beside it. The gap is a polygon between
  two rows, and each half of it is fanned to its own corner. The cap is limited
  to gaps two columns wide: the hood's opening also *starts* against cloth, 55
  degrees wide over 0.01 of height, because a horizontal ray cannot see the
  collar's near-horizontal top, and fanning that bridged the whole throat with a
  flat triangular patch. Fanned to one corner it comes out
  as a long thin sheet and creases the throat at 121 degrees, against 116 in the
  old cloak.
- **An opening lets go of the rim gradually, in both directions.** The snap only
  touches rows inside an opening, so the first full row beyond it sat back at the
  plain column angle and the surface stepped there: the chest creased at 154
  degrees and the hood's top corners at 134. Two corrections, and no new
  geometry. Outward, the edge's shift carries into the next rows beyond the
  opening and falls to zero. Inward, the edge backs off the rim in the last rows
  of an opening, but only where the opening closes against cloth, never at the
  hem, where the split is genuinely 0.05 wide and backing off would widen it.
  The columns inward of an edge also take a share of its travel, so cell widths
  grade instead of putting a sliver beside a wide quad.
- **The border is one level ribbon.** Its height above the hem and its two atlas
  rows are the same at every column. Read per column instead, the old border's
  own zig-zag top landed at atlas row 0.105 in most columns and 0.037 in a few,
  and those lost the dark-light-dark gradient and read as patches. The atlas
  rows carry one colour across their whole width, so u holds nothing here and
  only v had to be fixed. The zig-zag is lost; at 24 columns it was being
  sampled at an arbitrary phase anyway.
- **The clasp is kept out of the split's widening.** Its lower half sits inside
  the split's own height range, and widened with it the brooch came out pulled
  sideways rather than round.
- **The clasp is built, not copied.** A small faceted brooch sits at the throat,
  where the front opening is held shut. Its rim is cast onto the new cape a point
  at a time, so it follows the curve instead of floating off it at the sides, and
  it sets its own normals because it is an open shell with no volume for the
  solver to work from. It takes the hem border's own dark blue, so the trim and
  the clasp match and the atlas is unchanged. 24 triangles, its own island, and
  the hem lip skips its rim so no cloth-coloured collar wraps it.
- **The collar yoke keeps its shape and loses its paint.** It is eight old
  triangles on the front centre plane, a flat V panel welded into the old shell.
  Its four corner points read as cloth, but the atlas rows between them hold a
  painted dark diamond, and a grid vertex landing at v 0.22 takes (0.19, 0.29,
  0.36) and paints a bar across the chest. Its geometry cannot be copied across
  either, at any offset: 0.034 proud its edges draw a hard V, and flush it cuts
  through the cape it sits on. So the grid samples its shape like the rest of the
  surface, skips its atlas band, and the chest is relaxed so the step a grazing
  ray leaves does not read as a ledge. The clasp is modelled instead.
- **The front split is widened after the keys, not before.** Moved in the basis
  alone, the sideways shift becomes part of every key's offset and `CloakOpen`
  swings it into the chest: 30 overlapping triangles at z 1.71 to 1.84. Applied
  to the basis and to each key together, the widening is the same in all of them
  and cannot rotate.
- **The cloth has no thickness.** It is a single sheet, which is what cloth is,
  and it keeps the animation simple. Every hard fold in the cloak was the lip
  that used to give it thickness: the sharpest angle anywhere falls from 165
  degrees to 58 with the lip gone, and 162 triangles go with it. Its material
  must draw both sides; `TravellerDrawingBody` already does, and the export
  carries `doubleSided`.
- **The split is a line, not a gap.** The character drawing shows the front as a
  single line from the clasp to the hem, parting only at the feet, so it runs
  0.030 under the brooch to 0.095 at the hem. Widening it does not help it read:
  over the chest the body behind is the same blue-grey as the cloak, so a gap has
  nothing to read against, and at 0.105 wide it still looked shut. A painted
  facing draws it, but a band wide enough to see reads as a stripe rather than an
  opening.
- **The front split's width is set outright.** It opens at the clasp and widens
  as it falls: 0.038 under the brooch to 0.095 at the hem. Held to the old
  cloak's own rim it reads as shut, because that rim is 0.008 wide at the clasp,
  and the wide dark chest in the old renders is not an opening at all: it is the
  hood's shadow, which disappears when the lights are set to cast none. The old cloak's own
  split is not even, because its panels wander, and held to the measured rim the
  new one inherits that wobble: 0.109 at the hem, 0.001 at z 1.40 and 0.021 again
  at the clasp. Closing the narrow rows instead sewed the cloak shut over the
  chest. Setting the angle does not work either, because a ray crosses the panel
  wherever the panel happens to be, so the angle and the gap are not the same
  measure; the edge's own x is set, and the panel is flat enough across the front
  to carry it. The split is also never capped at its top, because it should reach
  the clasp, and a cap there is a sliver folding at 179 degrees. The hood's apex
  sits on the front centre too, so the two are told apart by height.
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
| Cloak triangles | 1,745 (was 3,332), including a 48-triangle clasp |
| Cloak quads | 95% (was 0%) |
| Hood opening width against the true rim | within 4 degrees at every row |
| Cloak edge / face ratios | 21:1 and 144:1 (were 258:1 and 999:1) |
| Cloak sharpest fold | 58° (the old cloak's was 116°) |
| Front split, clasp to hem | 0.038 widening to 0.095 |
| Cloak islands | 2: the cape and the clasp |
| Hood shell folds | p90 23°, max 50° (were 35° and 92°) |
| Chest fold / hood corner fold | 109° and 93° (were 154° and 134°) |
| Cloak clearance, all nine keys | 0 overlaps |
| Hair against the cloak | 0 overlaps |
| Hair triangles | 728 (was 964) |
| Hair ngons / crown poles | 0 / none (were 10 / two 28-valence) |
| Hair against the hood, all nine keys | 0 overlaps |
| Hair against the body | 0 overlaps |
| Hair against the head | 44, all of them the ears (was 136, 6 of them not) |
| triangles | 5,351, under the 6,000 target |

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
- **The front line does not reach the brooch.** The split's hole runs right up
  under the clasp, measured at z 1.834 against the brooch's 1.722 to 1.878, but a
  scan of the render shows the line only becoming solid at z 1.366. Over the
  chest the body behind the opening is the same blue-grey as the cloak, so a gap
  there has nothing to read against, at any width: 0.105 looked as shut as 0.038.
  Drawing it the whole way needs a painted band on the outward faces beside the
  split, and to keep that band thin the grid needs extra columns at the front:
  the nearest column is 15 degrees away, which is 0.09 of cloth.
- **The hem border no longer zig-zags.** The old border's top edge stepped up
  and down around the hem. Levelling it was what stopped the band breaking into
  patches. Bringing the zig-zag back needs enough columns to sample it in phase,
  which means raising `COLUMNS` from 24 to about 48 and roughly doubling the
  cloak's cost.
- **The collar yoke reads as a soft step.** The old cloak shows a dark diamond at
  the chest, which is the yoke's own shape catching the light. The grid samples
  it as a gentle swell instead. The clasp now carries that read, so the yoke is
  left alone; sharpening it would mean building it into the grid as real rows and
  columns following its V edges.
- **The hair still simplifies the accepted style.** 32 columns by 8 rings cannot
  hold the study's separated side lock, so the cap reads its volume as a swell
  rather than a parted lock. The fringe, the forehead line and the back volume do
  carry across. Going further means more rows and columns at the side, or the
  side lock built as its own tuft aimed at the study's own measurement.
- **Retiring the old trials.** `traveller_rigify_trial` and
  `traveller_upper_body_trial` are superseded. Remove them once this file is
  accepted.

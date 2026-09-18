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

The cloak's shape lives in `cloak_profile.py` as curves measured once off the
accepted cloak. `build_cloak.py` only turns those curves into a mesh: no ray
casting at build time, and nothing to correct afterwards.

The generator this replaced projected a grid onto the inherited mesh with a ray
per vertex, and **336 of its 921 lines did nothing but correct the result**.
Every fault came from that. A horizontal ray cannot see a near-horizontal rim,
so the hood's throat jumped from closed to 55 degrees wide over 0.01 of height.
The old split wanders, 0.008 at the clasp and 0.001 at z 1.40, so following it
gave a slit that pinched in the middle. A grazing ray on the collar yoke left a
step that read as a bar across the chest.

- **An opening is a gap in the row's own spread of columns**, not a set of absent
  cells. Each row spreads its columns over the cloth that row has, so the first
  and last land exactly on the opening's edge and every cell between is the same
  width. That one change removed the snapping, tapering, easing, squaring,
  stitching and relaxing.
- **An opening closes on one vertex.** A row with no opening beside a row that
  has one is its *apex*: it takes the open spread with nothing removed, so its
  first and last column land on the same angle and share a vertex. The cells
  around them meet there in a fan. Treated as a shut row instead, its columns
  stay 15 degrees apart, so the opening bottoms out on a flat edge half a cell
  off centre. Three apexes exist: the top of the hood's face, its foot at the
  gem, and the top of the front seam.
- **The band across the front is left out wherever a row beside it is open.** An
  apex is inside the opening it closes, so one open row either side is enough.
  Judging it by the opening's width instead sews the cloak shut, because the
  front seam never exceeds 2 degrees.
- **The front split is authored, not followed.** It starts at a point under the
  brooch and opens quickly, which is the shape the user cut by hand. The accepted
  cloak is no guide for it: its own panels wander.
- **The hood's opening runs to the gem.** It falls from 27 degrees at the throat
  to a point at 1.88, which is 0.010 above the gem's top edge, so the gem covers
  where the two edges meet. It used to stop on a flat bib across the throat. See
  [the throat](traveller-cloak-review/throat_to_the_gem.png).
- **The hood's rim carries its own radius.** It curls inward, so it is measured
  rather than read off the cloth beside it. Only the hood proper: below 2.145 the
  opening is a plain cut, so its edge follows the cape's own front radius.
- **The gem reads its seat off the profile, not off the mesh.** It used to cast a
  ray per corner. Its lowest corner sits on the middle of the front, and once the
  seam came together that ray went down the pinch and out the other side, so the
  gem vanished. The profile answers everywhere, including where there is no cloth
  to hit.
- **The border's two rows share one spread of columns.** Distributing each at its
  own height gave them different angles, and the band ran 0.016 to 0.230 tall
  instead of an even 0.145.
- **The paint is authored too.** The atlas is a flat palette, so the cloth is one
  texel, the border is its two rows, and the clasp takes the border's dark blue.
  No UV is sampled, so no lookup can land on the wrong wall.
- **The front seam is a real opening, and nothing draws it.** The two panels
  nearly touch: 0.012 apart under the brooch and 0.036 at the hem, which is 1.1%
  of the cloak's width falling to 2.4%. It is dark without paint or a filler,
  because the space behind it is 0.22 deep at the chest and 0.57 at the legs, so
  a slot this narrow lets in almost no light and the near edge hides it from any
  angle but head on. Measured down the render it runs 29 to 49 of 255, against
  cloth at 96 to 121. See [the line](traveller-cloak-review/seam_line.png).
- **The opening has to stay real**, because the arms come out through it.
  `CloakOpen` parts the panels from 0.012 to 0.147 with no drift of the centre,
  and the seven hood keys leave the opening alone.
- **Two attempts to draw the seam are recorded here, because both failed.** A
  band over the cloth each side made the gap easier to see, but the gap still
  showed the body in the cloak's shadow, so the seam read as three tones: 83
  each side of a core at 41, over cloth at 116. That core was shadow, not paint,
  and a flat light drew it *brighter* than the cloth
  ([capture](traveller-cloak-review/seam_three_tones.png)). Filling the gap with
  the band's dark made it one colour but left the band's 0.034 of padding, which
  does not taper, so the seam held a near constant 10.5% of the cloak at every
  height and read as a strap. The width was never a decision; it was the sum of
  two workarounds.
- **The cloth has no thickness.** It is a single sheet, which also keeps the
  animation simple. Its material must draw both sides; `TravellerDrawingBody`
  already does, and the export carries `doubleSided`.
- **Shape keys move across by barycentric position** on the old triangles. The
  curves are fitted to the accepted cloak, so the new surface stays near it:
  measured, the median vertex sits 0.003 to 0.005 from the old surface.

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
| Cloak triangles | 1,386 (was 3,332) |
| Cloak quads | 95% (was 0%) |
| Hood opening width against the true rim | within 4 degrees at every row |
| Cloak edge / face ratios | 9:1 and 64:1 (were 258:1 and 999:1) |
| Cloak sharpest fold | 40° (the old cloak's was 116°) |
| Cloak generator | 560 lines over two files (was 921) |
| Front seam, brooch to hem | 0.012 widening to 0.036, a real opening |
| Front seam under `CloakOpen` | 0.147, centre drift 0.000 |
| Cloak islands | 2: the cape and the gem |
| Gem | seven sides, lone corner at x 0.0000 z 1.7220, straight down |
| Hood shell folds | p90 23°, max 50° (were 35° and 92°) |
| Chest fold / hood corner fold | 109° and 93° (were 154° and 134°) |
| Cloak clearance, all nine keys | 0 overlaps |
| Hair against the cloak | 0 overlaps |
| Hair triangles | 728 (was 964) |
| Hair ngons / crown poles | 0 / none (were 10 / two 28-valence) |
| Hair against the hood, all nine keys | 0 overlaps |
| Hair against the body | 0 overlaps |
| Hair against the head | 44, all of them the ears (was 136, 6 of them not) |
| triangles | 4,992, under the 6,000 target |

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
- **The hem border no longer zig-zags.** The old border's top edge stepped up
  and down around the hem. Levelling it was what stopped the band breaking into
  patches. Bringing the zig-zag back needs enough columns to sample it in phase,
  which means raising `COLUMNS` from 24 to about 48 and roughly doubling the
  cloak's cost.
- **The hood is still fitted, not authored.** Its profile tables are measured off
  the accepted cloak, which is what keeps the eight hood keys working: the new
  surface sits a median 0.003 from the old one, with a worst case of 0.039 at the
  crown. Authoring the hood outright would need those keys re-made.
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

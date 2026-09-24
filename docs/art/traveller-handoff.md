# Traveller handoff

Written at `b915740` on branch `traveller-single-source`. Read this before you
change the Traveller mesh or its animation. It records what is done, what is
open, how to prove a change, and which approaches are already measured and
failed.

## Where things stand

The character has one source: [`art_sources/traveller/`](../../art_sources/traveller/).
It opens `art_sources/traveller_animated/traveller_animated.blend` as its mesh
upstream and rebuilds everything from Python.

- The mesh is accepted at tag **`traveller-mesh-v1`** (`46a632c`).
- The two hood clips are authored and pass. 4,992 triangles, 1.000 s each.
- **The walk is authored.** One looping second, and the three cloak
  deformations the design asks for, driven and damped in the study viewer.
- `assets/character/traveller.glb` is the export. **Gameplay loads it**: the
  walker and the fall ghost are the skinned traveller, running its own walk
  cycle with the three cloak deformations damped against movement and turning.
- `assets/character/ceramic_traveller.glb` was removed in `b1d2b6d`.

| check | result |
| --- | --- |
| `animated_traveller_tests` | 281 checks, 0 failures |
| `gameplay_art_tests` | 62 checks, 0 failures |
| `check_walk` | 4 of 4 pass |
| `drawing` / `full` / `painted` / `ceramic` | 90 / 92 / 137 / 14, all 0 failures |
| `run_tests` (gameplay) | 0 failures. The check count varies run to run, 521 to 524; this is not new |
| Export | PASS, no missing animation targets |
| Wrist on its authored path, both clips | error 0.0000 at every frame |
| Hem travel under a 2 degree chest turn | 0.0000 |
| Cloak | 1,386 triangles, 0 ngons, sharpest fold 39.9 degrees |
| `check_clearance` | **FAIL.** Arms cross the cloak on 58 of 61 frames, both clips |

## How to build and prove a change

Run every one of these from the project root. Do not report a change as good
until all of them pass.

```bash
rtk /Applications/Blender.app/Contents/MacOS/Blender --background --python art_sources/traveller/build_traveller.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/review_mesh.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/export.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/bounds.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/check_clearance.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/check_walk.py
rtk /Applications/Godot.app/Contents/MacOS/godot --headless --path . --editor --quit
rtk /Applications/Godot.app/Contents/MacOS/godot --headless --path . --script tests/animated_traveller_tests.gd
rtk /Applications/Godot.app/Contents/MacOS/godot --headless --path . --script tests/run_tests.gd
```

`build_traveller.py` prints its own checks. Watch these lines:

- `### rest-pose drift (must be ~0)` must stay `0.0`.
- `### cloak: merged 0 vertices by distance` must stay `0`.
- `### clips {'HoodDown': 0.0, 'HoodUp': 0.0}` is the wrist error. Any other
  number means the hand does not reach its authored point.

## How the source is built

Each part is a pair: the shape as data, and a generator that makes the mesh.
Keep that split. It is what removed 336 lines of correction code.

| file | holds |
| --- | --- |
| [`cloak_profile.py`](../../art_sources/traveller/cloak_profile.py) | the cloak's shape as fitted curves |
| [`build_cloak.py`](../../art_sources/traveller/build_cloak.py) | turns those curves into the mesh |
| [`hood_motion.py`](../../art_sources/traveller/hood_motion.py) | the hood clips as data: phases, wrist path, tilts, morph weights |
| [`walk_motion.py`](../../art_sources/traveller/walk_motion.py) | the walk cycle as data: leg angles, pelvis channels, counter-turns |
| [`build_animation.py`](../../art_sources/traveller/build_animation.py) | turns that into actions and NLA tracks |
| [`skin_body.py`](../../art_sources/traveller/skin_body.py) | weights for the body and the cloak |
| [`bounds.py`](../../art_sources/traveller/bounds.py) | the sampled culling box the viewer needs |
| [`check_clearance.py`](../../art_sources/traveller/check_clearance.py) | arm against garment, at every frame of both clips |
| [`check_walk.py`](../../art_sources/traveller/check_walk.py) | the walk: it loops, it clears the cloth, it holds the design's caps |

Two rules that hold the whole thing together:

- **An opening is a gap in each row's own spread of columns.** The row spreads
  its columns over the cloth it has, so its edges sit on the opening's curve. An
  apex row shares one vertex, so an opening closes on a point.
- **The arm is a circular arc.** All four arm segments share one roll axis, so
  turning them by the same angle makes an arc. The chord shortens with that
  angle, so one bisection finds the angle that reaches the wrist. Do not add
  inverse kinematics. The rig has none, and bendy bones do not survive export.

## Open work, most useful first

1. **The arms cross the cloak, and the user has rejected it.** Prove any change
   with `check_clearance.py`. It is 78 to 374 triangle pairs on 58 of the 61
   frames of each clip, both clips.

   The cause is the garment, not the motion. The cape is a closed cone fitted to
   the body with 0.066 of clearance at the shoulder and no armhole. A raised arm
   has to leave through the wall, and the wall is continuous: crossings start 8
   degrees above the idle pose, and swept over azimuth, elevation and reach, no
   reachable wrist target is clear. The floor is 72 to 94 pairs at every raised
   pose, and it is always the upper arm against the cape at z 1.76 to 2.06.

   All four mechanisms that leave the resting shape alone are measured and
   failed; they are in the list below. What is left changes the garment: give
   the cape enough radius to hold a raised arm, give it armholes or end it above
   the elbow, or drop the two-handed grip and move the hood without the hands.
   The user owns that choice.
2. **The gait is authored, but only the study drives it.** One looping second
   on `Walk`, plus `CloakSide`, `CloakForward` and `CloakTwist`, damped in
   `art_trial/animated_traveller_study.gd`. Gameplay drives none of it, because
   gameplay still loads the old character; see the next item.

   Two numbers to keep in mind if you change it. **Only `Pelvis` reaches the
   cloak's hem** - `Spine` and `Chest` move the waist and leave the hem at
   exactly 0.0000, because `skin_body.cloak` clamps the lower bands to
   `Pelvis`. And **the pelvis over-drives the hem**: two degrees of lean moves
   it 0.0291 against a budget of 0.032, and two degrees of twist moves it
   0.0417, which is already over. That is why the pelvis angles in
   `walk_motion.py` are near one degree. `check_walk.py` measures the gait's
   own hem sway against the cap, so it will tell you if you push them.

3. **The old character is gone.** `assets/character/ceramic_traveller.glb`, its
   atlas, and `art_sources/character/build_ceramic_traveller.py` were removed
   in `b1d2b6d`.

4. **Remove `CloakArms`.** It is a morph that nothing drives. See the failed
   approaches below for why it cannot be used. Removing it drops the cloak from
   nine morph targets to eight and removes `add_arms_key` from `build_cloak.py`.
5. **The retired two-second study's files are gone.** `assets/character/traveller_animated.glb`,
   its bounds sidecar, and the three `*_checks.json` reports in
   `art_sources/traveller_animated/` were removed in `b1d2b6d`.
6. **The two old trials are gone.** The Rigify trial and the upper-body study
   were removed in `b1d2b6d`, resolving the disagreement `GAME_DESIGN.md` used
   to carry between keeping the Rigify trial for review and removing both once
   this source was accepted.
7. **The hood is fitted, not authored.** Its profile tables are measured off the
   accepted cloak. That is what keeps the eight hood keys working, median 0.003
   from the old surface, worst 0.039 at the crown. Authoring the hood outright
   means re-making those keys.

## One file that belongs to the user

`art_sources/traveller_animated/traveller_animated.blend` belongs to the user.
The build reads it, so the current asset depends on it. Do not change or commit
it without asking. `art_sources/traveller/traveller_esmond_split.blend`, the
user's hand edit of the front seam, was removed in `b1d2b6d`.

## Approaches that are already measured and failed

Do not repeat these. Each cost real time.

- **Weighting the cloak's front panels to the arm bones.** Tried to stop the
  arms crossing the cloth. It measured *worse*: 147 crossings against 139 at the
  moment of contact. It cannot work. The arm turns by its whole angle and cloth
  on a share of it turns by less, so the arm overtakes the cloth however the
  share is set. The reason is written into `skin_body.cloak`.
- **Weighting the cloak's shoulder cap to the deltoid**, the way the body's own
  shoulder ring is weighted. This is a different region from the front panels,
  so it was worth one measurement. It removes nothing at any radius or share,
  and it breaks the resting pose: the arm rests 78 degrees down from the bind
  pose, so cloth that follows `UpperArm` swings down with it and collapses into
  the body. At radius 0.60 and share 0.85 the idle pose goes from 0 crossings to
  76.
- **Parting the front wider during the reach.** The opening turns the panels
  about the up axis, so a wider swing sweeps cloth *around* the body and into
  the arms. Measured over both clips at 19, 30, 40, 50, 60 and 75 degrees, the
  worst frame grows from 374 to 452 and the number of crossing frames never
  moves off 116. `build_cloak` already records the same effect against the
  chest; it holds against the arms as well.
- **Cutting armholes in the cape.** Built, measured and **rejected on the
  look**, at `4742501` and `adaf41e`, both reverted. It *worked*: the cape came
  out clear at every frame of both clips, with the wrist path re-routed through
  the corridor that measures clear and the grip moved outboard of the hood's
  lower rim. It is the only thing tried that cleared the cape.

  It was rejected because of what it costs to look at. The hole cannot be
  small: the arm is anchored 0.282 out on a cape of radius 0.47, so near the
  shoulder it subtends a wide angle, and the hole has to run from 30 to 120
  degrees off the front at shoulder height. At that height the cape is then a
  front bib and a back panel, which reads from the side as an open-sided
  garment rather than a cloak.

  It also did not finish the job. Lowered, 229 of the hood's 312 vertices fall
  into the arms' own band at z 1.60 to 2.10 and wrap from 29 degrees off the
  front round to the back, so the folded hood covers the holes and the arms
  still crossed it on 31 of the 122 frames. Clearing that needed either a
  re-authored `HoodLowered` or a tenth morph.

  Do not rebuild this without the user asking for it by name.
- **A clearance morph fitted to the arms' own swept envelope.** Not the same as
  `CloakArms`, which pushed the whole garment out over a band 2.5 tall. This one
  is fitted, pass by pass, to the measured envelope of both clips. It does not
  converge: after four passes it still leaves 50 of the 122 frames crossing,
  and by then it moves 542 of the cloak's 733 vertices by up to 0.398. A morph
  moves a vertex along one fixed path, and the arm passes on both sides of the
  cloth it has to clear.
- **Driving `CloakArms`.** At 1 it splits the garment open and the legs show
  through, and the crossings it exists to remove do not move.
- **Holding the hood's rim all the way down.** Folded, the rim is 0.42 of the
  arm's reach from the shoulder. An arc of one curvature only gets that close by
  turning 68 degrees at every joint, which is a coil. The hands release early
  instead.
- **A grip at eye height.** Eye height is z 2.73. The highest rim point a hand
  can hold is z 2.48, because the arm reaches 0.663 and the rim runs 0.414 to
  1.294 away.
- **Painting the seam with the cloth beside it.** The nearest column is 15
  degrees away, so a 0.09 band reads as a stripe.
- **Leaving the front opening wide and unfilled.** The gap then draws the body in
  the cloak's own shadow, which is near black under these lights and *brighter*
  than the cloth under a flat one.

## Traps in the tools

These are not obvious and each one produced a wrong answer at least once.

- **`ortho_scale` spans the render's longer side, not its width.** Read every
  measurement off a square render, or every width is wrong by the aspect ratio.
- **Blender 5 actions are slotted.** `action.fcurves` does not exist. Walk
  `action.layers` to `strips` to `channelbags` to `fcurves`, and set
  `animation_data.action_slot` after you assign an action, or nothing plays.
- **`rtk grep` reads the working directory, not a pipe.** Use `rtk proxy grep`
  when the input comes from a pipe or a redirect.
- **The bounds sidecar gates the viewer tests.** Any change to a clip's poses
  needs `bounds.py` run again, or `check_bounds` fails on poses that are fine.
- **The tests ban the substring `root` in any track path**, case-insensitive,
  along with leg, foot, toe, boot, pelvis, hip, thigh and shin. A bone named
  `Root` in a clip fails the check.
- **Every morph except `HoodLowered` must read 0 at both ends of both clips.**
- **`pose_idle` at 78 degrees is the pose the garment is fitted to**, not the
  bind pose. The bind pose is a T-pose, and in it the arms stick through the
  cloak, which is where the standing 82 crossings come from. At idle it is 0.

## Where to read more

- [The source notes](traveller.md) hold the mesh decisions and the measured
  results table.
- [The animation notes](traveller-animation.md) hold the clip specification, the
  current result, and the three recorded departures from it.
- [The retired pipeline's README](../../art_sources/traveller_animated/README.md)
  says why the old animation code could not be kept.

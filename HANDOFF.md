# Handoff — MVP tutorial

Written at `607bd05`, updated at the block-set and stage-sweep work. Read this
before you change a level, the character, the block look, or the level sequence. It records what is done, what is blocked, what was already
measured and failed, and which traps cost real time.

## Your task, in order

0. **The user's next request is the block look.** Make the ceramic block
   texture and its markings more impressive. Iterate on the one block set in
   `world/block_set.gd`, `world/ceramic.gdshader` and `world/porcelain.gdshader`,
   and judge every change in the block gallery (see "The block set and the
   gallery" below). The user asked for this before the tutorial work.
1. **Iterate the stage design through the tutorial.** The tutorial does not
   exist yet as a sequence. Three puzzles exist and two control verbs are still
   taught nowhere.
2. **Wire a consistent MVP: the whole tutorial, start to finish.** One
   continuous run, not a menu of rooms.
3. **Only then refine the gameplay style and the design.**

Do not reverse that order. The style work is the cheapest to redo and the
sequence work is what the design record is waiting on.

## Read first

| file | why |
| --- | --- |
| `GAME_DESIGN.md` | the design record. Agreed rules are separate from proposals and open questions. Update it when the user confirms a decision |
| `AGENTS.md` | working rules, the Blender workflow, and the check policy. It says to use the smallest useful check while exploring |
| `docs/art/traveller-handoff.md` | the character in detail, including every failed approach |
| `VALIDATION.md` | what has actually been checked, and on what |

## What the game is

A calm spatial puzzle about discovery and cheap experiments. The character
starts in an original world. One bounded mirror panel, 1 to 6 units a side and
3x3 by default, selects the source geometry inside its rectangular aperture and
replaces the destination column. The column has unlimited depth along the panel
normal and both sides clip at the plane. The reflection is real, walkable,
collidable geometry, and it is how you reach places an ordinary path cannot.

Absolutes are one shared object across both worlds. A mirror cannot copy, move
or cut them, so they are the stable ground. Gravity always points down.
Deactivating a mirror removes its reflections and restores the original
geometry it replaced. Previews, undo, cancel and reset keep experiments cheap.

**One mirror at a time, today.** Multi-mirror is intended, but the rules for
order, depth, overlap, dependency and recursion are not agreed. The user has
said that if it proves too hard or too costly it may be limited to predefined
stages or cutscenes. **So the core sequence must work with one mirror.**

## State: the character

### Modelling — done

One source, `art_sources/traveller/`, rebuilt from Python. It reads
`art_sources/traveller_animated/traveller_animated.blend` as its mesh upstream.

- 4,992 triangles for the whole character, against a 6,000 target and an 8,000
  ceiling. The cloak is 1,386, against a 1,500 cap.
- One 1024 atlas, two opaque materials, 26 bones, at most 4 influences a vertex.
- 0 self-intersections and rest-pose drift 0.0. The cloak is 95 percent quads
  with no ngons; across the whole character quads run 81 to 98 percent and there
  are 6 ngons, 2 in the body and 4 in the boots.
- Accepted at tag `traveller-mesh-v1` (`46a632c`) and unchanged since.

### The walk — done

One looping second at 60 fps, authored as data in `walk_motion.py` with the
generator in `build_animation.py`. `Root` is never touched, so gameplay keeps
ownership of position. No arm swing, as the design asks.

Three cloak deformations, `CloakSide`, `CloakForward` and `CloakTwist`, carry no
keys in any clip. `world/character_visual.gd` drives them from movement and
turning and damps them on a 0.18 s half-life, because cloth lags and a bone
cannot: a bone turns the cloth with it at the same instant. Each reads its own
cap at a weight of 1, so clamping the weight is the whole of clamping the
deformation and the runtime needs no geometry.

**Two measurements constrain any change here.** Only `Pelvis` reaches the
cloak's hem; `Spine` and `Chest` move the waist and leave the hem at exactly
0.0000, because `skin_body.cloak` clamps the lower bands to `Pelvis`. And the
pelvis over-drives it: two degrees of lean moves the hem 0.0291 against a budget
of 0.032, and two degrees of twist moves it 0.0417, which is already over. That
is why the pelvis angles are near one degree. `check_walk.py` measures the
gait's own hem sway against the cap and will tell you if you push them.

### In gameplay — done

`world/character_visual.gd` loads `assets/studies/traveller.glb` for both the
walker and the fall ghost. It scales the model to the walker's capsule, runs the
walk at the speed the character is moving, and damps the cloak. It poses nothing
by hand, because the asset carries the feet and the cloth. Standing holds the
cycle where the legs pass; airborne holds still; paused freezes; a frame gap
longer than 0.1 s is cut rather than paid back.

The traveller shows on every stage. The old ceramic traveller and every earlier
study were removed in `b1d2b6d`; git history keeps them.

### Hood and unhood — partial, and blocked

Be precise about what is wrong here, because the obvious reading is wrong.

**The clips are fully authored, arms and hands included.** `HoodDown` and
`HoodUp` are 1.000 s each and animate 15 nodes, 8 of them arm and hand bones.
The hands reach out, grip the hood's rim, move it, release and return. The wrist
lands on its authored path at **every frame of both clips, error 0.0000**. The
hood itself moves through eight authored morph targets.

**What is unresolved is that the arms pass through the cloak.** Measured at
every frame by `check_clearance.py`, it is 78 to 374 triangle pairs on **116 of
the 122 frames**. So the clips cannot ship with their hand movement as authored.

The cause is the garment, not the motion:

- The cape is a closed cone fitted to the body with **0.066 of clearance at the
  shoulder and no armhole**, so a raised arm has to leave through the wall and
  the wall is continuous.
- Crossings begin **8 degrees above the idle pose**. Swept over azimuth,
  elevation and reach, **no reachable wrist target is clear**; the floor is 72
  to 94 pairs at every raised pose.
- The intended motion in `GAME_DESIGN.md` is hands emerging through the front
  split, widening it, and pulling the hood. The split is 0.006 to 0.020 half
  width. **Nothing that was tried could open it enough.**

**Five approaches are measured and failed or rejected. Do not repeat them.**

| approach | result |
| --- | --- |
| Weight the cloak's front panels to the arm bones | Worse: 147 crossings against 139 at contact |
| Weight the cape's shoulder cap to the deltoid | Removes nothing at any share, and breaks the rest pose: idle goes 0 to 76 |
| Part the front wider during the reach | Worse at every width from 19 to 75 degrees; worst frame grows 374 to 452. Rotating panels about the body sweeps cloth *into* the arms |
| A clearance morph fitted to the arms' own swept envelope | Does not converge: 50 of 122 frames still cross after four fitting passes, moving 542 of 733 vertices by up to 0.398 |
| **Cut armholes in the cape** | **Worked, then rejected on the look.** The cape came out clear at every frame. But the hole cannot be small: the arm is anchored 0.282 out on a cape of radius 0.47, so it must run 30 to 120 degrees off the front, leaving a front bib and a back panel. Built at `4742501` and `adaf41e`, reverted at `97b4389` |

The armhole attempt also left the lowered hood crossing the arms on 31 frames,
because folded it covers the holes.

**This does not block the MVP.** Gameplay never plays these clips; only the
trial scene in `art_trial/` does. The live choices, all the user's, are: accept
the clipping, re-author the clips without the hand movement, or change the
garment. None is started.

## State: the stages

### How levels are written

Levels are JSON in `levels/`, separate from scenes, and everything is an
axis-aligned box.

```
originals / absolutes : [{ id, center:[x,y,z], size:[x,y,z] }]
start, goal           : [x, y, z]
mirror                : { enabled, axis, source, offset, pivot }
limits                : { axes:[...], min:[x,y,z], max:[x,y,z] }
kill_y, title, objective, is_test
```

`game.gd` holds two lists. `PUZZLE_PATHS` is the ordered sequence, and
`LEVEL_PATHS` is that plus the fixtures. **The puzzles must stay the front of
the level list**, or Next runs into a test room; `run_tests.gd` checks this.
Tests look levels up with `LEVEL_PATHS.find(...)`, so inserting a puzzle is
safe.

### What exists

Three puzzles and eight fixtures.

| file | kind | teaches or tests |
| --- | --- | --- |
| `01_route` "A place to stand" | puzzle | create and move a mirror; an absolute as the place that stays |
| `08_reveal` "The path beneath" | puzzle | disabling restores the original ground |
| `11_aperture` "Only the ground" | puzzle | **Resize** |
| `02_partial_cut` | fixture | moving the plane through a block; surfaces and collision outlines |
| `03_source` | fixture | which side is source |
| `04_absolute` | fixture | absolute support |
| `05_restore` | fixture | returning ground |
| `06_wall` | fixture | wall conflict |
| `07_horizontal` | fixture | a useful fall |
| `09_movement` | fixture | natural walking |
| `10_extent` | fixture | bounded cuts, side crossing, absolute priority, source-anchored materials |
| `12_block_gallery` "Block gallery" | fixture | demo ground for the one ceramic block set: every original, reflected, and absolute look together |

### Level 3, the one stage experiment that landed

`11_aperture`, "Only the ground". Resize had no coverage anywhere: `02` moves
the plane through a block but never changes the panel's size, so the pills, the
captured opposite edge and the grid-centre correction went unexercised.

A ledge carries a tower at one end and the ring sits across a five-unit gap.
Reflecting the ledge bridges the gap, but a full-height aperture carries the
tower across too and stands it between the bridge and the ring. Shortening the
aperture to the ground band brings only the ledge.

The resize rule does the teaching by itself: pulling the top pill down captures
the bottom edge, and the bottom edge is exactly the band that is wanted. The
wrong answer is reachable and visibly wrong, so the player builds the wall and
then unbuilds it.

Verified through the real preview path, not by writing geometry:

| mirror | route to the goal |
| --- | --- |
| off | no |
| 3 wide x 3 high | no, the tower blocks one step short |
| 3 wide x 1 high | **yes** |

### The solvability harness

`tests/level_solvability_tests.gd` is new. It drives `begin_preview`,
`change_preview`, `apply_preview` and the navigation exactly as a player does,
and asks whether the intended solution reaches the goal and the near misses do
not. **A level is only a puzzle if the wrong answer is reachable and wrong**, so
check both. Reuse this for every new stage; it is the cheapest guard you have
against a level that is accidentally unsolvable or accidentally trivial.

### The tilt experiment, unfinished

Every authored object is an axis-aligned box, so **a tilted mirror is the only
way a slope can exist in this game**. That matters, because the 45 degree
walking limit currently governs terrain the player has no way to produce.

Probed and half-answered: a tilted mirror **does** produce genuinely angled
fragments, and the reflected ledge splits into pieces with non-box extents such
as `y -1.82..0.00`. But in every tilt tried the reflection swung downward and
away from the ledge, so **no walkable ramp was produced and walkability is
unproven**. A Tilt level is plausible and needs real design, not a quick check.

### What the tutorial still does not teach

- **Rotate / Turn.** No level, no fixture.
- **Tilt.** No level, no fixture, and see above.
- **The half turn that exchanges source and reflected sides.** An agreed rule
  with nothing behind it.

### The block set and the gallery

Every stage, puzzle or fixture, uses one block set. The look follows the kind
of solid (original, reflected, absolute), never the level index. It lives in
`world/block_set.gd` (the materials and the goal ring) and two shaders:
`world/ceramic.gdshader` (originals and jade absolutes) and
`world/porcelain.gdshader` (reflections). The lighting is one environment in
`world/trial_lighting.gd`. There is no fog. The level JSON has no block type
field; add one only when a second variant of one kind exists.

`levels/12_block_gallery.json` is the demo ground. It is a fixture with an
enabled 3x3 mirror and shows a whole original, a tall original, a whole
reflected copy, an original cut at the plane with its cut reflection, a
reflected piece cut at the aperture edge, and the jade start and goal.
`tests/gameplay_art_tests.gd` fails if a later edit removes one of these looks.
`tests/block_gallery_review.gd` (native) saves four turns, a phone size, a close
view, and a 30 degree turn that shows the angled polygon cut path.

### The stage sweep

Each stage stays a self-contained JSON file in its own coordinates. At the goal
of a puzzle that has a next puzzle, `game.gd` waits 0.5 s, then loads the next
stage at once. The real world, collision, walker and HUD are the new stage from
that moment. `world/stage_sweep.gd` then draws the old stage for 1.7 s only: a
second, visual-only `MirrorWorldView`, moved by `new start - old goal` so the
traveller stays where he stood. A glass panel sweeps from the far end back past
the traveller. A clip plane in both block shaders hides the new stage ahead of
the panel and the old stage behind it. Phase is `"transition"` during the
sweep: editing, walking, Undo, the pointer and camera turns are refused. The
last puzzle does not sweep; it stays complete with "The end of the tutorial so
far." The level picker and Reset stay instant and cancel a sweep. There is no
Next button.

Known limits: a clipped box is open at the plane for about one second, and the
camera frames both stages together, so each stage is smaller during the sweep.
The user chose the sweep over a Monument Valley style diorama join, so that
the join comes from the game's own mirror rule.

## Decisions already made. Do not reopen them without the user

- **Multi-mirror is coming**, but may be limited to predefined stages or
  cutscenes if it proves too hard or costly. Build the core on one mirror.
- **Build puzzles on geometry, not on scarcity.** Any puzzle whose only tension
  is "you cannot be in two places at once" deflates the moment a second mirror
  exists.
- **Only the lower boundary kills. Permanently.** Height never hurts. Falling is
  a cheap, explorable move, and vertical stages are safe to design.
- **Editing while falling is undecided.** It is permitted by the rules and a
  "Standing still only" option exists. Keep it out of the sequence; prototype it
  as fixtures, one that requires it and one that merely allows it, and let a
  playtest decide.
- **One block set on every stage**, made from the Level 1 ceramic look. The
  reference scene's look is a source of ideas, not the base.
- **Stages join by the mirror sweep**, not a diorama take-apart or a title card.
- **Armholes in the cape are rejected on the look.** Do not rebuild them unless
  the user asks by name.

## Blocking the MVP specifically

1. **There is no tutorial structure.** Three puzzles exist in a sequence;
   nothing introduces the verbs in order, and Rotate and Tilt are missing
   entirely.
2. **Exports ship the study scenes.** `export_presets.cfg` exports all
   resources, so `art_trial/` (the reference scene and the traveller viewer)
   and `assets/studies/` go into a build. Decide before a release build.
3. **Not implemented, so do not design around them**: ladders; and switches,
   keys and doors, whose state sharing across the plane is explicitly undecided.

## How to build and prove

Character, from the project root:

```bash
rtk /Applications/Blender.app/Contents/MacOS/Blender --background --python art_sources/traveller/build_traveller.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/review_mesh.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/export.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/bounds.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/check_clearance.py
rtk /Applications/Blender.app/Contents/MacOS/Blender --background art_sources/traveller/traveller.blend --python art_sources/traveller/check_walk.py
```

Godot. Import first, or a changed asset is not picked up:

```bash
rtk /Applications/Godot.app/Contents/MacOS/godot --headless --path . --editor --quit
```

| check | current result |
| --- | --- |
| `tests/run_tests.gd` | 551 checks, 0 failures (varies by one between runs) |
| `tests/level_solvability_tests.gd` | 6 checks, 0 failures |
| `tests/gameplay_art_tests.gd` | 61 checks, 0 failures |
| `tests/display_geometry_tests.gd` | 2089 checks, 0 failures |
| `tests/animated_traveller_tests.gd` | 281 checks, 0 failures |
| `tests/reference_art_tests.gd` | 626 checks, 0 failures |
| `tests/extent_tests.gd` | 68 checks, 0 failures |
| `tests/constellation_tuning_tests.gd` | 25 checks, 0 failures |
| `check_walk.py` | 4 of 4 pass |
| `check_clearance.py` | **FAIL by design**: 116 crossing frames, the open hood problem above |

Native reviews, without `--headless`, save to the ignored `test-output/`:

```bash
rtk /Applications/Godot.app/Contents/MacOS/godot --path . --script tests/traveller_gameplay_review.gd
rtk /Applications/Godot.app/Contents/MacOS/godot --path . --script tests/block_gallery_review.gd
rtk /Applications/Godot.app/Contents/MacOS/godot --path . --script tests/block_gallery_review.gd -- --sweep
```

The `--sweep` mode completes Level 1 and saves the sweep at 0, 25, 50, 75 and
100 percent. `tests/capture.gd` also runs only natively; headless, it waits
forever for a frame.

`tests/preview_tests.gd` and `tests/mirror_interaction_tests.gd` are modules with
no runner. They print nothing on their own and are driven by `run_tests.gd`.
`tests/extent_tests.gd` words its summary "failures:" rather than "checks,".

## Traps. Each of these produced a wrong answer at least once

- **A moved block view needs its own transform in the material mapping.**
  `_apply_source_mapping` uses `(transform * material_to_world).affine_inverse()`.
  Without `transform`, a moved view gets wrong surface detail and marks every
  face as cut. The clip plane is in world space.
- **A test that completes a puzzle must set `game.auto_advance = false`**, or
  the sweep carries the game to the next stage during the checks.
- **`load_level` sets the phase to "play".** The sweep sets "transition" again
  after it. A new phase must be added to the guards in `undo`, `_pointer` and
  `turn_camera`, not only to `can_edit`.

- **`run_tests.gd`'s check count varies by one between runs.** It reports
  531 or 532, seen before this change too. Compare failures, not the count.
- **A resize is silently dropped while the camera is blending.** `_resize_to`
  returns early on `camera.busy`, and every `change_preview` re-triggers a
  camera fit. Any scripted solve must wait between steps, or the size never
  changes and the geometry looks identical.
- **Editing is refused while a level settles.** `can_edit()` is false while
  `settle_frames > 0`, so `begin_preview` does nothing and the whole chain
  fails quietly.
- **Godot's glTF import gives every clip a track for every bone that any clip
  animates.** Adding the walk gave the hood clips lower-body tracks holding the
  rest pose. Check that bones *hold still*, never that a name is absent from a
  track path.
- **The bounds sidecar gates the viewer tests.** Any change to a clip's poses
  needs `bounds.py` run again. It samples half frames, because the test steps
  0.125 s and lands on 7.5, 22.5, 37.5 and 52.5, and a vertex does not move
  linearly between two bone rotations.
- **Blender 5 actions are slotted.** `action.fcurves` does not exist. Walk
  `action.layers` to `strips` to `channelbags` to `fcurves`, and set
  `animation_data.action_slot` after assigning an action or nothing plays.
- **`rtk grep` reads the working directory, not a pipe.** Use `rtk proxy grep`
  when the input comes from a pipe or a redirect.
- **One blend file belongs to the user.** The build reads
  `art_sources/traveller_animated/traveller_animated.blend`. The user
  committed it in `337b50d`. Do not change or commit it without asking.
  `art_sources/traveller/traveller_esmond_split.blend`, the user's split copy,
  was removed in `b1d2b6d`.

# Handoff

Current state only, kept under about 150 lines. Git history keeps the rest;
the old traveller is in `docs/art/traveller-handoff.md`.

## Now: the still-water look (owner agreed, 2026-11-11)

The owner gives no reference pictures now: chasing a target damaged the
earlier rounds. The agent proposes a style with a proof frame from the
engine, the owner agrees, then the agent builds. The owner agreed to **still
water** from a sketch, and it is built: five rules in `docs/art/STYLE.md`,
frame `docs/art/target/still-water-2026-11-11.jpg`. **The owner has not
approved the built frame.** Branch `claude/funny-dirac-7dv0hf`, all pushed.

Five independent reviews each gave beauty 6/10, readability 6 to 7 on a
desktop and 4 to 5 on a phone; the painted ice before it had 6, 6 and 4. The
surface does not limit the picture. Every review names three faults that
are not the surface's. **The next step is a proposal for them, agreed with
the owner before code**; more rounds on the water will not move the score.

- The place is small in an empty frame, and the stones read as toys.
- The girl is about 10 pixels tall on a phone, pale on snow, behind the pane.
- A stone high above the water has no image and no tie to it ("Together").

**Portrait (owner, 2026-11-12):** the owner expects most play on a phone in
portrait. The five reviews above judged landscape. One independent review of
portrait (390x844, six places): beauty 6, readability 6 without and 6 with
the interface. Its worst faults: the sun's light reads as a flat warm screen
gradient, the largest warm area; `01_route`'s pink has no cause; the lowest
35 to 40% of the frame is empty dark water; the girl is about 25 pixels tall
and grey on snow; pale reeds in a row along the lower edge. The hint card is
clear of the place. Judge portrait first from now on.

**Proposed, waits for the owner (2026-11-12): the light lies on the water.**
The water's ripples carry the sun's light as soft level lines, with lanes of
calm water; reeds are dark; a copy's image is darker than the copy. Sketch:
`test-output/polish/portrait-light-sketch.patch` (not in Git) and
`VALIDATION.md`. Two blind pairs chose it over the branch (beauty 7 to 6).
The build must vary the lines (they read as scan lines), give the two views
away from the sun some light, and cut the cost (3.1 ms to 2.4 at 1170x2532).
A first sketch with hard streaks lost its blind pair: keep the water calm.

**The owner wants to decide the world first (2026-11-12):** what the
backdrop is, and whether it is water, before more work on the look. The
light proposal above waits for that.

**A change follows the pane (owner, 2026-11-12, built):** the mirror's effect
reaches as high as the pane's moving edge. `world.reveal_along` in
`toggle_mirror`; `reveal_plane` in `stone.gdshader`; `sheet.sink()`. A slide
of a raised mirror still changes at once. Moving on still uses `reveal_from`.

How the look is made, where `STYLE.md` does not say:

- `world/ice.gd` and `ice.gdshader` are the water (names kept), unshaded. A
  second camera draws `MIRRORED_LAYER`: the stones, the pane's glass, the
  reeds. Their shaders write the image by `world/water_image.gdshaderinc`
  (gone 1.1 above the water); the water reads from its brightness how much
  is left. `ice.ring(at)` makes a ring (`toggle_mirror`, `_track_fall`).
- The sun stands at 39 degrees, so a top is lighter than a sunlit side.
- The lowest ground stands in the water (`ICE_CLEAR`); a block cut at an
  angle keeps the old plain shape; a place with a `story` gets no reeds; the
  girl's shade comes from the shader global `walker_at`; only `01_route` is
  dusk. Captures: `tests/capture_stage.gd` (`--turns`, `--motion`,
  `--nudge`, `--rise`).

Changed without the owner's word, to confirm or reverse: the girl's colours
are taken down by 0.64 (`TONE_DEEPEN`, `world/character_visual.gd`); the
pane's frame is pale, not brass; the girl has no image in the water; the
snow is sparse; the hidden-ground ghost is clear (`HIDDEN_FILL`,
`world/world_view.gd`) and the mirror's guide lines very faint;
`docs/VISION.md` calls the ice the first mirror, and now water lies on it.
The pond and the first scene share the look; nobody has looked at them.

**For the interface polish round** (owner, 2026-11-11: not now): at 844x390
the hint card covers the girl, the mirror and both of its stones. Capture
with `--size 844x390` and no `--clean`.

**The camera** fits the points that are drawn (each solid, the mirror with
room for one step, the goal, the girl): `world/stage_camera.gd`,
`_fit_camera` in `game.gd`.

Also open: the colour script cuts when moving on; the reeds appear at once
with a new place; the title screen was not checked. Frame time on the Mac
(M2 Pro): 2.0 ms at 1152x800, 4.4 ms at 2532x1170. **No phone has run this.**

Open with the owner: approval of the frame; the three faults; the colour
script per stage; where her sister shows; vistas between puzzles; level
names (proposed 2026-11-09: Fresh Snow, Borrowed Ground, Still There, Just
Enough, The Other Way, Side by Side).

**On hold: the first scene.** The pond story place (`levels/00_pond.json`,
`world/prologue.gd`, `docs/briefs/the-pond.md`) gives away too much story.
Agreed direction: an empty, slow opening that explains nothing. Do not build
on the pond until the owner resumes it.

## What the game is

A calm spatial puzzle: one mirror panel copies the geometry in its aperture
to the other side, and the copy is real ground. `docs/VISION.md` sets the
feel; `GAME_DESIGN.md` has the rules.

## The stages

Levels are JSON in `levels/`: axis-aligned boxes (`originals`, `absolutes`),
`start`, `goal`, `mirror`, `limits`, `kill_y`, `title`, `objective`, optional
`prompts`, `props`, `story`, `untitled`, `goal_hidden`. `game.gd` holds
`PUZZLE_PATHS` (play order) and `LEVEL_PATHS` (that plus the fixtures); the
puzzles must stay at the front.

| play order | file | title | teaches |
| --- | --- | --- | --- |
| 0 | `00_pond` | The pond (untitled) | story place, on hold |
| 1 | `13_first_steps` | First steps | walk; turn the view to find the goal |
| 2 | `01_route` | A place to stand | make, move and place a mirror |
| 3 | `08_reveal` | The path beneath | lowering the mirror restores the ground |
| 4 | `11_aperture` | Only the ground | resize |
| 5 | `14_turn` | Another way round | turn |
| 6 | `15_together` | Together | turn, resize, a safe fall |

Fixtures (`is_test`): `02`–`07`, `09`, `10`, `12_block_gallery`.

## The code, briefly

- `main.tscn` runs `app.gd`: title, save (`core/tutorial_progress.gd`),
  music, settings, `game.story = true`. `Game.new()` alone (all tests) starts
  at stage 1 with the debug UI and no story.
- `game.gd`: levels, the mirror, phases (`play`, `preview`, `transition`),
  prompts, moving on (`_begin_sweep`, `ADVANCE_PAUSE` 1.2 s).
- Direct mirror controls (`game.direct_controls`, on in the app): the mirror
  button raises and lowers; a drag on the mirror slides it; a drag on its
  arrow points it; Undo takes it back. `GAME_DESIGN.md` has the rules.
- `world/world_view.gd` draws one mesh per solid; `world/block_set.gd` sets
  the kind on `world/stone.gdshader`; `world/stone_mesh.gd` is a whole
  stone's shape; `world/trial_lighting.gd` is the light and the colour
  scripts; `world/ice.gd` is the water and its mirror image;
  `world/pond_scenery.gd` is the reeds round a place.
- `world/character_visual.gd` plays the girl (`assets/character/girl.glb`,
  0.8 u, Idle/Walk/Wake/Lift/Raise/Lower/Wave). Sources in
  `art_sources/girl/`. `assets/character/traveller.glb` is the old character,
  unused by gameplay.
- `world/place_props.gd`: grey-box props; `world/prologue.gd`: the pond.
- UI: `ui/style/` tokens, `ui/motion/motion.gd` verbs (press, appear,
  dismiss, settle, swing 0.6, reveal 0.8, breathe 1.6, transition 1.6). Use
  them; no raw tween timings.
- Sound: `world/sounds.gd`; WAVs from `art_sources/audio/generate_sounds.py`.

## Decisions. Do not reopen them without the owner

- Multi-mirror is coming but may be limited to set pieces. Build on one.
- Build puzzles on geometry, not scarcity.
- Only the lower boundary kills. Height never hurts.
- Stages join by moving on: the next place grows from her feet.
- Prompts show once, are saved as done, and **?** replays them.
- Release builds are a normal game: settings only, no dev tools.
- Our own art first; CC0 kits for iteration and reference.

## How to run and check

On the Mac, see the appendix in `AGENTS.md`; use
`/Applications/Godot.app/Contents/MacOS/godot` in place of `$G` and drop
`xvfb-run -a`. In the cloud container:

```bash
G=<scratchpad>/godot/Godot_v4.7.2-stable_linux.x86_64   # downloaded per session
$G --headless --path . --editor --quit                  # import changed assets
$G --headless --path . -s res://tests/<name>.gd         # most tests
xvfb-run -a $G --path . --rendering-method mobile -s res://tests/tutorial_playthrough.gd
xvfb-run -a $G --path . --rendering-method mobile -s res://tests/capture_stage.gd -- --level 01_route --out /abs/dir --clean 1 --turns 1
blender -b art_sources/girl/girl.blend --python art_sources/girl/export.py
```

Tests are in `tests/`; `run_tests` is the main one (≈690 checks). Run only
the one that covers a change. `VALIDATION.md` records what was checked.

## Traps

- **The cloud container's software renderer can drop the sun.** With shadows
  or fog on, default Burley diffuse gets no directional light under llvmpipe;
  Lambert works. Metal on the Mac is fine with both (checked 2026-11-10), so
  this matters only for cloud captures.
- **Vertex colours reach a shader as written**, not converted like a
  `source_color`. `scenery.gdshader` converts them itself.
- **The first capture after a script change can miss the mirror's raise.**
- **A transparent quad under the girl did not draw** (cause unknown); her
  shade is painted in the stone shader instead.
- **A shader the mirror camera draws must use `water_image.gdshaderinc`**,
  or its image shows at full strength at any height. A `StandardMaterial3D`
  cannot, so keep such a thing off `MIRRORED_LAYER`.
- **Headless frames run uncapped.** A test that waits for walking must count
  `physics_frame`, not `process_frame`.
- **Godot's glTF import drops the first mesh part's vertex colours.** Put a
  part without vertex colours first, or keep colour in materials.
- **A direct change applies a few frames after release.** Wait for `phase` to
  leave `"preview"`, not just for `pending` to empty.
- **A new mirror starts at her feet height**, not the level pivot. Prove a
  stage with `create_at` in the solvability harness, not `place`.
- **She cannot walk off an edge.** A fall happens only when the ground under
  her is removed.
- **The view turn carries over between stages.**
- **A `--script` run must call `quit()` on every path.** Use `timeout`.
- **The App pauses the game behind the title**; wait out the 1.6 s sink.
- **A test that completes a puzzle sets `game.auto_advance = false`.**
- **`load_level` sets the phase to "play".** A new phase must be added to the
  guards in `undo`, `_pointer` and `turn_camera`.
- **A moved block view needs its own transform in the material mapping**
  (`(transform * material_to_world).affine_inverse()`).
- **A resize is dropped while the camera blends**; scripted solves wait.
- **Exports leave out `art_trial/` and `assets/reference/`.** Never load from
  them in game code.
- **Blender 5 actions are slotted**: walk `layers` → `strips` →
  `channelbags` → `fcurves`, and set `animation_data.action_slot`.
- **The WAV import loop enum is one off**: `edit/loop_mode=2` is Forward.
- **`art_sources/traveller_animated/traveller_animated.blend` is the owner's.**
  Do not change or commit it without asking.

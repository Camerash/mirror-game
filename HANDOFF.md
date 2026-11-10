# Handoff

Current state only, kept under about 150 lines. Git history keeps the rest;
the old traveller is in `docs/art/traveller-handoff.md`.

## Now: art and scene quality (owner, 2026-11-10)

**The work moves to the owner's Mac from here.** The branch is
`claude/funny-dirac-7dv0hf`; everything is pushed. Start with
`docs/briefs/polish-loop.md`: the next job, its limits, the first checks on
the Mac and three questions the owner has not answered yet. Then read
`docs/art/STYLE.md`. "A place to stand" (`01_route`) is the first quality
target; art is judged on real frames from the game's camera.

Not carried over from the cloud session: the image and 3D keys
(`GEMINI_API_KEY`, `TRIPO_API_KEY`, `MESHY_API_KEY`) must be set in the
Mac's environment; raw captures and reference contact sheets were scratch
files and are gone. The references are linked in the brief.

In the game now:

- **The look** (`world/trial_lighting.gd`, `world/stone.gdshader`): a low
  sun, a filmic tonemap, and one block surface drawn by rule: stone, snow
  with a lip, a patina band on absolutes, summer on a copy.
- **The ice** (`world/ice.gd`, `ice.gdshader`): the pond's ice 0.35 under a
  place's lowest ground, and the whole backdrop. A second camera, the stage
  camera mirrored through the ice, draws only the stones at half size
  (render layer 11); `stone.gdshader` darkens that image with height.
  `world/snowfall.gd` is the snow; `world_view` keeps a warm light in each
  copy, which also pools on the ice.
- **Colour scripts**: `SCRIPTS` in `world/trial_lighting.gd` (`morning`,
  `dusk`); a level names one with `"light"`. Only `01_route` is dusk.
- **Captures**: `tests/capture_stage.gd`.

Decided by the owner: blocks are dressed by rule from the level file; the
block may be redesigned to fit the story; our own art first, drawn by code.

Known gaps: the colour script cuts when moving on; snow is drawn on a side
face under a stacked block; the opposite view is back-lit; the second
camera's cost is unmeasured. The reviewer's list is in the brief.

Open with the owner: the brief's three questions; the colour script per
stage; whether her image in the ice becomes where her sister shows; vistas
between puzzles; level names (proposed 2026-11-09: Fresh Snow, Borrowed
Ground, Still There, Just Enough, The Other Way, Side by Side).

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
  the kind on `world/stone.gdshader`; `world/trial_lighting.gd` is the light
  and the colour scripts; `world/ice.gd` is the ice and its mirror image.
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

On the Mac, see the appendix in `AGENTS.md`; use the local Godot 4.7.2 in
place of `$G` and drop `xvfb-run -a`. In the cloud container:

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
  Lambert works. Cloud captures before 2026-11-09 had no sunlight. Not
  checked on a Mac. Use Lambert for new materials.
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

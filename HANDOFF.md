# Handoff

Current state only, kept under about 150 lines. Git history keeps the rest:
the old traveller and its hood work are in `docs/art/traveller-handoff.md` and
in the history of this file before 2026-11-09.

## Now: art and scene quality (owner, 2026-11-09)

The owner paused the first-scene work to raise art and scene quality. Three
independent reviews found the causes: the visuals are the collision boxes,
props are code primitives, there is no art direction in the game, and
pictures are not the gate. The renderer is not the limit. The owner approved
this plan; "A place to stand" (`01_route`) is the first quality target.

0. **Process cuts** (done 2026-11-09): `AGENTS.md` rewritten for the cloud
   container, this file trimmed, look-asserting tests removed, no video in Git.
1. **Style guide and target frame**: `docs/art/STYLE.md`, one page, and one
   target frame for "A place to stand" made as a paintover of a real capture.
   The owner approves both before step 2.
2. **A real look in the game**: filmic or AgX tonemap, a back sun, fog, a
   gradient backdrop, a face-direction snow shader, ambient occlusion baked in
   Blender Cycles. Remove the emission lifts in `world/trial_lighting.gd`.
   The look pilot (`art_trial/look_pilot/`) already built most of this and was
   never ported.
3. **An art layer over the grid**: the level JSON keeps driving collision; a
   Blender-made scene snapped to the grid dresses it. Mirror copies instance
   the source cell's dressing, mirrored, through the existing
   `source_bounds`/`world_to_material` and `clip_plane`. `world_view` stays as
   the debug grey box.
4. **A kit**: our own pieces first. CC0 kits (KayKit, Quaternius, Kenney) are
   fine for fast iteration and as modelling reference.
5. **Density and life**: scatter, falling snow, wind, ice.
6. **The art gate** (see `AGENTS.md`).

Open with the owner: new level names (1–2 poetic words each); the AI 3D trial
(Tripo and Meshy keys are in the environment).

**On hold: the first scene.** The owner found the pond story place
(`levels/00_pond.json`, `world/prologue.gd`, `docs/briefs/the-pond.md`) gives
away too much story. Agreed direction: an empty, slow opening that explains
nothing. Unanswered: where the sister's glimpse goes; whether the hand mirror
is found. Do not build on the pond until the owner resumes it.

## What the game is

A calm spatial puzzle. One bounded mirror panel copies the geometry inside its
aperture into the column on the other side; the copy is real, walkable ground.
Absolutes cannot be copied, moved or cut. Gravity points down. Only the lower
boundary kills. One mirror at a time for now. `docs/VISION.md` sets the feel:
loss and acceptance, "light after rain", about an hour in five chapters.
`GAME_DESIGN.md` has the rules.

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
- `world/world_view.gd` draws one mesh per solid; `world/block_set.gd` picks
  the material by kind; `world/trial_lighting.gd` is the light.
- `world/character_visual.gd` plays the girl (`assets/character/girl.glb`,
  0.8 u, Idle/Walk/Wake/Lift/Raise/Lower/Wave). Sources in
  `art_sources/girl/`. `assets/character/traveller.glb` is the old character,
  unused by gameplay.
- `world/place_props.gd`: grey-box props; `world/prologue.gd`: the pond story.
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

## How to run and check (cloud container)

```bash
G=<scratchpad>/godot/Godot_v4.7.2-stable_linux.x86_64   # downloaded per session
$G --headless --path . --editor --quit                  # import changed assets
$G --headless --path . -s res://tests/<name>.gd         # most tests
xvfb-run -a $G --path . --rendering-method mobile -s res://tests/tutorial_playthrough.gd
xvfb-run -a $G --path . --rendering-method mobile --write-movie out.avi --fixed-fps 30 -s <script>.gd
blender -b art_sources/girl/girl.blend --python art_sources/girl/export.py
```

Movie Maker records 1152x800 with the game's audio; convert with
`ffmpeg -c:v libx264 -pix_fmt yuv420p -crf 24 -vf scale=960:-2 -c:a aac`.

Main tests: `run_tests` (≈690 checks), `level_solvability_tests`,
`direct_controls_tests`, `prompt_tests`, `app_flow_tests`, `goal_tests`,
`gameplay_art_tests`, `sound_tests`, `small_fix_tests`. Run only the one that
covers a change. `VALIDATION.md` records what was checked.

## Traps

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

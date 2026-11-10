# Handoff

Current state only, kept under about 150 lines. Git history keeps the rest:
the old traveller and its hood work are in `docs/art/traveller-handoff.md` and
in the history of this file before 2026-11-09.

## Now: art and scene quality (owner, 2026-11-10)

The owner paused the first-scene work to raise art and scene quality.
"A place to stand" (`01_route`) is the first quality target. Read
`docs/art/STYLE.md`: the feel reference is now a painterly journey over
still water, and art is judged on real frames from the game's camera.

Done so far:

- **Process cuts**: see `AGENTS.md`.
- **The look in the game** (2026-11-09): a low sun, a filmic tonemap, and one
  block surface drawn by rule (`world/stone.gdshader`): stone, snow with a
  lip, a patina band on absolutes, summer on a copy.
- **The ice** (2026-11-10): `world/ice.gd` and `ice.gdshader` put the pond's
  ice 0.35 under a place's lowest ground. A second camera, the stage camera
  mirrored through the ice, draws the stones at half size (render layer 11;
  nothing else is mirrored). `stone.gdshader` darkens that image with height,
  so it never looks solid. The ice is the whole backdrop: a painted gradient,
  soft cloud, the image, and warm pools under the copies.
  `world/snowfall.gd` is the falling snow. `world_view` keeps one warm light
  in each copy.
- **Colour scripts**: `SCRIPTS` in `world/trial_lighting.gd` (`morning`,
  `dusk`); a level names one with `"light"`. Only `01_route` is dusk.

Next, in order:

1. The owner judges the ice frame and picks the colour script per stage.
2. **Blocks dressed by rule** (owner approved): the game builds each block's
   dressing from the level file, so every stage, copy and cut works. The
   owner wants the block itself redesigned to fit the story. Start with
   concept sheets on a hard case ("Together", mid-solve).
3. Far scenery on the ice, plants, wind. Our own art first; CC0 kits and
   Meshy (rocks only, after `art_sources/props/ai3d_trial/clean.py`) for
   drafts.
4. Vistas between puzzles with a low camera, perhaps as the new opening.
   Not decided.

Known gaps (the reviewer's list is in `VALIDATION.md`): the colour script
changes in a cut when moving on; snow is drawn on a side face even where
another block sits on top; the opposite view is back-lit; no ambient
occlusion; she is pale against snow and glass; the morning script is plain;
the second camera's cost is not measured on a real device. Open with the owner: level names of
one to three words (proposal sent 2026-11-09).

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
- `world/world_view.gd` draws one mesh per solid; `world/block_set.gd` sets
  the kind on `world/stone.gdshader`; `world/trial_lighting.gd` is the light
  and the colour scripts; `world/ice.gd` is the ice and its mirror image.
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

- **The cloud container's software renderer can drop the sun.** With shadows
  or fog on, a `StandardMaterial3D` in its default Burley diffuse mode gets no
  directional light under llvmpipe. Lambert and Lambert-wrap work. Captures
  made here before 2026-11-09 showed the stage without sunlight. Not checked
  on a Mac. Use Lambert for new materials and check a capture for sun.
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

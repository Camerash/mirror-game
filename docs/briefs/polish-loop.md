# Brief: the polish loop on "A place to stand"

Status: run on the owner's Mac on 2026-11-10 and 2026-11-11, seventeen rounds. The result and
what is still open are in `HANDOFF.md` and `VALIDATION.md`. The owner's
answers to the three questions: run it now; stones may be reshaped while
walkable edges stay on the grid and the tests pass; stay on the Mobile
renderer.

## Why

Three demos made with the same model look more polished than our game:

- A boat ride through eight painted worlds, the feel reference:
  <https://x.com/kevin_t_ngo/status/2119868968307695818>
- A flight over a meadow, made in about 30 minutes with a few subagents:
  <https://x.com/lexnlin/status/2119880654858977333>
- A floating 1886 New York. Its first prompt is flat blocks on a plain
  colour, much like our game; the final is the same scene after many rounds:
  <https://x.com/semichenkko/status/2119960596951236675>

What they did that we have not:

- One goal, the picture, and one long loop toward it without stopping.
- Full scenes. Polish reads as density, light and motion together. Our stage
  is five cubes over a gradient.
- Everything drawn by code: generated meshes, shaders, instancing. No
  modelling tool, no image model.
- They saw the real output on a real graphics card.

## The goal

One frame: "A place to stand" (`levels/01_route.json`), mirror raised, from
the game's own camera, as beautiful as the boat clip, with the puzzle still
readable on a phone. Then the same place from the other three views.

## Freedom

Add what the frame needs without asking, all drawn by code:

- Far scenery on the ice: a shore, bare trees, reeds, rocks, a jetty.
- Rounded stones and real snow shapes, built by rule from the level file.
- A low sun and its glitter path held in the ice. Darker accents.
- Life: wind in the snow, drifting mist, small glints.

## Limits

- The rules, the grid, collision and the tests stay untouched. Walkable
  edges stay where the grid says.
- Nothing far away may look walkable. Only stones show in the ice (render
  layer 11, `MIRRORED_LAYER`).
- Every addition must read from all four views and in both colour scripts.
- New materials use Lambert diffuse. Colours come from `docs/art/STYLE.md`.
- Take principles from the references. Do not copy their scenes.
- One commit per few rounds, so any round can be reverted.

## Method

1. Capture: `tests/capture_stage.gd` with `--clean 1 --turns 1`, plus one
   with the interface, plus "Together" (`15_together`) as the hard case.
2. An independent reviewer agent, which did not make the change, gets the
   references and the frames, not the maker's opinion. It lists what hurts
   most.
3. Fix the top three. Repeat for ten rounds or more.
4. At the end run `run_tests`, `gameplay_art_tests` and `app_flow_tests`,
   record the checks, and send the owner one sheet: first frame, last frame,
   the four views, "Together".

## Where to start

The reviewer's open list, in order of harm:

1. No dark accents: everything is mid-pastel.
2. The ice holds little sky: no low sun, no glitter path.
3. She is pale against snow and glass, and tiny on larger stages.
4. The morning script is plain grey-blue.
5. Stones are bare cubes: no rounding, no snow volume, no contact shade.
6. Snow reads as stars in a still; check it in motion.
7. The mirror pane is faint. A stray glowing dot sits under the title's
   island.

## First checks on the Mac

- Is the sun present on Metal with a default `StandardMaterial3D`? In the
  cloud it was not (see the trap in `HANDOFF.md`). If the Mac was always
  fine, earlier cloud captures understated the light.
- Frame time with the ice's second camera, at 1152×800 and at a phone size.
- Compare one Mac frame with `docs/art/target/ice-dusk-2026-11-10.jpg`.

## Questions for the owner

1. Run this loop now?
2. May the stones be reshaped without asking, as long as walkable edges stay
   on the grid?
3. Should the look target Steam first with the desktop renderer (more
   effects), or stay on the phone renderer as `AGENTS.md` says?

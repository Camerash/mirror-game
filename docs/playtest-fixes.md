# Playtest fixes: the plan

Written 2026-10-29. The owner agreed that every point in the
[agent playtest](playtests/2026-10-agent-playtest.md) is valid: fix the most
important first, then all of them in order. Each item names the playtest
section it comes from. Mark items done here as they land.

## Order

Ranked by how much each one cost the player: a stage that does not finish,
then deaths the player could not foresee, then time lost reading the
space, then wording and polish.

| # | Fix | Playtest | Status |
| --- | --- | --- | --- |
| 1 | **The goal counts on its whole tile.** A walk that ends anywhere on the goal's tile ends on the goal. | 4.1 | done |
| 2 | **Show what a raised mirror hides.** Draw the replaced originals as a faint outline while the mirror is up, and give the mirror button the fall ghost a drag already has, before it lowers or raises. | 4.2 | |
| 3 | **Don't apply a predicted fall off the world from the arrow or a drag.** Keep the preview on release and ask for a second release, or bounce it back as a blocked change does. Check that turning the mirror keeps the traveller on the source side where it can. | 4.5 | |
| 4 | **A clear failure state.** Show that the traveller fell, pulse Undo, or rewind after a moment. Today the traveller hangs in the void. | 4.6 | |
| 5 | **Make positions readable.** Contact shadows under copies; a "can't reach" cue on a failed tap; on desktop, the reachable path on hover. | 4.3 | |
| 6 | **Forgiving half-unit steps.** More pointer travel per step, or settling to the nearest connecting position; arrow-key nudges for the mirror on desktop. Size it for phones too. | 4.4 | |
| 7 | **Prompts.** Stage 1 on desktop names the arrows and Q/E, not a swipe; stage 3 drops "again" before the mirror is up; stage 4 shows the problem before the hint; stage 5 gets a visual cue instead of text. | 4.7 | |
| 8 | **Small fixes.** Camera buttons that don't look like Undo and Redo; a visible grab area and hover cue for the mirror; no mirror button on stage 1; a Reset in the release UI; a larger stage on phone layouts. | 3, 4.8 | |

Items 2 to 4 share one idea: the player sees an outcome before it
happens, and can always recover from it. Build them together if that
proves simpler.

## How each fix is checked

- A focused headless test for the changed behaviour, like
  `tests/goal_tests.gd` for item 1.
- The suites that touch it, once: `prompt_tests`,
  `level_solvability_tests -- --direct-only`, `app_flow_tests` and
  `direct_controls_tests`.
- After items 2 to 6, a second agent playtest that has not seen
  `tests/tutorial_playthrough.gd`, and then a person on a Mac.

## Done

1. **The goal counts on its whole tile** (`game.gd`, `request_walk`). The
   stage completes when the traveller is within 0.22 of the goal, but a
   walk ended at the exact tapped point, so an off-centre tap on the goal
   tile left the traveller standing on it with nothing happening.
   `tests/goal_tests.gd` reproduced it (stopped 0.46 from the goal) and now
   passes.

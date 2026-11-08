# Brief: the pond

APPROVED by the owner, 2026-11-08 ("I agree with the recommendations").
Built in grey box the same day. Follows the owner's note that the first
minute felt rushed: the story needs its own place before the first puzzle.

## What it is

A place before "First steps" with no puzzle: a small snowfield, a frozen
pond, a bench, a tree with a swing, and two snowmen. The player can only walk
and tap. About two minutes at the player's pace. She then walks out, and
"First steps" grows from her feet (moving on). No name is written on the
pond; names start with "First steps".

Storyboard (Gemini Flash draft): `docs/art/pond/storyboard-01.jpg`.

## Beats (nothing advances on a timer but the wake hint)

1. The sink lands on the pond. She lies in the snow and waits for the
   player's touch; after 3 s a soft warm light breathes on her. The tap
   wakes her.
2. Two sets of small footprints lead from where she lay, side by side.
3. Three lit things, any order, all optional: the snowmen, the bench, the
   swing. Walking to one raises a pane of frost; in it, pale figures of the
   two of them (building the snowmen, looking at the pond, waving from the
   swing).
4. One set of footprints stops at the pond's edge; her sister's goes on
   onto the ice and ends at the hand mirror. She picks it up.
5. The glimpse: her sister in the glass, waving, about two seconds.
6. Her sister's footprints carry on, glowing, across the far bank to the way
   on, where there were none. Only now does the way on open.

## How it is built

- `levels/00_pond.json`: the place (`untitled`, `goal_hidden`), its
  `props` (scenery) and its `story` (memories, keepsake, glimpse, way).
- `world/place_props.gd`: grey-box scenery for any place; it leaves with
  the old place when she moves on (`StageSweep.carry`).
- `world/prologue.gd`: the story player, driven by the level's `story`.
- The walk prompt moved to the pond; "First steps" keeps the turn prompt.

## Open

- The mitten idea (her sister's matching mitten as a found thing): not yet.
- Ice creak, footprints she leaves as she walks, and the real look of the
  place are later work.

# Style guide

One page. Every art change is judged on a real frame from the game, taken
from the game's own camera, against the references below.

**Feel reference (owner, 2026-11-10):** a clip of a slow, wordless journey
over still water (<https://x.com/kevin_t_ngo/status/2119868968307695818>;
not kept in Git). Each scene is one painting with its own colour and
weather; shapes are simple; water mirrors everything; one small warm light
leads the eye. We take the principles. We do not copy its boat, lantern or
scenes.

**What our camera can show.** The puzzle view looks down from above, so it
never sees a sky or a far shore: every line of sight ends on the ice. The
ice is the backdrop. Vistas belong to moments between puzzles, with another
camera, and are not built yet.

**Earlier target:** `docs/art/target/place-to-stand-v4.jpg` still stands for
the block's materials (stone, snow, patina band, summer copy). Its sky and
pillars are replaced by the ice. `look-port-2026-11-09.jpg` is the first
in-game pass; `ice-dusk-2026-11-10.jpg` is the first frame with the ice;
`polish-loop-2026-11-11.jpg` is the frame after seventeen rounds of the
polish loop, not yet approved by the owner.

## The bar

- **Two layers.** In front, the puzzle: simple, readable forms that read
  first. Behind, the ice: rich, soft, and never competing.
- **One colour script per place.** Each place has one time of day and one
  weather (`"light"` in its level file; `SCRIPTS` in
  `world/trial_lighting.gd`). Across the game the scripts run from winter to
  spring.
- **One warm light.** The summer copy is the lantern of a place: it glows,
  lights its neighbours and pools on the ice. The goal ring is the only
  other warm thing.
- **The ice mirrors the place.** Each stone stands over its own image. A
  reflection must never be mistaken for ground.
- **Material contrast does the work.** Matte snow and stone against clear,
  bright glass and dark ice.
- **One grain.** Every piece shares the same level of detail and bevel size.
- **Nothing is static.** Snow falls, the image in the ice wavers, the copy
  glows. Changes ease (`ui/motion/motion.gd`); nothing pops.

## The place

A garden pond in deep winter, seen from its far side, at an hour when the
low sun comes through the far trees. The light on the ice spreads from
where the ice holds the sun; it has a source, not a horizon. Gameplay
blocks are old garden stones that stand on the ice: each a pedestal (a
plinth, a rounder shaft, a cap slab) with snow on top that rolls over the
edge. Reeds and bare shrubs stand in the ice outside the ground the puzzle
can use, each over its own image; toward the sun they are pale and lit from
behind. Absolutes (the ground that stays) carry a dark
bronze-green band. A mirror copy is the same shape in summer: warm stone,
moss, small flowers, a soft glow. The mirror is a thin frosted pane in a
slim brass frame, frosted at the top and clear below. The owner wants the
block itself redesigned to fit the story; it need not stay a cube.

## Colours shared by every script

| role | colour |
| --- | --- |
| snow | `#EDEDF2` |
| stone | `#BDB099` |
| patina (absolutes) | `#385247` |
| gold (goal ring) | `#C99A4A` |
| moss, summer | `#667538` |
| summer glow | `#F3D9A0` |
| reed | `#806E5C` |
| twig | `#2B1F29` |

Sun, sky and ice colours belong to each colour script.

## Rules for pieces

- Silhouettes read at phone size from the 30°/45° orthographic camera.
- Gameplay edges stay where the grid says; dressing may overhang by at most
  about 0.1 unit and never hides a walkable edge.
- Every piece is mirrorable: no text, no handed details that look wrong
  flipped.
- Every piece must read in every colour script and from all four views.
- The scenery stays behind the stones in value: it takes on the colour of
  the air (`haze` in the colour script). Nothing in it has a flat top.
- Lambert diffuse is needed only for captures in the cloud container (see
  the trap in `HANDOFF.md`).
- AI 3D results are drafts: remesh, then repaint in this palette.

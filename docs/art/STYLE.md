# Style guide

One page. Every art change is judged on a real frame from the game, taken
from the game's own camera, against the references below.

**No reference picture (owner, 2026-11-11).** Chasing a target frame
damaged earlier rounds. The look follows the five rules below, which the
owner agreed to from a sketch in the engine. A change of style starts with a
proposal and a proof frame, then the owner's agreement, then the build.

**What our camera can show.** The puzzle view looks down from above, so it
never sees a sky or a far shore: every line of sight ends on the pond. The
pond is the backdrop. Vistas belong to moments between puzzles, with another
camera, and are not built yet.

**Frames kept:** `docs/art/target/still-water-2026-11-11.jpg` is the built
look, not yet approved by the owner. `polish-loop-2026-11-11.jpg` is the
painted ice that it replaced. `place-to-stand-v4.jpg` still stands for the
block's materials (stone, snow, patina band, summer copy).

## The five rules: still water

1. **One real surface.** A film of thaw water lies on the pond's ice. It
   mirrors the place and it turns with the world. Nothing is painted on it:
   no far trees, no bars of light, no clouds, no shadow.
2. **A true image, kept soft.** The stones, the pane and the reeds each
   stand over their own image. The image is darker than its source, the
   ripples break it, and it is gone with height. It must never read as
   ground or as a second object.
3. **Three values and one warm light.** Dark water, mid stone, light tops.
   Only a top that she can stand on is light. The summer copy and the goal
   are the only warm things; the pane's frame is pale and cool.
4. **Few things, each drawn by rule and none stamped.** A few reeds, a few
   small rings, the sun's path on the water, sparse snow. No two are alike.
5. **Each change has a cause that the player can see.** A ring spreads where
   the mirror rises or sinks and where she lands.

Also: one colour script per place (`"light"` in its level file; `SCRIPTS`
in `world/trial_lighting.gd`), from winter to spring across the game.
Changes ease (`ui/motion/motion.gd`); nothing pops.

## The place

A garden pond in deep winter, seen from its far side, at an hour when the
sun is low. The water is light where it holds the sun and deep elsewhere;
the light spreads from the sun's place and is never a band across the view,
which reads as a horizon. Gameplay blocks are old garden stones that stand
in the water: each a pedestal (a plinth, a rounder shaft, a cap slab) with
snow on top that rolls over the edge, and a wet, dark foot. Stands of dry
reed mace stand in the water outside the ground the puzzle can use.
Absolutes (the ground that stays) carry a dark bronze-green band. A mirror
copy is the same shape in summer: warm stone, moss, small flowers in
patches, a soft glow that lies on the water. The mirror is a clear pane in a
slim pale frame, frosted at the top. The owner wants the block itself
redesigned to fit the story; it need not stay a cube.

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

Sun, sky and water colours belong to each colour script.

## Rules for pieces

- Silhouettes read at phone size from the 30°/45° orthographic camera.
- Gameplay edges stay where the grid says; dressing may overhang by at most
  about 0.1 unit and never hides a walkable edge.
- Every piece is mirrorable: no text, no handed details that look wrong
  flipped.
- Every piece must read in every colour script and from all four views.
- The scenery stays behind the stones in value: it takes on the colour of
  the air (`haze` in the colour script). Nothing in it has a flat top.
- A thing that the water mirrors writes its image by
  `world/water_image.gdshaderinc`, so the image is gone with height.
- Lambert diffuse is needed only for captures in the cloud container (see
  the trap in `HANDOFF.md`).
- AI 3D results are drafts: remesh, then repaint in this palette.

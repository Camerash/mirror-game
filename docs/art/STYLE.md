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

**The pale winter look (owner, 2026-11-17).** The owner chose it over the
blue look, from a sketch in the engine, and chose mirror glass for the copy.
The feeling is that of "Girls' Last Tour" (`docs/VISION.md`): small figures
in a large, quiet place, almost no colour, snow and mist, one small warm
light. Built 2026-11-17.

**Frames kept:** `docs/art/target/still-water-2026-11-11.jpg` is the blue
look that the pale winter look replaced. `polish-loop-2026-11-11.jpg` is
the painted ice before it. `place-to-stand-v4.jpg` still stands for the
block's materials (stone, snow, patina band); its summer copy is gone.

## The five rules: still water

1. **One real surface.** A film of thaw water lies on the pond's ice. It
   mirrors the place and it turns with the world. Nothing is painted on it:
   no far trees, no bars of light, no clouds, no shadow.
2. **A true image, kept soft.** The stones, the pane and the reeds each
   stand over their own image. The image is darker than its source, the
   ripples break it, and it is gone with height. It must never read as
   ground or as a second object.
3. **Three values and one warm light.** Dark water, mid stone, light tops.
   Only a top that she can stand on is light. The goal and the lit window
   of the garden are the only warm things. The pane, its light and the
   copy are cool.
4. **Few things, each drawn by rule and none stamped.** A few reeds, a few
   small rings, a faint path of the sun on the water, sparse snow. No two
   are alike.
5. **Each change has a cause that the player can see.** A ring spreads where
   the mirror rises or sinks and where she lands.

Also: every place has the colour script `pale` (`SCRIPTS` in
`world/trial_lighting.gd`). A place can name another script with `"light"`
in its level file when one exists. Changes ease (`ui/motion/motion.gd`);
nothing pops.

## The place

A garden pond in deep winter, under a pale sky, in mist. The water is dark
slate near the view and goes into pale mist far away, so the snow tops, the
lightest things, stand on the darkest part of the frame. Gameplay blocks are
old garden stones that stand in the water: each a pedestal (a plinth, a
rounder shaft, a cap slab) with snow on top that rolls over the edge, and a
wet, dark foot. Stands of dry reed mace stand in the water near the place.
Absolutes (the ground that stays) carry a dark bronze-green band. The owner
wants the block itself redesigned to fit the story; it need not stay a cube.

**A stone keeps its shape when the mirror cuts it** (owner's report,
2026-11-18). Each part of a cut stone, and each copy, is the whole stone of
its source, cut flat where the mirror or a side of its pane cuts it
(`world/world_view.gd`, `cuts` in `world/stone.gdshader`). A part never gets
a plinth, a cap or a corner of its own, so nothing changes its look while
the mirror moves. A stone is drawn 0.1% smaller than its box (`SHRINK`), so
two stones that touch have no wall in one plane and a closed cut does not
flicker.

**The copy is mirror glass.** A mirror copy is the same shape as its
source, seen in glass: a grey-blue body in the colours of the water and the
sky. It keeps the light and dark of the stone, so each panel, crack and lip
is still there. Its edges are bright, as the edge of cut glass, and two soft
bands of light cross each face. It gives no warm light. The mirror is a
clear pane in a slim pale frame, frosted at the top; the light of the pane
(the sheet that closes a cut, and the line on the moving edge) is the cool
white of ice.

**The garden stands round the pond** (`world/garden_backdrop.gd`). Each of
its four sides has its own things: the house with one lit window; a wall
with a gate and old bare trees; a wall with the roof of a glasshouse and a
water tank behind it; a low wall with a large tree, a swing and a shed.
Behind the walls its ground is lost in the mist. Its rules:

- It is far and in the mist: pale, and paler the further it stands behind
  the place. It has its own soft light, the same from each view.
- Soft snow lies on what faces the sky: the roofs, the tops of the walls,
  the sills and the branches (owner, 2026-11-18). It is in the mist and
  less bright than the snow of the place.
- No thing in it shows a wide flat top that could be ground: a wall hides
  the beds of the kitchen garden. At least 6 units of open water lie
  between it and the stones.
- The water shows no image of it. A pale image along the foot of a wall
  reads as a ledge to walk on (independent review, 2026-11-17).
- A side that would stand between the view and the place is away. It
  leaves and comes through a fine screen while the view turns, so nothing
  appears at once. Where the next side is away, a wall runs on past its
  corner, so no view shows a wall that ends in the water.
- The lit window is the one warm light of a place. It is soft through the
  mist and lies on the water in front of the house. It must not be
  stronger than the goal.
- In a tall frame the mirror bar is high (its centre at 78% of the play
  area's height), so a slide from a knob has room below it, and the place
  sits toward the middle of the frame (owner, 2026-11-18). The garden then
  shows only at the top of the frame, as it does in a wide frame.

## Colours shared by every script

| role | colour |
| --- | --- |
| snow | `#EDEDF2` |
| stone | `#BDB099` |
| patina (absolutes) | `#385247` |
| gold (goal ring) | `#C99A4A` |
| reed | `#806E5C` |
| mirror glass, dark to light | `#2B4059` to `#94B3D1` |
| light of the pane | `#CCE8FF` |

Sun, sky and water colours, and the colour of the lit window (`lamp`),
belong to the colour script. For `pale`: water `#2B3944` (near), `#5C6F7B`
(middle), `#CED3D2` (far, the mist); lit window `#FFB665`.

## Rules for pieces

- Silhouettes read at phone size from the 30°/45° orthographic camera.
- Gameplay edges stay where the grid says; dressing may overhang by at most
  about 0.1 unit and never hides a walkable edge.
- Every piece is mirrorable: no text, no handed details that look wrong
  flipped.
- Every piece must read in every colour script and from all four views.
- The scenery stays behind the stones in value: the reeds take on the
  colour of the air (`haze` in the colour script), and the garden takes on
  the mist. Nothing in it has a flat top that is light.
- A thing that the water mirrors writes its image by
  `world/water_image.gdshaderinc`, so the image is gone with height.
- Lambert diffuse is needed only for captures in the cloud container (see
  the trap in `HANDOFF.md`).
- AI 3D results are drafts: remesh, then repaint in this palette.

# Style guide

One page. Every art change is judged against the target frame below.

**Target frame:** `docs/art/target/place-to-stand-v4.jpg` (a Gemini paintover
of the real "A place to stand" capture). The owner accepted it on 2026-11-09
as the direction for mood, palette and light, not as a pixel spec. The block
itself may be redesigned to fit the story. Known fix: the summer copy floats
on no pillar; a copy is a reflection, not a built thing.

## The bar

The owner's references: a dense, finished diorama rather than a crude one,
and a day/night toggle (pixel garden in a glass-pill frame) where every detail
is chosen. What that bar means here:

- **One palette, few hues.** Snow, warm stone, sage and patina, one gold. A
  second state (summer copy, night) re-colours the same palette; it never adds
  new hues.
- **One light story per place.** A low warm sun behind the first view's
  left, fixed in the world; blue snow shadows. One warm accent at most (the
  goal, the summer copy).
- **Material contrast does the work.** Matte snow and stone against clear,
  bright glass. Nothing else is shiny.
- **A clear focus, small rewards.** She, the mirror and the goal read first.
  Details (frosted grass, ivy, a far arbour) reward a closer look and never
  compete.
- **One grain.** Every piece shares the same level of detail and bevel size.
  No piece is noisier, sharper or smoother than its neighbours.
- **Grounded, not floating.** Places stand on old pillars that fall into
  mist; the wider garden shows faintly in the haze.
- **Nothing is static.** Snow drifts, mist moves, the copy glows softly.
  Changes ease (`ui/motion/motion.gd`); nothing pops.

## The place

An old garden in deep winter. Gameplay blocks are weathered limestone garden
masonry, edges softly rounded, thick snow on every top that drapes over the
edge. Absolutes (the ground that stays) carry a dark bronze-green patina band.
A mirror copy is the same shape in summer: warm stone, moss, small flowers,
a soft glow. The mirror is a thin frosted pane in a slim brass frame.

## Palette (approximate; tune against the target)

| role | colour |
| --- | --- |
| sky top | `#B0C1C9` |
| sky low, mist | `#EEE2D2` |
| snow, lit | `#F0EBE8` |
| snow, shadow | `#B9C6D3` |
| stone, lit | `#D8CCB4` |
| stone, shade | `#A79F92` |
| patina (absolutes) | `#4F6A5F` |
| gold (goal ring) | `#C99A4A` |
| moss, summer | `#8E9A4A` |
| summer glow | `#F3D9A0` |

## Rules for pieces

- Silhouettes read at phone size from the 30°/45° orthographic camera.
- Gameplay edges stay where the grid says; dressing may overhang by at most
  about 0.1 unit and never hides a walkable edge.
- Every piece is mirrorable: no text, no handed details that look wrong
  flipped.
- Colour comes from the palette atlas and baked AO, not from noisy textures.
- AI 3D results are drafts: remesh, then repaint in this palette.

# Brief: the first five minutes

DRAFT, 2026-10-30, for the owner's approval before code. Step 3 of the order
of work in [the vision](../VISION.md). Story: arc A, the pond
([story arcs](../story-arcs.md)).

## The fantasy

From the title to the first mirror, one unbroken stretch: a held breath, a
small girl alone in a snowed garden, a glimpse of someone who should not be
there, and the first time the glass opens a way that isn't there. No menu,
no cut, no sentence.

## Why it sparks joy

The player meets a person and a place before a puzzle. When the mirror
first rises, it already means something: it is her hand mirror, and the last
place she saw her sister.

## The stretch, beat by beat

| Time | Beat | The player does | What it teaches |
| --- | --- | --- | --- |
| 0:00 | **Title** (built): the snowed garden from afar, the pond at its centre. | Taps anywhere. | |
| 0:15 | **The sink** lands by the pond, not on a puzzle. She lies in the snow and slowly sits up, one left mitten on. Wind; the music is a single held note. | Waits, then taps the snow. | Walk. |
| 0:45 | **The hand mirror** lies on the ice, catching the light. She walks to it and picks it up. | Walks to the light. | Light marks what matters. |
| 1:10 | **The glimpse.** In the glass, for under a second, her sister waves with her right hand. The music thins to nothing. Then only snow. | Nothing: it happens to her. | The story's question. |
| 1:30 | **The way out** seems blocked; the garden beyond is broken into floating pieces. Turning the view lines a path up, like the first stage today. | Turns the view. | Turn the view. |
| 2:30 | **She walks on.** At the edge of the pond place she steps onto the path, and the camera travels with her to the next place. "The Garden" is written on the world. | Walks. | Places join; the garden is one world. |
| 3:00 | **The first mirror.** A gap she cannot cross. She holds up the hand mirror, and a tall pane forms from the ground like ice. On its far side the copy blooms in summer colour, with the same mirrored shape. | Raises the mirror, slides it. | The mirror. |
| 4:30 | **The goal** is where her sister stood a moment before, a faint warmth in the snow. She stops; one or two seconds of stillness; the light warms. Then on. | Reaches it. | Following her sister. |

## The feel work inside it

Each item follows "Moment-to-moment feel" in the vision.

- **Walking:** eased starts and stops, shorter steps, a little sway; she
  turns before she walks. Footprints in the snow that slowly fill. The
  grey-box pass is code (pace, easing, step timing); the real walk cycle is
  Blender work after the character is chosen.
- **Turning the mirror:** about 0.6 s with weight, settling at each
  direction (0.34 s today).
- **Raising and lowering:** the pane forms like ice over about 0.8 s; the
  copy blooms outward; the ground it replaces frosts and fades. Lowering
  wilts the copy back. Today both are instant.
- **Turning the view:** 0.8 s today; the owner says if it still feels quick.
- **Moving on:** the next place is already there; she walks out along a
  path and the camera follows (transition). Replaces the sweep.
- **Sound:** wind, footsteps in snow, one piano note on the title tap, a
  glass tone that opens into a chord on raising and resolves on lowering, a
  soft swell on turning the view. A Lyria sketch of the theme for the
  prologue, Flash-quality draft first.

## Her

She may change to fit the story: a small girl in winter, one left mitten,
like Deemo's girl. A Gemini Flash mockup round comes first; the owner picks.
Until then the grey box uses today's traveller. The Blender model work needs
a machine with Blender (not this cloud container).

## How it is built

- **A chapter is one world.** Each place stays its own level file. A chapter
  lists its places; each place is placed so its exit meets the next place's
  start, as the sweep does today. The next place is loaded ahead and shown
  in the distance.
- **Scenes** are short scripted sequences on a place: her pose, the camera,
  light, sound and waits for the player's tap or walk. One small sequencer,
  data in the level file. No words.
- **The hand mirror** becomes the mirror button's source: raising it plays
  her holding it up.

## Recommendation to decide

- **The hand mirror is the game's mirror.** She finds it in the prologue and
  every raised pane is it, grown. This answers the open question "carries
  the mirror from the start or finds it". Recommended: yes.

## Not in this brief

Final art, the rest of chapter 1, other chapters, the epilogue, a second
mirror.

## Review

One Movie Maker clip of the five minutes, then the owner plays it on a Mac.
Checks: only the tests for what changes (the walk between places, the scene
sequencer, the mirror raise).

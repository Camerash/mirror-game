# Her: mockup round 1 (2026-10-30)

Gemini Flash drafts (`tools/gemini/image.py`, model from `tools/gemini/models.json`)
for the new character and the prologue, per `docs/briefs/first-five-minutes.md`.
Each character prompt is `common.txt` plus one direction file. B used
`docs/art/traveller-target.png` as a reference; the prologue used
`docs/look-pilot/board-winter.jpg`. Results: `docs/art/her/*-01.jpg`.

Known misses in round 1: every sheet gives her two mittens, not one; the twins
come out identical, with no left/right difference; B's in-game figure copies
the old traveller; the prologue's hand mirror turns into a ring in panel 4.

# Round 2: a beanie (2026-10-31)

Owner: a beanie, not a pointed hat; do not let the old design limit her.
`common_v2.txt` plus `v2_a.txt`, `v2_b.txt` or `v2_c.txt`. Results:
`docs/art/her/beanie_{a,b,c}.jpg`.

- One mitten now holds on every view, and the twin pair is mirrored. The
  mitten lands on her right hand, not the left the story asks for; fix that
  in the model.
- C (long scarf) came out with stray floating heads; not usable as drawn.

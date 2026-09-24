# Standing hood actions — retired

This directory built the first animated study: two two-second clips, a body rig
with native IK, and an eight-morph garment. **Its Python is gone.** Only
`traveller_animated.blend` is still live, and only as the mesh that
[the single source](../traveller/) opens: `build_traveller.py` reads it as
`SOURCE` and rebuilds the character from there.

The animation moved to the single source. See
[`art_sources/traveller/hood_motion.py`](../traveller/hood_motion.py) for the
clips as data and
[`build_animation.py`](../traveller/build_animation.py) for the generator, and
[docs/art/traveller-animation.md](../../docs/art/traveller-animation.md) for the
result.

## Why the old pipeline could not be kept

It could not be run at all. `build_traveller.extend_rig` rebuilds each arm as
four deform segments and deletes the two-bone IK, the `ElbowPole` empties and the
`Thumb` bones that `arm_rig.py` and `motion.py` posed against. The clips they
baked survived in the blend and were inherited by every rebuild, which is how the
character came to carry 2.0 s clips that keyed two bones that no longer existed,
keyed `location` on a skinned chain, and touched nothing on the hood they were
named after.

The one piece worth keeping was the phase tables, and they are copied into
`hood_motion.py` unchanged, still in their original 0 to 60 frame space.

## What is still here

- `traveller_animated.blend` — the mesh upstream. Do not delete it.

The old two-second export, its bounds sidecar, and the retired checks'
`*_checks.json` reports were removed in `b1d2b6d`. The trial scene reads
`assets/character/traveller.glb`.

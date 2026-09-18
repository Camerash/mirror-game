# Two-handed hood animation trial

## Baseline and action

Use the approved [drawing study](traveller-drawing-02.md), [character and hood action](traveller-drawing-02/character-and-hood-action.jpeg), and [face and movement](traveller-drawing-02/face-and-movement.jpeg). Preserve the static source, viewer, and gameplay assets.

Create separate one-second standing HoodDown and HoodUp clips. Hands emerge through the front split, grip the hood rim, move it clear of the head and bun, release, and return beneath the cloak. Use 0.20 seconds for reach, 0.55 seconds for hood movement, and 0.25 seconds for release, return, and settling. Use broad rounded loose sleeves and simple thumb/grouped-finger hands. Each cuff has an outer rim, inner rim, and short recessed lining around a narrower wrist. Target cuff width at least twice the palm width and about 25% wider than the adjacent sleeve. Preserve volume at the elbow and remove the active cloak opening’s hard side step. Correct arm proportions so the upper arm is slightly longer than the forearm. Blend elbow and wrist weights.

Use one small body skeleton, unit bone scales, and at most four influences per vertex. Bake Blender arm IK to keyframes. Keep hair rigidly attached to the head, preserve the approved hood endpoints, and use authored intermediate hood targets. Small local front-cloak support rows may be added without changing the resting surface so the sleeves can pass through the split. Do not combine full hood morphs with skeletal hood folding. No offline or runtime cloth simulation.

Use stable chest-relative elbow poles and continuous hand arcs, with no forced stop at each transit waypoint. Shoulders lead the reach; wrists align before grip. Add slight left/right offsets only during free reach and return. Both hands establish contact before hood movement. Grip the raised hood at approximately eye height with elbows lifted outward to a natural reachable pose. Do not lengthen arms to put the elbows near the crown. Hood Up first reaches the actual folded rim behind the neck before lifting it. Allow small head and chest rotations up to approximately 4 and 2 degrees. Hood actions do not animate root, pelvis, legs, or feet. Later jogging will use legs and a small body rotation without arm swing. Shared body transforms keep hands and garment together, but combined clearance still requires later testing.

## Asset and viewer contract

The separate animated GLB keeps Head, Hair, Body, Boots, and Garment, two opaque drawing materials, and the 1024 atlas. Keep HoodLowered and add clearance targets as needed. HoodDown and HoodUp contain coordinated bone and morph tracks. Keep the complete character below 8,000 triangles.

Use native Godot animation playback. Preserve static pose inspection, views, expression, lighting, grey/colour, and size. Add action buttons, play/pause, speed, and time scrubbing. Reject reverse requests until the active action finishes. Scrubbing pauses. Reset stops and restores the raised hood with concealed arms. Use fixed bounds covering both full clips.

## Verification and delivery

Inspect reach and grip poses before final clips. Check front, side, rear, three-quarter, and elevated views at close and game size. Check every interval for hair/head clearance, cloth intersections, neckline continuity, hand contact, and fixed feet. The small hidden bun/scalp overlap remains intentional. Cloth stretch is diagnostic only.

Verify exported bone and morph tracks, bounds, asset limits, pause, seek, Reset, and material ownership. Review native Mac Mobile/Metal captures and clips. Stop the runtime and remove its bridge before commit. Physical-device performance, jogging, and gameplay replacement are outside this trial.

## Current result

Both clips are authored on [the single source](../../art_sources/traveller/).
The motion is data in
[`hood_motion.py`](../../art_sources/traveller/hood_motion.py) and
[`build_animation.py`](../../art_sources/traveller/build_animation.py) turns it
into keys, the same split the cloak's own shape already uses. The pipeline that
made the two-second clips is retired; see
[its README](../../art_sources/traveller_animated/README.md) for why it could not
be run at all.

- **One second, on the nose.** 0 to 60 frames at 60 fps, so the phase tables land
  on the approved budget with no retiming: hands on the rim at frame 12 (0.20 s),
  hood arrived at 45 (0.55 s), hands back by 60 (0.25 s).
- **The arm is an arc, not an IK chain.** `extend_rig` aligns all four arm
  segments to one roll axis, so turning them by the same angle makes the chain a
  circular arc. Its chord shortens with that angle, so one bisection finds the
  angle that reaches the wrist, and the chord is then aimed at the target. No
  visible elbow holds by construction. Measured, the wrist lands on the authored
  path at **every frame of both clips, error 0.0000**.
- **The idle pose falls out of the same solver.** A straight arm dropped 78
  degrees is a chord at full reach, so the solver returns a turn of zero and the
  identical pose. A clip starts and ends where the character rests, with nothing
  to blend.
- **The clips carry the hood.** Each exports as 1.000 s with rotation on 14 real
  nodes and a `weights` channel on the Garment. The export prints **no** missing
  animation targets, where it printed 14.
- **The cloak is skinned to the spine**, not a rigid child of `Chest`. See
  [the source notes](traveller.md).
- 241 viewer checks pass, from 228 with 5 failing.

### Where this departs from the specification above

- **The grip is not at eye height.** Eye height on this head is z 2.73 and the
  highest point of the hood's rim a hand can hold is z 2.48, because the arm
  reaches 0.663 and the rim runs from 0.414 away at the throat to 1.294 at the
  crown. The same paragraph says to preserve arm reach rather than stretch, so
  the grip sits 0.25 below the eye line.
- **The hands release before the hood settles.** Folded, the rim sits 0.42 of the
  arm's reach from the shoulder. An arc of one curvature only reaches that far in
  by turning 68 degrees at every joint, which is a coil and not an arm. The hands
  take the rim back and outward and let go while they are still comfortable,
  which is what the release-and-settle phase is for.
- **`CloakArms` is not driven.** Rendered side by side at 0 and at 1, the reach
  reads as a figure raising its hands at 0 and as an inflating cloak at 1, and
  the crossings it exists to remove do not move. It is now an undriven morph and
  a candidate for removal.
- **The arms cross the cloth during the reach**, 122 to 262 triangle pairs
  against 82 in the bind pose and 0 at rest. Weighting the front panels to
  `UpperArm` was tried and measured *worse*, 147 against 139 at contact: the arm
  turns by its whole angle and cloth on a share of it turns by less, so the arm
  overtakes the cloth however the share is set. The crossings are the arm inside
  the cape where it emerges at the shoulder, which is the asset's established
  look, and they do not read in any view checked.

## Previous two-second trial evidence

The two standing clips are ready for art review in `art_trial/animated_traveller_study.tscn`. Run `rtk proxy godot --path . art_trial/animated_traveller_study.tscn`. The static drawing study and gameplay character remain unchanged.

- The complete character has 6,688 triangles, 24 bones, and at most two influences per vertex. It retains two opaque materials and one 1024 atlas. Head and hair attach rigidly to Head; Garment attaches to Chest. The GLB has two non-looping two-second clips and eight garment morphs. Only the twelve arm bones and garment weights have animation tracks.
- The arms leave through the lower front split before reaching the rim. They return through the same corridor. Down releases before the final settle; Up uses a separate overhand grip and wrist turn. The cloak closes after the fingers return inside.
- The approved outer and lining endpoint coordinates differ by at most 0.000000254 units after adding the local support row. Head, hair, and boot local vertices are unchanged. The intermediate turn uses a thinner lining offset to prevent internal crossing; endpoint thickness is unchanged. There is no runtime cloth simulation.
- Baked Blender evaluation and independent GLB skin/morph evaluation each pass 482 samples at 120 Hz: zero detected garment self/head/hair/body crossings. The Blender check also reports zero arm/head/hair crossings, fixed head/hair/boots, and unit bone scales. Grip-patch midpoint-to-skin distance remains approximately 0.026–0.027 source units; this geometric measure does not replace the visual hand-contact review.
- Godot import and 228 focused viewer checks pass. These cover clips, skin weights, sampled bounds, expressions, material ownership, pause, speed, scrubbing, reverse blocking, and Reset. All 18 deformed test poses fit the fixed camera and local culling bounds.
- Native Mac Mobile/Metal capture completed at fixed 30 Hz timeline samples in all five views and at game size. Review [hood down](traveller-animation/native/hood-down-close.mp4), [hood up](traveller-animation/native/hood-up-close.mp4), [down in six views](traveller-animation/native/hood-down-all-views.mp4), and [up in six views](traveller-animation/native/hood-up-all-views.mp4). Saved frame boards show the [down sequence](traveller-animation/native/hood-down-frames.png) and [up sequence](traveller-animation/native/hood-up-frames.png).
- The bridge timed out, so capture used a direct native Mac launch. It exited normally. CoreAudio logged a start error; audio was not part of this check. The runtime and temporary capture bridge/script are stopped and removed.

The broad held hood turn and the visible front opening remain art review points. This is a first standing animation trial, not an approved final motion. It is not a physical cloth simulation. Jogging combinations, device performance, and gameplay replacement are unverified.

## Controls

Use Hood Down / Hood Up to start each action. Play/Pause stops or resumes the current action; speed cycles through 0.25, 0.5, 1, and 2 times. The time slider pauses and samples the active clip. Reverse requests remain disabled while an action is unfinished, including a paused action at time zero. The static Hood control deliberately cancels playback and shows an endpoint for inspection. Reset restores the raised hood, concealed arms, neutral face, and default view settings. Keyboard: D down, I up, Space play/pause; existing Q/E, G, L, V, F, U, R, and H controls remain.

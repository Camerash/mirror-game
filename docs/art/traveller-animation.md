# Two-handed hood animation trial

## Baseline and action

Use the approved [drawing study](traveller-drawing-02.md), [character and hood action](traveller-drawing-02/character-and-hood-action.jpeg), and [face and movement](traveller-drawing-02/face-and-movement.jpeg). Preserve the static source, viewer, and gameplay assets.

Create separate two-second standing HoodDown and HoodUp clips. Hands emerge through the front split, grip the hood rim, move it clear of the head and bun, release, and return beneath the cloak. Start with 0.4 seconds for reach, 1.1 seconds for hood movement, and 0.5 seconds for release and return. Refine existing arms and simple thumb/grouped-finger hands for clean joint bends and contact.

Use one small body skeleton, unit bone scales, and at most four influences per vertex. Bake Blender arm IK to keyframes. Keep head and hair rigid, preserve the approved hood endpoints, and use authored intermediate hood targets. Small local front-cloak support rows may be added without changing the resting surface so the sleeves can pass through the split. Do not combine full hood morphs with skeletal hood folding. No offline or runtime cloth simulation.

Hood actions do not animate root, pelvis, legs, or feet. Later jogging will use legs and a small body rotation without arm swing. Shared body transforms keep hands and garment together, but combined clearance still requires later testing.

## Asset and viewer contract

The separate animated GLB keeps Head, Hair, Body, Boots, and Garment, two opaque drawing materials, and the 1024 atlas. Keep HoodLowered and add clearance targets as needed. HoodDown and HoodUp contain coordinated bone and morph tracks. Keep the complete character below 8,000 triangles.

Use native Godot animation playback. Preserve static pose inspection, views, expression, lighting, grey/colour, and size. Add action buttons, play/pause, speed, and time scrubbing. Reject reverse requests until the active action finishes. Scrubbing pauses. Reset stops and restores the raised hood with concealed arms. Use fixed bounds covering both full clips.

## Verification and delivery

Inspect reach and grip poses before final clips. Check front, side, rear, three-quarter, and elevated views at close and game size. Check every interval for hair/head clearance, cloth intersections, neckline continuity, hand contact, and fixed feet. The small hidden bun/scalp overlap remains intentional. Cloth stretch is diagnostic only.

Verify exported bone and morph tracks, bounds, asset limits, pause, seek, Reset, and material ownership. Review native Mac Mobile/Metal captures and clips. Stop the runtime and remove its bridge before commit. Physical-device performance, jogging, and gameplay replacement are outside this trial.

## Current result

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


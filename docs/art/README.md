# Visual trial 01 — Earlier stage-spanning sheet

This is an earlier composition reference: **panel A** of [visual-trial-01.png](visual-trial-01.png), generated during the design discussion on 2026-09-08. Panel B is a comparison only.

![Approved art reference, panel A on the left](visual-trial-01.png)

The first art trial applies to **Level 1** after the camera and mirror mechanics pass. Match the reference's soft stone, warm daylight, cool night, smoky neutral background, restrained interface, and thin translucent sheet. Keep walkable surfaces readable from all four camera views.

The picture is a visual target. Its extra pillars and decorative cubes are not level instructions. The prototype retains its exact platforms, gaps, collision, goal, and reflection rules. Stone detail is procedural surface shading; the initial character remains a simple dark shape. The generated comparison remains unchanged as the reference.

Review the running level before extending the full treatment to the other puzzles and fixtures. Compare edit/play states, source-side marks, fall visibility, and phone/tablet layouts. Capture commands and actual test results are in the root README and VALIDATION documents.

## First in-game result

![Level 1, second camera view](trial-01-in-game.png)

This is the first procedural material trial, not the final Blender art kit. The reference remains the target for later refinement of stone shapes and depth haze.

## Visual trial 02 — Earlier reflection concepts

[Comparison image](visual-trial-02.png), generated on 2026-09-08. Its Panel D remains an earlier approximate material reference. Its light-direction cue is not the current shader decision.

| Panel | Reflected material | Edge light points toward |
| --- | --- | --- |
| A | Solid stone | Original space |
| B | Solid stone | Reflected space |
| C | Holographic stone | Original space |
| D | Holographic stone | Reflected space |

The target is an immersive world with depth fog, detailed stone, a bounded translucent sheet, and minimal controls. No sun/moon meaning is assigned to the sides. Keep holographic walking tops clear and absolutes solid. The extra pillars and cubes are image-generation additions, not level changes. Existing mockups are approximate references.

## Second in-game result

![Level 1 with holographic reflections](trial-02-in-game.png)

Native Mac capture of the earlier procedural trial. The mirror emits a continuous ribbon along its perimeter toward reflected space. Walking tops remain clear while sides are transparent. Mist is made from world-space layers; this is not volumetric fog. The stage keeps its original geometry.

## Earlier compact-frame trial

![Level 1 with the compact mirror frame](smooth-controls-in-game.png)

Native Mac capture on 2026-09-08. This is an earlier approximate trial. Its fixed three-unit square frame and faint extension do not define the current bounded panel. Current mechanics use local edge resizing, world-space yaw and pitch orbs, smooth translation with release snapping, and a translucent fog ghost with two fading afterimages.


## Bounded mirror workshop

These native Mac captures are older mechanics references for the bounded workshop, not new art targets.

![Bounded column comparison](extent-bounded-in-game.png)

The bounded panel keeps side obstacles and reflects only its selected aperture. The world-space orbs follow its animated edge. Stone detail keeps its source coordinates through cuts.

## Mirror shader board 03 — Current edge light

[Panel D](mirror-shader-03.png) is the current shader target. It replaces the earlier flowing-wave treatment and is a visual reference only, not an in-game capture.

Use an almost-clear panel centre with a fixed world-unit soft perimeter. Keep rare slow particles at the edge only. Short ribbons point uniformly into reflected space. Measure perimeter light with an edge-distance field so corners do not brighten through additive overlap. Do not add bloom, volumetrics, scene distortion, or contour bands.

## Current bounded controls in game

![Bounded panel with resize tabs](bounded-controls-in-game.png)

Native Mac portrait capture on 2026-09-09. The tabs resize from fixed opposite edges; the round rotation orbs stay on the panel. This records the procedural edge-light implementation, not the generated target.

## Free movement and continuous rotation

![Ground and height controls](continuous-controls-in-game.png)

![Intermediate reflected geometry during rotation](continuous-rotation-in-game.png)

Native Mac captures on 2026-09-09. Hollow knobs sit outside the frame; resize pills sit on its edges. Jade absolutes remain solid while reflected geometry follows the current angle. Final placement still uses quarter turns. These captures record the prototype, not a new generated art target.

## Direction and contact trial 04

`mirror-direction-contact-04.png` is the selected approximate B+C/E reference, made with the built-in image generator. Prompt: a bounded clear panel with an equal-perimeter one-sided light skirt, sparse outward motes, and a soft contact band crossing the top and side of one intact jade absolute. The image exaggerates light for readability. Runtime contact follows exact finite-panel intersections and never cuts an absolute. The earlier boards remain historical references.

Runtime review: `direction-contact-in-game.png` shows the earlier contrast correction on the jade contact seam and perimeter light; `placement-guide-in-game.png` shows the temporary ground reference. These are actual Mac Compatibility captures. The height control remains in its existing position and can cover part of a contact; moving it is deferred.

## Seam glow trial 05

`seam-glow-05.png` is a comparison made with the built-in image generator. **C: Mist glow** is selected. Prompt: compare a thin pearl contact seam with a narrow halo, soft surface glow, mist glow, and stronger contrast on jade and cream stone. Keep the object solid and show light across the top and side faces.

Use C for softness and colour only. Its mirror orientation is incorrect; runtime contours use the actual finite mirror plane and visible object faces. The wider surface band keeps a steady bright centre with slow, soft halo variation. It does not require bloom or volumetric fog.

## Prism guide trial 06

`prism-guides-06.png` is the selected revised **B: Soft ribbons** mockup, made with the built-in image generator. Prompt: retain B's scene and contact glow, reduce the four corner rays to faint, narrow pale blue-grey wisps with an earlier smooth fade, and keep platform contact light stronger. No filled prism faces or far cap.

This is an approximate visual reference. Runtime lines follow the four actual panel corners and reflected normal. Contact contours cover the panel and four side boundaries at any depth. The six-unit guide fade does not limit replacement or contact light.

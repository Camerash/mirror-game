Entries before commit `b1d2b6d` name studies that were removed. Git history
keeps them; this log is not rewritten to match.

# Latest check: direct mirror controls — 2026-10-04

- Built the direct controls trial (see `GAME_DESIGN.md`, "Direct controls trial 03"). Checked in a Linux cloud container with the official Godot 4.7.2 Linux build. **Not checked on a Mac, with Metal, or on a device.**
- Headless: every changed script passed `--check-only`. `tests/direct_controls_tests.gd`: **123 checks, 0 failures**. It covers axis picking in all four views (the six grid directions are 53° apart on screen), real mouse drags along X and straight up, a tap through the glass walking, the arrow, raise/lower keeping the place, a blocked turn going back, the fall ghost mid-drag, the camera staying still, key M, and the **Classic editor** switch. `tests/level_solvability_tests.gd -- --direct-only`: **33 checks, 0 failures** (stages 2 to 6 solved through the direct controls, near misses failing). `tests/prompt_tests.gd`: **78 checks, 0 failures**. `tests/app_flow_tests.gd`: **80 checks, 0 failures**.
- The tutorial playthrough ran headless from the title to the end card through `App`, with its screenshots replaced by a no-op in a scratch copy: **16 checks, 0 failures**. The real native script was not run.
- Visual check: native frames under Xvfb with Mesa's software Vulkan (llvmpipe), Forward Mobile renderer, at 1152×800 and 430×932. They show the raised mirror, a slide in progress with its guide line, the arrow held, and a lowered mirror's outline. The first set showed the arrow missing during a drag and the mirror button darkening while briefly disabled; both were fixed and re-captured. Software rendering is not a substitute for the Mac Metal check.
- Not run, following the exploration policy: `tests/run_tests.gd`, the classic pass of `level_solvability_tests.gd`, and the other suites. Classic behaviour is behind `direct_controls == false`, which `Game.new()` keeps. No export, Simulator, or device check.

# Latest check: simple reference traveller — 2026-09-12

- Refined the isolated traveller against the supplied close image. Kept simple mesh construction: **2,144 triangles total**, **560 cloak**, **600 hood**, one 512×512 atlas. Changed the sloped hood/opening, charcoal, triangular hem, feet, and three cloak shapes. Gameplay assets remain unchanged.
- Focused motion check passed 17 assertions during development. Final native Mobile/Metal reference check passed **643 checks, 0 failures**, no error output. It covers movement and turn limits, pause/resume, Reset, settling, 30/60 Hz consistency, local material ownership, and triangle limits. Actual Godot negative shape weight -1 was verified through the runtime tool.
- Native Mac review inspected rest, front, side, back, and normal camera distance. Corrected the initial hood profile, inward hood winding, deeply hidden face, atlas charcoal encoding, and a projecting collar. Saved the supplied target, previous/current views, and an eight-second normal/close motion recording; reviewed sampled motion frames for pose and hem continuity. MCP stopped without errors and its temporary bridge/autoload were removed.
- Same-camera Mac timing, off/on/off/on blocks with 30 warm-up and 120 measured frames each: median frame times **8.323 / 8.320 / 8.309 / 8.318 ms**; enabled controller mean **37.4 / 32.4 µs per call**. Apple M2 Pro, Godot 4.7.2, Mobile/Metal, 1152×800. Display pacing limits interpretation. No zero-cost or physical-device claim.
- No broad gameplay suite, game export, Simulator, or physical-device test. Raw recordings and temporary files remain outside Git. See `docs/art/reference-scene.md` for evidence and recording instructions.

# Latest check: soft illustration ceramic — 2026-09-12

- Applied NPR board panel B to the isolated reference scene. Preserved meshes, carvings, source-paired detail, cuts, and motion. Reduced grain, glaze contrast, clearcoat, and studio reflection contrast. Kept ivory originals, cool reflected sides, jade absolutes, and the mauve background.
- Godot MCP native review: Godot 4.7.2, Mobile/Metal, Apple M2 Pro; 1152×800 desktop and 430×932 portrait. Inspected overview, ceramic/jade details, opposite mirror view, cut/cap, and a short walking sequence. No runtime shader errors or new transparent-object ordering defects were observed. Narrow controls wrapped without overlap. Physical touch and device performance remain unverified.
- Initial headless and native regression runs passed their assertions but logged null-material errors when freeing character surface overrides. Replaced those overrides with materials on private mesh resources. A focused native lifecycle check then passed without errors. Added assertions for local mesh/material ownership and the soft cloak finish. Final native reference regression: **634 checks, 0 failures**, no error output. Repeated checks only to resolve this failure; broad gameplay tests were not run.
- Saved the selected generated board, prior overview, and current native captures. The earlier motion video and side-view captures 1/3 remain historical. See `docs/art/reference-scene.md`. No exports, Simulator checks, physical-device checks, or performance claims.
- MCP stopped without errors. Its temporary bridge and autoload were removed. Documentation assets remain excluded from exports.

# Latest check: ceramic reference detail refinement — 2026-09-10

- Kept this pass in the separate Mobile art scene. Added editable high-relief Blender sources and Cycles normal/AO/cavity/curvature bakes. Added source-paired glaze variation, fine crazing, clearcoat, a separate studio environment, silvered glass, and recessed goal shading. Existing gameplay assets and rules were not changed.
- Rebuilt the rounded hood and continuous patterned cloak. Native review caught a detached rim, an open crown, compressed hem UVs, hidden legs, wrong numeric-map encoding, and a remaining top groove. Corrected these in the source assets and regenerated them. The cloak now has restrained gait and inertia response, with a tested return to rest.
- Editor import passed. Focused reference-art checks passed **631 checks, 0 failures**, including closed oblique caps, numeric-map encoding and variation, reflected source variation, retained cloth shape keys, motion limits, and settling/reset. The broader gameplay suite was not repeated for this isolated art pass.
- Native Mac review used Godot 4.7.2, Mobile/Metal on Apple M2 Pro. Inspected 1440×760 and 390×844 windows, four stage views, character/ceramic/jade details, and the cut/cap controls. No runtime errors were reported. MCP was stopped and its temporary bridge was removed.
- Saved native review images and an eight-second 30 FPS motion recording. See `docs/art/reference-scene.md` for the before image, current images, source workflow, and remaining visual differences. This is a closer authored study, not a pixel-identical match. Physical iOS/Android, exports, and performance benchmarks were not run.

# Latest check: separate ceramic reference scene — 2026-09-10

- Added the isolated Mobile reference scene, real rounded ceramic/jade cores, source-space maps and arch shading, fitted goal socket, shaped character, glass/frame, repeatable gait, and one oblique cut demonstration. Existing playable-level assets were not replaced.
- The focused cut check passed **612 checks, 0 failures**: Mobile selection, imported core, separate cap surface, welded edge pairs, and cap-plane coordinates. This count includes individual mesh edge and cap-vertex assertions. The migration gameplay suite already passed **524 checks, 0 failures**; it was not repeated during art tuning.
- Native Mac review used Metal / Forward Mobile on Apple M2 Pro, 1440×760 desktop and 390×844 portrait. Inspected four views, character close view, source/reflected cut, exposed cap, moving hem and reset, glass, goal, and wrapped controls. The initial alternate-view fit clipped the stage; fitting projected stage bounds corrected it and the affected view was rechecked.
- Corrected early asset errors: axis conversion separated the face from the hood; separate pale panels did not follow the hem; goal cutter/rim used a local rather than world height. Final assets use one cloak with integrated hem faces and a real top socket. Final imports and native session had no runtime/shader errors. The bridge/autoload were removed after review.
- Native observation returned 119–120 FPS; a 60-frame process monitor sample averaged 10.006 ms on the portrait viewport. These are local observations with inspection active, not a device or isolated GPU benchmark. The eight-second 1152×800 recording used fixed 30 FPS; its encoding throughput is not runtime performance.
- Captures and comparison limits are in `docs/art/reference-scene.md`. Relief is shader-based, not an offline sculpture bake; the image remains an approximate target. Physical iOS/Android, Simulator, and game exports were not run.

---

# Earlier check: Mobile migration — 2026-09-10

- The full gameplay suite passed 524 checks, 0 failures. Native Mac startup reported Metal 4.0 / Forward Mobile on Apple M2 Pro; the runtime renderer query returned `mobile`. The active mirror and platform materials rendered without shader or runtime errors.
- First MCP launch timed out before bridge readiness; a native startup completed and a second MCP launch connected. The final session stopped cleanly and removed the temporary bridge. No exports or physical-device tests were run.
- Removed the Compatibility settings and fallback, Simulator preset/helper, resolution reduction, and shadow override. Physical iOS signing is intentionally unconfigured.

---

# Earlier check: ceramic, porcelain, and jade art trial — 2026-09-10

- Applied B + R3 + S1 to Level 1: mapped ceramic glaze and crackle, shallow arch relief, cool partly transparent porcelain reflections, solid carved jade, a thin metal frame, and near-clear glass. Level 1 haze is hidden. Other levels retain the simple prototype materials. Source mappings and plain cut caps preserve texture scale through slicing.
- Added an editable Blender character source and imported model with a small face, patterned cloak hem, feet, and two continuous hem blend shapes. Movement drives restrained cloth motion; editing freezes it and restoration clears it. The same model supplies the fall ghost. Blender 5.2.1 LTS was installed for asset generation.
- After integration, ceramic trial checks passed **14 checks, 0 failures**, legal-angle checks passed **47 checks, 0 failures**, and the gameplay regression suite passed **524 checks, 0 failures**. These cover the art contracts, unchanged capsule, cap classification, fixed frame thickness, cloth pause/reset, angled support, puzzle routes, and failure recovery. No broad suite was repeated during visual tuning.
- Native Godot 4.7.2 Compatibility review covered 1152×800 desktop and 390×844 portrait, all four camera views, a 15° tilted proposal, source reversal, 1×1 horizontal and 6×6 panels, walking and edit freeze, and the falling model with afterimages. The size and angle inspections used runtime state changes; they are not a physical touch test. Initial shadow acne, harsh jade detail, and hidden hem texture were corrected. Final texture imports use mipmaps and VRAM compression. The final native session stopped with no runtime or shader errors.
- Saved actual viewport captures in `docs/art/ceramic-trial-in-game.png`, `docs/art/ceramic-character-in-game.png`, and `docs/art/ceramic-fall-in-game.png`. Further local views are in the ignored `.mcp/screenshots/` folder (1789010130–1789010242 series).
- Limits: this is a first visual trial, not a pixel-identical reproduction. Platform silhouettes remain square; bevel and carving are surface shading. Lighting and the previously unseen character sides are authored interpretations. Mobile performance, physical touch feel, and device rendering remain unverified. No export or Simulator pass was run. The runtime bridge and autoload were removed before commit.

---

# Earlier check: angled reflection support — 2026-09-10

- Reproduced a support error on Level 1 with a 15° mirror tilt, which produces a 30° reflected ramp. A route across separate source blocks failed; the same route across one merged source block passed. At a fragment join, the capsule contact lay on the neighbouring face, but the query only checked the current face. It then lowered the support height and rejected the character as embedded.
- Support queries now accept a contact on an adjacent face with the same normal and plane. Graph sampling uses the full world for that check. The edge fallback, footprint clearance, and 45° walking limit remain in place.
- Focused reflected-join checks passed **10 checks, 0 failures**: split/merged heights, both route directions, graph support at the join, gaps, overhead clearance, steep slopes, and closed angled cut faces. Existing legal-angle checks passed **47 checks, 0 failures**, including native capsule traversal of uphill/downhill joints, confirmation, Undo, and Reset. An added graph assertion first used an unsupported packed-array method; conversion to Array corrected the test parse error. `git diff --check` passed.
- An exploratory sweep of 20 yaw/tilt combinations found **187 closed fragments and no unpaired edges**. The tested cap faces already exist; no mesh winding or cap-generation change was required. These checks do not establish the exact transforms in the user's screenshots.
- One Mac Compatibility diagnostic compared a steep reflected ramp with its normal holographic material and with transparency disabled at runtime. The opaque view showed filled surfaces; transparency exposed internal block faces. Local captures: `.mcp/screenshots/screenshot_1789005881_91868.png` and `screenshot_1789005915_37325.png`. This was a diagnosis, not a new material treatment. Steep-surface readability remains a playtest issue. A mirror tilt can produce twice that slope angle, so some reflected faces remain above the walking limit.
- The native session stopped without runtime or shader errors. Its temporary bridge and autoload are absent. No full gameplay suite, export, or Simulator check was run. Physical touch feel remains unverified.

---

# Earlier check: Constellation soft glow and tuning — 2026-09-10

- Applied selected B: brighter small pearl cores, soft radial halos, and a larger amber reference. Core and halo intensity use the existing distance weight. One shared radial texture supplies the effect without bloom. Halo footprints respect UI exclusion. Saved the approximate comparison board as `docs/art/constellation-03.png`.
- Added session-only brightness, glow, diameter, and halo sliders, Preview guides, and Reset defaults. Preview uses the last control in the current mode; gestures take priority. Tuning does not rebuild geometry, restart prediction, move the camera, or add history.
- Focused renderer checks passed for B defaults, reference caps, distance fading, fixed sizes, slider limits, UI/solid occlusion, and release fading. Controller tuning passed **25 checks, 0 failures**. Existing guide checks passed **88 checks, 0 failures**, and edit-control checks passed **22 checks, 0 failures**. UI checks passed for ranges, signal routing, no-signal sync, touch heights, preview availability, and portrait layout. Editor import/parse and `git diff --check` passed.
- Initial tuning tests used exact floating-point equality for Reset defaults and freed an unparented game test instance. The corrected test uses approximate comparisons and parents the instance before cleanup; it passed without leak warnings. Numeric settings are clamped after stepping to keep their values within slider limits.
- Mac Compatibility review used 1152×800 and 390×844. Checked idle debug preview, live slider changes, Reset defaults, rotating guides, and moving resize pills. A runtime comparison confirmed camera and prediction remained unchanged during tuning. The first portrait panel covered all guide points; the panel now caps at 220 logical units in narrow portrait, with Preview guides before the sliders. A focused follow-up capture showed 42 visible guide marks below it. Further settings remain scrollable.
- Captures remain local under `.mcp/screenshots/`: `screenshot_1788983955_96994.png` (desktop tuning), `screenshot_1788983974_22893.png` (rotation), `screenshot_1788983996_58357.png` (portrait resize), and `screenshot_1788984083_82856.png` (corrected portrait tuning). Both native sessions stopped without runtime or shader errors. The temporary bridge and autoload are absent.
- No full gameplay suite, export, or Simulator check was run for this display-only change. Physical touch feel remains unverified.

---

# Earlier check: Constellation snap guides — 2026-09-09

- Added small, passive snap dots for ground movement, height, resizing, and rotation. Current references are amber; selected targets are hollow pearl marks. Guides stay through settling and fade in 0.2 seconds. Removed the old grid, lower link, and ring ticks/markers. The approved subtle board is saved as `docs/art/constellation-02.png` and remains an approximate reference.
- Focused candidate and integration checks passed **88 checks, 0 failures**. They cover legal world-grid points, distance fading, angled resize centre correction, actual edge targets, unwrapped angle increments, no-snap mode, sheet press before movement, unchanged collision/history, release fading, ring capture, Cancel, moving-pill occlusion, and focus loss. Renderer checks passed for alpha, UI/solid occlusion, idempotent fade, and clear. Edit-mode checks passed **22 checks, 0 failures**; existing ring checks passed.
- One integrated regression passed **524 checks, 0 failures**, including both puzzle routes, support restoration, wall rejection, removal, Cancel, Undo, Reset, movement, prediction, input, and failure recovery. Final editor import/parse and `git diff --check` passed.
- Native Mac review used Godot 4.7.2 Compatibility at 1152×800 and 390×844. Inspected ground, height, resize, and rotation guides across four camera views in one session. Dots remained small and faint; the amber reference and hollow target were visible. A moving resize pill initially drew beneath its edge marker. Its occlusion now uses the current drawn pill bounds; the focused integration check verifies that correction. The screenshots precede this small correction.
- Local captures: `.mcp/screenshots/screenshot_1788949148_24031.png` (ground), `screenshot_1788949165_44111.png` (rotation), `screenshot_1788949191_34804.png` (angled resize), `screenshot_1788949220_55619.png` (portrait height), and `screenshot_1788949233_6652.png` (portrait ground). The process stopped without runtime or shader errors. Its temporary bridge and autoload are absent. Captures and generated output remain outside Git and exports.
- No export or Simulator check was run. Physical touch feel and readability on a physical phone remain unverified. No user playtest result is claimed.

---

# Earlier check: world-aligned rings and selective contact glow — 2026-09-09

- Replaced flat arcs with projected 3D rings centred on the panel. Turn lies in world X/Z; Tilt is perpendicular to local width. Rings grow with the panel, retain a 48-unit minimum projected major radius, and use a constant touch strip. The selected plane and radius stay fixed during a drag. Edge-on rings use the captured tangent.
- Focused ring checks passed: world-plane alignment, projection, growth, near-edge-on input, repeated/reversed travel, pointer capture, minimum portrait size, HUD blocking, and horizontal placement. The final edit-mode run passed **22 checks, 0 failures**. Prism contact checks passed **62 checks, 0 failures**; the existing contact check returned all eight flags true. Reflected-only, rotated, reversed, and mixed original/absolute inputs are covered.
- One combined regression passed **524 checks, 0 failures**, including both puzzle routes, movement, prediction, support restoration, wall rejection, removal, Cancel, Undo, Reset, and failure recovery. The final adjustment to match ring hit segments with visible HUD-clipped segments passed the focused ring check.
- Native Godot MCP review completed at 1152×800 and 390×844. Captured all four camera views, a runtime ring pointer/motion drag with snapped reflected geometry, 1×1 and 6×6 panels, portrait controls, and horizontal placement. The horizontal Turn ring and local Tilt ring are readable in the captures; originals and absolutes retain contact light. Holographic edge outlines remain visible on reflections. The native process stopped with no runtime or shader errors and removed its bridge and autoload.
- Early checks found an inferred Boolean type and a test that began resizing before the new mode camera fit ended. Both were corrected. One headless check was accidentally started while the native bridge was active; its bridge reported a port conflict. After stopping the native process, the same edit-mode check passed without that warning. This is not counted as a clean native check.
- No export or Simulator check was run. Physical touch feel remains unverified. The minimum ring size and the small stage in portrait still need user playtesting.
- Local evidence is under `.mcp/screenshots/`: desktop `screenshot_1788944622_29726.png`; held drag `screenshot_1788944636_93757.png`; alternate views `screenshot_1788944649_85384.png`, `screenshot_1788944650_70548.png`, `screenshot_1788944651_55803.png`; small/large `screenshot_1788944661_36469.png`, `screenshot_1788944674_15131.png`; portrait `screenshot_1788944674_968.png`, `screenshot_1788944691_82149.png`; horizontal `screenshot_1788944702_36433.png`. These images are runtime evidence and remain outside Git and exports.

---

# Earlier check: edit modes and target movement — 2026-09-09

- Added Move, Rotate, and Resize modes, stable screen-space rotation arcs, target selection during dragging, movement guides, and one blended camera turn. The default angle step is 15°; debug 0° retains legal continuous angles. The progressive mode tutorial remains a pending idea.
- One combined headless regression passed **524 checks, 0 failures**. It covers both puzzle routes, support restoration, wall rejection, removal, Cancel, Undo, Reset, failure recovery, prediction, movement, and control layouts.
- Focused checks passed: **22 edit-mode and target checks**, **68 bounded-mirror checks**, **47 legal-angle checks**, and **27 continuous-control checks**. HUD mode checks and stable-arc checks also passed. Arc checks include 390×844 portrait safe areas, separate hit regions, fixed 64-unit radius across panel sizes, repeated/reversed travel, and pointer capture. These are headless layout checks, not visual evidence.
- Initial integration checks found an inferred ray-distance type and an obsolete ring callback assignment. Both were fixed before the successful checks. Final editor import/parse passed. The final HUD-layout ordering change received the focused edit-mode check instead of another full regression.
- Godot MCP declined the Mac launch before starting a process. No alternative launch or native screenshot was made. The new GPU appearance, arc access in all four rendered views, camera motion feel, and physical touch feel remain unverified. No export or Simulator pass was run.
- The temporary MCP bridge and autoload are absent. Generated output remains outside Git.

---

# Earlier check: prism guides and contact boundaries — 2026-09-09

- Added the approved faint B corner guides: four 0.025-unit ribbons, 12% peak opacity, and a six-unit visual fade. Contact light now covers the panel and all four destination-column side boundaries. Original, reflected, and absolute surfaces share the C mist shader. Guide fade does not limit contact depth.
- Godot 4.7.2 headless prism-contact checks passed **74 checks, 0 failures**. Cases include distant contacts, source-side exclusion, reversal, resizing, translation, arbitrary and horizontal frames, actual cut/reflected fragments, removal, empty state, internal coplanar edges, adjacent surface bands, and non-overlapping corner bands. The existing eight contact results also passed after the boundary extension. An early test used an untyped empty array and reported a script error; the corrected typed-array check passed.
- The seven guide-state checks passed: four ribbons/six-unit extent, arbitrary frame and side sync, mesh reuse, resized origins, removal dimming, and absence without collision. Final headless editor import/parse and `git diff --check` passed. The temporary MCP bridge and autoload are absent.
- The runtime MCP tool declined launch before starting a process. No new native screenshot was captured, so GPU appearance, occlusion, and desktop/portrait visual density remain unverified. No export, Simulator, or full gameplay regression was run for this visual-only change. The approved mockup is retained in `docs/art/prism-guides-06.png`; it is not runtime evidence.

---

# Earlier check: soft intersection glow — 2026-09-09

- Applied selected **C: Mist glow** to the existing exact contact contours. The band is 0.36 world units wide with a thin steady pearl core and a soft cyan fade. Shader derivatives retain core visibility at a distance. Slow variation affects only the halo. The comparison image guides softness only; its mirror orientation is incorrect.
- Godot 4.7.2 headless contact check passed all eight results: finite, reused, angled, coplanar, changed normal, empty, wider band, and face clipping. `git diff --check` passed. No full gameplay suite or export was needed for this material change.
- The runtime MCP tool declined launch before starting a process. A local Mac capture was requested but has not been approved or run in this turn. The new GPU shader appearance and physical-device rendering remain unverified. No Simulator check was run.

---

# Earlier check: legal angles and mirror feedback — 2026-09-09

- Godot 4.7.2, Compatibility, Apple M2 Pro Mac. **47 focused angle checks passed**: free yaw/pitch, absolute 5° snap, side reversal without frame change, world-grid resize settling, no next-drag correction, convex slope support/penetration, uphill/downhill capsule motion, legal confirmation, Undo, and Reset. Surface-query checks include 0°, 20°, 44°, 45°, 46°, and 60° slopes. Final review found that flat/ramp joints were too restrictive; the corrected capsule-edge support and surface-following route checks passed at 20°, 30°, and 45°, including native movement across a 45° joint in both directions. Convex gap and overhead-clearance rejection passed.
- **1713 geometry checks passed**, comparing the convex calculation against the independent legacy box path at cardinal orientations, including closed cuts and absolute subtraction. Contact checks passed for finite/angled/coplanar contours, mesh reuse, changed normals, and empty meshes.
- One integrated regression pass: **511 checks, 0 failures**. Both puzzle solutions, support restoration, wall rejection, removal, Cancel, Undo, Reset, prediction, failure recovery, input, and layouts passed. That run reported one leaked visual node from the new contact test fixture. The fixture now parents the effect before freeing it. A focused cleanup/debug-format check passed 28 checks with no leak warning. The full suite was not repeated for this cleanup or visual tuning. Later slope-joint changes received the focused angle checks instead of another full pass.
- Native Mac review used 1152×800 and 390×844. Captured four camera views, source reversal, a 17° pitch, movement grid, portrait controls, and fall ghost. Initial contact/ribbon contrast was too faint. A targeted desktop/portrait follow-up inspected corrected band UVs, stronger contact contrast, and more visible outward light. Both native logs have no script or shader errors. The height control position remains unchanged by design; it can cover part of a contact.
- Early implementation checks found a typed-array assignment, a missing Dictionary annotation, and an invalid SpinBox property. These were fixed before the successful checks. A later test edit had an indentation error; the corrected final angle test passed. Failed attempts are not counted as successful checks.
- Godot MCP declined its launch before starting a process. The user then explicitly approved the local CLI Mac review. Native processes exited after capture; the temporary MCP bridge and autoload are absent. No exports, Simulator, or physical-device checks were run. Physical touch feel and mobile GPU performance remain unverified.
- Logs: `.local/legal-angles-final.log`, `.local/legal-parity.log`, `.local/legal-contact-final.log`, `.local/legal-regression.log`, `.local/legal-native.log`, and `.local/legal-effects-native.log`, `.local/legal-cleanup.log`, and `.local/legal-parse-final.log`. Local captures: ignored `test-output/legal-*.png`. Retained art evidence is under `docs/art/`; documentation assets stay excluded from game exports.

---

# Earlier check: free movement and continuous rotation — 2026-09-09

- Godot 4.7.2, Compatibility renderer, on this Apple M2 Pro Mac. Final headless editor import/parse passed.
- Focused display geometry: **1713 checks, 0 failures**. Closed box/cut volumes, snapped parity across the level fixtures and orientations, arbitrary-angle fragments, and absolute subtraction passed. The continuous path is visual only; snapped physics remains unchanged.
- Focused controller checks: **25 checks, 0 failures**. Ground X/Z drag, height movement, half-unit settling, immediate intermediate rotation, reverse/full turns, nearest-quarter settling, horizontal placement, Cancel, confirmation guards, and persistent mist/absolute nodes passed. Focused ring/resize input checks also passed.
- One integrated regression pass: **507 checks, 0 failures**. Both puzzle routes, support restoration, wall rejection, removal, Cancel, Undo, Reset, failure recovery, movement, and responsive layouts passed. After review, a focused check verified the fix for a yaw command on a horizontal panel leaving prediction pending; the full suite was not repeated.
- Native Mac review used 1152×800 and 390×844 windows. Intermediate reflected geometry, hollow knobs, resize pills, jade absolutes, and horizontal placement rendered without shader errors. The first run found a missing desktop height control. The corrected control passed the focused runtime check and a targeted desktop/portrait visual follow-up. These early failed checks are not counted as successful checks.
- Unchanged boxes keep their mesh path. Rendered fragment instances and materials are reused; mist layers retain their animation clock. The view no longer deletes and rebuilds all platforms and mist on each pointer update. Captures show intermediate angled reflections, not a fade between discrete layouts.
- Evidence: `.local/continuous-geometry.log`, `.local/continuous-controls-final.log`, `.local/continuous-rings-final.log`, `.local/continuous-regression.log`, `.local/continuous-native.log`, `.local/continuous-final-native.log`, and `.local/continuous-parse-final.log`. Local captures are in ignored `test-output/continuous-*.png`; retained examples are in `docs/art/continuous-*-in-game.png`.
- An optional final launch through Godot MCP was declined by the tool before launch. It is not counted as a completed check. The earlier native CLI reviews remain the runtime evidence. The temporary MCP bridge and autoload are absent.
- No exports, Simulator checks, or physical-device checks were run. Physical touch feel and mobile GPU performance remain unverified. Native review processes closed after capture. Documentation assets remain excluded from game exports.

---

# Earlier check: bounded mirrors and edge light — 2026-09-09

- Godot 4.7.2, Compatibility renderer, on this Apple M2 Pro Mac. Final headless editor import/parse passed; `.local/bounded-parse.log` has no errors. The temporary MCP bridge and autoload are absent.
- Focused `tests/extent_tests.gd`: **67 checks, 0 failures**. Covers bounded clipping, source material coordinates, fixed opposite edges, whole-unit sizes, half-unit centres, repeated grow/shrink cycles, placement limits, rotation after resizing, collision and camera stability, pointer capture, settling, Cancel, Undo, and fresh creation after removal.
- Focused `tests/ring_tests.gd` passed. Covers attached orbs during animated poses after resizing, captured gesture axes, repeated signed turns, outside release, resize target separation, and stable orb selection when both intersections are blocked.
- One integrated `tests/run_tests.gd` pass: **503 checks, 0 failures**, with no script errors. Both puzzle solutions, bounded collision, support restoration, wall rejection, removal, Cancel, Undo, Reset, failure recovery, movement, prediction, and responsive layouts passed. The sheet-input tests now avoid rotation-orb touch regions when selecting a translation point.
- One native Mac review used 1152×800 and 390×844 windows. Inspected all four views, a held four-turn yaw gesture, direct resizing, horizontal placement, partial cuts, 1×1 and 6×6 panels, and the holographic fall preview. No script or shader errors were logged. A focused portrait follow-up checked the corrected guidance wrapping and resize-arrow symbols; it passed.
- Visual result: clear panel centre, fixed-width soft edge light, short reflected-side ribbons, and sparse edge particles. Rotation orbs follow the panel edges. Resize tabs are distinct square controls with drag-direction arrows and separate 48-unit touch regions. The shader board is an approximate reference; this is a procedural prototype, not final art.
- Logs: `.local/bounded-focused.log`, `.local/bounded-rings.log`, `.local/bounded-regression.log`, `.local/bounded-native.log`, and `.local/bounded-ui-review.log`. Captures remain in ignored `test-output/`; `docs/art/bounded-controls-in-game.png` retains the final portrait example. Documentation images remain excluded from game exports.
- No exports, Simulator checks, or physical-device checks were run. Physical touch feel and mobile GPU performance remain unverified. The native review closed the game after capture.

---

# Earlier check: mirror extent and world-space rings — 2026-09-08

- Godot 4.7.2 on this Mac with Compatibility rendering. The final headless editor import/parse passed.
- `tests/extent_tests.gd`: **50 checks, 0 failures**. Covers full/column replacement, aperture cuts, side entry, absolute priority, source material mapping, mode reset, dimensions, removal/fresh creation, horizontal placement, source reversal, Cancel, and Undo.
- `tests/ring_tests.gd`: focused ring checks passed. Covers angle wrapping, signed quarter turns, captured axes, orb picking, dead-centre input, repeated turns, and pointer release outside the ring.
- `tests/extent_review.gd`: one completed native Mac review at 1152×800 and 390×844. Inspected both modes, all four camera views, a partial cut, horizontal placement, and Level 1. Its held yaw-orb revolution completed four turns through the real controller. Final runtime log has no script or shader errors.
- The first focused geometry run found an untyped fallback array in bounded subtraction; it was removed. Native review setup initially attempted editing before level physics settled; the capture script now waits. These failed attempts are not counted as successful checks.
- Full plane covers much of the view; bounded mode shows the selected column and retains side obstacles. Ring visibility and placement were inspected in all four views; physical drag feel still needs a user playtest. Source stone seams remain at their source coordinates after cutting. Detailed materials are enabled in the comparison fixture for this check.
- This comparison remains experimental. No full regression suite, puzzle replay matrix, export, Simulator, or physical-device pass was run for it. Previous smooth-control evidence is recorded below. Physical touch feel and mobile GPU performance remain unverified.
- Logs: `.local/extent-tests.log`, `.local/ring-tests.log`, `.local/extent-native.log`, `.local/extent-parse.log`. Captures: ignored `test-output/extent-*.png`; two retained examples are in `docs/art/extent-*-in-game.png`. The temporary MCP bridge is absent. The native review exits after capture.

---

# Earlier check: smooth mirror controls — 2026-09-08

- Godot 4.7.2 Compatibility renderer on this Mac. Headless import/parse passed.
- Focused smooth-control run: **83 checks, 0 failures**. Covered continuous display versus committed state, snap settling, queued quarter turns, signed tilt cycles, fixed frame dimensions, stable orbit scale, and resize cancellation.
- Integrated regression run: **512 checks, 6 failures**. Both puzzle solutions, movement, support restoration, clipping, absolute priority, wall rejection, prediction, Undo, Reset, failure recovery, gesture tests, and layout checks passed. The six failures were in an older sheet-drag test that reused screen coordinates after the camera refitted.
- Corrected that test to reacquire visible sheet points before each gesture. Reran only the affected interaction group: **132 checks, 0 failures**. No game-code change was needed for those six failures. The full suite was not repeated.
- An earlier worker invocation ran the legacy full runner during incomplete integration. It is not counted as final validation; later visual tuning used only targeted checks.
- One native Mac session inspected Level 1 in all four camera views, editing and placed states, removal/fall preview, and 390×844 portrait. A targeted follow-up checked two fixes found there: hiding grips on removal and keeping the portrait grip pair together. Native logs had no script or shader errors.
- Visual result: compact frame remains readable; reflected platforms stay visible through it. The falling ghost has a translucent fog fill and fading afterimages, without a trajectory or outcome label. Material detail remains procedural prototype art.
- Logs: `.local/smooth-focused.log`, `.local/smooth-regression.log`, `.local/smooth-interaction.log`, `.local/smooth-visual.log`, and `.local/smooth-visual-fixes.log`. Native captures are in ignored `test-output/smooth-*.png`.
- No export, Simulator, or physical-device pass was run. Physical touch feel remains unverified. Wider placement is permitted, but alternative puzzle solutions still need user playtesting.

---

# Prototype validation

## Immersive controls and holographic trial — 2026-09-08

- The integrated regression pass completed **439 checks with 0 failures and no script errors**. This includes both puzzle solutions, fresh creation after removal, Undo, support restoration, preview physics, camera turns, sheet dragging, and responsive control bounds. A focused gesture/grip pass also passed after adding four grip cases.
- Development used focused checks. An initial integration attempt exposed HUD parse errors; the next run exposed a new test using the headless default 64 × 64 viewport. Both were fixed before the successful regression pass. Full-suite runs were not used to tune each visual change.
- Native Mac Compatibility rendering was inspected in a 1152 × 800 desktop window and a 390 × 844 portrait window. One session captured all four camera views, editing, committed placement, and removal/fall feedback. Targeted captures then checked the corrected goal detail and failure label. No shader errors were logged.
- Review corrected overlapping narrow controls, low-contrast grips, faint haze, ribbon direction, and a failure label behind controls. Light ribbons use the same distance fade on all four edges and extend along the reflected normal. The approved reference is approximate; the trial retains simple box geometry and procedural surface detail.
- The final outline-only removal surface and recovery-button colour changes received a diff review; they do not alter interaction or physics. Physical touch feel, mobile GPU performance, and physical safe areas remain unverified. No Simulator or export pass was run.
- Evidence: `.local/immersive-tests.log`, `.local/immersive-visual.log`, `.local/immersive-final-visual.log`, and `test-output/immersive-*.png`. The retained in-game image is `docs/art/trial-02-in-game.png`. The debug bridge is absent.


## Exploration policy and visual concepts — 2026-09-08

- Applied the new policy: focused checks during exploration; full regression checks after design confirmation. Earlier broad runs below are historical evidence, not the required workflow for each idea.
- Removed the sheet sun/moon labels and added smooth movement-facing eyes to the character. Godot headless editor import/parse passed; the main review checked the code diff. No runtime visual check, full suite, layout matrix, export, or Simulator run was performed for this pass. Movement-facing appearance remains to be reviewed in the next play session.
- Saved the generated material and edge-light comparison as `docs/art/visual-trial-02.png`. It is a concept for user review, not runtime evidence. Minimal gesture controls and holographic rendering remain proposals.

## Visual trial 01 — 2026-09-08

- The combined suite passed **498 checks with 0 failures**, including unchanged visible/collision bounds in every level, both puzzle routes, camera/sheet input, prediction, and responsive controls.
- Native captures completed without shader errors or leaked-object warnings. Level 1 was inspected in all four camera views, during editing and play, and in phone/tablet layouts. Original stone stays warm and reflected stone stays cool as the camera turns; the material projection uses world normals.
- The saved concept remains unchanged at `docs/art/visual-trial-01.png`. Panel A is the approved target. `docs/art/trial-01-in-game.png` records the first procedural result. The art trial is limited to Level 1; other levels retain their simple materials and cream interface.
- Godot MCP Runtime replayed both routes after the art changes. Both goals completed; the runtime stopped without errors and removed its bridge. The final Mac export and 180-frame graphical startup passed.
- Documentation images are excluded from Godot imports and export presets. No collision, goal, or reflection rules changed for the art trial.
- Evidence: `.local/art-tests.log`, `.local/art-captures.log`, `.local/art-play.log`, `.local/art-export.log`, `.local/art-mac-startup.log`, and the `test-output/trial-*.png` captures.
- This is a first material and lighting trial toward the reference, with simple box silhouettes. A finished modular stone kit and richer depth haze remain later art refinements. No Simulator or physical-device check was run.

## Camera and sheet interaction — 2026-09-08

- The full mechanics suite passed **497 checks with 0 failures**. After the final camera-transition guard, a focused interaction run passed **132 checks with 0 failures**, including refitting during a camera turn.
- Quarter turns, source reversal, horizontal placement, stable pivots, multi-point sheet dragging in all four views, release outside the sheet, UI blocking, and fixed zoom during dragging passed. Both puzzle solutions still complete with all axes available.
- Responsive checks passed at the five existing phone/tablet/desktop sizes. Native captures exposed panel occlusion that numeric target checks missed; editing now reserves a stage area above the phone controls or beside the wide-screen controls.
- Mac captures show the actual sheet, local haze, all orientations/source sides, four camera views, and the contrast-stroked fall preview. Transparent draw ordering was corrected so the backdrop cannot cover the sheet or labels.
- Godot MCP Runtime replayed both puzzle routes through actual UI and world clicks. Both goals completed without runtime errors; the bridge was removed. The final native Compatibility startup passed without shader errors.
- Evidence: `.local/mechanics-tests.log`, `.local/final-interactions.log`, `.local/mechanics-play.log`, `.local/mechanics-startup.log`, and `test-output/trial-*.png`.
- No Simulator or physical-device pass was run. Physical touch feel, safe areas, and mobile performance remain pending under the Mac-first policy.

## Direct mirror controls and world feedback — 2026-09-08

- The automated suite passed **336 checks with 0 failures**. It covers direct diagonal routes, obstacle detours, gaps and narrow passages, full-footprint support, and absolute contact highlights.
- Prediction tests use a separate collision world and compare predicted endpoints with actual capsule motion. Safe landings, failure, restored support, wall rejection, mid-fall velocity, stale result rejection, Cancel resumption, and Undo passed.
- Mac layout checks passed at 390×844, 844×390, 768×1024, 1024×768, and 1152×800. Touch targets and menu rows meet the 48-unit minimum. Edit options have a visible scroll area. Test options leaves Confirm and Cancel visible at every checked size.
- Native Mac captures show the split atmosphere and boundary-only comparison, Level 2 reflection and restoration, all three plane orientations with both source directions, and the falling ghost. The fixed camera keeps the stage readable; failures below the view use a No landing edge marker.
- Godot MCP Runtime replayed both puzzle routes through actual control and world clicks, including Enable → Confirm, Modify → Confirm, and Modify → Disable → Confirm. Both goals completed. The runtime stopped with no errors and removed its temporary bridge.
- All nine level JSON files parse. The Mac export completed without errors or warnings and passed a graphical startup check for 180 frames on this Apple M2 Pro Mac.
- Local evidence: `.local/current-tests.log`, `.local/play-levels.log`, `.local/export-macos.log`, `.local/mac-startup.log`, `test-output/`, and `.mcp/screenshots/`. These generated files stay outside Git.
- No Simulator or physical-device checks were run. This pass uses native controls, existing character physics, and simple Compatibility shaders. No new native plugin or export architecture requires a focused Simulator pass. Touch feel, safe areas, and performance on physical devices remain unverified.

## Level 2 and level flow — 2026-09-08

- The final automated suite passed **272 checks with 0 failures**. It covers both puzzle routes, restoration on ordinary support, early deactivation and failure recovery, Cancel, Undo, Reset, and progression through the HUD.
- Next level appears only after Level 1 completion. It opens Level 2, updates the picker, and clears old movement and history. The last puzzle does not advance into technical fixtures.
- Fixed mirror touch opens preview without a drag. Offset controls and movement arrows are absent. The action buttons use two columns to fit the side panel.
- Layout checks passed at 390×844, 844×390, 768×1024, 1024×768, and 1152×800. They check touch sizes, control widths, and the Next level button. Native Mac captures show both boundary styles and Level 2 with reflected support and the restoration preview. The panel still needs scrolling on short windows.
- Godot MCP Runtime replayed both levels through control clicks and world clicks on Mac, including Next level and the supported restoration preview. Both goals completed. The final run stopped without runtime errors and removed its temporary bridge.
- The updated Mac app exported without errors or warnings and passed a graphical startup check for 180 frames on this Apple M2 Pro Mac. All eight level JSON files parse.
- Final local evidence: `test-output/level2-*.png`, updated Level 1 captures, and `.mcp/screenshots/`. `.local/play-levels.log` records the control replay.
- No Simulator or physical-device check was run for this step. It changes level data and existing native controls; no new platform feature requires a focused Simulator pass.

## First prototype and tool setup

Checked on 2026-09-08 with Godot `4.7.2.stable.official.ed1daf0bf`.

| Check | Result |
| --- | --- |
| Headless project import and script parsing | Passed |
| Automated suite | 162 checks, 0 failures |
| Geometry | Partial cuts, reflected positions, source reversal, absolute overlap removal, support, and wall conflicts passed |
| Real physics | Boundary crossing, unchanged position, restored support, downward falls, safe landing, failure, and Undo passed |
| Level 1 | Intended route passed through shared commands; earlier iPhone Simulator touch pass completed Level 1 |
| Input | Screen ray selection, HUD click, snapped touch drag, and release over the HUD passed |
| Layout | 390×844, 844×390, 768×1024, 1024×768, and 1152×800 checked; visible control targets are at least 48×48 logical units; menu rows also meet the minimum height |
| Visuals | Outline and translucent boundaries rendered; original, reflected, and patterned absolute surfaces inspected; horizontal fixture inspected |
| Mac export | Built and launched on this Apple M2 Pro Mac |
| iOS Simulator export | Earlier unsigned export built and installed on iPhone 17 and iPad Pro 11-inch (M5), iOS 26.3; final Simulator restart later stalled on a blank background |
| Build helper and data | Python syntax and all seven JSON files passed |

The first ARM Simulator link failed: the official library contains only `x86_64`, despite listing ARM support in its metadata. The build helper detects this and builds Intel code. Both Simulator apps launched through Rosetta. The first full-quality run had a long startup and slow software rendering. Simulator exports now disable shadows and use 35% 3D resolution while retaining full-resolution controls. In the earlier pass, iPhone touch preview, enable, apply, walking, adjustment from an absolute, and goal completion were checked. iPad rendering and portrait and landscape layouts were inspected. A later final Simulator restart stalled on a blank background, so the Simulator result is unresolved and is not treated as final verification. Apple runtime logs contain duplicate system-class notices; no game script errors were found in the captured iPhone log.

Local evidence is in the ignored `test-output/` folder: rendered layout comparisons, `horizontal.png`, `iphone-complete.png`, `iphone-landscape.png`, `ipad-simulator.png`, and `ipad-landscape.png`. Use the capture command in README to create new images after a change.

After the rapid-prototype policy change, Godot MCP Runtime 3.3.0 passed a Mac connection and runtime check: project metadata, control discovery, a click that opened mirror preview, and a captured viewport. The server stopped with no runtime errors and removed its temporary bridge; `project.godot` was unchanged. The exported Mac app also passed a headless startup check. The screenshot is in `.mcp/screenshots/`. No further Simulator checks were run for this follow-up.

## Test limits and next playtest

- Mac runtime, headless checks, and Mac window-size checks are the default rapid-prototype validation. Simulator timing is not a physical-device performance measurement. Physical iPhone, iPad, and Android tests are pending.
- Routine Simulator checks are deferred. Run one focused Simulator pass only when an unchecked platform-specific feature could cause substantial rework, or when explicitly requested; state the concrete risk first. The unresolved blank-background restart remains deferred under this policy.
- This is an agent-operated technical check. No user playtest observations have been collected.
- Test whether a new player sees the goal, predicts a useful mirror position, recognises the striped resting platform, and uses Undo after an experiment. In Level 2, check whether the player remembers the hidden original approach and understands that it can replace reflected support. Record confusion and safe alternative solutions. Do not add a score or time limit.
- On a physical phone, check direct resize and rotation input, edge-light direction, the fall ghost, and absolute contact highlights. Record whether players understand the bounded column and fixed opposite edge without opening debug controls.
- Navigation currently covers clear, connected flat surfaces. Ladders, keys, stepped routes, multiple mirrors, generation, sound, and final art are later milestones.

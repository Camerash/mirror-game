# Latest check: mirror extent and world-space rings — 2026-09-08

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
- Compare split atmosphere with Boundary only on a physical phone. Check whether players find the scrolling edit options, understand the fall ghost and absolute contact highlights, and prefer moving edits or Standing still only.
- Navigation currently covers clear, connected flat surfaces. Ladders, keys, stepped routes, multiple mirrors, generation, sound, and final art are later milestones.

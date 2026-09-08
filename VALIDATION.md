# Prototype validation

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

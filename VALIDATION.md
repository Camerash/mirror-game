# First prototype validation

Checked on 2026-09-08 with Godot `4.7.2.stable.official.ed1daf0bf`.

| Check | Result |
| --- | --- |
| Headless project import and script parsing | Passed |
| Automated suite | 162 checks, 0 failures |
| Geometry | Partial cuts, reflected positions, source reversal, absolute overlap removal, support, and wall conflicts passed |
| Real physics | Boundary crossing, unchanged position, restored support, downward falls, safe landing, failure, and Undo passed |
| Level 1 | Intended route passed through shared commands; also completed with touch controls in iPhone Simulator |
| Input | Screen ray selection, HUD click, snapped touch drag, and release over the HUD passed |
| Layout | 390×844, 844×390, 768×1024, 1024×768, and 1152×800 checked; visible control targets are at least 48×48 logical units; menu rows also meet the minimum height |
| Visuals | Outline and translucent boundaries rendered; original, reflected, and patterned absolute surfaces inspected; horizontal fixture inspected |
| Mac export | Built and launched on this Apple M2 Pro Mac |
| iOS Simulator export | Built unsigned with matching templates and installed on iPhone 17 and iPad Pro 11-inch (M5), iOS 26.3 |
| Build helper and data | Python syntax and all seven JSON files passed |

The first ARM Simulator link failed: the official library contains only `x86_64`, despite listing ARM support in its metadata. The build helper detects this and builds Intel code. Both Simulator apps launched through Rosetta. The first full-quality run had a long startup and slow software rendering. Simulator exports now disable shadows and use 35% 3D resolution while retaining full-resolution controls. iPhone touch preview, enable, apply, walking, adjustment from an absolute, and goal completion were checked. Portrait and landscape layouts were inspected. Apple runtime logs contain duplicate system-class notices; no game script errors were found in the captured iPhone log.

Local evidence is in the ignored `test-output/` folder: rendered layout comparisons, `horizontal.png`, `iphone-complete.png`, `iphone-landscape.png`, `ipad-simulator.png`, and `ipad-landscape.png`. Use the capture command in README to create new images after a change.

## Test limits and next playtest

- Simulator timing is not a physical-device performance measurement. Physical iPhone, iPad, and Android tests are pending.
- This is an agent-operated technical check. No user playtest observations have been collected.
- Test whether a new player sees the goal, predicts a useful mirror position, recognises the striped resting platform, and uses Undo after an experiment. Record confusion and safe alternative solutions. Do not add a score or time limit.
- Compare the two boundary styles on a physical phone. The control panel scrolls on short screens; check whether players find the lower options.
- Navigation currently covers clear, connected flat surfaces. Ladders, keys, stepped routes, multiple mirrors, generation, sound, and final art are later milestones.

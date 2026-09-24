# Mirror

[`HANDOFF.md`](HANDOFF.md) has the current state, what is blocked, and the traps. Read it before changing a level, the character, or the level sequence.

A small Godot 4.7.2 prototype. It opens on a title screen and plays a six-stage tutorial: **First steps**, **A place to stand**, **The path beneath**, **Only the ground**, **Another way round** and **Together**. Progress saves and resumes. In debug builds, the gear panel also opens any stage or technical fixture. Run with `-- --release-ui` to see the release settings panel in the editor. The current rules and pending stories are in [GAME_DESIGN.md](GAME_DESIGN.md).

## Run on Mac

Install Godot 4.7.2 and its matching export templates. From this folder:

```sh
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path .
```

Open `project.godot` in Godot to edit the project. The exported local app is `build/macos/Mirror.app`.

| Action | Touch or mouse | Keyboard |
| --- | --- | --- |
| Walk | Short tap on a platform top | — |
| Create mirror | Hold empty space for 450 ms | M uses fresh level defaults |
| Edit mirror | Hold its visible sheet | M |
| Select edit mode | Bottom-right mode icon cycles Move, Rotate, Resize | 1 Move; 2 Rotate; 3 Resize |
| Move | Drag the sheet across X/Z at captured height; drag the height control for Y | [ / ] and Page Up / Page Down |
| Rotate | Drag the horizontal Turn ring or the Tilt ring | Arrow keys |
| Resize mirror | Drag a local top or side pill | Debug width / height |
| Turn camera | Mobile swipe on empty space; desktop curved arrows | Q / E |
| Remove / keep in preview | Contextual bottom action | D |
| Confirm / cancel | Short tap on the sheet / Cancel | Enter / Escape |
| Recover | Contextual Undo; Reset after failure or in gear panel | Z / R |
| Debug controls | Top-right gear | — |

Debug panels start hidden. They contain level selection, numeric controls, collision outlines, atmosphere options, **Angle snap** (0–90° in 5° steps; default 15°, 0 means No snap), **Standing only** mode, and bounded mirror dimensions. Debug dimension changes use the same fixed-edge operation as the local tabs. The prototype supports one mirror. After removal, creation uses the new press and fresh level defaults; it never restores a saved placement. Undo can restore a removed mirror from history.

Every level permits legal free yaw and pitch and both source directions. The character walks on slopes up to 45°; steeper surfaces cause sliding or falling. A quarter turn preserves the panel centre; a half turn swaps the source side. Reverse sides is available during editing. Long presses and swipes cannot also issue walking commands. Editing starts in Move mode. The bottom-right icon cycles Move, Rotate, and Resize; only controls for that mode are touchable. A short sheet tap confirms in every mode. A dragged sheet or inactive mode control never confirms. Move uses sheet X/Z dragging at captured height and a separate height control for Y.

The passive Constellation guide starts on a Move sheet press before the drag threshold. It normally appears only while its related control is held, remains during settling, then fades for 0.2 seconds. Cancel, focus loss, removal, and level load clear it. Ground movement uses half-unit dots at the captured centre height, within two world units of the current displayed centre. Height movement uses half-unit dots at captured X/Z, within two units of the displayed height. Spatial dots fade with distance from the displayed reference. Resize uses actual fixed-edge, snapped-centre target positions and shows centre and held-edge references. Rotation shows legal-angle dots on the captured 3D ring, faded by angular distance; Angle snap 0 shows no discrete angle dots. B: Soft glow uses brighter three-unit pearl-blue cores and soft five-unit halos, with both intensities reduced by distance. The amber reference is larger and brighter. The selected target remains hollow. Sizes stay constant at every camera scale. Projected UI and displayed geometry occlude marks, but the mirror does not. The guide is passive and does not affect camera fitting.

Open **Gear → Constellation** to tune core brightness, glow strength, dot diameter, and halo radius. **Preview guides** keeps the last-used control guide visible while you adjust sliders; enter mirror editing first. It defaults to ground movement, Turn (Tilt when horizontal), or Width for the current mode. Gestures take priority. Closing gear, leaving editing, removal, focus loss, or level changes turns preview off. Settings survive level changes and Reset for the current run. **Reset defaults** restores B: brightness 0.80, glow 0.35, diameter 3, halo radius 5. Restart also restores these values. In narrow portrait, the shorter debug panel keeps the stage visible; scroll to reach the remaining settings.

Rotate uses two world-aligned full rings at the mirror pivot: Turn is in world X/Z and Tilt is perpendicular to local width. Turn is hidden while horizontal. Their radii are half width or height plus 0.35 world units, with a projected major radius of at least 48 logical units. The near half is clear and the far half is faint; each visible full ring has a 48-logical-unit touch strip. At an overlap, the nearest curve wins, with depth as the tie-breaker. Freeze the selected plane, radius, and camera during the gesture and hide the other ring. Below a 0.15 projected minor-to-major ratio, use the captured projected tangent and one projected radius per radian. Fit rings on entering Rotate, after resize, and after a camera-view change. Resize uses local top and side pills. Each drag captures the opposite edge, then applies grid-centre correction for each whole-unit size target. Position targets use half units, sizes use whole units, and angles use the selected increment. Targets change after 10% midpoint hysteresis; the display eases to the latest target in 0.10 seconds. Angle snap defaults to 15°; 0 means no snap and retains legal continuous angles. The camera blends angle, scale, and framing about a fixed pivot for 0.4 seconds; transient outer crop is accepted. One bounded panel selects a rectangular source aperture and replaces only the destination column; originals outside it remain. The panel has unlimited normal depth.

Editing freezes the real character, including during a walk or fall. The ghost shows the predicted result in a separate physics world. Confirm clears the previous walking route and resumes gravity; Cancel resumes the saved movement. A pending prediction cannot be confirmed. Unsafe falls remain valid experiments, and Undo restores the prior state. A fog-filled holographic ghost and two fading afterimages show falls. Supported proposals have no ghost; diagnostic outcome text stays in the gear panel.

Level 1's intended route: enable the mirror at 2.5, walk to the striped platform at 5, change the offset to 4.0, then walk to the goal ring. Other safe solutions count. Reaching the goal sweeps a mirror across the stage to the next puzzle.

Level 2’s intended route: place the mirror at offset 2.5, walk to the end of the reflection at 5, then disable it. The original platform returns beneath the character and restores the approach to the goal at 8. Deactivating above the gap causes a fall; Undo lets you try again. The goal stays visible on its absolute platform. All positions in the broad placement area and all orientations remain available for experiments.

## Bounded mirror workshop

Open **Bounded mirror workshop** from the level list. Its three ledges, side obstacles, and absolute start and goal check bounded cuts, original geometry outside the aperture, side crossing, and absolute priority. A new panel is 3×3 units. Resize it locally from 1 to 6 whole units after release; the aperture extends without a depth limit. Removal discards placement and dimensions.

## First art trial

One ceramic block set is used on every stage, puzzle and fixture alike; look follows the kind of solid, not the level index. `levels/12_block_gallery.json`, reviewed by `tests/block_gallery_review.gd`, is the demo ground showing every original, reflected, and absolute look together. [Board 04](docs/art/mirror-direction-contact-04.png) is the current approximate visual reference: a clear centre, a one-sided light skirt, sparse outward particles, and narrow contact bands on original and absolute surfaces. A mirror’s own reflected structures have no contact glow. Hologram edges, the perimeter light, and prism guides are unchanged. Absolutes remain solid. [The art record](docs/art/README.md) explains its limits. Documentation images are excluded from imports and game exports.

## Checks

During prototype exploration, choose only the smallest useful check for the change. Do not run all commands below for each visual or interaction idea. Once a design decision is confirmed, run the relevant full checks as regression guardrails. Repeat them only for changed behavior, failures, or a concrete risk.

```sh
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/run_tests.gd
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/capture.gd
```

The first command imports and parses the project. The second checks geometry, real physics, shared player commands, pointer input, and responsive layouts. It exits with a nonzero status on failure. For Constellation candidates and gesture lifecycle, use `tests/constellation_tests.gd`; `tests/constellation_view_tests.gd` checks glow, occlusion, and fading. `tests/constellation_tuning_tests.gd` checks live tuning and preview lifecycle; `tests/constellation_ui_tests.gd` checks the debug controls. For edit modes and target movement, use `tests/edit_mode_tests.gd`; `tests/mode_ui_tests.gd` checks mode visibility and `tests/ring_tests.gd` checks the rotation arcs. For legal angles and slopes, use `tests/legal_angles_tests.gd`. The focused native review is `tests/legal_visual_review.gd` without `--headless`. For panel contacts, use `tests/mirror_contact_tests.gd`. For continuous rotation, use `tests/display_geometry_tests.gd` for geometry or `tests/continuous_controls_tests.gd` for controller behavior with `--headless --path . --script`. Add `-- --visual-review` without `--headless` for a native review. For bounded resize work, run either focused check with `--headless --path . --script tests/extent_tests.gd` or `--headless --path . --script tests/ring_tests.gd`. The native bounded workshop review keeps the existing `tests/extent_review.gd` path and saves local captures in `test-output/`. For the immersive trial, `rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/visual_review.gd` performs one desktop/portrait review session. The third command above is the older broad capture matrix and is not routine prototype work.

For the tutorial, `tests/level_solvability_tests.gd` proves each stage's solution and its near misses through the player's own commands. `tests/prompt_tests.gd` checks the prompts, `tests/app_flow_tests.gd` checks the title, save and resume, end card and release settings, and `tests/sound_tests.gd` checks the sounds. `tests/tutorial_playthrough.gd`, run without `--headless`, plays all six stages from the title to the end card and saves one frame per stage to `test-output/`.

## Exports

Prototype exploration uses focused Mac checks with the Mobile renderer. Physical iOS and Android checks remain separate; do not use the Compatibility-only Simulator workflow.

Install templates through Godot's **Manage Export Templates** window. Use version **4.7.2.stable**. Build output and local captures are excluded from Git and resource imports.

For Mac:

```sh
rtk proxy mkdir -p build/macos
rtk proxy touch build/.gdignore
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug macOS build/macos/Mirror.app
rtk proxy open build/macos/Mirror.app
```

A debug export keeps the dev panel. Use `--export-release` for the player build: it shows the settings panel and has no Reset or dev keys. Both presets leave out `art_trial/`, `assets/reference/` and the viewer-only bounds file.

### Physical iOS and Android

The project uses the Mobile renderer exclusively. iOS Simulator is not a supported target. For physical iOS exports, set your real Apple development team in the iOS preset and configure signing in Xcode. No signing identity is supplied by the project. Android export setup and physical-device validation remain pending.

## Source layout

- `core/`: shared box/convex geometry, level validation, and polygon-surface walking graph with direct routes and obstacle detours.
- `world/`: procedural meshes, matching collision, character physics, isolated fall prediction, atmosphere, boundary, and route visuals.
- `ui/`: native responsive controls and action signals.
- `game.gd`: state, shared commands, preview/apply/undo, pointer input, and camera fitting and quarter-turn views.
- `levels/`: source JSON; no generated geometry is saved in scenes.
- `tests/`: deterministic rule/physics/input checks and visual capture script.

JSON boxes use `id`, `center: [x,y,z]`, and `size: [x,y,z]`. Character and goal positions are feet positions. `mirror` contains `enabled`, `axis` (0=X, 1=Y, 2=Z), `source` (+1 keeps coordinates below the offset; −1 keeps those above), `offset`, and `pivot: [x,y,z]`. Optional `width` and `height` fields default to 3 and must be whole units from 1 to 6. The pivot must use the half-unit grid, lie on the initial plane, and stay inside all offset ranges. `limits` contains permitted `axes`, `min`, and `max` vectors. `kill_y` is the lower failure boundary. Final offsets use half units; continuous drag offsets are presentation-only. Placement ranges include source/absolute bounds plus a two-unit margin and any existing ranges. Runtime state stores continuous `yaw` and `pitch` in radians and `source_sign` (+1 or −1) independently of the panel frame. JSON may provide these optional fields; legacy axis/source fields are converted at load. Axis/offset fields remain aliases for existing debug commands. Use small fixtures. The navigation graph samples exposed walkable faces every quarter unit at their actual heights, then returns direct or simplified routes with clearance checks. Ladders and stepped paths come later.

Runtime mirror state also stores `width` and `height`, each from 1 to 6 units. World generation returns closed convex faces, enclosing bounds, source identity, and a `material_to_world` transform. Actual boxes retain a fast box path. Meshes, convex collision, prediction, picking, and surface queries use the same geometry. Cut fragments retain source coordinates; reflection composes this native transform without compressing textures. Absolute bounds are subtracted from generated solids. Preview uses this same calculation with frozen physics. Confirm replaces collision at a physics boundary, rebuilds navigation, and cancels the old route. Both puzzle replays call the same commands as the UI. Puzzle order is defined by `PUZZLE_PATHS` in `game.gd`; technical fixtures follow in `LEVEL_PATHS`. The last puzzle does not advance into the fixtures.

See [VALIDATION.md](VALIDATION.md) for completed checks and test limits.

## Agent tools

Godot MCP Runtime **3.3.0** is installed outside this repository in `~/.local/share/mirror-tools` and registered in Codex as `godot-runtime`. It can inspect a running Mac scene, send input, and save screenshots. Use `get_project_info` to check the connection. Use `run_project`, then `get_ui_elements` before clicking controls. Call `stop_project` when done and confirm that the temporary bridge has been removed before export or commit. Local screenshots stay in the ignored `.mcp/` folder.

The `i-have-adhd` skill is installed in `~/.codex/skills/i-have-adhd`. It is available on the next turn; use `$i-have-adhd` to activate it. If the new MCP server is not listed in the current session, reload Codex to load its saved configuration.

## The ceramic block set

Every stage uses ceramic B, porcelain R3 reflections, and carved jade S1. The golden traveller has a hooded cloak and a damped walk cycle; the mirror uses a thin metal frame and clear glass. `levels/12_block_gallery.json` is the demo ground for this block set: an original block whole, a tall original, a whole reflected copy, an original the mirror plane cuts, a reflected piece cut at the aperture edge, and the jade start and goal platforms, all on one stage.

Asset source and regeneration instructions are in [art_sources/README.md](art_sources/README.md). Run the focused art checks with `rtk godot --headless --path . --script tests/gameplay_art_tests.gd`. For the traveller in the game, `rtk godot --path . --script tests/traveller_gameplay_review.gd` without `--headless` walks and turns the character on the spot and saves frames to `test-output/`. For the block gallery, `rtk godot --path . --script tests/block_gallery_review.gd` without `--headless` saves frames the same way. For whether a level's intended solution reaches its goal and its near misses do not, use `rtk godot --headless --path . --script tests/level_solvability_tests.gd`. Stop the runtime MCP session before any headless checks.

## Separate reference scene

Run `rtk godot --path . art_trial/reference_scene.tscn` for the new ceramic comparison scene. It uses Mobile/Metal on this Mac and does not replace the playable levels. It has no character. View cycles the camera; Detail cycles close views; Cut toggles the oblique cut; Caps exposes the cut face; Hide removes controls. Q/E rotate, C toggles the cut, and H restores hidden controls. A touch also restores hidden controls.

See [the scene record](docs/art/reference-scene.md) for captures, asset instructions, and limits.

# Mirror

A small Godot 4.7.2 prototype. Play **A place to stand**, then **The path beneath**. The gear panel also opens either puzzle or one of eight technical fixtures. The current rules and pending stories are in [GAME_DESIGN.md](GAME_DESIGN.md).

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
| Adjust position | Drag the sheet; release to snap | [ / ] |
| Resize mirror | Drag a local top or side tab; release to whole units | Debug width / height |
| Turn / tilt | Drag the orb on a yaw or pitch ring; keep dragging for more turns | Arrow keys; 1 / 2 / 3 selects X / Y / Z |
| Turn camera | Mobile swipe on empty space; desktop curved arrows | Q / E |
| Remove / keep in preview | Contextual bottom action | D |
| Confirm / cancel | Short tap on the sheet / Cancel | Enter / Escape |
| Recover | Contextual Undo; Reset after failure or in gear panel | Z / R |
| Debug controls | Top-right gear | — |

Debug panels start hidden. They contain level selection, numeric controls, collision outlines, atmosphere options, **Standing only** mode, and bounded mirror dimensions. Debug dimension changes use the same fixed-edge operation as the local tabs. The prototype supports one mirror. After removal, creation uses the new press and fresh level defaults; it never restores a saved placement. Undo can restore a removed mirror from history.

Every level permits all orientations and both source directions. A quarter turn preserves the panel centre; a half turn swaps the source side. Reverse sides is available during editing. Long presses and swipes cannot also issue walking commands. Releasing a mirror translation settles to the nearest half unit without confirming. One bounded panel selects a rectangular source aperture and replaces only the destination column; originals outside it remain. The panel has unlimited normal depth. A fresh panel is 3×3 units, and its local top and side tabs resize from a fixed opposite edge between 1 and 6 units; preview is continuous and release settles to whole units in 0.15 seconds. World-space yaw and pitch orbs stay on the animated panel edge, use half-width and half-height radii, and retain their pointer through repeated 90° requests. The yaw orb hides while horizontal. Tabs and orbs have 48-unit touch targets, block world input, and freeze the camera during their gestures.

Editing freezes the real character, including during a walk or fall. The ghost shows the predicted result in a separate physics world. Confirm clears the previous walking route and resumes gravity; Cancel resumes the saved movement. A pending prediction cannot be confirmed. Unsafe falls remain valid experiments, and Undo restores the prior state. A fog-filled holographic ghost and two fading afterimages show falls. Supported proposals have no ghost; diagnostic outcome text stays in the gear panel.

Level 1's intended route: enable the mirror at 2.5, walk to the striped platform at 5, change the offset to 4.0, then walk to the goal ring. Other safe solutions count. Select **Next** after reaching the goal.

Level 2’s intended route: place the mirror at offset 2.5, walk to the end of the reflection at 5, then disable it. The original platform returns beneath the character and restores the approach to the goal at 8. Deactivating above the gap causes a fall; Undo lets you try again. The goal stays visible on its absolute platform. All positions in the broad placement area and all orientations remain available for experiments.

## Bounded mirror workshop

Open **Bounded mirror workshop** from the level list. Its three ledges, side obstacles, and absolute start and goal check bounded cuts, original geometry outside the aperture, side crossing, and absolute priority. A new panel is 3×3 units. Resize it locally from 1 to 6 whole units after release; the aperture extends without a depth limit. Removal discards placement and dimensions.

## First art trial

Level 1 uses the holographic stone and atmosphere trial. The bounded workshop also uses detailed materials to check texture cuts; other puzzles and fixtures retain the simpler test materials. [Panel D of mirror shader board 03](docs/art/mirror-shader-03.png) is the current visual target: near-clear centre, fixed-width perimeter light, rare edge particles, and short reflected-side ribbons. [The art record](docs/art/README.md) explains its limits. Documentation images are excluded from imports and game exports.

## Checks

During prototype exploration, choose only the smallest useful check for the change. Do not run all commands below for each visual or interaction idea. Once a design decision is confirmed, run the relevant full checks as regression guardrails. Repeat them only for changed behavior, failures, or a concrete risk.

```sh
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/run_tests.gd
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/capture.gd
```

The first command imports and parses the project. The second checks geometry, real physics, shared player commands, pointer input, and responsive layouts. It exits with a nonzero status on failure. For bounded mirror work, run either focused check with `--headless --path . --script tests/extent_tests.gd` or `--headless --path . --script tests/ring_tests.gd`. The native bounded workshop review keeps the existing `tests/extent_review.gd` path and saves local captures in `test-output/`. For the immersive trial, `rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/visual_review.gd` performs one desktop/portrait review session. The third command above is the older broad capture matrix and is not routine prototype work.

## Exports

Prototype exploration uses focused checks on Mac. Full suites, layout matrices, captures, and exports are reserved for confirmed decisions or a concrete risk. Routine Simulator and physical-device checks are deferred. Run one focused Simulator pass only when an unchecked platform-specific feature could cause substantial rework, or when explicitly requested; record the concrete risk before that pass.

Install templates through Godot's **Manage Export Templates** window. Use version **4.7.2.stable**. Build output and local captures are excluded from Git and resource imports.

For Mac:

```sh
rtk proxy mkdir -p build/macos
rtk proxy touch build/.gdignore
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug macOS build/macos/Mirror.app
rtk proxy open build/macos/Mirror.app
```

### Optional focused iPhone and iPad Simulator check

Use this only for a documented platform-specific risk, such as renderer or shader support, export architecture, or critical touch or safe-area behavior. Install Xcode and an iOS Simulator runtime, then run:

```sh
rtk proxy python3 tools/build_simulator.py
rtk proxy xcrun simctl list devices available
rtk proxy xcrun simctl boot <device-UDID>
rtk proxy xcrun simctl install <device-UDID> build/ios-derived/Build/Products/Debug-iphonesimulator/Mirror.app
rtk proxy xcrun simctl launch <device-UDID> org.mirrorgame.prototype
rtk proxy open -a Simulator
```

Skip `boot` for an already running device. Replace `<device-UDID>` with the selected iPhone or iPad ID. The script exports a new Xcode project and builds without signing or provisioning. Set the `GODOT` environment variable if the editor is in another location. The team ID in the preset is a placeholder for this unsigned build.

The installed official template advertises an ARM Simulator library but contains only Intel code. The build script checks the actual library and selects its available architecture. On this Apple Silicon Mac, the Simulator app therefore runs through Rosetta. This matches a [reported Godot template issue](https://github.com/godotengine/godot/issues/118161). The `simulator` export feature turns off shadows and uses 35% 3D resolution; UI resolution stays unchanged. Simulator timing does not measure physical-device performance. Physical iOS signing and Android exports are later work. Do not run a broad repeated Simulator matrix.

## Source layout

- `core/`: pure box geometry, level validation, and flat-surface walking graph with direct routes and obstacle detours.
- `world/`: procedural meshes, matching collision, character physics, isolated fall prediction, atmosphere, boundary, and route visuals.
- `ui/`: native responsive controls and action signals.
- `game.gd`: state, shared commands, preview/apply/undo, pointer input, and camera fitting and quarter-turn views.
- `levels/`: source JSON; no generated geometry is saved in scenes.
- `tests/`: deterministic rule/physics/input checks and visual capture script.

JSON boxes use `id`, `center: [x,y,z]`, and `size: [x,y,z]`. Character and goal positions are feet positions. `mirror` contains `enabled`, `axis` (0=X, 1=Y, 2=Z), `source` (+1 keeps coordinates below the offset; −1 keeps those above), `offset`, and `pivot: [x,y,z]`. Optional `width` and `height` fields default to 3 and must be whole units from 1 to 6. The pivot must use the half-unit grid, lie on the initial plane, and stay inside all offset ranges. `limits` contains permitted `axes`, `min`, and `max` vectors. `kill_y` is the lower failure boundary. Final offsets use half units; continuous drag offsets are presentation-only. Placement ranges include source/absolute bounds plus a two-unit margin and any existing ranges. Runtime state also stores a discrete `frame_up` vector to preserve the frame through signed tilt cycles. Use small fixtures. The navigation graph samples flat surfaces every quarter unit, then returns direct or simplified routes with clearance checks. Ladders and stepped paths come later.

Runtime mirror state also stores `width` and `height`, each from 1 to 6 units. World generation returns bounds for both meshes and collision, plus immutable source identity and a `material_to_world` transform. Cut fragments retain source coordinates; reflection composes this native transform without compressing textures. Absolute bounds are subtracted from generated solids. Preview uses this same calculation with frozen physics. Confirm replaces collision at a physics boundary, rebuilds navigation, and cancels the old route. Both puzzle replays call the same commands as the UI. Puzzle order is defined by `PUZZLE_PATHS` in `game.gd`; technical fixtures follow in `LEVEL_PATHS`. The last puzzle does not advance into the fixtures.

See [VALIDATION.md](VALIDATION.md) for completed checks and test limits.

## Agent tools

Godot MCP Runtime **3.3.0** is installed outside this repository in `~/.local/share/mirror-tools` and registered in Codex as `godot-runtime`. It can inspect a running Mac scene, send input, and save screenshots. Use `get_project_info` to check the connection. Use `run_project`, then `get_ui_elements` before clicking controls. Call `stop_project` when done and confirm that the temporary bridge has been removed before export or commit. Local screenshots stay in the ignored `.mcp/` folder.

The `i-have-adhd` skill is installed in `~/.codex/skills/i-have-adhd`. It is available on the next turn; use `$i-have-adhd` to activate it. If the new MCP server is not listed in the current session, reload Codex to load its saved configuration.

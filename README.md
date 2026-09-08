# Mirror

A small Godot 4.7.2 prototype. Play **A place to stand**, then **The path beneath**. The top menu also opens either puzzle or one of seven technical fixtures. The current rules and pending stories are in [GAME_DESIGN.md](GAME_DESIGN.md).

## Run on Mac

Install Godot 4.7.2 and its matching export templates. From this folder:

```sh
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path .
```

Open `project.godot` in Godot to edit the project. The exported local app is `build/macos/Mirror.app`.

| Action | Touch or mouse | Keyboard |
| --- | --- | --- |
| Walk | Tap a platform's top surface | — |
| Open mirror preview | Enable / Modify on the canvas | M |
| Adjust position | Drag any visible part of the sheet while editing, or use −0.5 / +0.5 | [ / ] |
| Change orientation | Turn left/right, Lay flat/Stand up, Reverse sides | 1 / 2 / 3 (X / Y / Z) |
| Turn camera | Camera left/right buttons | Q / E |
| Enable / disable in preview | Enable / Disable | D |
| Commit / cancel | Confirm / Cancel | Enter / Escape |
| Recover | Undo / Reset | Z / R |

Every level permits all mirror orientations and both source directions. Fixed offsets hide the step buttons for that axis. A quarter turn preserves the mirror pivot; a half turn swaps the source side. Confirm and Cancel stay visible while other edit options can scroll on short windows. Test options includes the atmosphere comparison, collision outlines, and **Standing still only** mode; source reversal is available in every level while editing.

Editing freezes the real character, including during a walk or fall. The ghost shows the predicted result in a separate physics world. Confirm clears the previous walking route and resumes gravity; Cancel resumes the saved movement. A pending prediction cannot be confirmed. Unsafe falls remain valid experiments, and Undo restores the prior state. A failure below the view has a **No landing** edge marker.

Level 1's intended route: enable the mirror at 2.5, walk to the striped platform at 5, change the offset to 4.0, then walk to the goal ring. Other safe solutions count. Select **Next** after reaching the goal.

Level 2’s intended route: enable the fixed mirror, walk to the end of the reflection at 5, then disable it. The original platform returns beneath the character and restores the approach to the goal at 8. Deactivating above the gap causes a fall; Undo lets you try again. The goal stays visible on its absolute platform. Its X offset stays fixed; the other orientations remain available for experiments.

## First art trial

Level 1 uses the first stone and atmosphere trial. Other puzzles and fixtures retain the simpler test materials. [Panel A of the saved reference](docs/art/visual-trial-01.png) is the visual target; [the trial record](docs/art/README.md) explains its limits. Documentation images are excluded from imports and game exports.

## Checks

```sh
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/run_tests.gd
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/capture.gd
```

The first command imports and parses the project. The second checks geometry, real physics, shared player commands, pointer input, and responsive layouts. It exits with a nonzero status on failure. The third captures both atmosphere settings, plane orientations, a fall ghost, and phone/tablet layouts in `test-output/`. Run it with a graphical desktop session.

## Exports

Mac runtime, headless checks, and Mac window-size checks are the default rapid-prototype validation. Routine Simulator and physical-device checks are deferred. Run one focused Simulator pass only when an unchecked platform-specific feature could cause substantial rework, or when explicitly requested; record the concrete risk before that pass.

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

JSON boxes use `id`, `center: [x,y,z]`, and `size: [x,y,z]`. Character and goal positions are feet positions. `mirror` contains `enabled`, `axis` (0=X, 1=Y, 2=Z), `source` (+1 keeps coordinates below the offset; −1 keeps those above), `offset`, and `pivot: [x,y,z]`. The pivot must lie on the initial plane and inside all offset ranges. `limits` contains permitted `axes`, `min`, and `max` vectors. `kill_y` is the lower failure boundary. Use half-unit offsets and small fixtures. The navigation graph samples flat surfaces every quarter unit, then returns direct or simplified routes with clearance checks. Ladders and stepped paths come later.

World generation returns bounds for both meshes and collision. Absolute bounds are subtracted from generated solids. Preview uses this same calculation with frozen physics. Confirm replaces collision at a physics boundary, rebuilds navigation, and cancels the old route. Both puzzle replays call the same commands as the UI. Puzzle order is defined by `PUZZLE_PATHS` in `game.gd`; technical fixtures follow in `LEVEL_PATHS`. The last puzzle does not advance into the fixtures.

See [VALIDATION.md](VALIDATION.md) for completed checks and test limits.

## Agent tools

Godot MCP Runtime **3.3.0** is installed outside this repository in `~/.local/share/mirror-tools` and registered in Codex as `godot-runtime`. It can inspect a running Mac scene, send input, and save screenshots. Use `get_project_info` to check the connection. Use `run_project`, then `get_ui_elements` before clicking controls. Call `stop_project` when done and confirm that the temporary bridge has been removed before export or commit. Local screenshots stay in the ignored `.mcp/` folder.

The `i-have-adhd` skill is installed in `~/.codex/skills/i-have-adhd`. It is available on the next turn; use `$i-have-adhd` to activate it. If the new MCP server is not listed in the current session, reload Codex to load its saved configuration.

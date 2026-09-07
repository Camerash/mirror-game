# Mirror

A small Godot 4.7.2 prototype. Play **A place to stand** or select one of six technical fixtures from the top menu. The current rules and pending stories are in [GAME_DESIGN.md](GAME_DESIGN.md).

## Run on Mac

Install Godot 4.7.2 and its matching export templates. From this folder:

```sh
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path .
```

Open `project.godot` in Godot to edit the project. The exported local app is `build/macos/Mirror.app`.

| Action | Touch or mouse | Keyboard |
| --- | --- | --- |
| Walk | Tap a platform's top surface | — |
| Preview | Drag the circular plane handle, or select Edit mirror | M |
| Adjust | Drag, or use −0.5 / +0.5 | [ / ] |
| Commit / cancel | Apply / Cancel | Enter / Escape |
| Recover | Undo / Reset | Z / R |
| Compare visuals | Outline / Translucent view | — |

The fixture controls also select plane orientation, source side, and collision outlines. Scroll the control panel on short screens. Preview pauses movement. Apply resumes gravity; losing support can cause a safe fall or failure. Undo restores the state before the last accepted action.

Level 1's intended route: enable the mirror at 2.5, walk to the striped platform at 5, change the offset to 4.0, then walk to the goal ring. Other safe solutions count.

## Checks

```sh
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/run_tests.gd
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --path . --script tests/capture.gd
```

The first command imports and parses the project. The second checks geometry, real physics, shared player commands, pointer input, and responsive layouts. It exits with a nonzero status on failure. The third captures both boundary styles and phone/tablet layouts in `test-output/`. Run it with a graphical desktop session.

## Exports

Install templates through Godot's **Manage Export Templates** window. Use version **4.7.2.stable**. Build output and local captures are excluded from Git and resource imports.

For Mac:

```sh
rtk proxy mkdir -p build/macos
rtk proxy touch build/.gdignore
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug macOS build/macos/Mirror.app
rtk proxy open build/macos/Mirror.app
```

For iPhone and iPad Simulator, install Xcode and an iOS Simulator runtime, then run:

```sh
rtk proxy python3 tools/build_simulator.py
rtk proxy xcrun simctl list devices available
rtk proxy xcrun simctl boot <device-UDID>
rtk proxy xcrun simctl install <device-UDID> build/ios-derived/Build/Products/Debug-iphonesimulator/Mirror.app
rtk proxy xcrun simctl launch <device-UDID> org.mirrorgame.prototype
rtk proxy open -a Simulator
```

Skip `boot` for an already running device. Replace `<device-UDID>` with the selected iPhone or iPad ID. The script exports a new Xcode project and builds without signing or provisioning. Set the `GODOT` environment variable if the editor is in another location. The team ID in the preset is a placeholder for this unsigned build.

The installed official template advertises an ARM Simulator library but contains only Intel code. The build script checks the actual library and selects its available architecture. On this Apple Silicon Mac, the Simulator app therefore runs through Rosetta. This matches a [reported Godot template issue](https://github.com/godotengine/godot/issues/118161). The `simulator` export feature turns off shadows and uses 35% 3D resolution; UI resolution stays unchanged. Simulator timing does not measure physical-device performance. Physical iOS signing and Android exports are later work.

## Source layout

- `core/`: pure box geometry, level validation, and flat-surface walking graph.
- `world/`: procedural meshes, matching collision, character physics, boundary and route visuals.
- `ui/`: native responsive controls and action signals.
- `game.gd`: state, shared commands, preview/apply/undo, pointer input, and fixed camera framing.
- `levels/`: source JSON; no generated geometry is saved in scenes.
- `tests/`: deterministic rule/physics/input checks and visual capture script.

JSON boxes use `id`, `center: [x,y,z]`, and `size: [x,y,z]`. Character and goal positions are feet positions. `mirror` contains `enabled`, `axis` (0=X, 1=Y, 2=Z), `source` (+1 keeps coordinates below the offset; −1 keeps those above), and `offset`. `limits` contains permitted `axes`, `min`, and `max` vectors. `kill_y` is the lower failure boundary. Use half-unit offsets and small fixtures. The current navigation graph samples flat surfaces every quarter unit; ladders and stepped paths come later.

World generation returns bounds for both meshes and collision. Absolute bounds are subtracted from generated solids. Preview uses this same calculation with frozen physics. Apply replaces collision at a physics boundary, rebuilds navigation, and cancels the old route. Level 1 replay calls the same commands as the UI.

See [VALIDATION.md](VALIDATION.md) for completed checks and test limits.

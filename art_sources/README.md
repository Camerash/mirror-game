# Art assets

[Blender 5.2.1 LTS](https://www.blender.org/download/) is installed at `/Applications/Blender.app`. The CLI is `blender`. Game execution needs only the imported assets, not Blender or Python.

## Material maps

From the project root:

```sh
rtk proxy python3 art_sources/materials/generate_material_maps.py
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
```

The generator requires NumPy. Use an existing Python environment with NumPy, or Blender's Python runtime. It uses fixed parameters and seeds, and writes eight seamless 2K PNG maps (ceramic/jade colour, roughness, normal, height). Colour maps contain no directional lighting.

Gameplay blocks read polygon vertex colour green to identify cap faces, with a source-plane fallback for box fragments. This is a rendering attribute, not a collision change.

## Audio

From the project root:

```sh
rtk proxy python3 art_sources/audio/generate_sounds.py
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
```

The generator requires NumPy. Use an existing Python environment with NumPy, or Blender's Python runtime. It uses fixed parameters and seeds, so two runs write byte-identical files. It writes 44.1 kHz, 16-bit PCM WAV effects (mono) and one mono ambient loop into `assets/audio/`: `step_1..3.wav`, `ui.wav`, `create.wav`, `confirm.wav`, `remove.wav`, `goal.wav`, `sweep.wav`, `land.wav`, and `ambient_loop.wav`. Effects peak around -6 dBFS (`step_*` sits lower, around -16 dBFS, because it plays on every footstep); the loop peaks around -14 dBFS.

`ambient_loop.wav` loops without a click: every oscillator completes a whole number of cycles within the 30 s duration, and its `.wav.import` sets `edit/loop_mode` to Forward so Godot loops it at playback. Re-run the Godot import step after regenerating audio, so `.import` files stay current.

`default_bus_layout.tres` at the project root defines the `Master`, `Music`, and `Effects` buses (`Music` and `Effects` both send to `Master`). Godot loads it automatically; `project.godot` has no `audio/buses/default_bus_layout` override.

## Reference blocks

`art_sources/reference/` holds the source models and scripts for the isolated reference scene: the ceramic and jade blocks, the goal block, and their detail bakes. Runtime GLBs and maps are under `assets/reference/`. See [the scene record](../docs/art/reference-scene.md) for build commands, captures, and limits. The scene has no character.

## Traveller

The golden traveller lives in `art_sources/traveller/`. See [the source notes](../docs/art/traveller.md) for the build command and the mesh decisions. [`art_sources/traveller_animated/README.md`](traveller_animated/README.md) explains the retired two-clip pipeline and the one asset still read from it.

`art_sources/.gdignore` prevents source imports. Export presets exclude this directory and `docs/`. Keep `.blend1`, caches, local screenshots, and build output outside Git.

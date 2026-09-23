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

## Reference blocks

`art_sources/reference/` holds the source models and scripts for the isolated reference scene: the ceramic and jade blocks, the goal block, and their detail bakes. Runtime GLBs and maps are under `assets/reference/`. See [the scene record](../docs/art/reference-scene.md) for build commands, captures, and limits. The scene has no character.

## Traveller

The golden traveller lives in `art_sources/traveller/`. See [the source notes](../docs/art/traveller.md) for the build command and the mesh decisions. [`art_sources/traveller_animated/README.md`](traveller_animated/README.md) explains the retired two-clip pipeline and the one asset still read from it.

`art_sources/.gdignore` prevents source imports. Export presets exclude this directory and `docs/`. Keep `.blend1`, caches, local screenshots, and build output outside Git.

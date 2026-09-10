# Ceramic art assets

[Blender 5.2.1 LTS](https://www.blender.org/download/) is installed at `/Applications/Blender.app`. The CLI is `blender`. Game execution needs only the imported assets, not Blender or Python.

From the project root:

```sh
rtk proxy blender --background --python art_sources/character/build_ceramic_traveller.py
rtk proxy python3 art_sources/materials/generate_material_maps.py
rtk proxy /Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
```

The material generator requires NumPy. Use an existing Python environment with NumPy, or Blender's Python runtime. Both generators use fixed parameters and seeds. The character generator writes the editable `.blend`, GLB, and 1K cloak atlas. Godot extracts the embedded atlas during import. The material generator writes eight seamless 2K PNG maps (ceramic/jade colour, roughness, normal, height). Colour maps contain no directional lighting.

`world/character_visual.gd` drives two hem blend shapes and small foot steps. It accepts movement, grounded state, and pause state without controlling collision. The upper cloak and hood are fixed; hem displacement is capped at 0.035 units. `reset_motion()` restores the neutral pose.

`world/trial_materials.gd` binds source maps by solid kind. Both ceramic and reflected porcelain sample the same source maps; the porcelain shader supplies the cool finish. Polygon vertex colour green identifies cap faces, with a source-plane fallback for box fragments. Red retains the existing boundary distance. These are rendering attributes, not collision changes.

The studio sky supplies reflection lighting only; the visible background is a fixed colour. Mirror frame thickness remains 0.044 world units. No fog, bloom, screen-space reflection, native plugin, or full cloth simulation is required.

`art_sources/.gdignore` prevents source imports. Export presets exclude this directory and `docs/`. Keep `.blend1`, caches, local screenshots, and build output outside Git.

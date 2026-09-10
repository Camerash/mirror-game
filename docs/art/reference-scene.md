# Ceramic reference scene

This is a native Godot Mobile scene. The generated [B target](reference-target.jpg) supplies the art reference; it is not a runtime capture. R3 porcelain and S1 jade remain the selected material variants.

- [Native scene](reference-scene.png)
- [Character](reference-character.png)
- [Closed cut cap](reference-cut-cap.png)
- [Portrait controls](reference-portrait.png)
- [Eight-second motion recording](reference-motion.mp4)

## Run and inspect

From the project root, run `rtk godot --path . art_trial/reference_scene.tscn`.

View/Q/E rotates through four views. Detail cycles character, ceramic, and jade close views. Walk/Space toggles the walking sequence. Cut/C selects the controlled oblique cut. Caps hides the reflected half and sheet to expose the original cap. Hide/H controls the inspection interface; touch restores hidden controls. Buttons are at least 48 units high and wrap in narrow windows.

The cut demo clips the imported convex rounded core at one fixed plane, interpolates surface normals and UVs, closes the cut, and reflects the clipped result. Its coordinate shader preserves source detail. This does not implement arbitrary gameplay cuts or navigation on these new assets.

## Editable sources

Blender 5.2.1 is used. Source models and scripts are under `art_sources/reference/`; runtime GLBs and 2K ceramic/jade maps are under `assets/reference/`. The cloak uses one mesh with integrated material triangles at the hem; shape keys move that mesh. The retained Blender rig is for editing, while runtime motion drives named nodes and shape keys directly.

Regenerate from the project root:

```sh
rtk proxy blender --background --python art_sources/reference/build_reference_blocks.py
rtk proxy blender --background --python art_sources/reference/build_reference_goal.py
rtk proxy blender --background --python art_sources/reference/character_build.py
rtk proxy python3 art_sources/reference/generate_surface_maps.py
rtk godot --headless --editor --path . --quit
```

The map generator uses NumPy. Maps have mipmaps and VRAM compression. The surface shader supplies recessed arch shading and broad glaze variation; arches are not separate collision geometry or an offline high-poly bake. The goal socket is real mesh geometry. Reflected sides use 96% opacity; caps and tops remain opaque.

For a motion recording, stop MCP first, then run:

```sh
rtk godot --path . art_trial/reference_scene.tscn --write-movie .local/reference-recording/motion.avi --fixed-fps 30 --quit-after 240 -- --record
```

Create the output directory first. The saved review MP4 was encoded from this native recording using FFmpeg. It is 1152×800 at 30 FPS. Movie recording timing is not a gameplay performance benchmark.

## Comparison and limits

The new models have real rounded silhouettes and the scene fills the view. Material highlights, the recessed goal, and the character shape are improved over the first trial. Remaining differences include less handmade asymmetry, simpler arch relief, simpler hood/fabric construction, and weaker glass reflection structure than B. The background is a uniform dusty pink, without fog. The selected jade treatment follows S1, rather than B's dark block.

Gameplay art is deliberately separate pending review. Physical iOS/Android rendering, touch feel, and performance have not been checked. No Compatibility renderer or Simulator fallback is included.

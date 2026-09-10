# Ceramic reference scene

This is a native Godot Mobile scene. The generated [B target](reference-target.jpg) supplies the art reference; it is not a runtime capture. R3 porcelain and S1 jade remain the selected material variants.

- [Native scene](reference-scene.png)
- [Before the detail pass](reference-before-detail.png)
- [Character](reference-character.png)
- [Ceramic detail](reference-ceramic.png)
- [Jade detail](reference-jade.png)
- [Closed cut cap](reference-cut-cap.png)
- [Cut and reflected copy](reference-cut.png)
- [View 2](reference-view-1.png), [View 3](reference-view-2.png), [View 4](reference-view-3.png)
- [Portrait controls](reference-portrait.png)
- [Eight-second motion recording](reference-motion.mp4)

## Run and inspect

From the project root, run `rtk godot --path . art_trial/reference_scene.tscn`.

View/Q/E rotates through four views. Detail cycles character, ceramic, and jade close views. Walk/Space toggles the walking sequence. Cut/C selects the controlled oblique cut. Caps hides the reflected half and sheet to expose the original cap. Hide/H controls the inspection interface; touch restores hidden controls. Buttons are at least 48 units high and wrap in narrow windows.

The cut demo clips the imported convex rounded core at one fixed plane, interpolates surface normals and UVs, closes the cut, and reflects the clipped result. Its coordinate shader preserves source detail. This does not implement arbitrary gameplay cuts or navigation on these new assets.

## Editable sources

Blender 5.2.1 is used. Source models and scripts are under `art_sources/reference/`; runtime GLBs and 2K ceramic/jade maps are under `assets/reference/`. The cloak uses one folded mesh with a continuous UV hem pattern; shape keys move that mesh. The retained Blender rig is for editing, while runtime motion drives named nodes and shape keys directly.

Regenerate from the project root:

```sh
rtk proxy blender --background --python art_sources/reference/build_reference_blocks.py
rtk proxy blender --background --python art_sources/reference/build_reference_goal.py
rtk proxy blender --background --python art_sources/reference/character_build.py
rtk proxy python3 art_sources/reference/generate_surface_maps.py
rtk proxy blender --background --python art_sources/reference/bake_reference_detail_maps.py
rtk godot --headless --editor --path . --quit
```

The glaze map generator uses NumPy. Editable high-relief face models are baked with Cycles to 1K tangent normal maps and packed masks (R: AO, G: cavity, B: positive convex curvature). These numeric maps use Non-Color encoding, mipmaps, and VRAM compression. They supply surface detail on the rounded runtime cores; they do not change collision. The ceramic top bake includes a gentle convex form to break up flat reflections. The 2K glaze maps supply fine crazing, color, roughness, and grain normals. Source-local sampling preserves detail through cuts. Reflected pairs share one variation value. The goal socket is real mesh geometry, with reduced ambient light and glaze at its recessed floor. Reflected sides use 94% opacity; caps and tops remain opaque.

For a motion recording, stop MCP first, then run:

```sh
rtk godot --path . art_trial/reference_scene.tscn --write-movie .local/reference-recording/motion.avi --fixed-fps 30 --quit-after 240 -- --record
```

Create the output directory first. The saved review MP4 was encoded from this native recording using FFmpeg. It is 1152×800 at 30 FPS. Movie recording timing is not a gameplay performance benchmark.

## Comparison and limits

The scene uses rounded silhouettes, baked arch detail, glaze pooling, broad studio highlights, a rounded hood, and a fine patterned hem. The silvered sheet has angle-dependent opacity, soft surface variation, and a faint finite studio-card reflection. This card represents a light source, not a second game world. The distant background has a quiet rose gradient, without fog. The selected jade treatment follows S1. The source image remains an appearance target: it contains more handmade shape variation and richer cloth detail. Surface bakes do not add geometric undercuts or alter the runtime silhouette. Gameplay integration follows review.

Gameplay art is deliberately separate pending review. Physical iOS/Android rendering, touch feel, and performance have not been checked. No Compatibility renderer or Simulator fallback is included.

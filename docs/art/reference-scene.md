# Ceramic reference scene

This is a native Godot Mobile scene. The generated [NPR board, panel B — Soft illustration](ceramic-npr-board.png) supplies the current shading reference. The earlier [ceramic target](reference-target.jpg), R3 porcelain, and S1 jade still guide forms and material identity. Generated boards are approximate references, not runtime captures.

- [Native scene](reference-scene.png)
- [Before soft illustration](reference-before-soft.png)
- [Before the detail pass](reference-before-detail.png)
- [Character](reference-character.png)
- [Ceramic detail](reference-ceramic.png)
- [Jade detail](reference-jade.png)
- [Closed cut cap](reference-cut-cap.png)
- [Cut and reflected copy](reference-cut.png)
- [Opposite view](reference-view-2.png)
- Earlier detail-pass views: [View 2](reference-view-1.png), [View 4](reference-view-3.png)
- [Portrait controls](reference-portrait.png)
- [Earlier detail-pass motion recording](reference-motion.mp4) (motion is unchanged; shading predates B)

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

The glaze map generator uses NumPy. Editable high-relief face models are baked with Cycles to 1K tangent normal maps and packed masks (R: AO, G: cavity, B: positive convex curvature). These numeric maps use Non-Color encoding, mipmaps, and VRAM compression. They supply surface detail on the rounded runtime cores; they do not change collision. The ceramic top bake includes a gentle convex form to break up flat reflections. The existing 2K glaze maps now supply low-contrast color and roughness variation. Fine grain normal maps remain source assets but are not sampled by this scene. Source-local sampling preserves detail through cuts. Reflected pairs share one variation value. The goal socket is real mesh geometry, with reduced ambient light and glaze at its recessed floor. Reflected sides use 94% opacity; caps and tops remain opaque.

For a motion recording, stop MCP first, then run:

```sh
rtk godot --path . art_trial/reference_scene.tscn --write-movie .local/reference-recording/motion.avi --fixed-fps 30 --quit-after 240 -- --record
```

Create the output directory first. The saved review MP4 was encoded from this native recording using FFmpeg. It is 1152×800 at 30 FPS. Movie recording timing is not a gameplay performance benchmark.

## Comparison and limits

The scene keeps rounded silhouettes, baked arches and rims, a rounded hood, and a fine patterned hem. Soft illustration simplifies small surface variations, weakens clearcoat, and uses broad satin highlights. A low-contrast light field replaces the bright studio windows. The glass uses a soft silver sheen and angle-dependent opacity without fine noise or simulated studio-card reflections. The background remains a quiet rose gradient without fog. Character and gold material changes use local copies, preserving imported resources. Models, surface coordinates, and the restrained cloth motion are unchanged.

The B mockup is a shading target, not an exact image match. Surface bakes do not add geometric undercuts or alter silhouettes. This pass adds no theme switcher or new gameplay assets.

Gameplay art is deliberately separate pending review. Physical iOS/Android rendering, touch feel, and performance have not been checked. No Compatibility renderer or Simulator fallback is included.


## Soft illustration validation — 2026-09-12

Native Mobile/Metal review covered 1152×800 and 430×932 windows, material close views, opposite mirror view, oblique cut/cap, and a short walking sequence. Final native reference checks passed 634 assertions with no failures or error output. The check includes local material ownership to preserve imported resources. Initial cleanup errors from per-surface overrides were resolved by assigning local material copies to private mesh resources. No gameplay regression suite, export, Simulator, or physical-device test was run for this isolated pass.

# Painted traveller study 01

This records the first painted-face result. The [three-style hair study](traveller-hair-study-02.md) is the current hair revision. Captures below preserve the earlier comparison; the study scene and source now use the revised hair.

## Confirmed direction

This is an isolated study of the girl's head, hair, hood, neck, and shoulders. It does not replace the gameplay character or the ceramic reference-scene character. The previous [plain study](traveller-head-study-01.md) is preserved for comparison.

Use a simple rounded head with cheek and chin volume. Paint the small vertical oval eyes, brows, and mouth onto its UV map. Do not add eye sockets, lip geometry, separate facial pieces, or a face card. Keep the liked hood silhouette, a complete hairstyle, broad long locks, and one consistent hair material. See the [construction reference](traveller-head-construction-01.md) for identity and proportions; its painted shading is not a requirement for anatomical facial geometry.

Review shape and painted appearance together. The target is about 3,000 triangles, with a 5,000-triangle ceiling, one shared 1024×1024 colour atlas, and at most two opaque materials. Native Mac review cannot establish physical-device performance.

## Latest visual correction

The user-provided [Link’s Awakening image](traveller-simple-face-reference.png) guides the degree of simplification: small dark vertical oval eyes and broad rounded hair volumes. It replaces the earlier almond-eye paint. The reference image is Nintendo artwork supplied for study; it is not a game asset. Keep this girl's long chestnut hair, hood, and identity.

The revised neutral, half-closed, closed, and smile tiles use the same eye positions. No sclera, iris rings, or facial-feature meshes are needed. The hair uses curved centre-lines with rounded sections, rather than angular ribbons or pointed columns. The back of the head samples plain skin, and a continuous rear hair mass covers the scalp in the lowered pose.

## Review controls

Run `art_trial/painted_traveller_study.tscn` with Godot Mobile. The existing `art_trial/head_study.tscn` still opens the earlier plain model.

- Front, Side, Back, Three-quarter, Game angle: fixed comparison views. Q/E cycle views.
- Face / F: neutral, half closed, closed, gentle smile.
- Blink / B: one short stepped blink, then the selected expression returns.
- Hood / U: raised or lowered static pose with matching authored hair clearance. No transition is claimed.
- Hair / T: Long, Bob, or Low bun. This preserves the face, hood, camera, lighting, and review size.
- Grey / G: inspect shape without the painted colours. Lighting / L: neutral or ceramic-scene light.
- Size / V: close or small review scale. Turntable / Space: rotate without changing scale.
- Hide / H: hide or restore controls. Touch the view to restore hidden controls.
- Reset study / R: long hair, neutral face, raised hood, colour, and the three-quarter view.

The four face tiles occupy the top 256-pixel row of the shared atlas, in the order above. The exported head UVs select the neutral tile. A local copy of the native head material shifts U by 0.25 per frame. Expressions do not rebuild geometry or change another character's material. Other surfaces use the remaining atlas area.

## Later animation work

Prepare independently controllable head, hood, and broad hair masses now. The hood endpoints use the same topology; the raised-to-lowered motion remains unapproved and is not played.

The planned full-body actions are walking, raising one or both hands to interact, and using both hands to raise or lower the hood. Add cloak arm openings, simple hands, shoulder clearance, and the full-body rig in that stage. Use authored motion rather than runtime cloth simulation. Do not start gameplay replacement until the user approves the study.

## Validation

2026-09-13. The GLB contains **4,312 triangles**, nine mesh nodes, two opaque materials, and one embedded 1024×1024 atlas. This is above the approximate 3,000-triangle target and below the 5,000 ceiling. Materials are shared; the two-material count is not a draw-call count.

- Focused Godot checks: **57 checks, zero failures**. These cover asset limits, shared texture, expression offsets, blink timing and recovery, Reset, hood topology, and instance-local material and pose state.
- Native review: Godot 4.7.2, Mobile renderer, Metal on an Apple M2 Pro. Inspected both static hood poses from front, side, back, three-quarter, and elevated views at 1152×800. Inspected close and small review sizes, all four faces, and neutral and ceramic-scene lighting.
- Captured an [eight-second native review](traveller-painted-study-01/native-review.mp4) with stepped blinks, smile, both hood endpoints, and the small view. This is a fixed-frame recording, not a performance measurement. The selected expression returns after a blink.
- Corrected rear-head UV leakage, scalp exposure, angular front locks, and a gap behind the fringe found in the side review. No separate facial-feature meshes or texture cards remain.
- Stopped the native runtime and removed its temporary bridge. No gameplay suite, device export, Simulator, or physical-device performance test was run.

The head, hair, and static hood remain a shape study. The rear hair uses one broad curtain, and the lowered hood is a simple folded endpoint. The bust has no completed torso, arms, walk rig, or hood transition. These need a later approved body pass.

## Sources and review files

- [Editable Blender scene](../../art_sources/traveller_painted/traveller_painted_study.blend), with the atlas packed inside.
- [Editable face atlas](../../art_sources/traveller_painted/traveller_painted_atlas.svg) and its [1024-square PNG](../../art_sources/traveller_painted/traveller_painted_atlas.png).
- [Self-contained GLB](../../assets/studies/traveller_painted.glb) and [Godot study scene](../../art_trial/painted_traveller_study.tscn).
- [Native ceramic-light view](traveller-painted-study-01/native/ceramic-three-quarter.png), [lowered side](traveller-painted-study-01/native/lowered-side.png), and [lowered back](traveller-painted-study-01/native/lowered-back.png). All files in `native/` are Godot captures; `raised/` and `lowered/` contain Blender renders.

The new source uses native Blender geometry and has no dependency on the earlier base-mesh download. Use Blender 5.2 in a separate factory-startup process. From the repository root:

```sh
rtk proxy rsvg-convert -w 1024 -h 1024 -o art_sources/traveller_painted/traveller_painted_atlas.png art_sources/traveller_painted/traveller_painted_atlas.svg
rtk proxy blender --background --factory-startup --python art_sources/traveller_painted/build_study.py
rtk proxy godot --path . --editor --headless --import
rtk proxy godot --path . art_trial/painted_traveller_study.tscn
```

The builder replaces only this study's source, GLB, and Blender captures. To run the focused checks, use `rtk proxy godot --path . --headless --script tests/painted_traveller_tests.gd`. To record the native review, use Godot's `--write-movie` with `tests/painted_traveller_review.gd`, `--fixed-fps 30`, and a local output path outside Git.

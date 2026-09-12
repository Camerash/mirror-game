# Traveller head base review

Status: historical source review for the first detailed head study. The current painted-face direction replaces its anatomical construction requirements; see [the painted study](traveller-painted-study-01.md). The facts below describe the inspected source and the earlier proposed adaptation.

## Source and license

The inspected source is the official Blender download [Human Base Meshes v1.4.1](https://download.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip). The [Blender Demo Files page](https://www.blender.org/download/demo-files/) lists this bundle as CC0. The local archive SHA-256 is `811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515`.

## Selected starting asset

The earlier trial selected `human_base_meshes_bundle.blend`, object `Head - Generic Topology`. The 318-vertex control mesh has 316 all-quad faces, no boundary edges, one `UVMap`, and a Subdivision modifier. At its viewport level it evaluates to 1,266 vertices and 2,528 triangles. It has the `Real_Kid`, `Toon_FEMALE`, and `Toon_Anime_Kid` shape keys. These are useful reference shapes, not final child proportions.

The actual face topology has closed loops around each eye and a loop around the mouth. These provide a starting point for eyelid and mouth work; they do not prove a usable blink. The object has no material and no blink shape key. The bundle's separate `Eye - Stylized` object is 1,600 triangles. Avoid that cost for this target. Painted atlas eyes or much simpler native eyeballs are candidates. Confirm that eyelid closure works without stretching the iris or exposing gaps before selecting the final construction.

## Limits and adaptation

The base has adult skull, nose, jaw, ear, and neck structure. Do not make a child face by only scaling it down. Start from `Real_Kid` only as a comparison. Then make the cranium larger relative to the lower face, shorten and soften the chin and jaw, reduce the nose bridge and nose length, move the eye line lower on the larger cranium, and keep small almond eye openings with clear upper lids. Keep the cheek and brow as broad forms. Do not add lashes, lip detail, or skin detail.

Use the existing eye loops for one blink shape key. Make head turn with a simple neck joint or parent control. Keep the hood and the two long hair masses as separate broad opaque forms. The head base at 2,528 evaluated triangles leaves about 2,472 triangles for the hood, hair, neck, and face details within the 5,000-triangle study limit. Use one 1,024 color atlas and no more than three opaque surfaces.

The asset was inspected in Blender 5.2.1 LTS in a separate background process with `--disable-autoexec`. This review does not prove final deformation quality. Inspect blink, head turn, hood overlap, and the Godot Mobile result after an approved model is made.

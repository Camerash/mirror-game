# Art pipeline pilot, 2026-10

The same two assets, a shrine gate and a bonsai in a pot, built from code
in three ways, and judged in one Godot scene with the game's lighting and
camera. The findings are in [`docs/art-pipeline.md`](../../docs/art-pipeline.md).
This folder holds the sources so that the result can be rebuilt; the `.glb`
files and renders are build outputs and are not committed. A `.gdignore`
keeps the folder out of the game project.

| Folder | What it is | Tools |
| --- | --- | --- |
| `judge/` | Renders `.glb` files from the game's four views and at in-game size, and writes `stats.json` | Godot 4.7.2, Mobile renderer |
| `godot/` | Meshes built with `ArrayMesh` in GDScript, exported with `GLTFDocument` | Godot 4.7.2 |
| `blender/` | Meshes built with modifiers in a headless Blender script | `bpy` 5.0.1 from PyPI, Python 3.11 |
| `threejs/` | Meshes built with Three.js in plain Node, exported with `GLTFExporter` | Node 22, `three` 0.186.1 |

## Rebuild

Each command writes one asset. Every route gives byte-identical files on
every run; this was checked by rebuilding from these copies.

```sh
# Godot (headless)
godot --headless --path godot -s gen.gd -- gate /abs/out/gate.glb
godot --headless --path godot -s gen.gd -- bonsai /abs/out/bonsai.glb

# Blender (pip install bpy==5.0.1 in a Python 3.11 venv); also saves a .blend
python blender/gate.py -- --out /abs/out/gate.glb
python blender/bonsai.py -- --out /abs/out/bonsai.glb

# Three.js
(cd threejs && npm ci)
node threejs/src/gate.mjs /abs/out/gate.glb
node threejs/src/bonsai.mjs /abs/out/bonsai.glb
```

## Judge

Rendering needs a display; on Linux use `xvfb-run` with Mesa's software
Vulkan. Run the judge from a copy of `judge/` when several agents render at
once, so they do not share Godot's cache.

```sh
xvfb-run -a godot --path judge --rendering-method mobile -s judge.gd -- --input /abs/out/gate.glb --out /abs/renders/gate
```

It writes `view_1.png` to `view_4.png` (yaw 45°, 135°, 225° and 315°,
30° down, orthographic), `sheet.png` (all four), `game_scale.png` (view 1
at 1152×800, where a 0.8-unit capsule stands in for the traveller) and
`stats.json` (triangles, surfaces, materials, missing normals or UVs). The
lighting copies `world/trial_lighting.gd`. Do not change the judge's
lighting, camera or scale between routes being compared.

`godot/vcol_test.gd` shows a Godot 4.7.2 glTF import bug: a part of a mesh
gets vertex-colour albedo only if an earlier part of the same mesh has
vertex colours, so the first part's vertex colours are always ignored.

Agents using Blender here follow the Blender workflow in `AGENTS.md`.

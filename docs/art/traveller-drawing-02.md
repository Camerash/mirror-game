# Traveller from the user drawings

## Primary reference

Use [character and hood action](traveller-drawing-02/character-and-hood-action.jpeg) and [face and movement](traveller-drawing-02/face-and-movement.jpeg) as the main shape and motion references. Give both files to each modelling worker. Earlier models are references only; preserve their sources and gameplay assets.

## Confirmed shape

Keep chestnut low-bun hair and blue-grey clothing. Match the compact figure, small painted face, close rounded hood fitted to the head at the front and sides, narrow shoulders, and cloak that widens toward the ankles. Arms and most of the legs are covered at rest. Small authored shoes remain visible. The front opening starts below a diamond garment clasp. Paint the triangular hem border and simple eyes, brows, mouth, and soft cheeks.

Build connected, deliberate mesh contours. Use broad cloth shading and restrained highlights. The hood joins the cloak at a continuous neckline. Both static hood poses share topology; the lowered hood rests across the upper back in broad, flat folds with a small soft fold behind the neck. Keep additional hood room local to the bun; do not widen the whole hood. Keep the complete hairstyle and its dimensions. Do not reduce the hood to a small band or conceal intersections.

The shared upper collar may move with the hood while the lower cloak and clasp remain stable. A connected seam does not require every collar vertex to remain fixed in space. Review the hood and moving collar separately from the fixed cloak. The lowered hood must still read as the same full-sized garment, with soft folds rather than a thin strip or stiff flap.

## Shape approval gate

Review raised and lowered hood poses in front, side, rear, three-quarter, and elevated views, in grey and colour, at close and game size. Animation follows user shape approval. Target 6,000 triangles, ceiling 8,000, one 1024-square atlas, and at most two opaque materials. The user replaced the strict area and edge-length gates with visual shape and clearance requirements. Area and strain may be recorded as diagnostics; they are not acceptance gates. Require a full-sized hood, continuous neckline, no cloth self-intersections, and no head, hair, or body penetration. Keep the full hair unchanged.

## Authored hood shapes

Model a good lowered endpoint directly on the same vertex topology as the fitted raised hood. Form a shallow cloth pocket with broad soft folds across the upper back. Keep the neckline attached, the lower cloak and clasp stable, and the full head and hair clear. A small rig may assist authoring, but a physical folding solution is not required. Do not use offline or runtime cloth simulation.

Export the static `Garment.HoodLowered` endpoint without runtime hood bones or clips. Pose selection remains an immediate switch. After endpoint approval, author intermediate shapes that lift the rim clear of the head and bun, move it back, then settle it. Check each interval; a clear endpoint does not prove a clear transition. Do not combine the full-pose morph with duplicate skeletal deformation.

This follows the use of blend shapes for controlled clothing deformation in [Phung Nhat Huy’s rigging breakdown](https://www.cgmasteracademy.com/blog/8-steps-to-rig-an-expressive-character-and-their-clothes.html) and [Blender’s shape-key workflow](https://docs.blender.org/manual/en/5.0/animation/shape_keys/introduction.html). The exact hood construction remains an artistic choice for this model, not a guaranteed recipe from either source. [Godot supports blend-shape animation tracks](https://docs.godotengine.org/en/stable/classes/class_animation.html); animation is still deferred until shape approval.

## Later motion

Hands emerge through the front opening, grip the hood, lower it, and return beneath the cloak. Later add the reverse action, small walking/jogging steps, limited body sway, and gentle cloak motion. Use authored animation without runtime cloth simulation. Device tests and gameplay replacement follow later approval.

## Art viewer

Open `art_trial/drawing_traveller_study.tscn`. From the project folder, run `rtk proxy godot --path . art_trial/drawing_traveller_study.tscn`. The previous full traveller scene remains a separate comparison.

Use Front, Side, Back, Three-quarter, and Elevated for fixed views. Grey / colour, Lighting, Size, Face, and Reset remain available. Hood switches between Raised and Folded immediately, with common camera bounds. Keyboard: Q/E views, G grey, L lighting, V size, F expression, U hood, R Reset, H controls. Arms and automatic motion remain disabled. The notice states that these are static poses, not a finished transition.

## Validation — authored endpoint pass

Both static hood poses are available for user shape review. The raised hood is narrower (1.198 source units across the outer hood) and follows the head more closely. The lowered hood lies close to the upper back. The source retains editable outer geometry, thickness modifiers, and the directly authored shape. The GLB has baked thickness with matching triangles and one `Garment.HoodLowered` morph; it has no skeleton or animation clips.

- Source checks: 5,892 triangles, two opaque materials, one 1024 atlas. Both endpoints have zero detected outer/lining self-crossings and zero head, hair, or body crossings. Hair coordinates are unchanged. The outer lower cloak, neckline, and clasp remain fixed. All 1,440 arm-coverage rays pass.
- Export checks: one garment morph, no other targets, skins, or animations. Garment base and morph position/normal accessors each contain 1,570 vertices.
- Cloth diagnostics: hood area change -64.07%, edge strain p95 81.38%, maximum 143.66%. This is an artistic morph, not a physical fold. These numbers are retained under the user's approved change to visual shape and clearance requirements.
- Godot import and all 90 focused drawing-viewer checks pass. They cover endpoint selection, shared bounds, expressions, material ownership, keyboard controls, and Reset. The shared viewer code and old gameplay assets were unchanged in this pass.
- Native Mac Mobile/Metal review: both poses captured from five views, plus grey and game-size views. See the [comparison](traveller-drawing-02/native-authored/comparison.png), [all views](traveller-drawing-02/native-authored/all-views.png), and [Blender shape captures](traveller-drawing-02/authored-shapes/lowered-back.png). The rear fold has low contrast under the flat inspector lighting; this remains a visual review point.
- The runtime bridge timed out, so the native review used the authorised direct Mac launch. It exited successfully after capture. A CoreAudio start error was logged; audio was not reviewed. The runtime is stopped and its temporary capture script and bridge are removed.

Animation is still deferred. Clear endpoints do not prove a clear path between them. After approval, author and check intermediate targets around the head and bun. Physical-device performance and gameplay replacement remain unverified.

# Traveller from the user drawings

## Primary reference

Use [character and hood action](traveller-drawing-02/character-and-hood-action.jpeg) and [face and movement](traveller-drawing-02/face-and-movement.jpeg) as the main shape and motion references. Give both files to each modelling worker. Earlier models are references only; preserve their sources and gameplay assets.

## Confirmed shape

Keep chestnut low-bun hair and blue-grey clothing. Match the compact figure, small painted face, close rounded hood, narrow shoulders, and cloak that widens toward the ankles. Arms and most of the legs are covered at rest. Small authored shoes remain visible. The front opening starts below a diamond garment clasp. Paint the triangular hem border and simple eyes, brows, mouth, and soft cheeks.

Build connected, deliberate mesh contours. Use broad cloth shading and restrained highlights. The hood joins the cloak at a continuous neckline. Both static hood poses share topology; the lowered hood rests behind the neck and upper back in broad folds. Keep the complete hairstyle and its dimensions. Do not shrink cloth or conceal intersections.

The shared upper collar may move with the hood while the lower cloak and clasp remain stable. A connected seam does not require every collar vertex to remain fixed in space. Measure the hood and moving collar separately from the fixed cloak so its larger area cannot hide local shrinkage.

## Shape approval gate

Review raised and lowered hood poses in front, side, rear, three-quarter, and elevated views, in grey and colour, at close and game size. Animation follows user shape approval. Target 6,000 triangles, ceiling 8,000, one 1024-square atlas, and at most two opaque materials. Preserve cloth area within 5%; at least 95% of edges remain within 10% of their original length and none exceed 20%. Record failed checks without relaxing these limits.

## Rig construction

Use a small hood rig and authored static poses with local corrective shapes. Do not use offline or runtime cloth simulation for further hood work. Keep bone scales at one; a rig must fold the cloth, not shrink it. The rig does not replace area, stretch, clearance, or visual checks. Approve both static poses before keyframe animation.

## Later motion

Hands emerge through the front opening, grip the hood, lower it, and return beneath the cloak. Later add the reverse action, small walking/jogging steps, limited body sway, and gentle cloak motion. Use authored animation without runtime cloth simulation. Device tests and gameplay replacement follow later approval.

## Art viewer

Open `art_trial/drawing_traveller_study.tscn`. From the project folder, run `rtk proxy godot --path . art_trial/drawing_traveller_study.tscn`. The previous full traveller scene remains a separate comparison.

Use Front, Side, Back, Three-quarter, and Elevated for fixed views. Grey / colour, Lighting, Size, Face, and Reset remain available. The current draft is raised-only: it has no hood-pose control, arm-pose control, or automatic animation. Keyboard: Q/E views, G grey, L lighting, V size, F expression, R Reset, H controls. U does nothing in this draft. The scene displays an unfinished notice rather than a false hood-down pose.

## Validation

The required two-pose delivery is **incomplete**. The useful raised silhouette is retained for review. No lowered pose or animation is approved, and no zero-displacement substitute is exported as a folded hood.

The final bounded sewn-pattern test failed the required raised-to-lowered comparison: area -11.378%, edge strain p95 31.368%, maximum 126.054%, and 57 outer self-intersections. Head, hair, and body crossings were zero, but the lowered hood was visibly crumpled. The attempt is rejected; its evidence is separate from the raised draft. Flat-pattern strain is an additional construction diagnostic and does not replace these endpoint measurements.

Earlier direct drape and panel-fit attempts also failed. The angular panel construction preserved lengths but lost the drawn rounded hood. It is not used as the visual target or exported as an accepted result. No limits were relaxed. The raised source checks pass: 5,892 triangles, two opaque materials, one 1024 atlas, and zero reported cloth self, shell, head, hair, or body crossings. The complete hairstyle is unchanged. There are 180 concealed arm vertices; all 1,440 coverage rays passed. The default two-pose checker correctly fails because the lower pose is absent.

Godot focused checks passed: drawing study 80/80 and preserved full study 92/92. Native Mac Mobile/Metal captures are saved in [native-raised](traveller-drawing-02/native-raised/view-3.png). The runtime bridge launch timed out twice, so a direct Mac launch captured the draft and exited. The runtime reported a CoreAudio start error; no audio result is claimed. The draft has a readable unfinished notice. The rear view shows a continuous garment; the hem detail remains low contrast. These captures do not validate a folded pose or animation. Physical-device performance is unverified.

The runtime is stopped and the temporary capture script and bridge are removed. The failed simulation is retained only as evidence, not as a model target.

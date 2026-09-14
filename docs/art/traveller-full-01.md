# Full-body traveller study 01

This revision is preserved for comparison. The [drawing-led remodel](traveller-drawing-02.md) is the current shape target. Its longer cloak and new hood construction replace the proportions and failed folded endpoint in this study.

## Shape review gate

Build a new compact girl, approximately three heads tall, with a painted face, chestnut low bun, and blue-grey open-front hooded cape. Use a simple tunic, sleeved arms, hands with thumbs and grouped fingers, and boots. The old busts are appearance references only. Keep their assets and the gameplay character intact.

Review the complete figure in front, side, back, three-quarter, and elevated views, at close and game size. Show the raised and folded hood in colour and plain grey, plus a static raised-arm reach pose. User shape approval is required before animation work.

## Construction

Use a new hood pattern joined to the cape neckline. Both endpoints share topology. The lowered hood folds behind the neck and over the upper back, retaining cloth area and visible thickness. Keep the scalp and low bun fixed. Loose hair may bend locally for contact, but must not shrink, disappear, or pass through the hood.

The current mesh refresh replaces the primitive-looking bun and feet. Hair is one welded, closed low-poly volume with a shared nape connection (932 triangles). Boots are two welded, closed shoe volumes, one per foot, with authored sole, toe, heel, shaft, and cuff loops (424 triangles). The complete asset is 5,584 triangles with two opaque materials and one embedded 1024-square atlas. These checks confirm the construction; they do not approve the separate hood fold.

Target 6,000 triangles, with an 8,000 ceiling; one shared 1024×1024 atlas and at most two opaque materials. Preserve the painted expression approach. Measure one cloth surface without thickness rims: total area within 5% of rest, 95% of edges within 10% of rest length, and no edge beyond 20%. These are review limits, not a substitute for visual checks.

## Later animation stage

After shape approval, use one skeleton with hood, cape, and loose-hair controls and authored corrective shapes. Bake Blender constraints for export. Keep cloth bone scales at one. Author both hands gripping fixed rim points through reach, lift, settle, and release.

Provide idle and gentle jogging loops plus hood-up and hood-down actions while standing and jogging. Use a lower-body jogging layer and an upper-body hood-action layer, with complete arm poses at both endpoints. Add corrective poses for combined motion. Complete an active hood action before reversing. Pause freezes motion; Reset restores the defined initial state. No runtime cloth simulation or per-frame mesh rebuilding.

The later viewer adds motion, speed, pause, and timeline controls. No motion clips or gameplay replacement are part of the initial shape review.

## Static viewer

Open `art_trial/full_traveller_study.tscn`. Use the five view buttons, Grey / colour, Lighting, and Size to inspect the figure. Hood and Arms select independent static endpoints. Face selects neutral, half-closed, closed, or smile. Reset restores the raised hood, resting arms, and neutral face. The camera includes both endpoints in its fixed fit.

From the project folder, import new assets with `rtk proxy godot --headless --editor --import`, then launch with `rtk proxy godot --path . art_trial/full_traveller_study.tscn`.

Desktop shortcuts: Q/E for views, G for grey, L for lighting, V for size, U for hood, A for arms, F for face, R for Reset, and H for controls. Touch controls remain available in the art viewer. This scene has no automatic pose transition.

The exported `Hood` uses `HoodLowered`; `Arms` uses `ArmsReach`. Hair remains fixed. These static shapes are review controls, not a claim that interpolation between endpoints is a valid future animation.

## Current evidence

The mesh refresh passed the focused construction checks and native Mac Mobile review. The bun and each shoe read as continuous authored forms without overlapping primitive shells. Captures are in `docs/art/traveller-full-01/character-refresh/`. The hood remains provisional: its lowered endpoint still fails the cloth edge-strain and self-crossing checks. Physical-device performance and the future hood transition are unverified.

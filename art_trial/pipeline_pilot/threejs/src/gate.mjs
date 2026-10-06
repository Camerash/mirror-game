// Shrine gate. Units: 1 = one game block. Y up, origin at base centre, resting on y = 0.
import { roundedBox, bendArc, roundedPolyline, splineProfile, lathe, material, exportGLB } from './lib.mjs';

const out = process.argv[2] || new URL('../out/gate.glb', import.meta.url).pathname;

const ivory = material('ivory_glaze', '#efe6d8', 0.35, 0);
const jade = material('jade', '#5f8f78', 0.3, 0);
const metal = material('warm_metal', '#c9a36a', 0.35, 1);
const parts = { ivory: [], jade: [], metal: [] };

const box = (size, r, at, opts) => roundedBox(size, r, opts).translate(at[0], at[1], at[2]);
const EMBED = 0.005; // stacked parts overlap slightly: no hairline gaps, no coplanar faces

// --- Plinth: two steps and a jade band around the upper step ---
parts.ivory.push(box([3.0, 0.2, 2.0], 0.03, [0, 0.1, 0]));
parts.ivory.push(box([2.6, 0.2 + EMBED, 1.6], 0.03, [0, 0.3 - EMBED / 2, 0]));
parts.jade.push(box([2.64, 0.05, 1.64], 0.02, [0, 0.3, 0]));

// --- Columns: base (stepped disc), shaft, astragal ring, echinus; abacus on top ---
const STEP_TOP = 0.4, ABACUS_BOTTOM = 2.12, SPRING = 2.2;
const columnProfile = roundedPolyline([
  [0, STEP_TOP - EMBED],
  [0.22, STEP_TOP - EMBED, 0],          // sits on the step (hidden corner)
  [0.22, STEP_TOP + 0.05, 0.02],        // lower disc
  [0.19, STEP_TOP + 0.05, 0.008],
  [0.19, STEP_TOP + 0.1, 0.02],         // upper disc
  [0.16, STEP_TOP + 0.1, 0.008],        // shaft starts (y 0.5)
  [0.16, 1.955, 0.008],                 // shaft top
  [0.182, 1.955, 0.012],                // astragal ring
  [0.182, 1.985, 0.008],
  [0.164, 1.985, 0.003],
  [0.19, 2.005, 0.03],                  // echinus: convex flare
  [0.215, 2.05, 0.04],
  [0.215, ABACUS_BOTTOM + EMBED, 0],    // hidden inside the abacus
  [0, ABACUS_BOTTOM + EMBED],
], { step: Math.PI / 4 });
for (const x of [-0.85, 0.85]) {
  parts.ivory.push(lathe(columnProfile, 20).translate(x, 0, 0));
  parts.ivory.push(box([0.42, 0.08 + EMBED, 0.42], 0.02, [x, (ABACUS_BOTTOM + SPRING + EMBED) / 2, 0]));
}

// --- Arch: nine voussoirs on a semicircle centred on x = 0, springing from the abaci ---
const RC = 0.85, THICK = 0.18, DEPTH = 0.36, COUNT = 9, CY = SPRING - 0.003;
const span = Math.PI / COUNT;
for (let k = 0; k < COUNT; k++) {
  const theta = span * (k + 0.5);
  const key = k === (COUNT - 1) / 2;
  const len = RC * span + 0.001; // slight overlap at the joints; the bevels form the joint grooves
  if (key) {
    // Keystone: protrudes below the intrados, above the extrados and from both faces.
    const inner = 0.72, outer = 1.03; // rises 0.09 above the extrados to carry the slab
    const g = roundedBox([len, outer - inner, DEPTH + 0.04], 0.02, { flat: [2, 1, 1] })
      .translate(0, (inner + outer) / 2 - RC, 0);
    parts.jade.push(bendArc(g, RC, theta, 0, CY));
  } else {
    const g = roundedBox([len, THICK, DEPTH], 0.02, { flat: [2, 1, 1] });
    parts.ivory.push(bendArc(g, RC, theta, 0, CY));
  }
}

// --- Cap slab resting on the keystone, and the finial ---
const SLAB_BOTTOM = 3.19, SLAB_TOP = SLAB_BOTTOM + 0.1;
parts.ivory.push(box([2.0, 0.1, 0.5], 0.03, [0, (SLAB_BOTTOM + SLAB_TOP) / 2, 0]));

const collar = roundedPolyline([
  [0, -EMBED], [0.065, -EMBED, 0], [0.065, 0.028, 0.012], [0.03, 0.028, 0.008], [0.03, 0.045],
], { step: Math.PI / 4 });
const bulb = splineProfile([
  [0.03, 0.045], [0.052, 0.066], [0.074, 0.098], [0.08, 0.125], [0.068, 0.158], [0.042, 0.19],
  [0.02, 0.22], [0.009, 0.255], [0.0, 0.3],
], 12);
const finial = [...collar, ...bulb.slice(1)];
parts.metal.push(lathe(finial, 16).translate(0, SLAB_TOP, 0));

await exportGLB([
  { name: 'gate_ivory', mat: ivory, parts: parts.ivory },
  { name: 'gate_jade', mat: jade, parts: parts.jade },
  { name: 'gate_metal', mat: metal, parts: parts.metal },
], out, 'shrine_gate');

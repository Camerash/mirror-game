// Bonsai in a shallow oval pot. Units: 1 = one game block. Y up, origin at the pot's base centre.
import { THREE, rng, roundedPolyline, splineProfile, lathe, sweepTube, material, exportGLB } from './lib.mjs';
import { mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

const out = process.argv[2] || new URL('../out/bonsai.glb', import.meta.url).pathname;
const OVAL = 0.76; // pot depth / width

const glaze = material('celadon_glaze', '#a3c1b0', 0.35, 0);
const moss = material('moss', '#5a6b3d', 0.95, 0);
const bark = material('bark', '#6b5040', 0.8, 0);
const leaves = [material('leaf_mid', '#6f9a5a', 0.8), material('leaf_light', '#7aa462', 0.8), material('leaf_dark', '#648d50', 0.8)];

// --- Pot: foot ring, rounded belly, outward lip; hidden underside corners stay hard ---
const potProfile = roundedPolyline([
  [0, 0.018], [0.17, 0.018, 0], [0.175, 0, 0], [0.215, 0, 0.006], [0.222, 0.028, 0.006],
  [0.272, 0.04, 0.02], [0.285, 0.19, 0.006], [0.305, 0.198, 0.008], [0.307, 0.24, 0.012],
  [0.268, 0.24, 0.01], [0.262, 0.205, 0], [0, 0.205],
], { step: Math.PI / 4 });
const pot = lathe(potProfile, 36, { scaleZ: OVAL });

// --- Moss: a low dome sealed into the inner wall ---
const mossProfile = [
  ...roundedPolyline([[0, 0.2], [0.27, 0.2, 0], [0.27, 0.221]]),
  ...splineProfile([[0.27, 0.221], [0.2, 0.228], [0.1, 0.232], [0, 0.233]], 4).slice(1),
];
const mossDisc = lathe(mossProfile, 36, { scaleZ: OVAL });

// --- Trunk: gentle S-curve, tapering, with a lobed root flare at the soil line ---
// Analytic centreline: a gentle S in x and a softer sway in z, damped towards the apex.
// (A Catmull-Rom through hand-placed points made tight elbows that folded the tube.)
const smooth = (e0, e1, x) => { const t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };
class TrunkCurve extends THREE.Curve {
  getPoint(t, target = new THREE.Vector3()) {
    const y = 0.15 + 0.71 * t, env = (1 - 0.5 * Math.max(0, (y - 0.24) / 0.62)) * smooth(0.12, 0.32, y);
    const x = 0.01 - 0.04 * Math.sin((Math.PI * (y - 0.24)) / 0.3) * env;
    const z = 0.025 * Math.sin((Math.PI * (y - 0.3)) / 0.45) * env;
    return target.set(x, y, z);
  }
}
const trunkCurve = new TrunkCurve();
const T_SOIL = 0.11; // curve parameter where the trunk meets the moss
const trunkRadius = (t, th) => {
  const base = 0.064 + (0.021 - 0.064) * Math.pow(t, 0.8);
  const w = 1 - smooth(T_SOIL, T_SOIL + 0.2, t);
  // Integer frequencies keep the ring periodic (no seam crease); two terms make uneven roots.
  // Raised cosines: smooth everywhere and broad enough for the ring resolution.
  const lobe = 0.8 * ((1 + Math.cos(3 * (th - 0.4))) / 2) ** 2 + 0.5 * ((1 + Math.cos(2 * (th - 1.9))) / 2) ** 2 - 0.25;
  return base * (1 + w * (0.5 + 0.35 * lobe)); // gentle lobes: ~1.33x radius swing at the soil
};
const trunkTs = Array.from({ length: 26 }, (_, i) => Math.pow(i / 25, 1.3));
const trunk = sweepTube(trunkCurve, trunkTs, 22, trunkRadius);

// --- Branches: start inside the trunk, end inside their pads ---
function branch(tOnTrunk, end, r0, r1) {
  // Cubic Bezier from inside the trunk to inside the pad: dips slightly, then rises.
  const S = trunkCurve.getPointAt(tOnTrunk), E = new THREE.Vector3(...end), D = E.clone().sub(S);
  const c1 = S.clone().addScaledVector(D, 0.35).add(new THREE.Vector3(0, -0.02, 0));
  const c2 = S.clone().addScaledVector(D, 0.7).add(new THREE.Vector3(0, -0.01, 0));
  const curve = new THREE.CubicBezierCurve3(S, c1, c2, E);
  const ts = Array.from({ length: 12 }, (_, i) => i / 11);
  return sweepTube(curve, ts, 10, (t) => r0 + (r1 - r0) * Math.pow(t, 0.7), { maxBendDeg: 12 });
}
const branches = [
  branch(0.33, [0.24, 0.52, 0.05], 0.03, 0.012),
  branch(0.5, [-0.19, 0.62, -0.04], 0.026, 0.011),
  branch(0.62, [0.09, 0.71, -0.15], 0.022, 0.01),
  branch(0.75, [0.14, 0.78, 0.11], 0.018, 0.009),
];

// --- Foliage pads: one closed, displaced icosphere each (no intersection creases) ---
// The surface is a smooth union of ellipsoid puffs seen from the pad centre: for each
// direction, the exit distance through every puff, blended with a p-norm smooth max.
// Every puff contains the centre, so the distance is continuous and the pad is closed.
function pad({ c, ax, az, h, yaw, puffs, seed, detail = 5 }) {
  const rand = rng(seed);
  // A narrower base cushion, a rim ring of puffs that defines a scalloped outline, and
  // a few inner puffs that make a tiered, lumpy top.
  const parts = [{ q: [0, 0, 0], r: [0.72 * ax, 0.4 * h, 0.72 * az] }];
  for (let k = 0; k < puffs; k++) {
    const phi = (2 * Math.PI * (k + 0.3 * rand())) / puffs, s = 0.95 + 0.15 * rand();
    parts.push({ q: [0.46 * ax * Math.cos(phi), 0.1 * h, 0.46 * az * Math.sin(phi)],
      r: [0.52 * ax * s, 0.5 * h * s, 0.52 * az * s] });
  }
  for (let k = 0; k < 3; k++) {
    const phi = 2 * Math.PI * rand();
    parts.push({ q: [0.2 * ax * Math.cos(phi), (0.2 + 0.1 * rand()) * h, 0.2 * az * Math.sin(phi)],
      r: [0.45 * ax, 0.55 * h, 0.45 * az] });
  }
  for (const { q, r } of parts) {
    const u2 = (q[0] / r[0]) ** 2 + (q[1] / r[1]) ** 2 + (q[2] / r[2]) ** 2;
    if (u2 > 0.95) throw new Error(`puff does not contain the pad centre (${u2.toFixed(2)})`);
  }
  let g = new THREE.IcosahedronGeometry(1, detail);
  g.deleteAttribute('uv'); g.deleteAttribute('normal');
  g = mergeVertices(g);
  const P = 12, pos = g.attributes.position, uv = [], cy = Math.cos(yaw), sy = Math.sin(yaw);
  for (let i = 0; i < pos.count; i++) {
    const d = [pos.getX(i), pos.getY(i), pos.getZ(i)], dl = Math.hypot(...d);
    d[0] /= dl; d[1] /= dl; d[2] /= dl;
    let acc = 0;
    for (const { q, r } of parts) {
      const u = [-q[0] / r[0], -q[1] / r[1], -q[2] / r[2]], v = [d[0] / r[0], d[1] / r[1], d[2] / r[2]];
      const vv = v[0] ** 2 + v[1] ** 2 + v[2] ** 2, uv_ = u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
      const uu = u[0] ** 2 + u[1] ** 2 + u[2] ** 2;
      const t = (-uv_ + Math.sqrt(uv_ * uv_ - vv * (uu - 1))) / vv;
      acc += t ** P;
    }
    const rad = acc ** (1 / P);
    const lx = d[0] * rad, ly = d[1] * rad * (d[1] < 0 ? 0.6 : 1), lz = d[2] * rad; // flatter underside
    pos.setXYZ(i, c[0] + lx * cy - lz * sy, c[1] + ly, c[2] + lx * sy + lz * cy);
    uv.push(0.5 + Math.atan2(d[2], d[0]) / (2 * Math.PI), Math.acos(Math.max(-1, Math.min(1, d[1]))) / Math.PI);
  }
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.computeVertexNormals();
  return g;
}
const pads = [
  { c: [0.24, 0.53, 0.05], ax: 0.16, az: 0.13, h: 0.13, yaw: 0.3, puffs: 7, seed: 11, m: 0 },
  { c: [-0.19, 0.63, -0.04], ax: 0.14, az: 0.115, h: 0.115, yaw: -0.4, puffs: 6, seed: 23, m: 2 },
  { c: [0.09, 0.72, -0.15], ax: 0.13, az: 0.105, h: 0.11, yaw: 0.9, puffs: 6, seed: 37, m: 0, detail: 4 },
  { c: [0.14, 0.79, 0.11], ax: 0.11, az: 0.095, h: 0.1, yaw: -0.2, puffs: 5, seed: 41, m: 1, detail: 4 },
  { c: [0.005, 0.87, 0.01], ax: 0.15, az: 0.125, h: 0.14, yaw: 0.6, puffs: 7, seed: 53, m: 1 },
];
const leafParts = [[], [], []];
for (const spec of pads) leafParts[spec.m].push(pad(spec));

await exportGLB([
  { name: 'pot', mat: glaze, parts: [pot] },
  { name: 'moss', mat: moss, parts: [mossDisc] },
  { name: 'trunk', mat: bark, parts: [trunk, ...branches] },
  ...leafParts.map((parts, i) => ({ name: `foliage_${i}`, mat: leaves[i], parts })),
], out, 'bonsai');

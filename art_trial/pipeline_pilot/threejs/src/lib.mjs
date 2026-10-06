// Shared geometry, check and export helpers for the Three.js route (Node, no browser).
import * as THREE from 'three';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import fs from 'node:fs';

export { THREE };

// GLTFExporter's binary path reads Blobs with FileReader, which Node lacks (Blob exists in Node 22).
if (typeof globalThis.FileReader === 'undefined') {
  globalThis.FileReader = class FileReader {
    readAsArrayBuffer(blob) {
      blob.arrayBuffer().then((buf) => { this.result = buf; this.onloadend?.(); });
    }
    readAsDataURL(blob) {
      blob.arrayBuffer().then((buf) => {
        this.result = 'data:application/octet-stream;base64,' + Buffer.from(buf).toString('base64');
        this.onloadend?.();
      });
    }
  };
}

// Seeded PRNG (mulberry32) so every run is identical.
export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export class MeshBuilder {
  constructor() { this.pos = []; this.nrm = []; this.uv = []; this.idx = []; }
  get count() { return this.pos.length / 3; }
  v(p, n, uv) {
    this.pos.push(p[0], p[1], p[2]); this.nrm.push(n[0], n[1], n[2]); this.uv.push(uv[0], uv[1]);
    return this.count - 1;
  }
  tri(a, b, c) { this.idx.push(a, b, c); }
  // a,b,c,d counter-clockwise seen from outside
  quad(a, b, c, d) { this.idx.push(a, b, c, a, c, d); }
  geometry() {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(this.nrm, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(this.uv, 2));
    g.setIndex(this.idx);
    return g;
  }
}

// ---------- Rounded box (Minkowski box + sphere, cube-sphere parametrisation) ----------
// Flat faces keep the exact face normal; the round edges carry analytic normals, so the
// bevel catches a soft highlight while flat faces stay crisp.
function axisSamples(a, sHalf, nFlat) {
  const out = [];
  for (let k = 0; k <= sHalf; k++) out.push([-a, (-Math.PI / 4) * (sHalf - k) / sHalf]);
  for (let k = 1; k < nFlat; k++) out.push([-a + (2 * a * k) / nFlat, 0]);
  for (let k = 0; k <= sHalf; k++) out.push([a, (Math.PI / 4) * k / sHalf]);
  return out;
}

export function roundedBox(size, r, { sHalf = 1, flat = [1, 1, 1] } = {}) {
  const half = size.map((s) => s / 2 - r);
  const samples = half.map((a, i) => axisSamples(a, sHalf, flat[i]));
  const mb = new MeshBuilder();
  // [face axis, sign, u axis, v axis] with u x v = sign * face axis (outward, CCW)
  const faces = [[0, 1, 1, 2], [0, -1, 2, 1], [1, 1, 2, 0], [1, -1, 0, 2], [2, 1, 0, 1], [2, -1, 1, 0]];
  for (const [f, s, u, v] of faces) {
    const su = samples[u], sv = samples[v], W = su.length, base = mb.count;
    for (let j = 0; j < sv.length; j++) {
      for (let i = 0; i < W; i++) {
        const inner = [0, 0, 0]; inner[f] = s * half[f]; inner[u] = su[i][0]; inner[v] = sv[j][0];
        const n = [0, 0, 0]; n[f] = s; n[u] = Math.tan(su[i][1]); n[v] = Math.tan(sv[j][1]);
        const l = Math.hypot(n[0], n[1], n[2]); n[0] /= l; n[1] /= l; n[2] /= l;
        const p = [inner[0] + r * n[0], inner[1] + r * n[1], inner[2] + r * n[2]];
        mb.v(p, n, [p[u], p[v]]);
      }
    }
    for (let j = 0; j < sv.length - 1; j++) {
      for (let i = 0; i < W - 1; i++) { const a = base + j * W + i; mb.quad(a, a + 1, a + 1 + W, a + W); }
    }
  }
  return mb.geometry();
}

// Bend a part built along local x (tangential), y (radial), z (depth) around a circle of
// radius Rc in the XY plane, centred at (cx, cy). thetaC is the angle of local x = 0.
// Normals use the inverse-transpose Jacobian, so they stay analytic.
export function bendArc(g, Rc, thetaC, cx = 0, cy = 0) {
  const p = g.attributes.position, n = g.attributes.normal;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), y = p.getY(i), z = p.getZ(i);
    const th = thetaC - x / Rc, rho = Rc + y, c = Math.cos(th), s = Math.sin(th);
    p.setXYZ(i, cx + rho * c, cy + rho * s, z);
    const k = (-n.getX(i) * Rc) / rho, ny = n.getY(i), nz = n.getZ(i);
    const ox = -k * s + ny * c, oy = k * c + ny * s, l = Math.hypot(ox, oy, nz);
    n.setXYZ(i, ox / l, oy / l, nz / l);
  }
  return g;
}

// ---------- 2D profiles: polyline with per-corner fillets, analytic normals ----------
// pts: [[x, y, fillet], ...]. Outward normal is to the right of the travel direction.
// fillet 0 on an inner corner makes a hard edge (duplicated sample, two normals).
export function roundedPolyline(pts, { step = Math.PI / 6 } = {}) {
  const out = [];
  const right = (d) => [d[1], -d[0]];
  const unit = (x, y) => { const l = Math.hypot(x, y); return [x / l, y / l]; };
  // Pass 1: tangent length of every fillet; adjacent fillets must fit on their shared segment.
  const tl = pts.map((P, i) => {
    if (i === 0 || i === pts.length - 1 || !(P[2] > 0)) return 0;
    const A = pts[i - 1], C = pts[i + 1];
    const d1 = unit(P[0] - A[0], P[1] - A[1]), d2 = unit(C[0] - P[0], C[1] - P[1]);
    return P[2] * Math.tan(Math.abs(Math.atan2(d1[0] * d2[1] - d1[1] * d2[0], d1[0] * d2[0] + d1[1] * d2[1])) / 2);
  });
  for (let i = 0; i < pts.length - 1; i++) {
    const len = Math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]);
    if (tl[i] + tl[i + 1] > len + 1e-9) throw new Error(`fillets overlap on segment ${i}: ${pts[i]} -> ${pts[i + 1]}`);
  }
  for (let i = 0; i < pts.length; i++) {
    const P = pts[i];
    if (i === 0 || i === pts.length - 1) {
      const Q = i === 0 ? pts[1] : pts[i - 1];
      const d = i === 0 ? unit(Q[0] - P[0], Q[1] - P[1]) : unit(P[0] - Q[0], P[1] - Q[1]);
      out.push({ p: [P[0], P[1]], n: right(d) });
      continue;
    }
    const A = pts[i - 1], C = pts[i + 1];
    const d1 = unit(P[0] - A[0], P[1] - A[1]), d2 = unit(C[0] - P[0], C[1] - P[1]);
    const rf = P[2] || 0;
    if (rf <= 0) { out.push({ p: [P[0], P[1]], n: right(d1) }, { p: [P[0], P[1]], n: right(d2) }); continue; }
    const phi = Math.atan2(d1[0] * d2[1] - d1[1] * d2[0], d1[0] * d2[0] + d1[1] * d2[1]);
    const t = tl[i];
    const T1 = [P[0] - d1[0] * t, P[1] - d1[1] * t];
    const side = phi > 0 ? [-d1[1], d1[0]] : [d1[1], -d1[0]];
    const Cc = [T1[0] + side[0] * rf, T1[1] + side[1] * rf];
    const k = Math.max(1, Math.ceil(Math.abs(phi) / step - 1e-9));
    for (let s = 0; s <= k; s++) {
      const a = (phi * s) / k, ca = Math.cos(a), sa = Math.sin(a);
      const vx = T1[0] - Cc[0], vy = T1[1] - Cc[1];
      const d = [d1[0] * ca - d1[1] * sa, d1[0] * sa + d1[1] * ca];
      out.push({ p: [Cc[0] + vx * ca - vy * sa, Cc[1] + vx * sa + vy * ca], n: right(d) });
    }
  }
  return out;
}

// Smooth spline samples (THREE.SplineCurve), normals from the curve tangent.
export function splineProfile(points, count) {
  const curve = new THREE.SplineCurve(points.map(([x, y]) => new THREE.Vector2(x, y)));
  const out = [];
  for (let i = 0; i <= count; i++) {
    const u = i / count, p = curve.getPointAt(u), d = curve.getTangentAt(u);
    out.push({ p: [Math.max(0, p.x), p.y], n: [d.y, -d.x] });
  }
  return out;
}

// Revolve a profile (bottom to top, solid on the left) about Y. scaleZ makes an oval.
export function lathe(profile, segments, { scaleZ = 1 } = {}) {
  const mb = new MeshBuilder(), W = segments + 1, vs = [0];
  for (let i = 1; i < profile.length; i++) {
    vs.push(vs[i - 1] + Math.hypot(profile[i].p[0] - profile[i - 1].p[0], profile[i].p[1] - profile[i - 1].p[1]));
  }
  for (let i = 0; i < profile.length; i++) {
    const { p: [r, y], n: [nr, ny] } = profile[i];
    for (let j = 0; j <= segments; j++) {
      const phi = (2 * Math.PI * j) / segments, c = Math.cos(phi), s = Math.sin(phi);
      const n = [nr * c, ny, (nr * s) / scaleZ], l = Math.hypot(n[0], n[1], n[2]);
      mb.v([r * c, y, r * s * scaleZ], [n[0] / l, n[1] / l, n[2] / l], [j / segments, vs[i]]);
    }
  }
  const eps = 1e-9;
  for (let i = 0; i < profile.length - 1; i++) {
    const [r0, y0] = profile[i].p, [r1, y1] = profile[i + 1].p;
    if (Math.hypot(r1 - r0, y1 - y0) < eps) continue; // hard-corner duplicate
    for (let j = 0; j < segments; j++) {
      const a = i * W + j, b = a + 1, d = a + W, c = d + 1;
      if (r0 > eps) mb.tri(a, c, b);
      if (r1 > eps) mb.tri(a, d, c);
    }
  }
  return mb.geometry();
}

// ---------- Swept tube with variable radius (organic parts) ----------
// curve: THREE.Curve; ts: sample parameters (0..1, arc length); radius(t, theta) -> r.
// Normals are smooth (computed on the welded ring mesh, no seam split).
export function sweepTube(curve, ts, segments, radius, { capStart = true, capEnd = true, maxBendDeg = 10 } = {}) {
  const pos = [], uv = [], idx = [];
  // A tight bend between rings folds the tube on the inside of the bend (reads as facets).
  for (let i = 1; i < ts.length; i++) {
    const bend = THREE.MathUtils.radToDeg(curve.getTangentAt(ts[i - 1]).angleTo(curve.getTangentAt(ts[i])));
    if (bend > maxBendDeg) throw new Error(`sweep bends ${bend.toFixed(1)} deg between rings ${i - 1} and ${i}`);
  }
  let T = curve.getTangentAt(ts[0]).normalize();
  let N = Math.abs(T.y) < 0.9 ? new THREE.Vector3(0, 1, 0).cross(T).normalize() : new THREE.Vector3(1, 0, 0).cross(T).normalize();
  const rings = [];
  for (let i = 0; i < ts.length; i++) {
    const t = ts[i], P = curve.getPointAt(t), Ti = curve.getTangentAt(t).normalize();
    N = N.clone().sub(Ti.clone().multiplyScalar(N.dot(Ti))).normalize(); // parallel transport
    const B = new THREE.Vector3().crossVectors(Ti, N);
    rings.push({ P, N: N.clone(), B });
    for (let j = 0; j < segments; j++) {
      const th = (2 * Math.PI * j) / segments, r = radius(t, th);
      const o = N.clone().multiplyScalar(Math.cos(th) * r).add(B.clone().multiplyScalar(Math.sin(th) * r));
      pos.push(P.x + o.x, P.y + o.y, P.z + o.z); uv.push(j / segments, t);
    }
  }
  for (let i = 0; i < ts.length - 1; i++) {
    for (let j = 0; j < segments; j++) {
      const a = i * segments + j, b = i * segments + ((j + 1) % segments), c = b + segments, d = a + segments;
      idx.push(a, b, c, a, c, d);
    }
  }
  const addCap = (ring, P, flip) => {
    const centre = pos.length / 3; pos.push(P.x, P.y, P.z); uv.push(0.5, flip ? 0 : 1);
    for (let j = 0; j < segments; j++) {
      const a = ring * segments + j, b = ring * segments + ((j + 1) % segments);
      if (flip) idx.push(centre, b, a); else idx.push(centre, a, b);
    }
  };
  if (capStart) addCap(0, rings[0].P, true);
  if (capEnd) addCap(ts.length - 1, rings[ts.length - 1].P, false);
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  return g;
}

// ---------- Checks ----------
// Triangle count, bounds, NaNs, degenerate triangles, and triangles whose winding
// disagrees with their vertex normals (inverted or badly shaded faces).
export function checkGeometry(name, g) {
  const p = g.attributes.position.array, n = g.attributes.normal.array, idx = g.index.array;
  let inverted = 0, degenerate = 0, nan = 0;
  for (let i = 0; i < p.length; i++) if (!Number.isFinite(p[i])) nan++;
  for (let t = 0; t < idx.length; t += 3) {
    const [a, b, c] = [idx[t] * 3, idx[t + 1] * 3, idx[t + 2] * 3];
    const e1 = [p[b] - p[a], p[b + 1] - p[a + 1], p[b + 2] - p[a + 2]];
    const e2 = [p[c] - p[a], p[c + 1] - p[a + 1], p[c + 2] - p[a + 2]];
    const fn = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
    const area = Math.hypot(...fn) / 2;
    if (area < 1e-10) { degenerate++; continue; }
    const vn = [n[a] + n[b] + n[c], n[a + 1] + n[b + 1] + n[c + 1], n[a + 2] + n[b + 2] + n[c + 2]];
    if (fn[0] * vn[0] + fn[1] * vn[1] + fn[2] * vn[2] <= 0) inverted++;
  }
  // Watertightness: weld by position, then every edge must be used by exactly two triangles.
  const key = (i) => [p[i * 3], p[i * 3 + 1], p[i * 3 + 2]].map((x) => Math.round(x * 1e5)).join(',');
  const weld = new Map(), id = [];
  for (let i = 0; i < p.length / 3; i++) { const k = key(i); if (!weld.has(k)) weld.set(k, weld.size); id.push(weld.get(k)); }
  const edges = new Map();
  for (let t = 0; t < idx.length; t += 3) {
    const v = [id[idx[t]], id[idx[t + 1]], id[idx[t + 2]]];
    if (v[0] === v[1] || v[1] === v[2] || v[0] === v[2]) continue;
    for (let e = 0; e < 3; e++) {
      const a = v[e], b = v[(e + 1) % 3], k = a < b ? a * 1e7 + b : b * 1e7 + a;
      edges.set(k, (edges.get(k) || 0) + 1);
    }
  }
  let open = 0, nonManifold = 0;
  for (const c of edges.values()) { if (c === 1) open++; else if (c > 2) nonManifold++; }
  g.computeBoundingBox();
  const bb = g.boundingBox;
  const r3 = (v) => [v.x, v.y, v.z].map((x) => +x.toFixed(4));
  return { name, tris: idx.length / 3, inverted, degenerate, nan, open, nonManifold, min: r3(bb.min), max: r3(bb.max) };
}

export function material(name, hex, roughness, metalness = 0) {
  return new THREE.MeshStandardMaterial({ name, color: new THREE.Color(hex), roughness, metalness });
}

// Merge parts per material into one mesh each, check, and export a binary glTF.
export async function exportGLB(groups, file, rootName) {
  const scene = new THREE.Scene();
  const root = new THREE.Group(); root.name = rootName; scene.add(root);
  const report = [];
  let total = 0;
  for (const { name, mat, parts } of groups) {
    const g = mergeGeometries(parts, false);
    if (!g) throw new Error(`merge failed for ${name}`);
    const r = checkGeometry(name, g); report.push(r); total += r.tris;
    const mesh = new THREE.Mesh(g, mat); mesh.name = name; root.add(mesh);
  }
  const box = new THREE.Box3().setFromObject(root);
  const glb = await new GLTFExporter().parseAsync(scene, { binary: true });
  fs.writeFileSync(file, Buffer.from(glb));
  const r3 = (v) => [v.x, v.y, v.z].map((x) => +x.toFixed(4));
  console.log(JSON.stringify({ file, total, min: r3(box.min), max: r3(box.max), parts: report }, null, 1));
  return { total, box };
}

// Generates golden fixtures from the ORIGINAL JavaScript implementation so the
// Dart domain port can be verified against it.
//   node tool/gen_parity_fixtures.js <legacy.html> <out.json>
const fs = require('fs');

const [, , htmlPath, outPath] = process.argv;
const lines = fs.readFileSync(htmlPath, 'utf8').split('\n');
// Lines 700-1289: Delaunay .. buildCivil3DScript (pure algorithm code, no DOM).
const src = lines.slice(699, 1289).join('\n');
const lib = new Function(
  `${src}; return { Delaunay, smoothContour, generateContours, getTerrainStats,
    generateSmartSummary, buildDXF, buildAutoLISP, buildCivil3DScript };`,
)();

function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const r2 = (v) => Math.round(v * 1000) / 1000;

function randomPoints(seed, n, size, zBase, zAmp) {
  const rnd = rng(seed);
  const pts = [];
  for (let i = 0; i < n; i++) {
    const x = r2(rnd() * size), y = r2(rnd() * size);
    const z = r2(zBase + zAmp * Math.sin(x / (size / 4)) * Math.cos(y / (size / 3)) + rnd());
    pts.push({ borehole: `BH${i + 1}`, x, y, z });
  }
  return pts;
}

const cases = [
  { name: 'small_random', points: randomPoints(1, 15, 100, 10, 4), breakLines: [], interval: 1, majorEvery: 5, smoothness: 0 },
  { name: 'negative_levels', points: randomPoints(2, 50, 500, 2, 8), breakLines: [], interval: 0.5, majorEvery: 4, smoothness: 0 },
  {
    name: 'breaklines_smooth',
    points: randomPoints(3, 36, 200, 50, 6),
    breakLines: [
      { name: 'BL-1', points: [{ x: 20, y: 20, z: 52 }, { x: 100, y: 60, z: 54 }, { x: 180, y: 90, z: 53 }] },
      { name: 'BL-2', points: [{ x: 100.0004, y: 60.0004, z: 99 }, { x: 150, y: 170, z: 51.25 }] },
    ],
    interval: 0.5, majorEvery: 4, smoothness: 3,
  },
  { name: 'smooth_small', points: randomPoints(4, 20, 100, 0, 3), breakLines: [], interval: 0.25, majorEvery: 4, smoothness: 1.5 },
];

function build(c) {
  // Mirrors App "Process data" effect (merge breakline points, triangulate).
  const allPts = [...c.points];
  for (const bl of c.breakLines) {
    for (const pt of bl.points) {
      const exists = allPts.some((p) => Math.abs(p.x - pt.x) < 0.001 && Math.abs(p.y - pt.y) < 0.001);
      if (!exists) allPts.push({ ...pt, borehole: bl.name });
    }
  }
  const tris = lib.Delaunay.triangulate(allPts);
  const contours = lib.generateContours(tris, c.interval, c.majorEvery, c.smoothness);
  const stats = lib.getTerrainStats(allPts, tris);
  const summary = lib.generateSmartSummary(stats, allPts, c.breakLines, contours);
  const lisp = lib.buildAutoLISP(contours, c.breakLines, c.points).split('\n');
  lisp[1] = '; Generated: <DATE>';
  return {
    ...c,
    allPointCount: allPts.length,
    triangles: tris.map((t) => [t.p1.idx, t.p2.idx, t.p3.idx]),
    contours: contours.map((k) => ({ level: k.level, isMajor: k.isMajor, points: k.points.map((p) => [p.x, p.y]) })),
    stats,
    summary,
    dxf: lib.buildDXF(contours, c.breakLines, c.points),
    lisp: lisp.join('\n'),
    civil3d: lib.buildCivil3DScript(contours, c.breakLines, c.points),
  };
}

// toFixed edge cases, to pin number formatting parity.
const toFixedCases = [0, -0, 0.0004, -0.0004, 1.005, 2.5, -2.5, 1234.5678, 0.0005, -0.0005, 1e-7, 99.9995, 12.345, 0.125, -1.45, 1e21]
  .map((v) => ({ v, f0: v.toFixed(0), f1: v.toFixed(1), f2: v.toFixed(2), f3: v.toFixed(3) }));

fs.writeFileSync(outPath, JSON.stringify({ cases: cases.map(build), toFixedCases }));
console.log('wrote', outPath, (fs.statSync(outPath).size / 1024).toFixed(0) + ' KB');

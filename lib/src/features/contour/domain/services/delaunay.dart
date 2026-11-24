import 'dart:math' as math;
import 'dart:typed_data';

import '../entities/geometry.dart';
import '../entities/triangle.dart';

/// Bowyer-Watson Delaunay triangulation.
///
/// Faithful port of the original implementation: same super-triangle, same
/// circumcircle tolerance and same iteration order, so the produced triangles
/// (and their order) match the web application.
///
/// The output is bit-for-bit identical to the straightforward O(n^2)
/// implementation (see `test/.../optimised_equivalence_test.dart`):
///  * the set of "bad" triangles of every inserted point is still decided by
///    the exact same floating-point determinant, evaluated in creation order;
///  * the shared-edge search is an edge-count map instead of an O(k^2) scan;
///  * triangles live in a struct-of-arrays store (no per-point allocation);
///  * a uniform grid over circumcircle bounding discs only decides *which*
///    triangles the determinant is evaluated for. A triangle is left out of a
///    query only when a rigorous floating-point error bound proves its
///    determinant cannot exceed the threshold (see [_Grid]); anything
///    ill-conditioned stays on an always-scanned list.
final class Delaunay {
  const Delaunay._();

  /// Determinant threshold above which a point is inside a circumcircle.
  static const double _epsilon = 1e-10;

  /// Below this many points the plain scan is as fast as the grid.
  static const int _gridMinPoints = 96;

  static List<Triangle> triangulate(List<SurveyPoint> points) =>
      _triangulate(points, verify: false);

  /// Same as [triangulate] but cross-checks, for every inserted point, the
  /// grid-pruned bad-triangle set against a full scan and throws a
  /// [StateError] on any difference. Used by tests and benchmarks only.
  static List<Triangle> triangulateVerified(List<SurveyPoint> points) =>
      _triangulate(points, verify: true);

  static List<Triangle> _triangulate(
    List<SurveyPoint> points, {
    required bool verify,
  }) {
    final n = points.length;
    if (n < 3) return const [];

    // Vertex coordinates; indices n..n+2 are the super-triangle corners.
    final xs = Float64List(n + 3);
    final ys = Float64List(n + 3);
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      xs[i] = points[i].x;
      ys[i] = points[i].y;
      minX = math.min(minX, xs[i]);
      maxX = math.max(maxX, xs[i]);
      minY = math.min(minY, ys[i]);
      maxY = math.max(maxY, ys[i]);
    }

    final dmax = math.max(maxX - minX, maxY - minY) * 3;
    final midX = (minX + maxX) / 2;
    final midY = (minY + maxY) / 2;
    xs[n] = midX - dmax * 2;
    ys[n] = midY - dmax;
    xs[n + 1] = midX + dmax * 2;
    ys[n + 1] = midY - dmax;
    xs[n + 2] = midX;
    ys[n + 2] = midY + dmax * 2;

    final mesh = _Mesh(xs, ys, n);
    final grid = n >= _gridMinPoints
        ? _Grid.tryCreate(mesh, minX, maxX, minY, maxY, n)
        : null;
    mesh.grid = grid;
    mesh.add(n, n + 1, n + 2);

    final bad = <int>[];
    final scratch = <int>[];
    final edgeCount = <int, int>{};
    final polyA = <int>[];
    final polyB = <int>[];
    final stride = n + 3;

    for (var p = 0; p < n; p++) {
      if (grid == null) {
        _collectBadAll(mesh, xs[p], ys[p], bad);
      } else {
        grid.collectBad(xs[p], ys[p], bad);
        if (verify) {
          _collectBadAll(mesh, xs[p], ys[p], scratch);
          if (!_sameIds(bad, scratch)) {
            throw StateError('grid pruning diverged at point $p');
          }
        }
      }
      _boundaryPolygon(mesh, bad, stride, edgeCount, polyA, polyB);
      for (var i = 0; i < bad.length; i++) {
        mesh.kill(bad[i]);
      }
      for (var i = 0; i < polyA.length; i++) {
        mesh.add(polyA[i], polyB[i], p);
      }
      if (grid == null) mesh.compactIfSparse();
    }

    final result = <Triangle>[];
    for (var id = 0; id < mesh.count; id++) {
      if (mesh.alive[id] == 0) continue;
      final a = mesh.a[id], b = mesh.b[id], c = mesh.c[id];
      if (a < n && b < n && c < n) {
        result.add(Triangle(points[a], points[b], points[c]));
      }
    }
    return result;
  }

  static bool _sameIds(List<int> x, List<int> y) {
    if (x.length != y.length) return false;
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }

  /// The original circumcircle test, character for character.
  static double _det(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    final ax = x1 - px, ay = y1 - py;
    final bx = x2 - px, by = y2 - py;
    final cx = x3 - px, cy = y3 - py;
    return (ax * ax + ay * ay) * (bx * cy - cx * by) -
        (bx * bx + by * by) * (ax * cy - cx * ay) +
        (cx * cx + cy * cy) * (ax * by - bx * ay);
  }

  /// Ids (ascending, i.e. list order) of live triangles whose circumcircle
  /// contains the point, by scanning every live triangle.
  static void _collectBadAll(_Mesh mesh, double px, double py, List<int> bad) {
    bad.clear();
    final alive = mesh.alive;
    final ta = mesh.a, tb = mesh.b, tc = mesh.c;
    final xs = mesh.xs, ys = mesh.ys;
    final count = mesh.count;
    for (var id = 0; id < count; id++) {
      if (alive[id] == 0) continue;
      final ia = ta[id], ib = tb[id], ic = tc[id];
      final det = _det(px, py, xs[ia], ys[ia], xs[ib], ys[ib], xs[ic], ys[ic]);
      if (det > _epsilon) bad.add(id);
    }
  }

  /// Boundary edges of the cavity formed by [bad], in the same order as the
  /// original nested scan: bad triangles in list order, edges (a,b),(b,c),(c,a);
  /// an edge is dropped when any other bad triangle has the same undirected
  /// edge. A triangle never repeats an edge, so "shared" == "counted twice".
  static void _boundaryPolygon(
    _Mesh mesh,
    List<int> bad,
    int stride,
    Map<int, int> edgeCount,
    List<int> polyA,
    List<int> polyB,
  ) {
    polyA.clear();
    polyB.clear();
    if (bad.isEmpty) return;
    edgeCount.clear();
    for (final id in bad) {
      final a = mesh.a[id], b = mesh.b[id], c = mesh.c[id];
      _bump(edgeCount, a, b, stride);
      _bump(edgeCount, b, c, stride);
      _bump(edgeCount, c, a, stride);
    }
    for (final id in bad) {
      final a = mesh.a[id], b = mesh.b[id], c = mesh.c[id];
      _emitIfUnshared(edgeCount, a, b, stride, polyA, polyB);
      _emitIfUnshared(edgeCount, b, c, stride, polyA, polyB);
      _emitIfUnshared(edgeCount, c, a, stride, polyA, polyB);
    }
  }

  static int _key(int u, int v, int stride) =>
      u < v ? u * stride + v : v * stride + u;

  static void _bump(Map<int, int> counts, int u, int v, int stride) {
    final key = _key(u, v, stride);
    counts[key] = (counts[key] ?? 0) + 1;
  }

  static void _emitIfUnshared(
    Map<int, int> counts,
    int u,
    int v,
    int stride,
    List<int> polyA,
    List<int> polyB,
  ) {
    if (counts[_key(u, v, stride)] == 1) {
      polyA.add(u);
      polyB.add(v);
    }
  }
}

/// Struct-of-arrays triangle store. Ids are assigned in creation order and the
/// live ids in ascending order are exactly the triangle list order of the
/// original algorithm (survivors keep their relative order, new triangles are
/// appended).
final class _Mesh {
  _Mesh(this.xs, this.ys, this.realCount);

  final Float64List xs;
  final Float64List ys;

  /// Vertices with an index below this are survey points (not super-triangle).
  final int realCount;
  _Grid? grid;

  Int32List a = Int32List(256);
  Int32List b = Int32List(256);
  Int32List c = Int32List(256);
  Uint8List alive = Uint8List(256);
  int count = 0;
  int _dead = 0;

  void add(int va, int vb, int vc) {
    if (count == a.length) _grow();
    final id = count;
    a[id] = va;
    b[id] = vb;
    c[id] = vc;
    alive[id] = 1;
    count++;
    grid?.register(id, va, vb, vc);
  }

  void kill(int id) {
    alive[id] = 0;
    _dead++;
  }

  void _grow() {
    final size = a.length * 2;
    a = Int32List(size)..setRange(0, count, a);
    b = Int32List(size)..setRange(0, count, b);
    c = Int32List(size)..setRange(0, count, c);
    alive = Uint8List(size)..setRange(0, count, alive);
  }

  /// Drops dead slots once they outnumber the live ones (stable: keeps order).
  /// Only used without a grid (the grid stores ids).
  void compactIfSparse() {
    if (_dead < 1024 || _dead * 2 < count) return;
    var out = 0;
    for (var id = 0; id < count; id++) {
      if (alive[id] == 0) continue;
      a[out] = a[id];
      b[out] = b[id];
      c[out] = c[id];
      alive[out] = 1;
      out++;
    }
    alive.fillRange(out, count, 0);
    count = out;
    _dead = 0;
  }
}

/// Uniform grid over the circumcircle discs of well-conditioned triangles.
///
/// Why pruning with it cannot change the result. For a triangle with
/// counter-clockwise orientation `K` (twice its area), circumcentre `O` and
/// circumradius `R`, the exact incircle determinant of a point `p` at distance
/// `d` from `O` is `K * (R^2 - d^2)`. The determinant computed by
/// [Delaunay._det] differs from it by at most `E <= c * perm` with
/// `perm <= 6 * (R + d)^4` and `c = 1e-12` (about 500 times the textbook
/// bound of 2e-15, so the argument does not hinge on the exact constant).
/// With `p` inside the data bounding box, `d <= dMax` and therefore
/// `E <= 6e-12 * (R + dMax)^4`. For `d >= rho` where
/// `rho^2 >= R^2 + E(dMax) / K` this gives `K * (d^2 - R^2) >= E`, i.e. the
/// computed determinant is `<= 0 < 1e-10` and the triangle can never be "bad".
/// Such a triangle is stored in the cells overlapped by the bounding box of
/// its disc of radius `rho`; a query only looks at the cell of `p`.
/// Everything the bound does not cover (super-triangle vertices, clockwise or
/// nearly degenerate triangles, huge discs, non-finite data) goes to the
/// always-scanned [_global] list, where the exact test decides.
final class _Grid {
  _Grid._(
    this._mesh,
    this._minX,
    this._minY,
    this._cell,
    this._w,
    this._h,
    this._maxX,
    this._maxY,
  ) : _cells = List<List<int>?>.filled(_w * _h, null);

  static const double _slack = 1e-6;
  static const int _maxCells = 64;

  final _Mesh _mesh;
  final double _minX;
  final double _minY;
  final double _maxX;
  final double _maxY;
  final double _cell;
  final int _w;
  final int _h;
  final List<List<int>?> _cells;
  final List<int> _global = [];

  /// Null when the data cannot be gridded safely (non-finite or degenerate).
  static _Grid? tryCreate(
    _Mesh mesh,
    double minX,
    double maxX,
    double minY,
    double maxY,
    int n,
  ) {
    if (!(minX.isFinite && maxX.isFinite && minY.isFinite && maxY.isFinite)) {
      return null;
    }
    final wx = maxX - minX, wy = maxY - minY;
    if (!(wx.isFinite && wy.isFinite) || (wx == 0 && wy == 0)) return null;
    final area = wx * wy;
    final longest = math.max(wx, wy);
    final cell = math.max(math.sqrt(2 * area / n), longest / (2 * n));
    if (!(cell > 0) || !cell.isFinite) return null;
    final w = (wx / cell).floor() + 1;
    final h = (wy / cell).floor() + 1;
    if (w * h > 8 * n + 16) return null;
    return _Grid._(mesh, minX, minY, cell, w, h, maxX, maxY);
  }

  int _cx(double x) {
    final i = ((x - _minX) / _cell).floor();
    return i < 0 ? 0 : (i >= _w ? _w - 1 : i);
  }

  int _cy(double y) {
    final i = ((y - _minY) / _cell).floor();
    return i < 0 ? 0 : (i >= _h ? _h - 1 : i);
  }

  /// Files a new triangle either in the grid or on the always-scanned list.
  void register(int id, int va, int vb, int vc) {
    if (!_tryRegisterInGrid(id, va, vb, vc)) _global.add(id);
  }

  bool _tryRegisterInGrid(int id, int va, int vb, int vc) {
    final n = _mesh.realCount;
    if (va >= n || vb >= n || vc >= n) return false;
    final xs = _mesh.xs, ys = _mesh.ys;
    final ax = xs[va], ay = ys[va];
    final ux = xs[vb] - ax, uy = ys[vb] - ay;
    final vx = xs[vc] - ax, vy = ys[vc] - ay;
    final k = ux * vy - uy * vx;
    final perm = (ux * vy).abs() + (uy * vx).abs();
    // Counter-clockwise and not nearly degenerate (orientation is reliable).
    if (!(k > 0 && k > 1e-6 * perm)) return false;
    final lu = ux * ux + uy * uy;
    final lv = vx * vx + vy * vy;
    final d = 2 * k;
    final ox = (vy * lu - uy * lv) / d;
    final oy = (ux * lv - vx * lu) / d;
    final r = math.sqrt(ox * ox + oy * oy);
    final cx = ax + ox, cy = ay + oy;
    if (!(cx.isFinite && cy.isFinite && r.isFinite)) return false;

    // Farthest any query point (inside the data box) can be from the centre.
    final dx = math.max((cx - _minX).abs(), (cx - _maxX).abs());
    final dy = math.max((cy - _minY).abs(), (cy - _maxY).abs());
    final dMax = math.sqrt(dx * dx + dy * dy) * (1 + _slack);
    final rm = r * (1 + _slack);
    final reach = rm + dMax;
    final err = 6e-12 * reach * reach * reach * reach;
    final margin = err / (k * (1 - _slack));
    final rho = (rm + math.sqrt(margin)) * (1 + _slack) +
        1e-9 * (cx.abs() + cy.abs()) +
        1e-12;
    if (!rho.isFinite) return false;

    final x0 = _cx(cx - rho), x1 = _cx(cx + rho);
    final y0 = _cy(cy - rho), y1 = _cy(cy + rho);
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > _maxCells) return false;
    for (var gy = y0; gy <= y1; gy++) {
      final row = gy * _w;
      for (var gx = x0; gx <= x1; gx++) {
        (_cells[row + gx] ??= <int>[]).add(id);
      }
    }
    return true;
  }

  /// Bad triangle ids for point (px, py), ascending (list order).
  void collectBad(double px, double py, List<int> bad) {
    bad.clear();
    final mesh = _mesh;
    final alive = mesh.alive;
    final ta = mesh.a, tb = mesh.b, tc = mesh.c;
    final xs = mesh.xs, ys = mesh.ys;

    // Grid candidates (ascending), dropping dead ids on the way.
    final index = _cy(py) * _w + _cx(px);
    final cell = _cells[index];
    var g = 0;
    var gOut = 0;
    final cellIds = cell ?? const <int>[];
    // Global candidates (ascending).
    var q = 0;
    var qOut = 0;
    final global = _global;

    // Merge the two ascending id streams so that `bad` stays ascending.
    final cellLen = cellIds.length;
    final globalLen = global.length;
    while (true) {
      while (g < cellLen && alive[cellIds[g]] == 0) {
        g++;
      }
      while (q < globalLen && alive[global[q]] == 0) {
        q++;
      }
      final hasCell = g < cellLen;
      final hasGlobal = q < globalLen;
      if (!hasCell && !hasGlobal) break;
      final int id;
      if (hasCell && (!hasGlobal || cellIds[g] < global[q])) {
        id = cellIds[g++];
        cell![gOut++] = id;
      } else {
        id = global[q++];
        global[qOut++] = id;
      }
      final ia = ta[id], ib = tb[id], ic = tc[id];
      final det = Delaunay._det(
        px,
        py,
        xs[ia],
        ys[ia],
        xs[ib],
        ys[ib],
        xs[ic],
        ys[ic],
      );
      if (det > Delaunay._epsilon) bad.add(id);
    }
    if (cell != null) cell.length = gOut;
    global.length = qOut;
  }
}

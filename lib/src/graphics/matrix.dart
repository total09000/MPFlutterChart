// Android shim: android.graphics.Matrix (3x3) for MPAndroidChart v4.0.1 port
import 'dart:typed_data';

import 'mutable_rect.dart';

/// A 3×3 transformation matrix with the semantics of `android.graphics.Matrix`.
///
/// The nine values are stored row-major in Android order: [MSCALE_X], [MSKEW_X], [MTRANS_X],
/// [MSKEW_Y], [MSCALE_Y], [MTRANS_Y], [MPERSP_0], [MPERSP_1], [MPERSP_2]. A point `(x, y)` is mapped
/// as the column vector `(x, y, 1)`.
///
/// The `post*` operations replace this matrix with `M × this` (M is applied after the current
/// transform); the `pre*` operations replace it with `this × M` (M is applied before it).
class Matrix {
  static const int MSCALE_X = 0;
  static const int MSKEW_X = 1;
  static const int MTRANS_X = 2;
  static const int MSKEW_Y = 3;
  static const int MSCALE_Y = 4;
  static const int MTRANS_Y = 5;
  static const int MPERSP_0 = 6;
  static const int MPERSP_1 = 7;
  static const int MPERSP_2 = 8;

  /// The nine matrix values in Android order.
  final Float64List values = Float64List(9);

  /// Scratch storage for products, so concatenation does not allocate.
  final Float64List _tmp = Float64List(9);

  /// Creates an identity matrix.
  Matrix() {
    reset();
  }

  /// Sets this matrix to identity.
  void reset() {
    values.fillRange(0, 9, 0.0);
    values[MSCALE_X] = 1.0;
    values[MSCALE_Y] = 1.0;
    values[MPERSP_2] = 1.0;
  }

  /// Copies the values of [other] into this matrix.
  void set(Matrix other) {
    values.setAll(0, other.values);
  }

  /// Copies the nine matrix values into the first nine slots of [out].
  void getValues(List<double> out) {
    for (int i = 0; i < 9; i++) {
      out[i] = values[i];
    }
  }

  /// Copies the first nine values of [v] into this matrix.
  void setValues(List<double> v) {
    for (int i = 0; i < 9; i++) {
      values[i] = v[i];
    }
  }

  /// Sets this matrix to scale by [sx] and [sy] around the pivot ([px], [py]).
  ///
  /// Without a pivot (both omitted or null; Android `setScale(sx, sy)`) the translation is exactly 0, as in Skia's
  /// `setScaleTranslate(sx, sy, 0, 0)`. With a pivot it is `px - sx * px`, so an infinite factor with a 0 pivot gives
  /// NaN there, as on Android. A single null pivot coordinate counts as 0.
  void setScale(double sx, double sy, [double? px, double? py]) {
    if (px == null && py == null) {
      _setRaw(sx, 0, 0, 0, sy, 0, 0, 0, 1);
      return;
    }
    final x = px ?? 0, y = py ?? 0;
    _setRaw(sx, 0, x - sx * x, 0, sy, y - sy * y, 0, 0, 1);
  }

  /// Sets this matrix to translate by [dx] and [dy].
  void setTranslate(double dx, double dy) {
    _setRaw(1, 0, dx, 0, 1, dy, 0, 0, 1);
  }

  /// Post-concatenates a scale by [sx] and [sy] around the pivot ([px], [py]): `this = S(sx, sy, px, py) × this`.
  ///
  /// The scale matrix is built like [setScale] (no pivot term when both pivot coordinates are omitted). As in Skia's
  /// `SkMatrix::postScale`, a scale of (1, 1) is a no-op and an identity matrix simply becomes the scale matrix, so
  /// a pivot-less infinite factor on an identity matrix keeps translation 0 instead of `infinity * 0 = NaN`.
  bool postScale(double sx, double sy, [double? px, double? py]) {
    if (sx == 1 && sy == 1) return true;
    final double tx, ty;
    if (px == null && py == null) {
      tx = 0;
      ty = 0;
    } else {
      final x = px ?? 0, y = py ?? 0;
      tx = x - sx * x;
      ty = y - sy * y;
    }
    if (_isIdentity()) {
      _setRaw(sx, 0, tx, 0, sy, ty, 0, 0, 1);
    } else {
      _postConcatRaw(sx, 0, tx, 0, sy, ty, 0, 0, 1);
    }
    return true;
  }

  /// Post-concatenates a translation by [dx] and [dy]: `this = T(dx, dy) × this`.
  bool postTranslate(double dx, double dy) {
    _postConcatRaw(1, 0, dx, 0, 1, dy, 0, 0, 1);
    return true;
  }

  /// Pre-concatenates [other]: `this = this × other`.
  bool preConcat(Matrix other) {
    _multiply(values, other.values, _tmp);
    values.setAll(0, _tmp);
    return true;
  }

  /// Post-concatenates [other]: `this = other × this`.
  bool postConcat(Matrix other) {
    _multiply(other.values, values, _tmp);
    values.setAll(0, _tmp);
    return true;
  }

  /// Writes the inverse of this matrix into [out] (which may be this matrix).
  ///
  /// Returns false and leaves [out] unchanged if the matrix is not invertible (determinant 0, or an inverse that is
  /// not finite).
  bool invert(Matrix out) {
    final m = values;
    final a = m[0], b = m[1], c = m[2];
    final d = m[3], e = m[4], f = m[5];
    final g = m[6], h = m[7], i = m[8];

    final c00 = e * i - f * h;
    final c01 = c * h - b * i;
    final c02 = b * f - c * e;
    final c10 = f * g - d * i;
    final c11 = a * i - c * g;
    final c12 = c * d - a * f;
    final c20 = d * h - e * g;
    final c21 = b * g - a * h;
    final c22 = a * e - b * d;

    final det = a * c00 + b * c10 + c * c20;
    if (det == 0) return false;
    final invDet = 1.0 / det;

    final t = _tmp;
    t[0] = c00 * invDet;
    t[1] = c01 * invDet;
    t[2] = c02 * invDet;
    t[3] = c10 * invDet;
    t[4] = c11 * invDet;
    t[5] = c12 * invDet;
    t[6] = c20 * invDet;
    t[7] = c21 * invDet;
    t[8] = c22 * invDet;
    for (int k = 0; k < 9; k++) {
      if (!t[k].isFinite) return false;
    }
    out.values.setAll(0, t);
    return true;
  }

  /// Maps x, y pairs through this matrix.
  ///
  /// With only [dst], every pair in [dst] is mapped in place (Android `mapPoints(float[] pts)`). With the optional
  /// arguments this is Android `mapPoints(dst, dstIndex, src, srcIndex, pointCount)`: [pointCount] pairs are read
  /// from [src] (default [dst]) starting at [srcIndex] and written to [dst] starting at [dstIndex]; the rest of [dst]
  /// is left untouched.
  void mapPoints(
    Float32List dst, [
    int dstIndex = 0,
    Float32List? src,
    int srcIndex = 0,
    int? pointCount,
  ]) {
    final s = src ?? dst;
    final count = pointCount ?? (s.length - srcIndex) ~/ 2;
    final m = values;
    final sx = m[MSCALE_X], kx = m[MSKEW_X], tx = m[MTRANS_X];
    final ky = m[MSKEW_Y], sy = m[MSCALE_Y], ty = m[MTRANS_Y];
    final p0 = m[MPERSP_0], p1 = m[MPERSP_1], p2 = m[MPERSP_2];
    final hasPersp = p0 != 0 || p1 != 0 || p2 != 1;
    // SkMatrix::mapPoints picks its routine by type mask: without skew and perspective x and y are mapped
    // independently, so a non-finite x never turns y into NaN through a zero skew (0 * inf).
    if (!hasPersp && kx == 0 && ky == 0) {
      for (int n = 0; n < count; n++) {
        final x = s[srcIndex + 2 * n];
        final y = s[srcIndex + 2 * n + 1];
        dst[dstIndex + 2 * n] = sx * x + tx;
        dst[dstIndex + 2 * n + 1] = sy * y + ty;
      }
      return;
    }
    for (int n = 0; n < count; n++) {
      final x = s[srcIndex + 2 * n];
      final y = s[srcIndex + 2 * n + 1];
      double nx = sx * x + kx * y + tx;
      double ny = ky * x + sy * y + ty;
      if (hasPersp) {
        final w = 1.0 / (p0 * x + p1 * y + p2);
        nx *= w;
        ny *= w;
      }
      dst[dstIndex + 2 * n] = nx;
      dst[dstIndex + 2 * n + 1] = ny;
    }
  }

  /// Maps [rect] through this matrix in place; the result is the bounding box of the four mapped corners.
  void mapRect(MutableRect rect) {
    final m = values;
    final p0 = m[MPERSP_0], p1 = m[MPERSP_1], p2 = m[MPERSP_2];
    final hasPersp = p0 != 0 || p1 != 0 || p2 != 1;
    // As in mapPoints: without skew and perspective the edges map independently (SkMatrix::mapRect).
    if (!hasPersp && m[MSKEW_X] == 0 && m[MSKEW_Y] == 0) {
      final sx = m[MSCALE_X], tx = m[MTRANS_X];
      final sy = m[MSCALE_Y], ty = m[MTRANS_Y];
      final x0 = sx * rect.left + tx, x1 = sx * rect.right + tx;
      final y0 = sy * rect.top + ty, y1 = sy * rect.bottom + ty;
      // SkRect::sort: swap only when left > right (top > bottom).
      rect.set(
        x0 > x1 ? x1 : x0,
        y0 > y1 ? y1 : y0,
        x0 > x1 ? x0 : x1,
        y0 > y1 ? y0 : y1,
      );
      return;
    }
    double minX = 0, minY = 0, maxX = 0, maxY = 0;
    for (int corner = 0; corner < 4; corner++) {
      final x = corner & 1 == 0 ? rect.left : rect.right;
      final y = corner & 2 == 0 ? rect.top : rect.bottom;
      double nx = m[MSCALE_X] * x + m[MSKEW_X] * y + m[MTRANS_X];
      double ny = m[MSKEW_Y] * x + m[MSCALE_Y] * y + m[MTRANS_Y];
      if (hasPersp) {
        final w = 1.0 / (p0 * x + p1 * y + p2);
        nx *= w;
        ny *= w;
      }
      if (corner == 0) {
        minX = maxX = nx;
        minY = maxY = ny;
      } else {
        if (nx < minX) minX = nx;
        if (nx > maxX) maxX = nx;
        if (ny < minY) minY = ny;
        if (ny > maxY) maxY = ny;
      }
    }
    rect.set(minX, minY, maxX, maxY);
  }

  /// Returns a new column-major 4×4 matrix storage equivalent to this 3×3 matrix, for `ui.Path.transform` and
  /// `ui.Canvas.transform`.
  ///
  /// The 3×3 acts on `(x, y, 1)`; the 4×4 acts on `(x, y, z, 1)` with z passed through unchanged, so the third row
  /// and column are those of the identity and the translation and perspective values move to the fourth.
  Float64List toMatrix4Storage() {
    final m = values;
    final s = Float64List(16);
    // Column 0.
    s[0] = m[MSCALE_X];
    s[1] = m[MSKEW_Y];
    s[3] = m[MPERSP_0];
    // Column 1.
    s[4] = m[MSKEW_X];
    s[5] = m[MSCALE_Y];
    s[7] = m[MPERSP_1];
    // Column 2 (z).
    s[10] = 1;
    // Column 3.
    s[12] = m[MTRANS_X];
    s[13] = m[MTRANS_Y];
    s[15] = m[MPERSP_2];
    return s;
  }

  bool _isIdentity() {
    final m = values;
    return m[0] == 1 &&
        m[1] == 0 &&
        m[2] == 0 &&
        m[3] == 0 &&
        m[4] == 1 &&
        m[5] == 0 &&
        m[6] == 0 &&
        m[7] == 0 &&
        m[8] == 1;
  }

  void _setRaw(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
    double g,
    double h,
    double i,
  ) {
    final m = values;
    m[0] = a;
    m[1] = b;
    m[2] = c;
    m[3] = d;
    m[4] = e;
    m[5] = f;
    m[6] = g;
    m[7] = h;
    m[8] = i;
  }

  /// `this = M × this` for M given by its nine values.
  void _postConcatRaw(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
    double g,
    double h,
    double i,
  ) {
    final m = values;
    final t = _tmp;
    for (int col = 0; col < 3; col++) {
      final m0 = m[col], m1 = m[3 + col], m2 = m[6 + col];
      t[col] = a * m0 + b * m1 + c * m2;
      t[3 + col] = d * m0 + e * m1 + f * m2;
      t[6 + col] = g * m0 + h * m1 + i * m2;
    }
    m.setAll(0, t);
  }

  /// `out = a × b` for row-major 3×3 matrices; [out] must not alias [a] or [b].
  static void _multiply(Float64List a, Float64List b, Float64List out) {
    for (int row = 0; row < 3; row++) {
      final r0 = a[3 * row], r1 = a[3 * row + 1], r2 = a[3 * row + 2];
      for (int col = 0; col < 3; col++) {
        out[3 * row + col] = r0 * b[col] + r1 * b[3 + col] + r2 * b[6 + col];
      }
    }
  }
}

// Tests for the android.graphics.Matrix shim; no Kotlin counterpart.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/matrix.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';

Float32List _map(Matrix m, double x, double y) {
  final pts = Float32List.fromList([x, y]);
  m.mapPoints(pts);
  return pts;
}

void main() {
  group('Matrix', () {
    test('new matrix is identity', () {
      final v = Float64List(9);
      Matrix().getValues(v);
      expect(v, [1, 0, 0, 0, 1, 0, 0, 0, 1]);
    });

    test('value index constants follow Android order', () {
      expect(Matrix.MSCALE_X, 0);
      expect(Matrix.MSKEW_X, 1);
      expect(Matrix.MTRANS_X, 2);
      expect(Matrix.MSKEW_Y, 3);
      expect(Matrix.MSCALE_Y, 4);
      expect(Matrix.MTRANS_Y, 5);
      expect(Matrix.MPERSP_0, 6);
      expect(Matrix.MPERSP_1, 7);
      expect(Matrix.MPERSP_2, 8);
    });

    test('postScale then mapPoints scales', () {
      final m = Matrix();
      expect(m.postScale(2, 3), isTrue);
      expect(_map(m, 1, 1), [2, 3]);
    });

    test('postTranslate is applied after the existing scale', () {
      final m = Matrix()..postScale(2, 3);
      expect(m.postTranslate(5, -5), isTrue);
      expect(_map(m, 1, 1), [7, -2]);
    });

    test('postScale with pivot keeps the pivot fixed', () {
      final m = Matrix()..postScale(2, 2, 10, 10);
      expect(_map(m, 10, 10), [10, 10]);
      expect(_map(m, 0, 0), [-10, -10]);
    });

    test('setScale replaces the matrix, with and without pivot', () {
      final m = Matrix()..postTranslate(100, 100);
      m.setScale(2, 3);
      expect(_map(m, 1, 1), [2, 3]);
      m.setScale(2, 2, 10, 10);
      expect(_map(m, 10, 10), [10, 10]);
      expect(_map(m, 0, 0), [-10, -10]);
    });

    test(
      'pivot-less setScale/postScale keep translation 0 for an infinite factor',
      () {
        // Android's pivot-less forms build a pure scale (Skia setScaleTranslate(sx, sy, 0, 0)); the pivot term
        // px - sx * px would give infinity * 0 = NaN.
        final v = Float64List(9);
        (Matrix()..setScale(double.infinity, 1)).getValues(v);
        expect(v[Matrix.MSCALE_X], double.infinity);
        expect(v[Matrix.MTRANS_X], 0);
        expect(v[Matrix.MTRANS_Y], 0);
        final m = Matrix();
        expect(m.postScale(double.infinity, 1), isTrue);
        m.getValues(v);
        expect(v[Matrix.MSCALE_X], double.infinity);
        expect(v[Matrix.MTRANS_X], 0);
        expect(v[Matrix.MTRANS_Y], 0);
      },
    );

    test('explicit pivot keeps the pivot term, as Android does', () {
      final v = Float64List(9);
      (Matrix()..setScale(double.infinity, 1, 0, 0)).getValues(v);
      expect(v[Matrix.MTRANS_X], isNaN);
    });

    test('postScale on a non-identity matrix still concatenates', () {
      final m = Matrix()
        ..setTranslate(3, 4)
        ..postScale(2, 5);
      expect(_map(m, 1, 1), [8, 25]);
    });

    test('postScale(1, 1) leaves the matrix unchanged', () {
      final m = Matrix()..setTranslate(3, 4);
      m.postScale(1, 1, 7, 9);
      final v = Float64List(9);
      m.getValues(v);
      expect(v, [1, 0, 3, 0, 1, 4, 0, 0, 1]);
    });

    test('setTranslate replaces the matrix', () {
      final m = Matrix()..postScale(5, 5);
      m.setTranslate(3, -4);
      expect(_map(m, 1, 1), [4, -3]);
    });

    test('preConcat and postConcat multiply on opposite sides', () {
      final t = Matrix()..setTranslate(5, 0);
      final pre = Matrix()..setScale(2, 2);
      expect(pre.preConcat(t), isTrue); // this × T: translate first, then scale
      expect(_map(pre, 1, 0)[0], 12);
      final post = Matrix()..setScale(2, 2);
      expect(
        post.postConcat(t),
        isTrue,
      ); // T × this: scale first, then translate
      expect(_map(post, 1, 0)[0], 7);
    });

    test('invert then mapPoints returns to the original point', () {
      final m = Matrix()
        ..postScale(2, 3)
        ..postTranslate(5, -5);
      final inv = Matrix();
      expect(m.invert(inv), isTrue);
      final pts = Float32List.fromList([1, 1]);
      m.mapPoints(pts);
      inv.mapPoints(pts);
      expect(pts[0], closeTo(1, 1e-9));
      expect(pts[1], closeTo(1, 1e-9));
    });

    test(
      'invert of a singular matrix returns false and leaves out unchanged',
      () {
        final m = Matrix()..setScale(0, 2);
        final out = Matrix()..setTranslate(7, 8);
        expect(m.invert(out), isFalse);
        final v = Float64List(9);
        out.getValues(v);
        expect(v, [1, 0, 7, 0, 1, 8, 0, 0, 1]);
      },
    );

    test('invert may write into the matrix itself', () {
      final m = Matrix()
        ..postScale(2, 4)
        ..postTranslate(6, 8);
      expect(m.invert(m), isTrue);
      expect(_map(m, 8, 12), [1, 1]);
    });

    test('mapRect of a rotated matrix gives the bounding box', () {
      const a = math.pi / 4;
      final c = math.cos(a), s = math.sin(a);
      final m = Matrix()
        ..setValues(Float64List.fromList([c, -s, 0, s, c, 0, 0, 0, 1]));
      final r = MutableRect(0, 0, 2, 2);
      m.mapRect(r);
      final h = math.sqrt2; // half the diagonal
      expect(r.left, closeTo(-h, 1e-9));
      expect(r.top, closeTo(0, 1e-9));
      expect(r.right, closeTo(h, 1e-9));
      expect(r.bottom, closeTo(2 * h, 1e-9));
    });

    test('mapRect sorts the result when the matrix flips an axis', () {
      final m = Matrix()..postScale(1, -1);
      final r = MutableRect(1, 2, 3, 4);
      m.mapRect(r);
      expect([r.left, r.top, r.right, r.bottom], [1, -4, 3, -2]);
    });

    test('getValues/setValues round-trip', () {
      final src = Float64List.fromList([1.5, 0.25, -3, 0.5, 2.5, 7, 0, 0, 1]);
      final m = Matrix()..setValues(src);
      final out = Float64List(9);
      m.getValues(out);
      expect(out, src);
    });

    test('getValues/setValues accept Float32List buffers', () {
      final m = Matrix()
        ..postScale(2, 3)
        ..postTranslate(5, -5);
      final vals = Float32List(9);
      m.getValues(vals);
      expect(vals[Matrix.MSCALE_X], 2);
      expect(vals[Matrix.MSCALE_Y], 3);
      expect(vals[Matrix.MTRANS_X], 5);
      expect(vals[Matrix.MTRANS_Y], -5);
      vals[Matrix.MTRANS_X] = 0;
      m.setValues(vals);
      expect(_map(m, 1, 1), [2, -2]);
    });

    test('set copies without aliasing; reset restores identity', () {
      final a = Matrix()..postScale(2, 2);
      final b = Matrix()..set(a);
      a.postTranslate(10, 10);
      expect(_map(b, 1, 1), [2, 2]);
      b.reset();
      expect(_map(b, 3, 4), [3, 4]);
    });

    test(
      'mapPoints with range maps only pointCount pairs and leaves the tail',
      () {
        final m = Matrix()..postScale(2, 2);
        final pts = Float32List.fromList([1, 1, 2, 2, 3, 3]);
        m.mapPoints(pts, 0, pts, 0, 2);
        expect(pts, [2, 2, 4, 4, 3, 3]);
      },
    );

    test('mapPoints with range honours src and dst offsets', () {
      final m = Matrix()..postTranslate(1, 1);
      final src = Float32List.fromList([9, 9, 1, 2, 3, 4]);
      final dst = Float32List(5);
      m.mapPoints(dst, 1, src, 2, 2);
      expect(dst, [0, 2, 3, 4, 5]);
    });

    // SkMatrix::mapPoints picks its routine by type mask: a matrix without skew or perspective maps x and y
    // independently, so a non-finite x never reaches y (0 * inf would be NaN). YAxisRenderer relies on it: it
    // maps a reused buffer whose x slots it never resets, and on Android they grow to infinity harmlessly.
    test('mapPoints of a scale and translate matrix keeps a non-finite x out of y', () {
      final m = Matrix()
        ..postScale(2, 3)
        ..postTranslate(5, 7);
      final inf = _map(m, double.infinity, 1);
      expect(inf[0], double.infinity);
      expect(inf[1], 10);
      final nan = _map(m, 1, double.nan);
      expect(nan[0], 7);
      expect(nan[1].isNaN, isTrue);
    });

    test('mapPoints of a skewed matrix still mixes x into y', () {
      final m = Matrix()..setValues(Float64List.fromList([1, 2, 0, 3, 1, 0, 0, 0, 1]));
      expect(_map(m, 1, 1), [3, 4]);
    });

    test('mapRect of a scale and translate matrix keeps a non-finite x out of y', () {
      final m = Matrix()
        ..postScale(2, 3)
        ..postTranslate(5, 7);
      final r = MutableRect(double.negativeInfinity, 1, 0, 2);
      m.mapRect(r);
      expect(r.left, double.negativeInfinity);
      expect(r.right, 5);
      expect(r.top, 10);
      expect(r.bottom, 13);
    });

    test('mapPoints divides by w for a perspective matrix', () {
      final m = Matrix()
        ..setValues(Float64List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 2]));
      expect(_map(m, 4, 6), [2, 3]);
    });

    test('toMatrix4Storage lays the 3x3 out column-major in a 4x4', () {
      final m = Matrix()
        ..setValues(Float64List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]));
      expect(m.toMatrix4Storage(), [
        1, 4, 0, 7, //
        2, 5, 0, 8, //
        0, 0, 1, 0, //
        3, 6, 0, 9, //
      ]);
    });

    test('toMatrix4Storage returns a fresh list', () {
      final m = Matrix();
      final a = m.toMatrix4Storage();
      a[0] = 42;
      expect(m.toMatrix4Storage()[0], 1);
      expect(m.values[Matrix.MSCALE_X], 1);
    });

    test('Path.transform with toMatrix4Storage matches mapRect', () {
      final m = Matrix()
        ..postScale(2, -3)
        ..postTranslate(10, 20);
      final path = ui.Path()..addRect(const ui.Rect.fromLTRB(1, 2, 5, 7));
      final bounds = path.transform(m.toMatrix4Storage()).getBounds();
      final r = MutableRect(1, 2, 5, 7);
      m.mapRect(r);
      expect(bounds.left, closeTo(r.left, 1e-4));
      expect(bounds.top, closeTo(r.top, 1e-4));
      expect(bounds.right, closeTo(r.right, 1e-4));
      expect(bounds.bottom, closeTo(r.bottom, 1e-4));
      // (12, -1, 20, 14): scale then translate, y flipped.
      expect(
        [bounds.left, bounds.top, bounds.right, bounds.bottom],
        [12, -1, 20, 14],
      );
    });
  });
}

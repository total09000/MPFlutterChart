// Tests for the Transformer port (MPAndroidChart v4.0.1 utils/Transformer.kt); no Kotlin counterpart.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/matrix.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/utils/chart_invalidator.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_d.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

class _NoopInvalidator implements ChartInvalidator {
  @override
  void invalidate() {}
}

/// A 400x300 chart with offsets (10, 20, 30, 40): content rect (10, 20, 370, 260), 360x240.
ViewPortHandler _handler() => ViewPortHandler()
  ..setChartDimens(400, 300)
  ..restrainViewPort(10, 20, 30, 40);

/// x in [0, 10] and y in [0, 100] spread over the content rect.
Transformer _transformer(ViewPortHandler h, {bool inverted = false}) =>
    Transformer(h)
      ..prepareMatrixValuePx(0, 10, 100, 0)
      ..prepareMatrixOffset(inverted);

void _expectPoint(MPPointD p, double x, double y, [double tol = 1e-6]) {
  expect(p.x, closeTo(x, tol));
  expect(p.y, closeTo(y, tol));
}

void _expectRect(MutableRect r, double l, double t, double rt, double b) {
  expect(r.left, closeTo(l, 1e-4));
  expect(r.top, closeTo(t, 1e-4));
  expect(r.right, closeTo(rt, 1e-4));
  expect(r.bottom, closeTo(b, 1e-4));
}

/// The `pathValueToPixel` of Phase 0 up to the final review: the three matrices applied one after another through
/// `ui.Path.transform`, the copy written back. The oracle for the one-step implementation.
void _pathValueToPixelInThreeSteps(
  Transformer t,
  ViewPortHandler h,
  ui.Path path,
) {
  var transformed = path.transform(t.valueMatrix.toMatrix4Storage());
  transformed = transformed.transform(h.matrixTouch.toMatrix4Storage());
  transformed = transformed.transform(t.offsetMatrix.toMatrix4Storage());
  final fillType = path.fillType;
  path.reset();
  path.fillType = fillType;
  path.addPath(transformed, ui.Offset.zero);
}

/// Maps ([x], [y]) through the value, touch and offset matrices one after another in double precision, as the three
/// sequential transforms do: like `Matrix.mapPoints` and Skia, a matrix without skew maps each axis on its own (no
/// perspective in these tests).
ui.Offset _mapInThreeSteps(
  Transformer t,
  ViewPortHandler h,
  double x,
  double y,
) {
  var px = x, py = y;
  for (final m in [
    t.valueMatrix.values,
    h.matrixTouch.values,
    t.offsetMatrix.values,
  ]) {
    final skewed = m[Matrix.MSKEW_X] != 0 || m[Matrix.MSKEW_Y] != 0;
    final nx = skewed ? m[0] * px + m[1] * py + m[2] : m[0] * px + m[2];
    final ny = skewed ? m[3] * px + m[4] * py + m[5] : m[4] * py + m[5];
    px = nx;
    py = ny;
  }
  return ui.Offset(px, py);
}

/// Where `pathValueToPixel` (or [convert]) puts the point ([x], [y]): the bounds of a one-point path.
ui.Offset _pathPoint(double x, double y, void Function(ui.Path path) convert) {
  final path = ui.Path()..moveTo(x, y);
  convert(path);
  return path.getBounds().topLeft;
}

/// Sample points of the value range used below, including some outside of it.
const List<(double, double)> _samples = [
  (0, 0),
  (10, 100),
  (5, 50),
  (2.5, 75),
  (-3, -20),
  (7.25, 33.3),
  (12, 120),
  (0.1, 99.9),
];

/// Float32 tolerance for coordinates that went through the engine's float matrices and points: one rounding versus
/// three of values up to ~1000 px differ by a few float ulps (6.1e-5 between 512 and 1024).
const double _pathTolerance = 1e-3;

void main() {
  group('Transformer values to pixels', () {
    test('value range maps to the content rect corners', () {
      final t = _transformer(_handler());
      _expectPoint(t.getPixelForValues(0, 0), 10, 260);
      _expectPoint(t.getPixelForValues(10, 100), 370, 20);
      _expectPoint(t.getPixelForValues(5, 50), 190, 140);
    });

    test('pixelsToValue round-trips pointValuesToPixel', () {
      final t = _transformer(_handler());
      final pts = Float32List.fromList([0, 0, 10, 100, 2.5, 75]);
      t.pointValuesToPixel(pts);
      expect(pts[0], closeTo(10, 1e-6));
      expect(pts[1], closeTo(260, 1e-6));
      expect(pts[2], closeTo(370, 1e-6));
      expect(pts[3], closeTo(20, 1e-6));
      t.pixelsToValue(pts);
      const expected = [0.0, 0.0, 10.0, 100.0, 2.5, 75.0];
      for (int i = 0; i < expected.length; i++) {
        expect(pts[i], closeTo(expected[i], 1e-4));
      }
    });

    test('inverted axis puts the smallest value at the top', () {
      final t = _transformer(_handler(), inverted: true);
      _expectPoint(t.getPixelForValues(0, 0), 10, 20);
      _expectPoint(t.getPixelForValues(10, 100), 370, 260);
      _expectPoint(t.getValuesByTouchPoint(190, 140), 5, 50, 1e-4);
    });

    test('a zero range gives scale 0 instead of NaN or infinity', () {
      final t = Transformer(_handler())
        ..prepareMatrixValuePx(3, 0, 0, 7)
        ..prepareMatrixOffset(false);
      _expectPoint(t.getPixelForValues(5, 9), 10, 260);
      final v = Float64List(9);
      t.valueMatrix.getValues(v);
      expect(v[Matrix.MSCALE_X], 0);
      expect(v[Matrix.MSCALE_Y], 0);
      expect(v.every((e) => e.isFinite), isTrue);
    });

    test(
      'the touch matrix zoom and drag are applied between value and offset',
      () {
        final h = _handler();
        final t = _transformer(h);
        h.refresh(
          h.zoom(2, 1)..postTranslate(-180, 0),
          _NoopInvalidator(),
          false,
        );
        expect(h.transX, -180);
        // x 5 → 180 px unzoomed → 360 zoomed → 180 after the drag → 190 with the left offset.
        _expectPoint(t.getPixelForValues(5, 0), 190, 260);
        // x 10 → 360 → 720 → 540 → 550, right of the content rect.
        _expectPoint(t.getPixelForValues(10, 100), 550, 20);
        _expectPoint(t.getValuesByTouchPoint(10, 260), 2.5, 0, 1e-4);
      },
    );

    test(
      'a singular value matrix re-applies the stale touch inverse, like Android',
      () {
        // A zero range gives value scale 0, so matrixValueToPx.invert fails and leaves the buffer holding the
        // inverted touch matrix (Matrix.invert leaves its output untouched, as Android does), which pixelsToValue
        // then applies a second time.
        final h = _handler();
        h.refresh(h.zoom(2, 2), _NoopInvalidator(), false);
        final t = Transformer(h)
          ..prepareMatrixValuePx(3, 0, 0, 7)
          ..prepareMatrixOffset(false);
        // (110, 160) → offset⁻¹ (100, -100) → touch⁻¹ (50, -50) → touch⁻¹ again (25, -25).
        _expectPoint(t.getValuesByTouchPoint(110, 160), 25, -25, 1e-4);
        final pts = Float32List.fromList([110, 160, 10, 260]);
        t.pixelsToValue(pts);
        expect(pts, [25, -25, 0, 0]);
        // A single zero range is singular too.
        t.prepareMatrixValuePx(0, 0, 100, 0);
        _expectPoint(t.getValuesByTouchPoint(110, 160), 25, -25, 1e-4);
      },
    );

    test(
      'a singular value matrix with an identity touch matrix gives the offset-only result',
      () {
        final t = Transformer(_handler())
          ..prepareMatrixValuePx(3, 0, 0, 7)
          ..prepareMatrixOffset(false);
        _expectPoint(t.getValuesByTouchPoint(110, 160), 100, -100, 1e-4);
      },
    );

    test(
      'pointValuesToPixel with count converts only the first count floats',
      () {
        final t = _transformer(_handler());
        final pts = Float32List.fromList([0, 0, 10, 100, 7, 7]);
        t.pointValuesToPixel(pts, 4);
        expect(pts.sublist(0, 4), [10, 260, 370, 20]);
        expect(pts.sublist(4), [7, 7]);
        // An odd count converts count ~/ 2 points.
        final odd = Float32List.fromList([0, 0, 10, 100]);
        t.pointValuesToPixel(odd, 3);
        expect(odd, [10, 260, 10, 100]);
      },
    );

    test(
      'getValuesByTouchPoint returns a new point or fills the given one',
      () {
        final t = _transformer(_handler());
        final p = t.getValuesByTouchPoint(370, 20);
        _expectPoint(p, 10, 100, 1e-4);
        final out = MPPointD(-1, -1);
        final r = t.getValuesByTouchPoint(10, 260, out);
        expect(identical(r, out), isTrue);
        _expectPoint(out, 0, 0, 1e-4);
      },
    );
  });

  group('Transformer rects and paths', () {
    test('rectValueToPixel maps and sorts the rect', () {
      final t = _transformer(_handler());
      final r = MutableRect(0, 100, 10, 0);
      t.rectValueToPixel(r);
      _expectRect(r, 10, 20, 370, 260);
    });

    test('rectToPixelPhase multiplies top and bottom by phaseY', () {
      final t = _transformer(_handler());
      final r = MutableRect(0, 100, 10, 0);
      t.rectToPixelPhase(r, 0.5);
      _expectRect(r, 10, 140, 370, 260);
    });

    test('rectToPixelPhaseHorizontal multiplies left and right by phaseY', () {
      final t = _transformer(_handler());
      final r = MutableRect(2, 100, 10, 0);
      t.rectToPixelPhaseHorizontal(r, 0.5);
      _expectRect(r, 46, 20, 190, 260);
    });

    test('rectValueToPixelHorizontal with and without phase', () {
      final t = _transformer(_handler());
      final a = MutableRect(0, 100, 10, 0);
      t.rectValueToPixelHorizontal(a);
      _expectRect(a, 10, 20, 370, 260);
      final b = MutableRect(2, 100, 10, 0);
      t.rectValueToPixelHorizontal(b, 0.5);
      _expectRect(b, 46, 20, 190, 260);
    });

    test('rectValuesToPixel maps every rect', () {
      final t = _transformer(_handler());
      final rects = [MutableRect(0, 100, 10, 0), MutableRect(0, 50, 5, 0)];
      t.rectValuesToPixel(rects);
      _expectRect(rects[0], 10, 20, 370, 260);
      _expectRect(rects[1], 10, 140, 190, 260);
    });

    test(
      'pathValueToPixel transforms the path in place and keeps its fill type',
      () {
        final t = _transformer(_handler());
        final path = ui.Path()
          ..fillType = ui.PathFillType.evenOdd
          ..moveTo(0, 0)
          ..lineTo(10, 100)
          ..lineTo(5, 50);
        t.pathValueToPixel(path);
        final b = path.getBounds();
        expect(b.left, closeTo(10, 1e-4));
        expect(b.top, closeTo(20, 1e-4));
        expect(b.right, closeTo(370, 1e-4));
        expect(b.bottom, closeTo(260, 1e-4));
        expect(path.fillType, ui.PathFillType.evenOdd);
        // Still one open contour of three points: (0,0) (10,100) (5,50) → pixels.
        final metrics = path.computeMetrics().toList();
        expect(metrics, hasLength(1));
        expect(metrics.single.isClosed, isFalse);
      },
    );

    test('pathValuesToPixel transforms every path', () {
      final h = _handler();
      final t = _transformer(h);
      h.refresh(h.zoom(2, 1), _NoopInvalidator(), false);
      final paths = [
        ui.Path()
          ..moveTo(0, 0)
          ..lineTo(5, 100),
        ui.Path()
          ..moveTo(0, 0)
          ..lineTo(2.5, 50),
      ];
      t.pathValuesToPixel(paths);
      final a = paths[0].getBounds();
      expect(a.right, closeTo(370, 1e-4));
      expect(a.top, closeTo(20, 1e-4));
      final b = paths[1].getBounds();
      expect(b.right, closeTo(190, 1e-4));
      expect(b.top, closeTo(140, 1e-4));
    });
  });

  group('Transformer matrices', () {
    test('valueMatrix and offsetMatrix expose the prepared matrices', () {
      final t = _transformer(_handler());
      final v = Float64List(9);
      t.valueMatrix.getValues(v);
      expect(v[Matrix.MSCALE_X], closeTo(36, 1e-9));
      expect(v[Matrix.MSCALE_Y], closeTo(-2.4, 1e-9));
      t.offsetMatrix.getValues(v);
      expect(v, [1, 0, 10, 0, 1, 260, 0, 0, 1]);
      expect(identical(t.valueMatrix, t.valueMatrix), isTrue);
    });

    test('valueToPixelMatrix combines value, touch and offset', () {
      final h = _handler();
      final t = _transformer(h);
      h.refresh(h.zoom(2, 1), _NoopInvalidator(), false);
      final pts = Float32List.fromList([5, 100]);
      t.valueToPixelMatrix.mapPoints(pts);
      expect(pts[0], closeTo(370, 1e-4));
      expect(pts[1], closeTo(20, 1e-4));
      expect(identical(t.valueToPixelMatrix, t.valueToPixelMatrix), isTrue);
    });

    test('pixelToValueMatrix inverts valueToPixelMatrix', () {
      final t = _transformer(_handler());
      final pts = Float32List.fromList([370, 20, 190, 140]);
      t.pixelToValueMatrix.mapPoints(pts);
      expect(pts[0], closeTo(10, 1e-4));
      expect(pts[1], closeTo(100, 1e-4));
      expect(pts[2], closeTo(5, 1e-4));
      expect(pts[3], closeTo(50, 1e-4));
    });

    test('prepareMatrixValuePx translates by the chart minimums first', () {
      final t = Transformer(_handler())
        ..prepareMatrixValuePx(-5, 10, 200, -100)
        ..prepareMatrixOffset(false);
      _expectPoint(t.getPixelForValues(-5, -100), 10, 260);
      _expectPoint(t.getPixelForValues(5, 100), 370, 20);
    });
  });

  group('pathValueToPixel in one step', () {
    /// A handler zoomed 2.5 x 1.5 around (150, 120) and dragged by (-60, 25), whose touch matrix is not the
    /// identity.
    ViewPortHandler zoomedHandler() {
      final h = _handler();
      h.refresh(
        h.zoom(2.5, 1.5, 150, 120)..postTranslate(-60, 25),
        _NoopInvalidator(),
        false,
      );
      return h;
    }

    final cases = <String, (ViewPortHandler Function(), bool, List<double>)>{
      'identity touch matrix': (_handler, false, [0, 10, 100, 0]),
      'zoomed and dragged touch matrix': (
        zoomedHandler,
        false,
        [-3, 12, 80, -20],
      ),
      'zoomed and dragged, inverted axis': (
        zoomedHandler,
        true,
        [-3, 12, 80, -20],
      ),
    };

    for (final MapEntry(key: name, value: (handler, inverted, range))
        in cases.entries) {
      test('$name: the one-step matrix equals the three transforms', () {
        final h = handler();
        final t = Transformer(h)
          ..prepareMatrixValuePx(range[0], range[1], range[2], range[3])
          ..prepareMatrixOffset(inverted);
        final m = Float64List(16);
        expect(t.valueToPixelMatrix4(m), isTrue);
        // No skew, no perspective, z passed through.
        for (final i in [1, 2, 3, 4, 6, 7, 8, 9, 11, 14]) {
          expect(m[i], 0, reason: 'slot $i');
        }
        expect(m[10], 1);
        expect(m[15], 1);
        for (final (x, y) in _samples) {
          final expected = _mapInThreeSteps(t, h, x, y);
          expect(
            m[0] * x + m[12],
            closeTo(expected.dx, 1e-6),
            reason: 'x of ($x, $y)',
          );
          expect(
            m[5] * y + m[13],
            closeTo(expected.dy, 1e-6),
            reason: 'y of ($x, $y)',
          );
        }
      });

      test(
        '$name: pathValueToPixel moves every point where the three transforms did',
        () {
          final h = handler();
          final t = Transformer(h)
            ..prepareMatrixValuePx(range[0], range[1], range[2], range[3])
            ..prepareMatrixOffset(inverted);
          for (final (x, y) in _samples) {
            final now = _pathPoint(x, y, t.pathValueToPixel);
            final before = _pathPoint(
              x,
              y,
              (p) => _pathValueToPixelInThreeSteps(t, h, p),
            );
            final exact = _mapInThreeSteps(t, h, x, y);
            expect(
              now.dx,
              closeTo(before.dx, _pathTolerance),
              reason: 'x of ($x, $y)',
            );
            expect(
              now.dy,
              closeTo(before.dy, _pathTolerance),
              reason: 'y of ($x, $y)',
            );
            expect(
              now.dx,
              closeTo(exact.dx, _pathTolerance),
              reason: 'x of ($x, $y)',
            );
            expect(
              now.dy,
              closeTo(exact.dy, _pathTolerance),
              reason: 'y of ($x, $y)',
            );
          }
        },
      );

      test('$name: curves, contours and the fill type come out as before', () {
        final h = handler();
        final t = Transformer(h)
          ..prepareMatrixValuePx(range[0], range[1], range[2], range[3])
          ..prepareMatrixOffset(inverted);
        ui.Path build() => ui.Path()
          ..fillType = ui.PathFillType.evenOdd
          ..moveTo(0, 10)
          ..cubicTo(1, 80, 3, -10, 5, 50)
          ..lineTo(9, 90)
          ..moveTo(2, 20)
          ..quadraticBezierTo(4, 60, 6, 20)
          ..close();
        final now = build();
        t.pathValueToPixel(now);
        final before = build();
        _pathValueToPixelInThreeSteps(t, h, before);

        expect(now.fillType, ui.PathFillType.evenOdd);
        final a = now.getBounds(), b = before.getBounds();
        expect(a.left, closeTo(b.left, _pathTolerance));
        expect(a.top, closeTo(b.top, _pathTolerance));
        expect(a.right, closeTo(b.right, _pathTolerance));
        expect(a.bottom, closeTo(b.bottom, _pathTolerance));
        final ma = now.computeMetrics().toList();
        final mb = before.computeMetrics().toList();
        expect(ma, hasLength(2));
        expect(ma.map((m) => m.isClosed), [false, true]);
        for (var i = 0; i < 2; i++) {
          expect(
            ma[i].length,
            closeTo(mb[i].length, 1e-2),
            reason: 'contour $i',
          );
          for (final f in [0.0, 0.3, 0.7, 1.0]) {
            final pa = ma[i].getTangentForOffset(ma[i].length * f)!.position;
            final pb = mb[i].getTangentForOffset(mb[i].length * f)!.position;
            expect(
              (pa - pb).distance,
              lessThan(1e-2),
              reason: 'contour $i at $f',
            );
          }
        }
      });
    }

    test('consecutive calls do not carry points over', () {
      final h = zoomedHandler();
      final t = _transformer(h);
      final first = ui.Path()
        ..moveTo(0, 0)
        ..lineTo(10, 100);
      t.pathValueToPixel(first);
      final second = ui.Path()
        ..moveTo(5, 50)
        ..lineTo(6, 60);
      t.pathValueToPixel(second);
      final expected = ui.Path()
        ..moveTo(5, 50)
        ..lineTo(6, 60);
      _pathValueToPixelInThreeSteps(t, h, expected);
      final a = second.getBounds(), b = expected.getBounds();
      expect(a.left, closeTo(b.left, _pathTolerance));
      expect(a.top, closeTo(b.top, _pathTolerance));
      expect(a.right, closeTo(b.right, _pathTolerance));
      expect(a.bottom, closeTo(b.bottom, _pathTolerance));
      expect(second.computeMetrics().toList(), hasLength(1));

      final empty = ui.Path();
      t.pathValueToPixel(empty);
      expect(empty.computeMetrics().toList(), isEmpty);
    });

    test('a skewed touch matrix still goes through the three transforms', () {
      final h = _handler();
      h.matrixTouch.setValues([1.5, 0.25, -20, 0.1, 1.2, 5, 0, 0, 1]);
      final t = _transformer(h);
      expect(t.valueToPixelMatrix4(Float64List(16)), isFalse);
      for (final (x, y) in _samples) {
        final now = _pathPoint(x, y, t.pathValueToPixel);
        final before = _pathPoint(
          x,
          y,
          (p) => _pathValueToPixelInThreeSteps(t, h, p),
        );
        expect(now, before, reason: '($x, $y)');
      }
    });

    test(
      'a one-step matrix beyond Float range falls back to the three transforms, which stay finite',
      () {
        // Value scale 1e30 and touch scale 1e30: the product, 1e60, does not fit the engine's float matrix (it would
        // be clamped to Float.MAX), while the three transforms map x = 1e-35 to 1e-5, then 1e25, then 1e25 + 10.
        final h = _handler();
        h.matrixTouch.setValues([1e30, 0, 0, 0, 1, 0, 0, 0, 1]);
        final t = _transformer(h);
        t.valueMatrix.setValues([1e30, 0, 0, 0, -2.4, 240, 0, 0, 1]);
        final m = Float64List(16);
        expect(t.valueToPixelMatrix4(m), isTrue);
        expect(m[0], closeTo(1e60, 1e45));

        final now = _pathPoint(1e-35, 50, t.pathValueToPixel);
        final before = _pathPoint(
          1e-35,
          50,
          (p) => _pathValueToPixelInThreeSteps(t, h, p),
        );
        expect(before.dx.isFinite && before.dy.isFinite, isTrue);
        expect(before.dx, closeTo(1e25, 1e19));
        expect(now, before);
      },
    );

    test(
      'a non-finite x term stays in x; a full 3x3 product makes y NaN through the zero skew (0 x infinity)',
      () {
        // The value matrix of an x range without scale whose minimum is minus infinity: x scale 0, x translation
        // infinity. Built by hand: postScale(0) over the infinite translation already gives NaN in the Matrix shim
        // (Final review I3, ledger Task 6).
        final h = _handler();
        h.refresh(h.zoom(2, 1.5, 100, 100), _NoopInvalidator(), false);
        final t = _transformer(h);
        t.valueMatrix.setValues([0, 0, double.infinity, 0, -2.4, 240, 0, 0, 1]);

        final m = Float64List(16);
        expect(t.valueToPixelMatrix4(m), isTrue);
        expect(m[12], double.infinity);
        expect(m[0].isNaN || m[5].isNaN || m[13].isNaN, isFalse);
        for (final (x, y) in _samples) {
          // The y the three transforms give one after another is finite and the one-step matrix gives it too.
          final sequentialY = _mapInThreeSteps(t, h, x, y).dy;
          expect(sequentialY.isFinite, isTrue);
          expect(
            m[5] * y + m[13],
            closeTo(sequentialY, 1e-6),
            reason: 'y of ($x, $y)',
          );
        }
        // The Kotlin-API getter multiplies all nine terms.
        expect(t.valueToPixelMatrix.values[Matrix.MTRANS_Y].isNaN, isTrue);
      },
    );
  });
}

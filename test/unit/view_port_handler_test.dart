// Tests for the ViewPortHandler port (MPAndroidChart v4.0.1 utils/ViewPortHandler.kt); no Kotlin counterpart.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/graphics/matrix.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/utils/chart_invalidator.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

/// Kotlin `Float.MAX_VALUE`.
const double _floatMax = 3.4028234663852886e38;

class _CountingInvalidator implements ChartInvalidator {
  int count = 0;

  @override
  void invalidate() => count++;
}

Float32List _values(Matrix m) {
  final v = Float32List(9);
  m.getValues(v);
  return v;
}

/// A 400x300 chart with offsets (10, 20, 30, 40): content rect (10, 20, 370, 260), 360x240.
ViewPortHandler _handler() => ViewPortHandler()
  ..setChartDimens(400, 300)
  ..restrainViewPort(10, 20, 30, 40);

void _expectRect(MutableRect r, double l, double t, double rt, double b) {
  expect(r.left, closeTo(l, 1e-6));
  expect(r.top, closeTo(t, 1e-6));
  expect(r.right, closeTo(rt, 1e-6));
  expect(r.bottom, closeTo(b, 1e-6));
}

void main() {
  group('ViewPortHandler dimensions', () {
    test('setChartDimens makes the content rect the full chart', () {
      final h = ViewPortHandler()..setChartDimens(400, 300);
      _expectRect(h.contentRect, 0, 0, 400, 300);
      expect(h.chartWidth, 400);
      expect(h.chartHeight, 300);
      expect(h.hasChartDimens(), isTrue);
    });

    test('restrainViewPort subtracts the offsets', () {
      final h = _handler();
      _expectRect(h.contentRect, 10, 20, 370, 260);
      expect(h.offsetLeft, 10);
      expect(h.offsetTop, 20);
      expect(h.offsetRight, 30);
      expect(h.offsetBottom, 40);
      expect(h.contentLeft, 10);
      expect(h.contentTop, 20);
      expect(h.contentRight, 370);
      expect(h.contentBottom, 260);
      expect(h.contentWidth, 360);
      expect(h.contentHeight, 240);
      expect(h.smallestContentExtension, 240);
      final c = h.contentCenter;
      expect(c.x, 190);
      expect(c.y, 140);
    });

    test('setChartDimens keeps the current offsets', () {
      final h = _handler()..setChartDimens(500, 400);
      _expectRect(h.contentRect, 10, 20, 470, 360);
    });

    test('a new handler has no dimensions and default limits', () {
      final h = ViewPortHandler();
      expect(h.hasChartDimens(), isFalse);
      expect(h.chartWidth, 0);
      expect(h.chartHeight, 0);
      expect(h.minScaleX, 1);
      expect(h.minScaleY, 1);
      expect(h.maxScaleX, _floatMax);
      expect(h.maxScaleY, _floatMax);
      expect(h.scaleX, 1);
      expect(h.scaleY, 1);
      expect(h.transX, 0);
      expect(h.transY, 0);
      expect(h.dragOffsetX, 0);
      expect(h.dragOffsetY, 0);
      expect(h.isFullyZoomedOut, isTrue);
      expect(h.hasNoDragOffset, isTrue);
    });

    test('hasChartDimens needs both sides above zero', () {
      expect(
        (ViewPortHandler()..setChartDimens(10, 0)).hasChartDimens(),
        isFalse,
      );
      expect(
        (ViewPortHandler()..setChartDimens(0, 10)).hasChartDimens(),
        isFalse,
      );
    });
  });

  group('ViewPortHandler zoom and refresh', () {
    test('zoom + refresh scales, fitScreen + refresh returns to 1', () {
      final h = _handler();
      final inv = _CountingInvalidator();
      final m = h.zoom(2, 2, h.contentRect.centerX(), h.contentRect.centerY());
      final result = h.refresh(m, inv, true);
      expect(identical(result, m), isTrue);
      expect(inv.count, 1);
      expect(h.scaleX, 2);
      expect(h.scaleY, 2);
      expect(h.isFullyZoomedOut, isFalse);
      expect(h.isFullyZoomedOutX, isFalse);
      expect(h.isFullyZoomedOutY, isFalse);
      expect(h.canZoomOutMoreX, isTrue);
      expect(h.canZoomOutMoreY, isTrue);

      h.refresh(h.fitScreen(), inv, true);
      expect(inv.count, 2);
      expect(h.scaleX, 1);
      expect(h.scaleY, 1);
      expect(h.transX, 0);
      expect(h.transY, 0);
      expect(h.isFullyZoomedOut, isTrue);
      expect(h.canZoomOutMoreX, isFalse);
    });

    test('zoom does not touch matrixTouch until refresh', () {
      final h = _handler();
      h.zoom(2, 2);
      expect(h.scaleX, 1);
      expect(_values(h.matrixTouch)[Matrix.MSCALE_X], 1);
    });

    test('refresh with invalidate false does not invalidate', () {
      final h = _handler();
      final inv = _CountingInvalidator();
      h.refresh(h.zoom(3, 1), inv, false);
      expect(inv.count, 0);
      expect(h.scaleX, 3);
    });

    test('refresh accepts matrixTouch itself', () {
      final h = _handler();
      final inv = _CountingInvalidator();
      h.matrixTouch.postScale(2, 2);
      final result = h.refresh(h.matrixTouch, inv, false);
      expect(identical(result, h.matrixTouch), isTrue);
      expect(h.scaleX, 2);
      expect(h.scaleY, 2);
    });

    test('refresh writes the clamped values back into the new matrix', () {
      final h = _handler();
      final m = Matrix()..setScale(0.5, 0.5);
      h.refresh(m, _CountingInvalidator(), false);
      final v = _values(m);
      expect(v[Matrix.MSCALE_X], 1);
      expect(v[Matrix.MSCALE_Y], 1);
    });

    test('zoom without pivot scales around the origin', () {
      final h = _handler();
      final v = _values(h.zoom(2, 3));
      expect(v[Matrix.MSCALE_X], 2);
      expect(v[Matrix.MSCALE_Y], 3);
      expect(v[Matrix.MTRANS_X], 0);
      expect(v[Matrix.MTRANS_Y], 0);
    });

    test('zoom with pivot keeps the pivot fixed', () {
      final h = _handler();
      final v = _values(h.zoom(2, 2, 100, 50));
      expect(v[Matrix.MSCALE_X], 2);
      expect(v[Matrix.MTRANS_X], -100);
      expect(v[Matrix.MTRANS_Y], -50);
    });

    test('output overloads write into and return the given matrix', () {
      final h = _handler();
      final out = Matrix()..setTranslate(99, 99);
      expect(identical(h.zoom(2, 2, 0, 0, out), out), isTrue);
      expect(_values(out)[Matrix.MSCALE_X], 2);
      expect(_values(out)[Matrix.MTRANS_X], 0);

      final out2 = Matrix();
      expect(identical(h.zoomIn(0, 0, out2), out2), isTrue);
      final out3 = Matrix();
      expect(identical(h.zoomOut(0, 0, out3), out3), isTrue);
      final out4 = Matrix();
      expect(identical(h.setZoom(2, 2, 0, 0, out4), out4), isTrue);
      final out5 = Matrix();
      expect(identical(h.fitScreen(out5), out5), isTrue);
      final out6 = Matrix();
      expect(
        identical(h.translate(Float32List.fromList([10, 20]), out6), out6),
        isTrue,
      );
    });

    test('zoomIn scales by 1.4 and zoomOut by 0.7 around the pivot', () {
      final h = _handler();
      final zin = _values(h.zoomIn(10, 20));
      expect(zin[Matrix.MSCALE_X], closeTo(1.4, 1e-6));
      expect(zin[Matrix.MSCALE_Y], closeTo(1.4, 1e-6));
      expect(zin[Matrix.MTRANS_X], closeTo(10 - 1.4 * 10, 1e-4));
      expect(zin[Matrix.MTRANS_Y], closeTo(20 - 1.4 * 20, 1e-4));
      final zout = _values(h.zoomOut(10, 20));
      expect(zout[Matrix.MSCALE_X], closeTo(0.7, 1e-6));
      expect(zout[Matrix.MSCALE_Y], closeTo(0.7, 1e-6));
    });

    test('zoom builds on the current touch matrix', () {
      final h = _handler();
      h.refresh(h.zoom(2, 2), _CountingInvalidator(), false);
      expect(_values(h.zoom(2, 1))[Matrix.MSCALE_X], 4);
    });

    test('resetZoom takes the scale back to 1 around the content center', () {
      final h = _handler();
      // Scale 2 around (190, 140) gives translation (-190, -140); refresh clamps y to 0.
      h.refresh(h.zoom(2, 2, 190, 140), _CountingInvalidator(), false);
      expect(h.transX, -190);
      expect(h.transY, 0);
      final out = Matrix();
      h.resetZoom(out);
      final v = _values(out);
      expect(v[Matrix.MSCALE_X], closeTo(1, 1e-6));
      expect(v[Matrix.MSCALE_Y], closeTo(1, 1e-6));
      // 0.5 * -190 + 190 - 0.5 * 190 = 0; 0.5 * 0 + 140 - 0.5 * 140 = 70.
      expect(v[Matrix.MTRANS_X], closeTo(0, 1e-4));
      expect(v[Matrix.MTRANS_Y], closeTo(70, 1e-4));
    });

    test('setZoom sets absolute scales and drops the translation', () {
      final h = _handler();
      h.refresh(h.zoom(2, 2, 190, 140), _CountingInvalidator(), false);
      expect(h.transX, isNot(0));
      final v = _values(h.setZoom(3, 4));
      expect(v, [3, 0, 0, 0, 4, 0, 0, 0, 1]);
      final p = _values(h.setZoom(3, 4, 10, 20));
      expect(p, [3, 0, 10 - 3 * 10, 0, 4, 20 - 4 * 20, 0, 0, 1]);
    });

    test('fitScreen resets scale, translation and the scale minima', () {
      final h = _handler()
        ..setMinimumScaleX(2)
        ..setMinimumScaleY(3);
      expect(h.scaleX, 2);
      expect(h.isFullyZoomedOut, isFalse);
      final m = h.fitScreen();
      expect(h.minScaleX, 1);
      expect(h.minScaleY, 1);
      expect(_values(m), [1, 0, 0, 0, 1, 0, 0, 0, 1]);
      h.refresh(m, _CountingInvalidator(), false);
      expect(h.scaleX, 1);
      expect(h.isFullyZoomedOut, isTrue);
    });

    test(
      'pivot-less zoom and setZoom keep translation 0 for an infinite factor',
      () {
        final h = _handler();
        final z = _values(h.zoom(double.infinity, 1));
        expect(z[Matrix.MTRANS_X], 0);
        expect(z[Matrix.MTRANS_Y], 0);
        final out = Matrix();
        // Kotlin zoom(sx, sy, outputMatrix): no pivot.
        h.zoom(double.infinity, 1, null, null, out);
        expect(_values(out)[Matrix.MTRANS_X], 0);
        final s = _values(h.setZoom(double.infinity, 1));
        expect(s[Matrix.MTRANS_X], 0);
        expect(s[Matrix.MTRANS_Y], 0);
        h.setZoom(double.infinity, 1, null, null, out);
        expect(_values(out)[Matrix.MTRANS_X], 0);
      },
    );

    test('translate moves the given pixel to the content top left', () {
      final h = _handler();
      final v = _values(h.translate(Float32List.fromList([110, 70])));
      expect(v[Matrix.MTRANS_X], -100);
      expect(v[Matrix.MTRANS_Y], -50);
    });

    test('centerViewPort translates, clamps and invalidates', () {
      final h = _handler();
      final inv = _CountingInvalidator();
      h.refresh(h.zoom(2, 2), inv, false);
      h.centerViewPort(Float32List.fromList([110, 20]), inv);
      expect(inv.count, 1);
      expect(h.transX, -100);
      // A translation past the zoomed data is clamped at -width * (scale - 1).
      h.centerViewPort(Float32List.fromList([1000, 20]), inv);
      expect(h.transX, -360);
    });
  });

  group('ViewPortHandler limits', () {
    test('setMinMaxScaleX clamps the scale', () {
      final h = _handler()..setMinMaxScaleX(1, 3);
      h.refresh(h.zoom(5, 5), _CountingInvalidator(), false);
      expect(h.scaleX, 3);
      expect(h.scaleY, 5);
      expect(h.canZoomInMoreX, isFalse);
      expect(h.canZoomInMoreY, isTrue);
    });

    test('setMinMaxScaleY clamps the scale', () {
      final h = _handler()..setMinMaxScaleY(2, 4);
      expect(h.scaleY, 2);
      h.refresh(h.zoom(1, 10), _CountingInvalidator(), false);
      expect(h.scaleY, 4);
      expect(h.canZoomInMoreY, isFalse);
      expect(h.canZoomOutMoreY, isTrue);
    });

    test('minimum scale is at least 1; maximum 0 means unlimited', () {
      final h = _handler()
        ..setMinimumScaleX(0.5)
        ..setMinimumScaleY(0.25)
        ..setMaximumScaleX(0)
        ..setMaximumScaleY(0);
      expect(h.minScaleX, 1);
      expect(h.minScaleY, 1);
      expect(h.maxScaleX, _floatMax);
      expect(h.maxScaleY, _floatMax);
      h
        ..setMinMaxScaleX(0, 0)
        ..setMinMaxScaleY(-1, 0);
      expect(h.minScaleX, 1);
      expect(h.maxScaleX, _floatMax);
      expect(h.minScaleY, 1);
      expect(h.maxScaleY, _floatMax);
    });

    test('a maximum that rounds to Float 0 means unlimited, like Kotlin', () {
      // Kotlin receives 1e-50 as a Float, which is 0f, so the limit is removed.
      final h = _handler()
        ..setMaximumScaleX(1e-50)
        ..setMaximumScaleY(-1e-50);
      expect(h.maxScaleX, _floatMax);
      expect(h.maxScaleY, _floatMax);
      h
        ..setMinMaxScaleX(1, 1e-50)
        ..setMinMaxScaleY(1, 1e-50);
      expect(h.maxScaleX, _floatMax);
      expect(h.maxScaleY, _floatMax);
    });

    test('setMaximumScaleX applies to the current touch matrix right away', () {
      final h = _handler();
      h.refresh(h.zoom(6, 6), _CountingInvalidator(), false);
      h
        ..setMaximumScaleX(2)
        ..setMaximumScaleY(3);
      expect(h.scaleX, 2);
      expect(h.scaleY, 3);
      expect(_values(h.matrixTouch)[Matrix.MSCALE_X], 2);
      expect(h.maxScaleX, 2);
      expect(h.maxScaleY, 3);
    });

    test(
      'scale below the minimum is raised; fully zoomed out needs minScale 1',
      () {
        final h = _handler()..setMinimumScaleX(1.5);
        expect(h.scaleX, 1.5);
        expect(h.isFullyZoomedOutX, isFalse);
        expect(h.isFullyZoomedOutY, isTrue);
        expect(h.canZoomOutMoreX, isFalse);
      },
    );

    test('scale limits are Floats, so they agree with the Float matrix', () {
      // Kotlin stores 1.1f / 2.1f; the matrix round-trips the clamped scale through a FloatArray, so a second
      // refresh reads back 1.1f and compares it against the Float limit, not against the double 1.1.
      final h = _handler()
        ..setMinimumScaleX(1.1)
        ..setMaximumScaleY(2.1);
      final inv = _CountingInvalidator();
      h.refresh(h.zoom(1, 5), inv, false);
      h.refresh(h.matrixTouch, inv, false);
      expect(h.canZoomOutMoreX, isFalse);
      expect(h.canZoomInMoreY, isFalse);
      h
        ..setMinMaxScaleX(1.3, 2.7)
        ..setMinMaxScaleY(1.3, 2.7);
      h.refresh(h.zoom(10, 0.1), inv, false);
      h.refresh(h.matrixTouch, inv, false);
      expect(h.canZoomInMoreX, isFalse);
      expect(h.canZoomOutMoreY, isFalse);
      expect(h.minScaleX, Float32List.fromList([1.3])[0]);
      expect(h.maxScaleX, Float32List.fromList([2.7])[0]);
    });

    test('translation is clamped to the zoomed content', () {
      final h = _handler();
      final inv = _CountingInvalidator();
      // Scale 2 → x translation in [-360, 0], y translation in [0, 240].
      final m = h.zoom(2, 2)..postTranslate(-1000, 1000);
      h.refresh(m, inv, false);
      expect(h.transX, -360);
      expect(h.transY, 240);
      h.refresh(h.matrixTouch..postTranslate(5000, -5000), inv, false);
      expect(h.transX, 0);
      expect(h.transY, 0);
    });

    test('unzoomed content cannot be dragged without a drag offset', () {
      final h = _handler();
      h.refresh(Matrix()..setTranslate(50, -50), _CountingInvalidator(), false);
      expect(h.transX, 0);
      expect(h.transY, 0);
    });

    test('drag offsets widen the translation limits', () {
      final h = _handler()
        ..dragOffsetX = 10
        ..dragOffsetY = 20;
      expect(h.hasNoDragOffset, isFalse);
      final inv = _CountingInvalidator();
      h.refresh(Matrix()..setTranslate(50, -50), inv, false);
      expect(h.transX, 10);
      expect(h.transY, -20);
      h.refresh(Matrix()..setTranslate(-50, 50), inv, false);
      expect(h.transX, -10);
      expect(h.transY, 20);
      final z = h.zoom(2, 2)..postTranslate(-1000, 1000);
      h.refresh(z, inv, false);
      expect(h.transX, -370);
      expect(h.transY, 260);
    });

    test('hasNoDragOffset is true for zero or negative offsets', () {
      final h = ViewPortHandler()
        ..dragOffsetX = -5
        ..dragOffsetY = 0;
      expect(h.hasNoDragOffset, isTrue);
      h.dragOffsetY = 1;
      expect(h.hasNoDragOffset, isFalse);
    });

    test('limitTransAndScale treats a null content rect as empty', () {
      final h = _handler();
      final m = Matrix()
        ..setScale(2, 2)
        ..postTranslate(-50, 50);
      h.limitTransAndScale(m, null);
      final v = _values(m);
      expect(v[Matrix.MSCALE_X], 2);
      expect(v[Matrix.MTRANS_X], 0);
      expect(v[Matrix.MTRANS_Y], 0);
      expect(h.scaleX, 2);
    });

    test('limitTransAndScale leaves skew and perspective untouched', () {
      final h = _handler();
      final m = Matrix()
        ..setValues(Float32List.fromList([2, 0.5, -10, 0.25, 2, 10, 0, 0, 1]));
      h.limitTransAndScale(m, h.contentRect);
      final v = _values(m);
      expect(v[Matrix.MSKEW_X], 0.5);
      expect(v[Matrix.MSKEW_Y], 0.25);
      expect(v[Matrix.MPERSP_2], 1);
      expect(v[Matrix.MTRANS_X], -10);
      expect(v[Matrix.MTRANS_Y], 10);
    });
  });

  group('ViewPortHandler bounds', () {
    test('isInBounds* use the content rect with the Kotlin tolerances', () {
      final h = _handler();
      expect(h.isInBoundsLeft(9), isTrue);
      expect(h.isInBoundsLeft(8.9), isFalse);
      expect(h.isInBoundsRight(371), isTrue);
      expect(h.isInBoundsRight(371.5), isFalse);
      expect(h.isInBoundsTop(20), isTrue);
      expect(h.isInBoundsTop(19.99), isFalse);
      expect(h.isInBoundsBottom(260), isTrue);
      expect(h.isInBoundsBottom(260.01), isFalse);
      // Rounded down to two decimals first: 260.009 → 260.0.
      expect(h.isInBoundsBottom(260.009), isTrue);
      expect(h.isInBoundsX(9), isTrue);
      expect(h.isInBoundsX(372), isFalse);
      expect(h.isInBoundsY(140), isTrue);
      expect(h.isInBoundsY(10), isFalse);
      expect(h.isInBounds(190, 140), isTrue);
      expect(h.isInBounds(190, 300), isFalse);
      expect(h.isInBounds(0, 140), isFalse);
    });

    test('isInBoundsRight/Bottom round in Float like Kotlin', () {
      // Kotlin: (0.29f * 100f).toInt() == 29 in Float math, so 0.29 stays 0.29; in double math 0.29 * 100 is
      // 28.999999999999996 and would truncate to 0.28.
      final h = ViewPortHandler();
      h.contentRect.set(0, 0, -0.715, 0.285);
      expect(h.isInBoundsBottom(0.29), isFalse);
      expect(h.isInBoundsRight(0.29), isFalse);
    });

    test('isInBoundsRight/Bottom do not throw on NaN or infinity', () {
      final h = _handler();
      // Kotlin Float.toInt(): NaN → 0, ±∞ saturate at Int.MAX_VALUE / Int.MIN_VALUE.
      expect(h.isInBoundsRight(double.nan), isTrue);
      expect(h.isInBoundsBottom(double.nan), isTrue);
      expect(h.isInBoundsRight(double.infinity), isFalse);
      expect(h.isInBoundsBottom(double.infinity), isFalse);
      expect(h.isInBoundsRight(double.negativeInfinity), isTrue);
      expect(h.isInBoundsBottom(double.negativeInfinity), isTrue);
      expect(h.isInBoundsLeft(double.nan), isFalse);
      expect(h.isInBoundsTop(double.nan), isFalse);
    });
  });
}

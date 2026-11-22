// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/AxisRendererTest.kt
//
// The Kotlin fake paint only overrides measureText; its font metrics are the android.jar stubs, all 0. The port's
// fake paint returns those zero metrics explicitly, so the rotated case keeps the Kotlin expectation of 0.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/y_axis.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/renderer/y_axis_renderer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

class _FixedWidthPaint extends ChartPaint {
  @override
  double measureText(String text) => 100;

  @override
  FontMetrics getFontMetrics([FontMetrics? metrics]) =>
      (metrics ?? FontMetrics())
        ..top = 0
        ..ascent = 0
        ..descent = 0
        ..bottom = 0
        ..leading = 0;
}

Float32List _compute(YAxis axis, double min, double max) {
  YAxisRenderer(ViewPortHandler(), axis, null).computeAxis(min, max, false);
  return axis.entries;
}

void main() {
  test('forcedLabelsStayOnTheGranularity', () {
    final yAxis = YAxis();
    yAxis.labelCount = 6;
    yAxis.isForceLabelsEnabled = true;
    yAxis.granularity = 1;
    final entries = _compute(yAxis, 0, 4);
    expect(yAxis.entryCount, 5);
    expect(entries[1] - entries[0], closeTo(1, 0.01));
    expect(entries[0], closeTo(0, 0.01));
    expect(entries[4], closeTo(4, 0.01));
  });

  test('computeAxisValues', () {
    var yAxis = YAxis();
    yAxis.labelCount = 6;
    var entries = _compute(yAxis, 0, 100);
    expect(entries.length, 6);
    expect(entries[1] - entries[0], closeTo(20, 0.01));
    expect(entries[0], closeTo(0, 0.01));
    expect(entries[entries.length - 1], closeTo(100, 0.01));

    yAxis = YAxis();
    yAxis.labelCount = 6;
    yAxis.granularity = 50;
    entries = _compute(yAxis, 0, 100);
    expect(entries.length, 3);
    expect(entries[1] - entries[0], closeTo(50, 0.01));
    expect(entries[0], closeTo(0, 0.01));
    expect(entries[entries.length - 1], closeTo(100, 0.01));

    yAxis = YAxis();
    yAxis.labelCount = 5;
    yAxis.isForceLabelsEnabled = true;
    entries = _compute(yAxis, 0, 100);
    expect(entries.length, 5);
    expect(entries[1] - entries[0], closeTo(25, 0.01));
    expect(entries[0], closeTo(0, 0.01));
    expect(entries[entries.length - 1], closeTo(100, 0.01));

    yAxis = YAxis();
    yAxis.labelCount = 5;
    yAxis.isForceLabelsEnabled = true;
    entries = _compute(yAxis, 0, 0.01);
    expect(entries.length, 5);
    expect(entries[1] - entries[0], closeTo(0.0025, 0.0001));
    expect(entries[0], closeTo(0, 0.0001));
    expect(entries[entries.length - 1], closeTo(0.01, 0.0001));

    yAxis = YAxis();
    yAxis.labelCount = 5;
    entries = _compute(yAxis, 0, 0.01);
    expect(entries.length, 5);
    expect(entries[1] - entries[0], closeTo(0.0020, 0.0001));
    expect(entries[0], closeTo(0, 0.0001));
    expect(entries[entries.length - 1], closeTo(0.0080, 0.0001));

    yAxis = YAxis();
    yAxis.labelCount = 6;
    entries = _compute(yAxis, -50, 50);
    expect(entries.length, 5);
    expect(entries[0], closeTo(-40, 0.0001));
    expect(entries[2], closeTo(0, 0.0001));
    expect(entries[entries.length - 1], closeTo(40, 0.0001));

    yAxis = YAxis();
    yAxis.labelCount = 6;
    entries = _compute(yAxis, -50, 100);
    expect(entries.length, 5);
    expect(entries[0], closeTo(-30, 0.0001));
    expect(entries[2], closeTo(30, 0.0001));
    expect(entries[entries.length - 1], closeTo(90, 0.0001));
  });

  test('rotatedLabelsNeedTheWidthOfTheirRotatedBounds', () {
    final paint = _FixedWidthPaint();
    final yAxis = YAxis();
    yAxis.xOffset = 0;

    expect(yAxis.getRequiredWidthSpace(paint), closeTo(100, 0.01));
    yAxis.labelRotationAngle = 90;
    expect(yAxis.getRequiredWidthSpace(paint), closeTo(0, 0.01));
  });

  test('an empty-data range overflows to infinity and computes no labels', () {
    // Not in AxisRendererTest.kt: the Float.MAX_VALUE .. -Float.MAX_VALUE range of empty data has an infinite span
    // in Kotlin Float arithmetic, so computeAxisValues leaves the axis without entries.
    final yAxis = YAxis();
    yAxis.entries = Float32List.fromList([1, 2, 3]);
    yAxis.entryCount = 3;
    final entries = _compute(
      yAxis,
      3.4028234663852886e38,
      -3.4028234663852886e38,
    );
    expect(entries.length, 0);
    expect(yAxis.entryCount, 0);
  });

  // Port-only regressions: the Kotlin signature takes Floats, so a range below the Float resolution collapses to zero;
  // the label count stops where the interval no longer advances a label value, where Kotlin would hang.
  group('sub-Float ranges terminate', () {
    const timeout = Timeout(Duration(seconds: 10));

    test('a range below the Float resolution computes no labels', () {
      final yAxis = YAxis();
      final entries = _compute(yAxis, 1.0, 1.0000000000000004);
      expect(entries.length, 0);
      expect(yAxis.entryCount, 0);
    }, timeout: timeout);

    test(
      'YAxis.calculate pads a sub-Float data range, then computeAxis labels it',
      () {
        // As with Kotlin's Float data, 1f .. 1f is padded to 0 .. 2 plus 10 % space (-0.2 .. 2.2) and labelled
        // every 0.4 from 0 to 2.
        final yAxis = YAxis()..calculate(1.0, 1.0000000000000004);
        final entries = _compute(yAxis, yAxis.axisMinimum, yAxis.axisMaximum);
        expect(yAxis.entryCount, 6);
        for (var i = 0; i < 6; i++) {
          expect(entries[i], closeTo(i * 0.4, 1e-6));
        }
      },
      timeout: timeout,
    );

    test('a huge range below the Float ulp computes no labels', () {
      // The Float ulp at 3e38 is 2^104 (about 2e31): both ends round to the same Float.
      final yAxis = YAxis();
      _compute(yAxis, 3.0e38, 3.0e38 + 1e30);
      expect(yAxis.entryCount, 0);
    }, timeout: timeout);

    test(
      'an interval below half an ulp of the labels stops counting (Kotlin hangs)',
      () {
        // Adjacent Floats with about two billion labels: the interval is ~2^-30 of the Float ulp, below half the
        // double ulp of the label values, so adding it no longer changes them.
        for (final min in [1.0, 3.0e38]) {
          final max = _nextFloatUp(min);
          final yAxis = YAxis()
            ..axisMaxLabels = 0x7fffffff
            ..labelCount = 0x7fffffff;
          expect(yAxis.labelCount, 0x7fffffff);
          _compute(yAxis, min, max);
          expect(yAxis.entryCount, inInclusiveRange(1, 2), reason: '$min');
          for (var i = 0; i < yAxis.entryCount; i++) {
            expect(yAxis.entries[i], closeTo(min, max - min), reason: '$min');
          }
        }
      },
      timeout: timeout,
    );
  });
}

/// The next Float above the Float [value].
double _nextFloatUp(double value) {
  final bits = ByteData(4)..setFloat32(0, value);
  bits.setUint32(0, bits.getUint32(0) + 1);
  return bits.getFloat32(0);
}

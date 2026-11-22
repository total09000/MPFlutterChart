// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for the component defaults and setters, the
// YAxis.calculate branches, the non-finite axis ranges, Legend.calculateDimensions, the axis size helpers,
// Description, LimitLine or MarkerImage. Checks them against the Kotlin source (components/*.kt).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/components/description.dart';
import 'package:mp_flutter_chart/src/components/legend.dart';
import 'package:mp_flutter_chart/src/components/legend_entry.dart';
import 'package:mp_flutter_chart/src/components/limit_line.dart';
import 'package:mp_flutter_chart/src/components/marker_image.dart';
import 'package:mp_flutter_chart/src/components/x_axis.dart';
import 'package:mp_flutter_chart/src/components/y_axis.dart';
import 'package:mp_flutter_chart/src/formatter/default_axis_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_axis_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/chart_drawable.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/graphics/typeface.dart';
import 'package:mp_flutter_chart/src/utils/color_template.dart';
import 'package:mp_flutter_chart/src/utils/f_size.dart';
import 'package:mp_flutter_chart/src/utils/float_math.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

const ui.Color _GRAY = ui.Color(0xFF888888);
const double _MAX = kotlinFloatMaxValue;

/// A paint with fixed metrics: 10 px per character, a 12 px line (ascent -10, descent 2), no extra line spacing
/// beyond the 2 px Utils.getLineSpacing computes (ascent - top + bottom).
class _FakePaint extends ChartPaint {
  @override
  double measureText(String text) => 10.0 * text.length;

  @override
  MutableRect getTextBounds(String text, [MutableRect? bounds]) {
    final r = bounds ?? MutableRect();
    r.set(0, -10, 10.0 * text.length, 2);
    return r;
  }

  @override
  FontMetrics getFontMetrics([FontMetrics? metrics]) =>
      (metrics ?? FontMetrics())
        ..top = -10
        ..ascent = -10
        ..descent = 2
        ..bottom = 2
        ..leading = 0;
}

ViewPortHandler _viewPort(double width, double height) =>
    ViewPortHandler()..setChartDimens(width, height);

void main() {
  group('ComponentBase', () {
    test('defaults', () {
      final c = LimitLine(0);
      expect(c.isEnabled, isTrue);
      expect(c.xOffset, 5);
      expect(c.yOffset, 5);
      expect(c.typeface, isNull);
      expect(c.textSize, 10);
      expect(c.textColor, const ui.Color(0xFF000000));
      c.typeface = Typeface.DEFAULT_BOLD;
      expect(c.typeface, Typeface.DEFAULT_BOLD);
    });

    test(
      'textSize is clamped to 6..24 and NaN passes through like coerceIn',
      () {
        final c = XAxis();
        c.textSize = 30;
        expect(c.textSize, 24);
        c.textSize = 1;
        expect(c.textSize, 6);
        c.textSize = 12;
        expect(c.textSize, 12);
        c.textSize = double.nan;
        expect(c.textSize.isNaN, isTrue);
      },
    );
  });

  group('AxisBase', () {
    test('defaults', () {
      final axis = XAxis();
      expect(axis.gridColor, _GRAY);
      expect(axis.gridLineWidth, 0.5);
      expect(axis.axisLineColor, _GRAY);
      expect(axis.axisLineWidth, 0.5);
      expect(axis.entries, isA<Float32List>());
      expect(axis.entries, isEmpty);
      expect(axis.centeredEntries, isEmpty);
      expect(axis.entryCount, 0);
      expect(axis.decimals, 0);
      expect(axis.labelCount, 6);
      expect(axis.isForceLabelsEnabled, isFalse);
      expect(axis.granularity, 1);
      expect(axis.isGranularityEnabled, isFalse);
      expect(axis.isDrawGridLinesEnabled, isTrue);
      expect(axis.isDrawAxisLineEnabled, isTrue);
      expect(axis.isDrawLabelsEnabled, isTrue);
      expect(axis.isCenterAxisLabelsEnabled, isFalse);
      expect(axis.axisLineDashPathEffect, isNull);
      expect(axis.gridDashPathEffect, isNull);
      expect(axis.limitLines, isEmpty);
      expect(axis.isDrawLimitLinesBehindDataEnabled, isFalse);
      expect(axis.isDrawGridLinesBehindDataEnabled, isTrue);
      expect(axis.spaceMin, 0);
      expect(axis.spaceMax, 0);
      expect(axis.axisMinimum, 0);
      expect(axis.axisMaximum, 0);
      expect(axis.axisRange, 0);
      expect(axis.isAxisMinCustom, isFalse);
      expect(axis.isAxisMaxCustom, isFalse);
      expect(axis.axisMinLabels, 2);
      expect(axis.axisMaxLabels, 25);
      expect(axis.longestLabel, '');
    });

    test('labelCount is clamped to axisMinLabels..axisMaxLabels', () {
      final axis = XAxis();
      axis.labelCount = 1;
      expect(axis.labelCount, 2);
      axis.labelCount = 100;
      expect(axis.labelCount, 25);
      axis.axisMinLabels = 0;
      axis.axisMaxLabels = -3;
      expect(axis.axisMinLabels, 2);
      expect(axis.axisMaxLabels, 25);
      axis.axisMaxLabels = 10;
      axis.labelCount = 12;
      expect(axis.labelCount, 10);
    });

    test('assigning granularity enables it', () {
      final axis = XAxis();
      axis.granularity = 0.5;
      expect(axis.granularity, 0.5);
      expect(axis.isGranularityEnabled, isTrue);
    });

    test(
      'isCenterAxisLabelsEnabled reads false while there are no entries',
      () {
        final axis = XAxis();
        axis.isCenterAxisLabelsEnabled = true;
        expect(axis.isCenterAxisLabelsEnabled, isFalse);
        axis.entries = Float32List.fromList([1, 2]);
        axis.entryCount = 2;
        expect(axis.isCenterAxisLabelsEnabled, isTrue);
      },
    );

    test(
      'assigning axisMinimum / axisMaximum fixes them and updates axisRange',
      () {
        final axis = XAxis();
        axis.axisMaximum = 10;
        expect(axis.isAxisMaxCustom, isTrue);
        expect(axis.axisRange, 10);
        axis.axisMinimum = -5;
        expect(axis.isAxisMinCustom, isTrue);
        expect(axis.axisRange, 15);
        axis.calculate(100, 200);
        expect(axis.axisMinimum, -5);
        expect(axis.axisMaximum, 10);
        axis.resetAxisMaximum();
        expect(axis.isAxisMaxCustom, isFalse);
        axis.calculate(100, 200);
        expect(axis.axisMaximum, 200);
        expect(axis.axisRange, 205);
      },
    );

    test('applyAxisRange sets the range without fixing a limit', () {
      final axis = XAxis();
      axis.applyAxisRange(3, -1);
      expect(axis.axisMinimum, 3);
      expect(axis.axisMaximum, -1);
      expect(axis.axisRange, 4);
      expect(axis.isAxisMinCustom, isFalse);
      expect(axis.isAxisMaxCustom, isFalse);
    });

    test('limit lines are added, removed and cleared', () {
      final axis = XAxis();
      final a = LimitLine(1, 'a');
      final b = LimitLine(2);
      axis.addLimitLine(a);
      axis.addLimitLine(b);
      expect(axis.limitLines, [a, b]);
      axis.removeLimitLine(a);
      expect(axis.limitLines, [b]);
      axis.removeLimitLine(a);
      expect(axis.limitLines, [b]);
      axis.removeAllLimitLines();
      expect(axis.limitLines, isEmpty);
    });

    test('dashed grid and axis lines', () {
      final axis = XAxis();
      axis.enableGridDashedLine(4, 2, 1);
      expect(axis.isGridDashedLineEnabled, isTrue);
      expect(axis.gridDashPathEffect!.intervals, [4, 2]);
      expect(axis.gridDashPathEffect!.phase, 1);
      axis.disableGridDashedLine();
      expect(axis.isGridDashedLineEnabled, isFalse);

      axis.enableAxisLineDashedLine(3, 3, 0);
      expect(axis.isAxisLineDashedLineEnabled, isTrue);
      expect(axis.axisLineDashPathEffect!.intervals, [3, 3]);
      axis.disableAxisLineDashedLine();
      expect(axis.isAxisLineDashedLineEnabled, isFalse);
    });

    test('the default formatter follows decimals; an assigned one is kept', () {
      final axis = XAxis();
      final first = axis.valueFormatter;
      expect(first, isA<DefaultAxisValueFormatter>());
      expect((first as DefaultAxisValueFormatter).decimalDigits, 0);
      expect(axis.valueFormatter, same(first));

      axis.decimals = 2;
      final second = axis.valueFormatter as DefaultAxisValueFormatter;
      expect(second.decimalDigits, 2);
      expect(axis.valueFormatter, same(second));

      final custom = IAxisValueFormatter.fromFunction((v, a) => 'v$v');
      axis.valueFormatter = custom;
      axis.decimals = 3;
      expect(axis.valueFormatter, same(custom));
    });

    test(
      'getFormattedLabel and longestLabel read the first entryCount entries',
      () {
        final axis = XAxis();
        axis.entries = Float32List.fromList([1, 1000, 10, 123456]);
        axis.entryCount = 3;
        expect(axis.getFormattedLabel(0), '1');
        expect(axis.getFormattedLabel(1), '1,000');
        expect(axis.getFormattedLabel(-1), '');
        expect(axis.getFormattedLabel(3), '');
        expect(axis.longestLabel, '1,000');
      },
    );
  });

  group('non-finite axis ranges', () {
    // AxisBase.calculate / YAxis.calculate have no guards in Kotlin: they never throw or loop, they carry NaN and
    // infinity through. The data classes leave non-finite y values out of the range (DataSet.calcMinMaxY) and the
    // axis renderer computes no labels for an infinite or non-positive range (AxisRenderer.computeAxisValues).
    test('XAxis.calculate carries NaN and infinity through', () {
      final axis = XAxis();
      axis.calculate(double.nan, double.nan);
      expect(axis.axisMinimum.isNaN, isTrue);
      expect(axis.axisMaximum.isNaN, isTrue);
      expect(axis.axisRange.isNaN, isTrue);

      axis.calculate(double.negativeInfinity, double.infinity);
      expect(axis.axisMinimum, double.negativeInfinity);
      expect(axis.axisMaximum, double.infinity);
      expect(axis.axisRange, double.infinity);

      axis.calculate(double.infinity, double.infinity);
      expect(axis.axisRange.isNaN, isTrue);
    });

    test('YAxis.calculate carries NaN and infinity through', () {
      final axis = YAxis();
      axis.calculate(double.nan, double.nan);
      expect(axis.axisMinimum.isNaN, isTrue);
      expect(axis.axisMaximum.isNaN, isTrue);

      axis.calculate(double.negativeInfinity, double.infinity);
      expect(axis.axisMinimum, double.negativeInfinity);
      expect(axis.axisMaximum, double.infinity);
      expect(axis.axisRange, double.infinity);

      axis.calculate(double.infinity, double.infinity);
      expect(axis.axisMinimum.isNaN, isTrue);
      expect(axis.axisMaximum.isNaN, isTrue);

      axis.axisMaximum = 10;
      axis.calculate(double.nan, double.nan);
      expect(axis.axisMinimum.isNaN, isTrue);
      expect(axis.axisMaximum, 10);
    });

    test('the empty-range sentinel overflows the Float range like Kotlin', () {
      // An empty ChartData reports xMin == Float.MAX_VALUE and xMax == -Float.MAX_VALUE. In Kotlin's Float math
      // max - min overflows to -Infinity, which the axis renderer treats as "no labels".
      final x = XAxis();
      x.calculate(_MAX, -_MAX);
      expect(x.axisMinimum, _MAX);
      expect(x.axisMaximum, -_MAX);
      expect(x.axisRange, double.infinity);

      final y = YAxis();
      y.calculate(_MAX, -_MAX);
      expect(y.axisMinimum, double.negativeInfinity);
      expect(y.axisMaximum, double.infinity);
      expect(y.axisRange, double.infinity);
    });
  });

  group('XAxis', () {
    test('defaults', () {
      final axis = XAxis();
      expect(axis.labelWidth, 1);
      expect(axis.labelHeight, 1);
      expect(axis.labelRotatedWidth, 1);
      expect(axis.labelRotatedHeight, 1);
      expect(axis.labelRotationAngle, 0);
      expect(axis.isAvoidFirstLastClippingEnabled, isFalse);
      expect(axis.position, XAxisPosition.TOP);
      expect(axis.yOffset, 4);
      expect(axis.xOffset, 5);
      expect(XAxisPosition.values, [
        XAxisPosition.TOP,
        XAxisPosition.BOTTOM,
        XAxisPosition.BOTH_SIDED,
        XAxisPosition.TOP_INSIDE,
        XAxisPosition.BOTTOM_INSIDE,
      ]);
    });

    test(
      'calculate rounds the data range to Float, so a sub-Float range is padded like an empty one',
      () {
        // Kotlin's AxisBase.calculate(dataMin: Float, dataMax: Float): both ends are 1f, padded by 1 to 0 .. 2.
        final axis = XAxis()..calculate(1.0, 1.0000000000000004);
        expect(axis.axisMinimum, 0);
        expect(axis.axisMaximum, 2);
        expect(axis.axisRange, 2);
      },
    );
  });

  group('YAxis', () {
    test('defaults', () {
      final axis = YAxis();
      expect(axis.axisDependency, AxisDependency.LEFT);
      expect(YAxis(AxisDependency.RIGHT).axisDependency, AxisDependency.RIGHT);
      expect(axis.isDrawBottomYLabelEntryEnabled, isTrue);
      expect(axis.isDrawTopYLabelEntryEnabled, isTrue);
      expect(axis.isInverted, isFalse);
      expect(axis.isDrawZeroLineEnabled, isFalse);
      expect(axis.zeroLineColor, _GRAY);
      expect(axis.zeroLineWidth, 0.5);
      expect(axis.spaceTop, 10);
      expect(axis.spaceBottom, 10);
      expect(axis.labelPosition, YAxisLabelPosition.OUTSIDE_CHART);
      expect(axis.labelXOffset, 0);
      expect(axis.labelRotationAngle, 0);
      expect(axis.minWidth, 0);
      expect(axis.maxWidth, double.infinity);
      expect(axis.yOffset, 0);
      expect(axis.xOffset, 5);
    });

    test('calculate widens an empty range and adds the percentage space', () {
      final axis = YAxis();
      axis.calculate(5, 5);
      expect(axis.axisMinimum, closeTo(3.8, 1e-4));
      expect(axis.axisMaximum, closeTo(6.2, 1e-4));
    });

    test(
      'calculate rounds the data range to Float, so a sub-Float range is padded like an empty one',
      () {
        // Kotlin's calculate(dataMin: Float, dataMax: Float): both ends are 1f, the range is 0 and gets padded by
        // max(1, 1 / 100) to 0 .. 2, then 10 % space: (2 / 100) * 10 below and above.
        final axis = YAxis()..calculate(1.0, 1.0000000000000004);
        expect(axis.axisMinimum, closeTo(-0.2, 1e-6));
        expect(axis.axisMaximum, closeTo(2.2, 1e-6));
        expect(axis.axisRange, closeTo(2.4, 1e-6));
      },
    );

    test('calculate with min above max and both limits fixed swaps them', () {
      final axis = YAxis();
      axis.axisMinimum = 0;
      axis.axisMaximum = 100;
      axis.calculate(50, 10);
      expect(axis.axisMinimum, 0);
      expect(axis.axisMaximum, 100);
      expect(axis.axisRange, 100);
    });

    test(
      'calculate with data below a fixed maximum derives the minimum from it',
      () {
        final axis = YAxis();
        axis.axisMaximum = 10;
        axis.calculate(50, 20);
        expect(axis.axisMaximum, 10);
        expect(axis.axisMinimum, closeTo(9, 1e-4));

        final negative = YAxis();
        negative.axisMaximum = 10;
        negative.calculate(50, -20);
        expect(negative.axisMinimum, closeTo(-31, 1e-4));
      },
    );

    test(
      'calculate with data above a fixed minimum derives the maximum from it',
      () {
        final axis = YAxis();
        axis.axisMinimum = -10;
        axis.calculate(-5, -20);
        expect(axis.axisMinimum, -10);
        expect(axis.axisMaximum, closeTo(-2.25, 1e-4));

        final positive = YAxis();
        positive.axisMinimum = -10;
        positive.calculate(4, -20);
        expect(positive.axisMaximum, closeTo(6.2, 1e-4));
      },
    );

    test(
      'getRequiredWidthSpace measures the longest label plus xOffset on both sides',
      () {
        final paint = _FakePaint();
        final axis = YAxis();
        axis.entries = Float32List.fromList([0, 100]);
        axis.entryCount = 2;
        axis.textSize = 12;

        expect(axis.getRequiredWidthSpace(paint), closeTo(40, 1e-4));
        expect(paint.textSize, 12);

        axis.minWidth = 50;
        expect(axis.getRequiredWidthSpace(paint), closeTo(50, 1e-4));
        axis.minWidth = 0;
        axis.maxWidth = 35;
        expect(axis.getRequiredWidthSpace(paint), closeTo(35, 1e-4));
        axis.maxWidth = double.infinity;

        // Rotated by 90 degrees the width is the line height (12) plus the offsets.
        axis.labelRotationAngle = 90;
        expect(axis.getRequiredWidthSpace(paint), closeTo(22, 1e-4));
      },
    );

    test(
      'getRequiredHeightSpace is the label height plus yOffset on both sides',
      () {
        final paint = _FakePaint();
        final axis = YAxis();
        axis.entries = Float32List.fromList([0, 100]);
        axis.entryCount = 2;
        expect(axis.getRequiredHeightSpace(paint), closeTo(12, 1e-4));
        axis.yOffset = 3;
        expect(axis.getRequiredHeightSpace(paint), closeTo(18, 1e-4));
      },
    );

    test('needsOffset', () {
      final axis = YAxis();
      expect(axis.needsOffset, isTrue);
      axis.labelPosition = YAxisLabelPosition.INSIDE_CHART;
      expect(axis.needsOffset, isFalse);
      axis.labelPosition = YAxisLabelPosition.OUTSIDE_CHART;
      axis.isDrawLabelsEnabled = false;
      expect(axis.needsOffset, isFalse);
      axis.isDrawLabelsEnabled = true;
      axis.isEnabled = false;
      expect(axis.needsOffset, isFalse);
    });
  });

  group('Legend', () {
    test('defaults', () {
      final legend = Legend();
      expect(legend.entries, isEmpty);
      expect(legend.extraEntries, isEmpty);
      expect(legend.isLegendCustom, isFalse);
      expect(legend.horizontalAlignment, LegendHorizontalAlignment.LEFT);
      expect(legend.verticalAlignment, LegendVerticalAlignment.BOTTOM);
      expect(legend.orientation, LegendOrientation.HORIZONTAL);
      expect(legend.isDrawInsideEnabled, isFalse);
      expect(legend.direction, LegendDirection.LEFT_TO_RIGHT);
      expect(legend.form, LegendForm.SQUARE);
      expect(legend.formSize, 8);
      expect(legend.formLineWidth, 3);
      expect(legend.formLineDashEffect, isNull);
      expect(legend.xEntrySpace, 6);
      expect(legend.yEntrySpace, 0);
      expect(legend.formToTextSpace, 5);
      expect(legend.stackSpace, 3);
      expect(legend.maxSizePercent, closeTo(0.95, 1e-6));
      expect(legend.isWordWrapEnabled, isFalse);
      expect(legend.neededWidth, 0);
      expect(legend.neededHeight, 0);
      expect(legend.textHeightMax, 0);
      expect(legend.textWidthMax, 0);
      expect(legend.textSize, 10);
      expect(legend.xOffset, 5);
      expect(legend.yOffset, 3);
    });

    test('the entries constructor makes a custom legend', () {
      final legend = Legend([LegendEntry('a')]);
      expect(legend.isLegendCustom, isTrue);
      expect(legend.entries.single.label, 'a');
    });

    test('setComputedEntries keeps the custom flag', () {
      final legend = Legend();
      legend.setComputedEntries([LegendEntry('computed')]);
      expect(legend.isLegendCustom, isFalse);
      expect(legend.entries.single.label, 'computed');

      legend.entries = [LegendEntry('custom')];
      legend.setComputedEntries([LegendEntry('computed')]);
      expect(legend.isLegendCustom, isTrue);
      expect(legend.entries.single.label, 'computed');
    });

    test(
      'setExtra maps the sentinel colors to forms and drops surplus items',
      () {
        final legend = Legend();
        legend.setExtra(
          [
            ColorTemplate.COLOR_SKIP,
            ColorTemplate.COLOR_NONE,
            const ui.Color(0xFF00FF00),
            const ui.Color(0xFF0000FF),
          ],
          ['skip', 'none', 'green'],
        );
        expect(legend.extraEntries.length, 3);
        expect(legend.extraEntries[0].form, LegendForm.NONE);
        expect(legend.extraEntries[1].form, LegendForm.EMPTY);
        expect(legend.extraEntries[2].form, LegendForm.DEFAULT);
        expect(legend.extraEntries[2].formColor, const ui.Color(0xFF00FF00));
        expect(legend.extraEntries[2].label, 'green');
      },
    );

    test('getMaximumEntryWidth / Height', () {
      final paint = _FakePaint();
      final legend = Legend([
        LegendEntry('AB'),
        LegendEntry(null, LegendForm.DEFAULT, 12),
        LegendEntry('ABCD'),
      ]);
      expect(legend.getMaximumEntryWidth(paint), closeTo(40 + 12 + 5, 1e-4));
      expect(legend.getMaximumEntryHeight(paint), closeTo(12, 1e-4));
    });

    test('calculateDimensions for a vertical legend', () {
      final paint = _FakePaint();
      final legend = Legend([LegendEntry('AB'), LegendEntry('ABCD')]);
      legend.orientation = LegendOrientation.VERTICAL;
      legend.calculateDimensions(paint, _viewPort(200, 100));
      expect(legend.textWidthMax, closeTo(53, 1e-4));
      expect(legend.textHeightMax, closeTo(12, 1e-4));
      expect(legend.neededWidth, closeTo(53 + 5, 1e-4));
      expect(legend.neededHeight, closeTo(24 + 3, 1e-4));
    });

    test('calculateDimensions for a vertical legend with a stacked form', () {
      final paint = _FakePaint();
      final legend = Legend([LegendEntry(null), LegendEntry('AB')]);
      legend.orientation = LegendOrientation.VERTICAL;
      legend.calculateDimensions(paint, _viewPort(200, 100));
      expect(legend.neededWidth, closeTo(30 + 5, 1e-4));
      expect(legend.neededHeight, closeTo(24 + 3, 1e-4));
    });

    test('calculateDimensions for a horizontal legend on one row', () {
      final paint = _FakePaint();
      final legend = Legend([LegendEntry('AB'), LegendEntry('ABCD')]);
      legend.calculateDimensions(paint, _viewPort(200, 100));
      expect(legend.calculatedLabelSizes.map((s) => [s.width, s.height]), [
        [20, 12],
        [40, 12],
      ]);
      expect(legend.calculatedLabelBreakPoints, [false, false]);
      expect(legend.calculatedLineSizes.map((s) => [s.width, s.height]), [
        [92, 12],
      ]);
      expect(legend.neededWidth, closeTo(92 + 5, 1e-4));
      expect(legend.neededHeight, closeTo(12 + 3, 1e-4));
    });

    test(
      'calculateDimensions wraps a horizontal legend at maxSizePercent of the content width',
      () {
        final paint = _FakePaint();
        final legend = Legend([
          LegendEntry('ABCD'),
          LegendEntry('ABCD'),
          LegendEntry('ABCD'),
        ]);
        legend.isWordWrapEnabled = true;
        legend.calculateDimensions(paint, _viewPort(100, 100));
        expect(legend.calculatedLabelBreakPoints, [false, true, true]);
        expect(legend.calculatedLineSizes.map((s) => [s.width, s.height]), [
          [53, 12],
          [53, 12],
          [53, 12],
        ]);
        expect(legend.neededWidth, closeTo(53 + 5, 1e-4));
        // 12 for the first row, then (line height 12 + line spacing 2) per further row, plus yOffset 3.
        expect(legend.neededHeight, closeTo(12 + 14 * 2 + 3, 1e-4));

        // Recomputing clears the lists first.
        legend.calculateDimensions(paint, _viewPort(1000, 100));
        expect(legend.calculatedLabelBreakPoints, [false, false, false]);
        expect(legend.calculatedLineSizes.length, 1);
      },
    );

    test('calculateDimensions with no entries', () {
      final legend = Legend();
      legend.calculateDimensions(_FakePaint(), _viewPort(100, 100));
      expect(legend.calculatedLineSizes, isEmpty);
      expect(legend.neededWidth, closeTo(5, 1e-4));
      expect(legend.neededHeight, closeTo(12 + 3, 1e-4));
    });
  });

  group('LegendEntry', () {
    test('defaults', () {
      final e = LegendEntry();
      expect(e.label, isNull);
      expect(e.form, LegendForm.DEFAULT);
      expect(e.formSize.isNaN, isTrue);
      expect(e.formLineWidth.isNaN, isTrue);
      expect(e.formLineDashEffect, isNull);
      expect(e.formColor, ColorTemplate.COLOR_NONE);
    });
  });

  group('Description', () {
    test('defaults and setPosition', () {
      final d = Description();
      expect(d.text, 'Description Label');
      expect(d.position, isNull);
      expect(d.textAlign, PaintAlign.RIGHT);
      expect(d.textSize, 8);
      d.setPosition(1, 2);
      final p = d.position!;
      expect([p.x, p.y], [1, 2]);
      d.setPosition(3, 4);
      expect(d.position, same(p));
      expect([p.x, p.y], [3, 4]);
    });
  });

  group('LimitLine', () {
    test('defaults, clamped lineWidth and dashes', () {
      final l = LimitLine(42, 'target');
      expect(l.limit, 42);
      expect(l.label, 'target');
      expect(LimitLine(1).label, '');
      expect(l.lineWidth, 1);
      expect(l.lineColor, const ui.Color.fromARGB(255, 237, 91, 91));
      expect(l.textStyle, PaintStyle.FILL_AND_STROKE);
      expect(l.dashPathEffect, isNull);
      expect(l.labelPosition, LimitLabelPosition.RIGHT_TOP);

      l.lineWidth = 20;
      expect(l.lineWidth, 12);
      l.lineWidth = 0.1;
      expect(l.lineWidth, closeTo(0.2, 1e-6));

      l.enableDashedLine(5, 1, 0);
      expect(l.isDashedLineEnabled, isTrue);
      expect(l.dashPathEffect!.intervals, [5, 1]);
      l.disableDashedLine();
      expect(l.isDashedLineEnabled, isFalse);
    });
  });

  group('MarkerImage', () {
    test('clamps the drawable into the chart and draws it at its size', () {
      final drawn = <ui.Size>[];
      final drawable = PainterDrawable(
        (canvas, size) => drawn.add(size),
        width: 30,
        height: 10,
      );
      final marker = MarkerImage(drawable);
      expect(marker.offset.x, 0);
      expect(marker.size, FSize(0, 0));
      expect(marker.chartView, isNull);

      // Without a chart only the left and top edge clamp.
      marker.setOffset(-50, -50);
      final unclamped = marker.getOffsetForDrawingAtPoint(10, 20);
      expect([unclamped.x, unclamped.y], [-10, -20]);

      marker.setOffset(0, 0);
      // The marker holds the chart weakly; the local keeps it alive and is used last.
      final chart = LineChart()..onSizeChanged(100, 100);
      marker.chartView = chart;
      final offset = marker.getOffsetForDrawingAtPoint(90, 95);
      expect(offset.x, closeTo(-20, 1e-4));
      expect(offset.y, closeTo(-5, 1e-4));

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      marker.draw(canvas, 90, 95);
      expect(canvas.getTransform()[12], 0);
      recorder.endRecording().dispose();
      expect(drawn, [const ui.Size(30, 10)]);

      // A set size wins over the intrinsic size and is truncated to whole pixels like Kotlin's toInt().
      marker.size = FSize(12.7, 0);
      final recorder2 = ui.PictureRecorder();
      marker.draw(ui.Canvas(recorder2), 10, 10);
      recorder2.endRecording().dispose();
      expect(drawn.last, const ui.Size(12, 10));
      expect(marker.chartView, same(chart));
    });
  });
}

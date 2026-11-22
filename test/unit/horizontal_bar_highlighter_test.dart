// Not a port of a Kotlin test: MPAndroidChart has no unit test for HorizontalBarHighlighter.kt. Locks the bar and the
// stack value a touch selects with the axes swapped, the vertical-only distance, and the swapped pixels of
// buildHighlights.
//
// The fake prepares horizontal bar transformers on a 400 x 300 content rect, as HorizontalBarChart.prepareValuePxMatrix
// does: the bar value runs along the screen's x and the x value along the screen's y. x 0..10 → 300..0 px (30 px per
// x); left values −10..10 → 0..400 px (20 px per value); right values 0..100 → 0..400 px (4 px per value). Touches are
// computed from values through them.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/data_set.dart';
import 'package:mp_flutter_chart/src/highlight/bar_highlighter.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/highlight/horizontal_bar_highlighter.dart';
import 'package:mp_flutter_chart/src/interfaces/datasets/i_data_set.dart';
import 'package:mp_flutter_chart/src/utils/horizontal_view_port_handler.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_d.dart';
import 'package:mp_flutter_chart/src/utils/transformer_horizontal_bar_chart.dart';

import 'support/fake_providers.dart';

/// Exposes the protected members of [HorizontalBarHighlighter] to the tests.
class _TestHorizontalBarHighlighter extends HorizontalBarHighlighter {
  _TestHorizontalBarHighlighter(super.chart);

  List<Highlight> build(
    IDataSet set,
    int dataSetIndex,
    double xVal,
    Rounding rounding,
  ) => buildHighlights(set, dataSetIndex, xVal, rounding);

  List<Highlight> atXValue(double xVal, double x, double y) =>
      getHighlightsAtXValue(xVal, x, y);

  double distance(double x1, double y1, double x2, double y2) =>
      getDistance(x1, y1, x2, y2);
}

/// [inverted] mirrors the values of both axes along the screen's x, as HorizontalBarChart does for an inverted axis.
FakeBarChart _chart(List<BarDataSet> sets, {bool inverted = false}) {
  final handler = HorizontalViewPortHandler()..setChartDimens(400, 300);
  final left = TransformerHorizontalBarChart(handler)
    ..prepareMatrixValuePx(-10, 20, 10, 0)
    ..prepareMatrixOffset(inverted);
  final right = TransformerHorizontalBarChart(handler)
    ..prepareMatrixValuePx(0, 100, 10, 0)
    ..prepareMatrixOffset(inverted);
  return FakeBarChart(
    BarData(sets),
    handler: handler,
    left: left,
    right: right,
    isInverted: inverted,
  );
}

/// The screen position of the bar value [y] at the x value [x] on [axis]: the transformers of the horizontal bar
/// chart take the value first.
MPPointD _px(
  FakeBarChart chart,
  double x,
  double y, [
  AxisDependency axis = AxisDependency.LEFT,
]) => chart.getTransformer(axis).getPixelForValues(y, x);

/// A touch at the screen position [screen], passed on the way `HorizontalBarChart.getHighlightByTouchPoint(x, y)`
/// does: as `getHighlight(y, x)`, which the highlighter swaps back.
Highlight? _touch(HorizontalBarHighlighter highlighter, MPPointD screen) =>
    highlighter.getHighlight(screen.y, screen.x);

void main() {
  test(
    'a touch selects the bar at its x, whose pixels are those of the value and of x',
    () {
      final chart = _chart([
        BarDataSet([BarEntry(x: 2, y: 5), BarEntry(x: 5, y: -4)], 'plain'),
      ]);
      final highlighter = HorizontalBarHighlighter(chart);

      final h = _touch(highlighter, _px(chart, 2, 5))!;
      expect(h.x, 2);
      expect(h.y, 5);
      expect(h.stackIndex, -1);
      expect(h.isStacked, isFalse);
      expect(h.dataSetIndex, 0);
      expect(h.axis, AxisDependency.LEFT);
      // (300, 240) px: the value 5 along the screen's x, the x value 2 along its y.
      expect(h.xPx, closeTo(300, 1e-4));
      expect(h.yPx, closeTo(240, 1e-4));

      // Only the vertical position counts: a touch far along the value axis still selects the bar at that x.
      final far = _touch(highlighter, _px(chart, 2.2, -9))!;
      expect(far.x, 2);
      expect(far.xPx, closeTo(_px(chart, 2, 5).x, 1e-4));

      final other = _touch(highlighter, _px(chart, 4.9, 0))!;
      expect(other.x, 5);
      expect(other.y, -4);
      expect(other.xPx, closeTo(_px(chart, 5, -4).x, 1e-4));
      expect(other.yPx, closeTo(_px(chart, 5, -4).y, 1e-4));

      chart.barData = null;
      expect(_touch(highlighter, _px(chart, 2, 5)), isNull);
    },
  );

  test(
    'on a stacked bar the horizontal position of the touch selects the stack value',
    () {
      // Ranges of [2, -3, 5]: (0, 2], (-3, 0], (2, 7].
      final entry = BarEntry.stacked(x: 5, stackValues: [2, -3, 5]);
      final chart = _chart([
        BarDataSet([entry], 'stack'),
      ]);
      final highlighter = HorizontalBarHighlighter(chart);
      final left = chart.getTransformer(AxisDependency.LEFT);

      for (final touchX in [4.8, 5.2]) {
        for (final (touchValue, stackIndex) in [
          (1.0, 0),
          (-1.0, 1),
          (6.0, 2),
          // Beyond the last range: the last index.
          (8.0, 2),
          // Below every range: 0.
          (-5.0, 0),
        ]) {
          final h = _touch(highlighter, _px(chart, touchX, touchValue))!;
          final reason = 'touch at x $touchX, value $touchValue';
          expect(h.stackIndex, stackIndex, reason: reason);
          expect(h.isStacked, isTrue, reason: reason);
          expect(h.x, 5, reason: reason);
          expect(h.y, closeTo(4, 1e-4), reason: reason);
          expect(h.dataSetIndex, 0, reason: reason);
          expect(h.axis, AxisDependency.LEFT, reason: reason);

          // As in Kotlin, getStackedHighlight is BarHighlighter's: its pixels are those of (x, top of the stack value)
          // passed in the vertical bar chart's order, not the bar's on screen. The renderer sets the drawn position.
          final pixels = left.getPixelForValues(
            5,
            entry.ranges![stackIndex].to,
          );
          expect(h.xPx, closeTo(pixels.x, 1e-4), reason: reason);
          expect(h.yPx, closeTo(pixels.y, 1e-4), reason: reason);
        }
      }
    },
  );

  test(
    'with the axes inverted the touch is read back through the mirrored transformer: the bar and the stack value '
    'under it are selected',
    () {
      // Ranges of [2, -3, 5]: (0, 2], (-3, 0], (2, 7]. Left values −10..10 now run 400..0 px.
      final entry = BarEntry.stacked(x: 5, stackValues: [2, -3, 5]);
      final chart = _chart([
        BarDataSet([BarEntry(x: 2, y: 5)], 'plain'),
        BarDataSet([entry], 'stack'),
      ], inverted: true);
      final highlighter = HorizontalBarHighlighter(chart);
      final left = chart.getTransformer(AxisDependency.LEFT);
      expect(_px(chart, 2, 5).x, closeTo(100, 1e-4));

      final plain = _touch(highlighter, _px(chart, 2, 5))!;
      expect(plain.x, 2);
      expect(plain.dataSetIndex, 0);
      expect(plain.stackIndex, -1);
      expect(plain.xPx, closeTo(100, 1e-4));
      expect(plain.yPx, closeTo(240, 1e-4));

      for (final (touchValue, stackIndex) in [
        (1.0, 0),
        (-1.0, 1),
        (6.0, 2),
        (8.0, 2),
        (-5.0, 0),
      ]) {
        final h = _touch(highlighter, _px(chart, 5.1, touchValue))!;
        final reason = 'touch at value $touchValue';
        expect(h.dataSetIndex, 1, reason: reason);
        expect(h.stackIndex, stackIndex, reason: reason);
        final pixels = left.getPixelForValues(5, entry.ranges![stackIndex].to);
        expect(h.xPx, closeTo(pixels.x, 1e-4), reason: reason);
        expect(h.yPx, closeTo(pixels.y, 1e-4), reason: reason);
      }
    },
  );

  test(
    'a plain entry in a stacked set keeps the highlight of buildHighlights through the inherited getStackedHighlight',
    () {
      final chart = _chart([
        BarDataSet([
          BarEntry.stacked(x: 1, stackValues: [2, 3]),
          BarEntry(x: 3, y: 4),
        ], 'stack'),
      ]);
      final highlighter = HorizontalBarHighlighter(chart);

      final h = _touch(highlighter, _px(chart, 3.1, -8))!;
      expect(h.x, 3);
      expect(h.y, 4);
      expect(h.stackIndex, -1);
      expect(h.isStacked, isFalse);
      // The swapped pixels of buildHighlights: the value along the screen's x, the x value along its y.
      expect(h.xPx, closeTo(_px(chart, 3, 4).x, 1e-4));
      expect(h.yPx, closeTo(_px(chart, 3, 4).y, 1e-4));

      // The stacked entry of the same set still gets its stack value.
      expect(_touch(highlighter, _px(chart, 1, 4))?.stackIndex, 1);
    },
  );

  test('getDistance is the vertical distance only', () {
    final highlighter = _TestHorizontalBarHighlighter(_chart([]));
    expect(highlighter.distance(0, 0, 100, 3), 3);
    expect(highlighter.distance(100, 3, 0, 0), 3);
    expect(highlighter.distance(-50, 1, 50, 1), 0);
  });

  test(
    'the nearest-candidate filter of BarHighlighter keeps the candidates vertically nearest to the touch',
    () {
      // (4.8, 5) on the left axis is at (300, 156) px; (5.2, 50) on the right axis at (200, 144) px.
      final chart = _chart([
        BarDataSet([BarEntry(x: 4.8, y: 5)], 'left'),
        BarDataSet([BarEntry(x: 5.2, y: 50)], 'right')
          ..axisDependency = AxisDependency.RIGHT,
      ]);
      final highlighter = _TestHorizontalBarHighlighter(chart);

      // Touch (5.1, 5) on the left axis, at (300, 147) px: the right bar is 3 px away, the left one 9 px.
      final touch = _px(chart, 5.1, 5);
      expect(
        highlighter
            .atXValue(5.1, touch.x, touch.y)
            .map((h) => h.dataSetIndex)
            .toList(),
        [1],
      );
      expect(_touch(highlighter, touch)?.dataSetIndex, 1);
    },
  );

  test(
    'buildHighlights gives the pixel of the value as xPx and the pixel of x as yPx',
    () {
      final leftSet = BarDataSet([
        BarEntry(x: 2, y: 5),
        BarEntry(x: 4, y: -3),
      ], 'left');
      final rightSet = BarDataSet([BarEntry(x: 2, y: 50)], 'right')
        ..axisDependency = AxisDependency.RIGHT;
      final chart = _chart([leftSet, rightSet]);
      final highlighter = _TestHorizontalBarHighlighter(chart);

      final exact = highlighter.build(leftSet, 0, 2, Rounding.CLOSEST);
      expect(exact, hasLength(1));
      expect(exact.single.x, 2);
      expect(exact.single.y, 5);
      expect(exact.single.xPx, closeTo(300, 1e-4));
      expect(exact.single.yPx, closeTo(240, 1e-4));
      expect(exact.single.dataSetIndex, 0);
      expect(exact.single.axis, AxisDependency.LEFT);

      // No entry at 3.8: the closest x value, 4, is used.
      final closest = highlighter.build(leftSet, 0, 3.8, Rounding.CLOSEST);
      expect(closest.single.x, 4);
      expect(closest.single.y, -3);
      expect(closest.single.xPx, closeTo(140, 1e-4));
      expect(closest.single.yPx, closeTo(180, 1e-4));

      // A set on the right axis is converted with the right transformer.
      final right = highlighter.build(rightSet, 1, 2, Rounding.CLOSEST);
      expect(right.single.xPx, closeTo(200, 1e-4));
      expect(right.single.yPx, closeTo(240, 1e-4));
      expect(right.single.dataSetIndex, 1);
      expect(right.single.axis, AxisDependency.RIGHT);

      expect(
        highlighter.build(BarDataSet([], 'empty'), 2, 2, Rounding.CLOSEST),
        isEmpty,
      );
    },
  );

  test('a HorizontalBarHighlighter is a BarHighlighter', () {
    expect(HorizontalBarHighlighter(_chart([])), isA<BarHighlighter>());
  });
}

// Not a port of a Kotlin test (task brief): MPAndroidChart's only BarHighlighter test is HighlighterTest.kt's
// grouped-bar case, ported in highlighter_test.dart. Locks the stack value a touch selects and its pixel position, the
// plain-bar and empty-stack paths, the horizontal-only distance and the nearest-candidate filter.
//
// The fake prepares real transformers on a 400 x 300 content rect: x 0..10 → 0..400 px (40 px per x); left y −10..10
// → 300..0 px (15 px per y); right y 0..100 → 300..0 px (3 px per y). Touches are computed from values through them.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_flutter_chart/src/highlight/bar_highlighter.dart';
import 'package:mp_flutter_chart/src/highlight/chart_highlighter.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/highlight/range.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_d.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import 'support/fake_providers.dart';

/// Exposes the protected members of [BarHighlighter] to the tests.
class _TestBarHighlighter extends BarHighlighter {
  _TestBarHighlighter(super.chart);

  int closestStackIndex(List<Range>? ranges, double value) =>
      getClosestStackIndex(ranges, value);

  List<Highlight> atXValue(double xVal, double x, double y) =>
      getHighlightsAtXValue(xVal, x, y);

  double distance(double x1, double y1, double x2, double y2) =>
      getDistance(x1, y1, x2, y2);

  List<Highlight> get buffer => highlightBuffer;

  BarLineScatterCandleBubbleData? get exposedData => data;
}

/// Counts the calls of [getDistance].
class _CountingBarHighlighter extends _TestBarHighlighter {
  _CountingBarHighlighter(super.chart);

  int distances = 0;

  @override
  double getDistance(double x1, double y1, double x2, double y2) {
    distances++;
    return super.getDistance(x1, y1, x2, y2);
  }
}

FakeBarChart _chart(List<BarDataSet> sets) {
  final handler = ViewPortHandler()..setChartDimens(400, 300);
  final left = Transformer(handler)
    ..prepareMatrixValuePx(0, 10, 20, -10)
    ..prepareMatrixOffset(false);
  final right = Transformer(handler)
    ..prepareMatrixValuePx(0, 10, 100, 0)
    ..prepareMatrixOffset(false);
  return FakeBarChart(
    BarData(sets),
    handler: handler,
    left: left,
    right: right,
  );
}

/// The pixel position of the values ([x], [y]) on [axis].
MPPointD _px(
  FakeBarChart chart,
  double x,
  double y, [
  AxisDependency axis = AxisDependency.LEFT,
]) => chart.getTransformer(axis).getPixelForValues(x, y);

void main() {
  test(
    'a touch on a stacked bar selects the stack value at its y, with the pixel y of that value\'s top',
    () {
      // Ranges of [2, -3, 5]: (0, 2], (-3, 0], (2, 7].
      final entry = BarEntry.stacked(x: 5, stackValues: [2, -3, 5]);
      final chart = _chart([
        BarDataSet([entry], 'stack'),
      ]);
      final highlighter = BarHighlighter(chart);

      for (final (touchY, stackIndex) in [
        (1.0, 0),
        (-1.0, 1),
        (6.0, 2),
        // Beyond the last range: the last index.
        (8.0, 2),
        // Below every range: 0.
        (-5.0, 0),
      ]) {
        final touch = _px(chart, 5.1, touchY);
        final h = highlighter.getHighlight(touch.x, touch.y)!;
        final reason = 'touch y $touchY';
        expect(h.stackIndex, stackIndex, reason: reason);
        expect(h.isStacked, isTrue, reason: reason);
        expect(
          h.yPx,
          closeTo(_px(chart, 5, entry.ranges![stackIndex].to).y, 1e-4),
          reason: reason,
        );
        expect(h.xPx, closeTo(_px(chart, 5, 0).x, 1e-4), reason: reason);
        expect(h.x, 5, reason: reason);
        expect(h.y, closeTo(4, 1e-4), reason: reason);
        expect(h.dataSetIndex, 0, reason: reason);
        expect(h.axis, AxisDependency.LEFT, reason: reason);
      }
    },
  );

  test(
    'a stacked set on the right axis has its touch y read on the left transformer, as in MPAndroidChart v4.0.1',
    () {
      // Ranges of [20, 30, 50]: (0, 20], (20, 50], (50, 100].
      final entry = BarEntry.stacked(x: 5, stackValues: [20, 30, 50]);
      final chart = _chart([
        BarDataSet([entry], 'right stack')
          ..axisDependency = AxisDependency.RIGHT,
      ]);

      // A touch at 60 on the right axis, inside the third stack value, is at 120 px.
      final touch = _px(chart, 5.1, 60, AxisDependency.RIGHT);
      expect(touch.y, closeTo(120, 1e-4));
      expect(entry.ranges![2].contains(60), isTrue);
      // getValsForTouch reads that pixel on the left axis, where it is 2.
      final onLeft = chart
          .getTransformer(AxisDependency.LEFT)
          .getValuesByTouchPoint(touch.x, touch.y);
      expect(onLeft.y, closeTo(2, 1e-4));

      final h = BarHighlighter(chart).getHighlight(touch.x, touch.y)!;

      // So the first stack value, which holds 2, is selected instead of the third, and the highlight sits at its
      // top: 20 on the right axis, 240 px.
      expect(h.stackIndex, 0);
      expect(h.yPx, closeTo(_px(chart, 5, 20, AxisDependency.RIGHT).y, 1e-4));
      expect(h.yPx, closeTo(240, 1e-4));
      expect(h.axis, AxisDependency.RIGHT);
      expect(h.dataSetIndex, 0);
    },
  );

  test(
    'a touch on a plain bar returns the ChartHighlighter result, stack index -1',
    () {
      final chart = _chart([
        BarDataSet([BarEntry(x: 2, y: 6), BarEntry(x: 5, y: -4)], 'plain'),
      ]);
      final touch = _px(chart, 5.1, 3);

      final h = BarHighlighter(chart).getHighlight(touch.x, touch.y)!;
      final parent = ChartHighlighter(chart).getHighlight(touch.x, touch.y)!;

      expect(h.stackIndex, -1);
      expect(h.isStacked, isFalse);
      expect(h.x, parent.x);
      expect(h.y, parent.y);
      expect(h.xPx, parent.xPx);
      expect(h.yPx, parent.yPx);
      expect(h.dataSetIndex, parent.dataSetIndex);
      expect(h.axis, parent.axis);
      expect(h.x, 5);
      expect(h.y, -4);
      expect(h.yPx, closeTo(_px(chart, 5, -4).y, 1e-4));
    },
  );

  test(
    'in a stacked set, a plain entry keeps the parent highlight and an empty stack gives null',
    () {
      final chart = _chart([
        BarDataSet([
          BarEntry.stacked(x: 2, stackValues: [1, 2]),
          BarEntry(x: 5, y: 3),
          BarEntry.stacked(x: 8, stackValues: []),
        ], 'mixed'),
      ]);
      final highlighter = BarHighlighter(chart);

      final plainTouch = _px(chart, 5, 1);
      final plain = highlighter.getHighlight(plainTouch.x, plainTouch.y)!;
      expect(plain.x, 5);
      expect(plain.y, 3);
      expect(plain.stackIndex, -1);
      expect(plain.yPx, closeTo(_px(chart, 5, 3).y, 1e-4));

      final emptyTouch = _px(chart, 8, 1);
      expect(highlighter.getHighlight(emptyTouch.x, emptyTouch.y), isNull);

      // The stacked entry still resolves: 2.5 lies in (1, 3].
      final stackedTouch = _px(chart, 2, 2.5);
      final stacked = highlighter.getHighlight(stackedTouch.x, stackedTouch.y)!;
      expect(stacked.stackIndex, 1);
    },
  );

  test('getDistance is the horizontal distance only', () {
    final highlighter = _TestBarHighlighter(_chart([]));
    expect(highlighter.distance(0, 0, 3, 100), 3);
    expect(highlighter.distance(3, 100, 0, 0), 3);
    expect(highlighter.distance(1, -50, 1, 50), 0);
  });

  test(
    'getHighlightsAtXValue keeps only the candidates horizontally nearest to the touch',
    () {
      // (4.8, 5) on the left axis is at (192, 75) px; (5.2, 50) on the right axis at (208, 150) px.
      final chart = _chart([
        BarDataSet([BarEntry(x: 4.8, y: 5)], 'left'),
        BarDataSet([BarEntry(x: 5.2, y: 50)], 'right')
          ..axisDependency = AxisDependency.RIGHT,
      ]);
      final highlighter = _TestBarHighlighter(chart);

      // Touch (5.1, 5) on the left axis, at (204, 75) px: the right bar is 4 px away, the left one 12 px.
      final touch = _px(chart, 5.1, 5);
      final nearest = highlighter.atXValue(5.1, touch.x, touch.y);
      expect(nearest, same(highlighter.buffer));
      expect(nearest.map((h) => h.dataSetIndex).toList(), [1]);

      // So the right bar is selected, although ChartHighlighter picks the left axis, whose bar is at the touch's y.
      expect(highlighter.getHighlight(touch.x, touch.y)?.dataSetIndex, 1);
      expect(
        ChartHighlighter(chart).getHighlight(touch.x, touch.y)?.dataSetIndex,
        0,
      );
    },
  );

  test(
    'getHighlightsAtXValue measures each candidate once for the nearest distance and once for the filter',
    () {
      // Kotlin's minOfOrNull calls the selector once per candidate, then removeAll once more per candidate. The touch
      // (5.1, 5) is at 204 px: the candidates at 192, 208 and 220 px are 12, 4 and 16 px away.
      final chart = _chart([
        BarDataSet([BarEntry(x: 4.8, y: 5)], 'first'),
        BarDataSet([BarEntry(x: 5.2, y: 5)], 'second'),
        BarDataSet([BarEntry(x: 5.5, y: 50)], 'right')
          ..axisDependency = AxisDependency.RIGHT,
      ]);
      final highlighter = _CountingBarHighlighter(chart);
      final touch = _px(chart, 5.1, 5);

      final nearest = highlighter.atXValue(5.1, touch.x, touch.y);
      expect(highlighter.distances, 6);
      expect(nearest.map((h) => h.dataSetIndex).toList(), [1]);
    },
  );

  test('getHighlightsAtXValue keeps every candidate tied for the nearest', () {
    final chart = _chart([
      BarDataSet([BarEntry(x: 5, y: 5)], 'left'),
      BarDataSet([BarEntry(x: 5, y: 50)], 'right')
        ..axisDependency = AxisDependency.RIGHT,
    ]);
    final highlighter = _TestBarHighlighter(chart);
    final touch = _px(chart, 5.1, 5);

    final tied = highlighter.atXValue(5.1, touch.x, touch.y);
    expect(tied.map((h) => h.dataSetIndex).toList(), [0, 1]);

    expect(_TestBarHighlighter(_chart([])).atXValue(5.1, 204, 75), isEmpty);
  });

  test(
    'getClosestStackIndex: the containing range, else the last beyond the end, else 0',
    () {
      final highlighter = _TestBarHighlighter(_chart([]));
      expect(highlighter.closestStackIndex(null, 1), 0);
      expect(highlighter.closestStackIndex([], 1), 0);

      // (0, 2], (-3, 0], (2, 7]: each range excludes its start and includes its end.
      final ranges = BarEntry.stacked(x: 0, stackValues: [2, -3, 5]).ranges;
      expect(highlighter.closestStackIndex(ranges, 2), 0);
      expect(highlighter.closestStackIndex(ranges, 0), 1);
      expect(highlighter.closestStackIndex(ranges, 7), 2);
      expect(highlighter.closestStackIndex(ranges, 7.5), 2);
      expect(highlighter.closestStackIndex(ranges, -3), 0);
      expect(highlighter.closestStackIndex(ranges, double.nan), 0);
    },
  );

  test('the data is the chart\'s bar data, read on every lookup', () {
    final chart = _chart([
      BarDataSet([BarEntry(x: 5, y: 5)], 'first'),
    ]);
    final highlighter = _TestBarHighlighter(chart);
    expect(highlighter.exposedData, same(chart.barData));

    final touch = _px(chart, 5, 5);
    expect(highlighter.getHighlight(touch.x, touch.y), isNotNull);

    chart.barData = null;
    expect(highlighter.exposedData, isNull);
    expect(highlighter.getHighlight(touch.x, touch.y), isNull);
  });
}

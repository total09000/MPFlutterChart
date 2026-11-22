// Ported from MPAndroidChart v4.0.1: MPChartLib/src/test/kotlin/com/github/mikephil/charting/test/HighlighterTest.kt
//
// Both Kotlin cases are bar / combined cases. The bar case runs on the shared `FakeBarChart`, whose transformers are
// unprepared, so pixels equal values as with the JVM transformer matrices of the Kotlin test. The combined case is kept
// as a skipped test with the ported body as a comment so the Phase 2 lane can enable it. Kotlin has no line case, so
// the `ChartHighlighter (line)` group below adds line tests on a local fake. Unlike the Kotlin test, that fake prepares
// real transformers, so pixels differ from values:
// content rect 0..100 x 0..100; x 0..10 → 0..100 px (10 px per x); left y 0..100 → 100..0 px (1 px per y);
// right y 0..10 → 100..0 px (10 px per y).
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/src/components/y_axis.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/data/bar_line_scatter_candle_bubble_data.dart';
import 'package:mp_flutter_chart/src/data/data_set.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';
import 'package:mp_flutter_chart/src/formatter/default_value_formatter.dart';
import 'package:mp_flutter_chart/src/formatter/i_value_formatter.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/highlight/bar_highlighter.dart';
import 'package:mp_flutter_chart/src/highlight/chart_highlighter.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/interfaces/dataprovider/line_data_provider.dart';
import 'package:mp_flutter_chart/src/interfaces/datasets/i_data_set.dart';
import 'package:mp_flutter_chart/src/utils/float_math.dart';
import 'package:mp_flutter_chart/src/utils/mp_point_f.dart';
import 'package:mp_flutter_chart/src/utils/transformer.dart';
import 'package:mp_flutter_chart/src/utils/view_port_handler.dart';

import 'support/fake_providers.dart';

class _FakeChart extends LineDataProvider {
  _FakeChart(this.lineData, {this.maxHighlightDistance = 500}) {
    _left
      ..prepareMatrixValuePx(0, 10, 100, 0)
      ..prepareMatrixOffset(false);
    _right
      ..prepareMatrixValuePx(0, 10, 10, 0)
      ..prepareMatrixOffset(false);
  }

  static ViewPortHandler _newHandler() =>
      ViewPortHandler()..setChartDimens(100, 100);

  final ViewPortHandler _handler = _newHandler();
  late final Transformer _left = Transformer(_handler);
  late final Transformer _right = Transformer(_handler);

  @override
  LineData? lineData;

  @override
  LineData? get data => lineData;

  @override
  double maxHighlightDistance;

  @override
  Transformer getTransformer(AxisDependency axis) =>
      axis == AxisDependency.LEFT ? _left : _right;

  @override
  bool isInverted(AxisDependency axis) => false;

  @override
  YAxis getAxis(AxisDependency axis) => YAxis(axis);

  @override
  double get lowestVisibleX => 0;

  @override
  double get highestVisibleX => 10;

  @override
  double get xChartMin => 0;

  @override
  double get xChartMax => 10;

  @override
  double get xRange => 10;

  @override
  double get yChartMin => 0;

  @override
  double get yChartMax => 100;

  @override
  MPPointF get centerOfView => MPPointF.getInstance(0, 0);

  @override
  MPPointF get centerOffsets => MPPointF.getInstance(0, 0);

  @override
  MutableRect get contentRect => MutableRect();

  @override
  IValueFormatter get defaultValueFormatter => DefaultValueFormatter(0);

  @override
  int get maxVisibleCount => 100;
}

/// Exposes the protected steps of [ChartHighlighter] to the tests.
class _TestHighlighter extends ChartHighlighter<_FakeChart> {
  _TestHighlighter(super.chart);

  List<Highlight> atXValue(double xVal, double x, double y) =>
      getHighlightsAtXValue(xVal, x, y);

  List<Highlight> build(
    IDataSet set,
    int dataSetIndex,
    double xVal,
    Rounding rounding,
  ) => buildHighlights(set, dataSetIndex, xVal, rounding);

  double minimumDistance(
    List<Highlight> closestValues,
    double pos,
    AxisDependency axis,
  ) => getMinimumDistance(closestValues, pos, axis);

  double distance(double x1, double y1, double x2, double y2) =>
      getDistance(x1, y1, x2, y2);

  List<Highlight> get buffer => highlightBuffer;

  BarLineScatterCandleBubbleData? get exposedData => data;
}

LineDataSet _set(
  List<List<double>> xy, {
  AxisDependency axis = AxisDependency.LEFT,
  bool highlightEnabled = true,
}) {
  final set = LineDataSet([for (final p in xy) Entry(x: p[0], y: p[1])], 'set');
  set.axisDependency = axis;
  set.isHighlightEnabled = highlightEnabled;
  return set;
}

_FakeChart _chart(
  List<LineDataSet> sets, {
  double maxHighlightDistance = 500,
}) => _FakeChart(LineData(sets), maxHighlightDistance: maxHighlightDistance);

void main() {
  test('tapOnGroupedBarSelectsItEvenWhenTheOtherBarUsesAnotherAxis', () {
    final left = BarDataSet([BarEntry(x: 0.8, y: 1.5)], 'left')
      ..axisDependency = AxisDependency.LEFT;
    final right = BarDataSet([BarEntry(x: 1.2, y: 8)], 'right')
      ..axisDependency = AxisDependency.RIGHT;
    final chart = FakeBarChart(BarData([left, right])..barWidth = 0.35);

    final high = BarHighlighter(chart).getHighlight(1.2, 1);

    expect(high?.dataSetIndex, 1);
  });

  test('tapInsideBarSelectsTheBarOverANearerLinePoint', () {
    // TODO(phase2): CombinedHighlighter / CombinedData / BarData.
    // final combined = CombinedData()
    //   ..lineData = LineData([LineDataSet([Entry(x: 1, y: 5)], 'line')])
    //   ..barData = BarData([BarDataSet([BarEntry(x: 1, y: 10)], 'bar')]);
    // final chart = FakeChart(combined);
    //
    // final insideBar = CombinedHighlighter(chart, chart).getHighlight(1.1, 4);
    // final besideBar = CombinedHighlighter(chart, chart).getHighlight(1.6, 5);
    //
    // expect(insideBar?.dataIndex, combined.allData.indexWhere((it) => it is BarData));
    // expect(besideBar?.dataIndex, combined.allData.indexWhere((it) => it is LineData));
  }, skip: 'phase2');

  group('ChartHighlighter (line)', () {
    test(
      'picks the entry nearest by x, then by pixel distance, across two data sets',
      () {
        final chart = _chart([
          _set([
            [1, 10],
            [2, 20],
            [3, 30],
          ]),
          _set([
            [1, 50],
            [2, 60],
            [3, 90],
          ]),
        ]);
        final highlighter = ChartHighlighter(chart);

        // x 2.2 → nearest x is 2; y 58 (42 px) is nearest to the second set's (2, 60) at (20, 40) px.
        final upper = highlighter.getHighlight(22, 42)!;
        expect(upper.dataSetIndex, 1);
        expect(upper.x, closeTo(2, 1e-4));
        expect(upper.y, closeTo(60, 1e-4));
        expect(upper.xPx, closeTo(20, 1e-4));
        expect(upper.yPx, closeTo(40, 1e-4));
        expect(upper.axis, AxisDependency.LEFT);
        expect(upper.dataIndex, -1);
        expect(upper.stackIndex, -1);

        // y 25 (75 px) is nearest to the first set's (2, 20) at (20, 80) px.
        final lower = highlighter.getHighlight(18, 75)!;
        expect(lower.dataSetIndex, 0);
        expect(lower.x, closeTo(2, 1e-4));
        expect(lower.y, closeTo(20, 1e-4));
        expect(lower.yPx, closeTo(80, 1e-4));
      },
    );

    test(
      'nothing is selected when the nearest entry is beyond maxHighlightDistance',
      () {
        final sets = [
          _set([
            [2, 60],
          ]),
        ];
        // (2, 60) is at (20, 40) px; the touch (22, 0) is about 40 px away.
        final near = ChartHighlighter(_chart(sets, maxHighlightDistance: 10));
        expect(near.getHighlight(22, 0), isNull);
        final far = ChartHighlighter(_chart(sets, maxHighlightDistance: 500));
        expect(far.getHighlight(22, 0), isNotNull);
      },
    );

    test(
      'getClosestHighlightByPixel ignores candidates at minSelectionDistance or further',
      () {
        final highlighter = ChartHighlighter(_chart([]));
        final h = Highlight.withPixels(1, 1, 0, 0, 0, AxisDependency.LEFT);
        // The touch (3, 4) is exactly 5 px away.
        expect(
          highlighter.getClosestHighlightByPixel([h], 3, 4, null, 5),
          isNull,
        );
        expect(
          highlighter.getClosestHighlightByPixel([h], 3, 4, null, 5.0001),
          same(h),
        );
      },
    );

    test('data sets with highlighting disabled are skipped', () {
      final chart = _chart([
        _set([
          [2, 20],
        ]),
        _set([
          [2, 60],
        ], highlightEnabled: false),
      ]);
      // The touch sits right on the disabled set's entry, yet the enabled one is chosen.
      final h = ChartHighlighter(chart).getHighlight(20, 40)!;
      expect(h.dataSetIndex, 0);
      expect(h.y, closeTo(20, 1e-4));
    });

    test(
      'NaN y entries, empty data sets, no data and NaN touches give null without throwing',
      () {
        final nanOnly = _chart([
          _set([
            [2, double.nan],
          ]),
        ]);
        expect(ChartHighlighter(nanOnly).getHighlight(20, 50), isNull);

        final nanAndValid = _chart([
          _set([
            [2, double.nan],
          ]),
          _set([
            [2, 50],
          ]),
        ]);
        expect(
          ChartHighlighter(nanAndValid).getHighlight(20, 50)?.dataSetIndex,
          1,
        );

        final empty = _chart([_set([])]);
        expect(ChartHighlighter(empty).getHighlight(20, 50), isNull);
        expect(_TestHighlighter(empty).atXValue(2, 20, 50), isEmpty);

        final noSets = _chart([]);
        expect(ChartHighlighter(noSets).getHighlight(20, 50), isNull);

        final noData = _FakeChart(null);
        final noDataHighlighter = _TestHighlighter(noData);
        expect(noDataHighlighter.exposedData, isNull);
        expect(noDataHighlighter.getHighlight(20, 50), isNull);
        expect(noDataHighlighter.atXValue(2, 20, 50), isEmpty);

        final valid = _chart([
          _set([
            [2, 50],
          ]),
        ]);
        expect(
          ChartHighlighter(valid).getHighlight(double.nan, double.nan),
          isNull,
        );
      },
    );

    test(
      'buildHighlights rounds to the closest, next larger or next smaller x',
      () {
        final set = _set([
          [1, 10],
          [3, 30],
        ]);
        final highlighter = _TestHighlighter(_chart([set]));

        List<double> xs(double xVal, Rounding rounding) =>
            highlighter.build(set, 0, xVal, rounding).map((h) => h.x).toList();

        expect(xs(1.8, Rounding.CLOSEST), [1]);
        expect(xs(2.4, Rounding.CLOSEST), [3]);
        expect(xs(1.8, Rounding.UP), [3]);
        expect(xs(2.4, Rounding.DOWN), [1]);
        // An exact x match wins whatever the rounding.
        expect(xs(3, Rounding.DOWN), [3]);

        final h = highlighter.build(set, 4, 2.4, Rounding.CLOSEST).single;
        expect(h.dataSetIndex, 4);
        expect(h.y, closeTo(30, 1e-4));
        expect(h.xPx, closeTo(30, 1e-4));
        expect(h.yPx, closeTo(70, 1e-4));
        expect(h.axis, AxisDependency.LEFT);

        expect(highlighter.build(_set([]), 0, 2, Rounding.CLOSEST), isEmpty);
      },
    );

    test('buildHighlights returns every entry sharing the x value', () {
      final set = _set([
        [1, 5],
        [1, 7],
        [2, 9],
      ]);
      final highlighter = _TestHighlighter(_chart([set]));
      final ys = highlighter
          .build(set, 0, 1.2, Rounding.CLOSEST)
          .map((h) => h.y)
          .toList();
      expect(ys, [5, 7]);
    });

    test(
      'getHighlightsAtXValue collects with CLOSEST rounding into the reused buffer',
      () {
        final chart = _chart([
          _set([
            [1, 10],
            [3, 30],
          ]),
          _set([
            [2, 60],
          ]),
        ]);
        final highlighter = _TestHighlighter(chart);

        final first = highlighter.atXValue(2.4, 24, 50);
        expect(first.map((h) => (h.dataSetIndex, h.x)).toList(), [
          (0, 3.0),
          (1, 2.0),
        ]);
        expect(first, same(highlighter.buffer));

        final second = highlighter.atXValue(1.2, 12, 50);
        expect(second, same(first));
        expect(second.map((h) => (h.dataSetIndex, h.x)).toList(), [
          (0, 1.0),
          (1, 2.0),
        ]);
      },
    );

    test(
      'the axis whose candidates are nearer in y wins over a nearer pixel distance',
      () {
        final chart = _chart([
          // (2, 50) on the left axis is at (20, 50) px.
          _set([
            [2, 50],
          ]),
          // (6, 4.8) on the right axis is at (60, 52) px.
          _set([
            [6, 4.8],
          ], axis: AxisDependency.RIGHT),
        ]);
        final highlighter = ChartHighlighter(chart);

        // Touch (30, 52): the left candidate is about 10 px away, the right one 30 px, but the right one is 0 px away in
        // y, so the right axis is chosen.
        final right = highlighter.getHighlight(30, 52)!;
        expect(right.dataSetIndex, 1);
        expect(right.axis, AxisDependency.RIGHT);
        expect(right.yPx, closeTo(52, 1e-4));

        // Touch (30, 49): the left candidate is nearer in y, so the left axis is chosen.
        final left = highlighter.getHighlight(30, 49)!;
        expect(left.dataSetIndex, 0);
        expect(left.axis, AxisDependency.LEFT);
      },
    );

    test(
      'getClosestHighlightByPixel considers only the given axis, or all when null',
      () {
        final highlighter = ChartHighlighter(_chart([]));
        final l = Highlight.withPixels(1, 1, 10, 10, 0, AxisDependency.LEFT);
        final r = Highlight.withPixels(1, 1, 50, 50, 1, AxisDependency.RIGHT);

        expect(
          highlighter.getClosestHighlightByPixel(
            [l, r],
            48,
            48,
            AxisDependency.LEFT,
            500,
          ),
          same(l),
        );
        expect(
          highlighter.getClosestHighlightByPixel(
            [l, r],
            12,
            12,
            AxisDependency.RIGHT,
            500,
          ),
          same(r),
        );
        expect(
          highlighter.getClosestHighlightByPixel([l, r], 48, 48, null, 500),
          same(r),
        );
        expect(
          highlighter.getClosestHighlightByPixel([], 48, 48, null, 500),
          isNull,
        );
      },
    );

    test(
      'getMinimumDistance measures y pixels per axis, Float.MAX_VALUE when the axis has none',
      () {
        final highlighter = _TestHighlighter(_chart([]));
        final candidates = [
          Highlight.withPixels(1, 1, 0, 30, 0, AxisDependency.LEFT),
          Highlight.withPixels(1, 1, 0, 70, 0, AxisDependency.LEFT),
          Highlight.withPixels(1, 1, 0, 10, 1, AxisDependency.RIGHT),
        ];
        expect(
          highlighter.minimumDistance(candidates, 60, AxisDependency.LEFT),
          closeTo(10, 1e-4),
        );
        expect(
          highlighter.minimumDistance(candidates, 60, AxisDependency.RIGHT),
          closeTo(50, 1e-4),
        );
        expect(
          highlighter.minimumDistance(
            candidates.sublist(0, 2),
            60,
            AxisDependency.RIGHT,
          ),
          kotlinFloatMaxValue,
        );
      },
    );

    test('getDistance is the straight line distance', () {
      final highlighter = _TestHighlighter(_chart([]));
      expect(highlighter.distance(0, 0, 3, 4), closeTo(5, 1e-6));
      expect(highlighter.distance(3, 4, 0, 0), closeTo(5, 1e-6));
      expect(highlighter.distance(1, 1, 1, 1), 0);
      expect(highlighter.distance(1e200, 0, -1e200, 0), closeTo(2e200, 1e186));
      expect(highlighter.distance(double.nan, 0, 0, 0).isNaN, isTrue);
      // Like Kotlin's hypot: an infinite difference gives infinity even when the other one is NaN.
      expect(
        highlighter.distance(double.infinity, double.nan, 0, 0),
        double.infinity,
      );
    });
  });
}

// Not a port of a Kotlin test: MPAndroidChart v4.0.1 has no unit test for BarChart. Checks what charts/BarChart.kt
// adds to BarLineChartBase: its renderer, highlighter and x axis spacing, the fit-bars range, the bar bounds, the
// full-bar highlight and groupBars.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/bar_chart.dart';
import 'package:mp_flutter_chart/src/components/y_axis_dependency.dart';
import 'package:mp_flutter_chart/src/data/bar_data.dart';
import 'package:mp_flutter_chart/src/data/bar_data_set.dart';
import 'package:mp_flutter_chart/src/data/bar_entry.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/highlight/bar_highlighter.dart';
import 'package:mp_flutter_chart/src/renderer/bar_chart_renderer.dart';
import 'package:mp_flutter_chart/src/utils/utils.dart';

/// Five plain bars at x 0..4 with heights 1..5.
BarDataSet _plainSet([String label = 'plain']) => BarDataSet([
  for (var i = 0; i < 5; i++) BarEntry(x: i.toDouble(), y: i + 1.0),
], label);

/// A 400 x 300 bar chart without a host showing [data].
BarChart _chart(BarData data) => BarChart()
  ..data = data
  ..onSizeChanged(400, 300);

void _expectRect(MutableRect actual, MutableRect expected) {
  expect(actual.left, closeTo(expected.left, 1e-4), reason: 'left');
  expect(actual.top, closeTo(expected.top, 1e-4), reason: 'top');
  expect(actual.right, closeTo(expected.right, 1e-4), reason: 'right');
  expect(actual.bottom, closeTo(expected.bottom, 1e-4), reason: 'bottom');
}

void main() {
  test(
    'a new bar chart draws with the bar renderer and highlighter and pads the x axis by half a bar',
    () {
      final chart = BarChart();

      expect(chart.renderer, isA<BarChartRenderer>());
      expect(chart.highlighter, isA<BarHighlighter>());
      expect(chart.xAxis.spaceMin, 0.5);
      expect(chart.xAxis.spaceMax, 0.5);
      expect(chart.isHighlightFullBarEnabled, isFalse);
      expect(chart.isDrawValueAboveBarEnabled, isTrue);
      expect(chart.isDrawBarShadowEnabled, isFalse);
      expect(chart.isFitBarsEnabled, isFalse);
      expect(chart.barData, isNull);

      final data = BarData([_plainSet()]);
      chart.data = data;
      expect(chart.barData, same(data));
    },
  );

  test(
    'fitting the bars widens the x axis by half a bar width on each side',
    () {
      final data = BarData([_plainSet()]);
      final chart = _chart(data);
      final min = chart.xAxis.axisMinimum;
      final max = chart.xAxis.axisMaximum;
      expect(min, closeTo(-0.5, 1e-4));
      expect(max, closeTo(4.5, 1e-4));

      chart.isFitBarsEnabled = true;
      chart.notifyDataSetChanged();

      expect(chart.xAxis.axisMinimum, closeTo(min - data.barWidth / 2, 1e-4));
      expect(chart.xAxis.axisMaximum, closeTo(max + data.barWidth / 2, 1e-4));
    },
  );

  test(
    'bar bounds are the pixel rectangle from 0 to y, half a bar width either side of x',
    () {
      final left = _plainSet('left');
      final negative = BarEntry(x: 5, y: -2);
      left.addEntry(negative);
      final right = BarDataSet([
        BarEntry(x: 0, y: 50),
        BarEntry(x: 1, y: 100),
      ], 'right')..axisDependency = AxisDependency.RIGHT;
      final data = BarData([left, right]);
      final chart = _chart(data);
      final half = data.barWidth / 2;

      MutableRect pixels(
        double l,
        double t,
        double r,
        double b,
        AxisDependency axis,
      ) {
        final topLeft = chart.getPixelForValues(l, t, axis);
        final bottomRight = chart.getPixelForValues(r, b, axis);
        return MutableRect(topLeft.x, topLeft.y, bottomRight.x, bottomRight.y);
      }

      final positive = left.getEntryForIndex(2);
      _expectRect(
        chart.getBarBounds(positive),
        pixels(2 - half, 3, 2 + half, 0, AxisDependency.LEFT),
      );
      _expectRect(
        chart.getBarBounds(negative),
        pixels(5 - half, 0, 5 + half, -2, AxisDependency.LEFT),
      );
      _expectRect(
        chart.getBarBounds(right.getEntryForIndex(1)),
        pixels(1 - half, 100, 1 + half, 0, AxisDependency.RIGHT),
      );

      final output = MutableRect();
      expect(chart.getBarBounds(positive, output), same(output));
      _expectRect(
        output,
        pixels(2 - half, 3, 2 + half, 0, AxisDependency.LEFT),
      );
    },
  );

  test(
    'an entry that is not in the data has bounds of Float.MIN_VALUE on every side',
    () {
      final chart = _chart(BarData([_plainSet()]));
      List<double> sides(MutableRect r) => [r.left, r.top, r.right, r.bottom];
      const min = Utils.FLOAT_EPSILON;

      // The set has a bar at x = 2, but 3 high.
      expect(sides(chart.getBarBounds(BarEntry(x: 2, y: 7))), [
        min,
        min,
        min,
        min,
      ]);
      expect(
        sides(BarChart().getBarBounds(BarEntry(x: 0, y: 1))),
        [min, min, min, min],
        reason: 'a chart without data',
      );
    },
  );

  test(
    'a touch on a stacked bar highlights the whole bar only with full bar highlighting on',
    () {
      final set = BarDataSet([
        for (var i = 0; i < 3; i++)
          BarEntry.stacked(x: i.toDouble(), stackValues: [2, 3, 4]),
      ], 'stacked');
      final chart = _chart(BarData([set]));
      // Inside the middle section (2..5) of the bar at x = 1.
      final touch = chart.getPixelForValues(1, 4, AxisDependency.LEFT);

      final section = chart.getHighlightByTouchPoint(touch.x, touch.y)!;
      expect(section.stackIndex, 1);

      chart.isHighlightFullBarEnabled = true;
      final whole = chart.getHighlightByTouchPoint(touch.x, touch.y)!;

      expect(whole.stackIndex, -1);
      expect(whole.x, section.x);
      expect(whole.y, section.y);
      expect(whole.xPx, section.xPx);
      expect(whole.yPx, section.yPx);
      expect(whole.dataSetIndex, section.dataSetIndex);
      expect(whole.axis, section.axis);
    },
  );

  test('grouping bars needs data', () {
    expect(
      () => BarChart().groupBars(0, 0.1, 0.1),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'You need to set data for the chart before grouping bars.',
        ),
      ),
    );
  });

  test('grouping bars moves the bars and then refreshes the chart', () {
    BarDataSet set(String label) => BarDataSet([
      for (var i = 0; i < 3; i++) BarEntry(x: i.toDouble(), y: 1),
    ], label);
    final a = set('a');
    final b = set('b');
    final data = BarData([a, b]);
    final chart = _chart(data);
    // Neither change is seen by the x axis until the chart is notified.
    chart.isFitBarsEnabled = true;
    data.barWidth = 0.4;
    expect(chart.xAxis.axisMinimum, closeTo(-0.5, 1e-4));
    expect(chart.xAxis.axisMaximum, closeTo(2.5, 1e-4));

    // Groups 1 wide from x = 0: the bars of group i sit at i + 0.275 and i + 0.725.
    chart.groupBars(0, 0.1, 0.05);

    expect(
      [for (final e in a.entries) e.x],
      [closeTo(0.275, 1e-4), closeTo(1.275, 1e-4), closeTo(2.275, 1e-4)],
    );
    expect(
      [for (final e in b.entries) e.x],
      [closeTo(0.725, 1e-4), closeTo(1.725, 1e-4), closeTo(2.725, 1e-4)],
    );
    // As in Kotlin, the sets keep the x range 0..2 they cached before the bars moved (BarData.groupBars only
    // recomputes the data's ranges from them), so the refreshed axis shows the new bar width but not the new x.
    expect(chart.xAxis.axisMinimum, closeTo(0 - 0.2 - 0.5, 1e-4));
    expect(chart.xAxis.axisMaximum, closeTo(2 + 0.2 + 0.5, 1e-4));
  });
}

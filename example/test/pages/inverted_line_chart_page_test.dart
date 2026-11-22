import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/my_marker_view.dart';
import 'package:mp_flutter_chart_example/pages/inverted_line_chart_page.dart';

import '../support/pages.dart';

/// res/menu/line.xml as InvertedLineChartActivity shows it, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Values',
  'Toggle Highlight Line Span',
  'Toggle Icons',
  'Toggle Filled',
  'Toggle Circles',
  'Toggle Cubic',
  'Toggle Stepped',
  'Toggle Horizontal Cubic',
  'Toggle PinchZoom',
  'Toggle Auto Scale',
  'Toggle Highlight',
  'Animate X',
  'Animate Y',
  'Animate XY',
];

void main() {
  testWidgets('the page shows InvertedLineChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const InvertedLineChartPage());

    expect(find.widgetWithText(AppBar, 'Inverted Axis'), findsOneWidget);
    expect(seekBars(tester), [25, 50]);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    final chart = chartOf<LineChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isTrue);
    expect(chart.marker, isA<MyMarkerView>());
    expect(chart.xAxis.isAvoidFirstLastClippingEnabled, isTrue);
    expect(chart.xAxis.axisMinimum, 0);
    expect(chart.axisLeft.isInverted, isTrue);
    expect(chart.axisLeft.axisMinimum, 0);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.legend.form, LegendForm.LINE);

    final data = chart.data!;
    expect(data.dataSetCount, 1);
    final set = data.dataSets.single as LineDataSet;
    expect(set.label, 'DataSet 1');
    expect(set.entryCount, 25);
    expect(set.lineWidth, 1.5);
    expect(set.circleRadius, 4);
    // (Math.random() * range) for x and y, with range 50, sorted by x.
    final xs = [for (final e in set.entries) e.x];
    expect(xs, everyElement(inInclusiveRange(0, 50)));
    expect(xs, [...xs]..sort());
    expect(ysOf(data), everyElement(inInclusiveRange(0, 50)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const InvertedLineChartPage());
    final data = chartOf<LineChartView>(tester).data!;
    final first = [for (final e in (data.dataSets.single as LineDataSet).entries) (e.x, e.y)];

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const InvertedLineChartPage());
    final again = chartOf<LineChartView>(tester).data!;
    expect([for (final e in (again.dataSets.single as LineDataSet).entries) (e.x, e.y)], first);
  });

  testWidgets('a seek bar sets new data, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const InvertedLineChartPage());
    final chart = chartOf<LineChartView>(tester);
    final before = chart.data;

    await setSeekBar(tester, 0, 35);
    final data = chart.data!;
    expect(data, isNot(same(before)));
    expect(data.dataSets.single.entryCount, 35);
    expect(find.text('35'), findsOneWidget);

    await setSeekBar(tester, 1, 10);
    final set = chart.data!.dataSets.single as LineDataSet;
    expect([for (final e in set.entries) e.x], everyElement(inInclusiveRange(0, 10)));
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(0, 10)));
    expect(find.text('10'), findsOneWidget);

    await setSeekBar(tester, 0, 0);
    expect(chart.data!.dataSets.single.entryCount, 0);
    await tester.pump();
    await setSeekBar(tester, 0, 25);

    // A rebuild of the page hands the host the chart's own data, so the host leaves it alone.
    final shown = chart.data;
    tester.element(find.byType(InvertedLineChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const InvertedLineChartPage());
    final chart = chartOf<LineChartView>(tester);
    LineDataSet set() => chart.data!.dataSets.single as LineDataSet;

    await selectMenuItem(tester, 'Toggle Values');
    expect(set().isDrawValuesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Filled');
    expect(set().isDrawFilledEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Circles');
    expect(set().isDrawCirclesEnabled, isFalse);
    // onOptionsItemSelected has no branch for the line modes.
    for (final title in ['Toggle Cubic', 'Toggle Stepped', 'Toggle Horizontal Cubic']) {
      await selectMenuItem(tester, title);
      expect(set().mode, LineDataSetMode.LINEAR, reason: title);
    }
    await selectMenuItem(tester, 'Toggle PinchZoom');
    expect(chart.isPinchZoomEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Auto Scale');
    expect(chart.isAutoScaleMinMaxEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Highlight');
    expect(chart.data!.isHighlightEnabled, isFalse);

    for (final title in ['Animate X', 'Animate Y', 'Animate XY']) {
      await selectMenuItem(tester, title, settle: false);
      expect(chart.isAnimating, isTrue, reason: title);
      await tester.pumpAndSettle();
      expect(chart.isAnimating, isFalse, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const InvertedLineChartPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/multi_line_chart_page.dart';

import '../support/pages.dart';

/// res/menu/line.xml as MultiLineChartActivity shows it, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Values',
  'Toggle Highlight Line Span',
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
  testWidgets('the page shows MultiLineChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const MultiLineChartPage());

    expect(find.widgetWithText(AppBar, 'Multiple'), findsOneWidget);
    expect(seekBars(tester), [20, 100]);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    final chart = chartOf<LineChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.axisLeft.isEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.legend.orientation, LegendOrientation.VERTICAL);

    final data = chart.data!;
    expect([for (final set in data.dataSets) set.label], ['DataSet 1', 'DataSet 2', 'DataSet 3']);
    expect([for (final set in data.dataSets) set.entryCount], [20, 20, 20]);
    // (Math.random() * 100) + 3
    expect(ysOf(data), everyElement(inInclusiveRange(3, 103)));
    final first = data.dataSets.first as LineDataSet;
    expect(first.isDashedLineEnabled, isTrue);
    expect(first.colors, ColorTemplate.VORDIPLOM_COLORS);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const MultiLineChartPage());
    final first = ysOf(chartOf<LineChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const MultiLineChartPage());
    expect(ysOf(chartOf<LineChartView>(tester).data!), first);
  });

  testWidgets('a seek bar sets new data, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const MultiLineChartPage());
    final chart = chartOf<LineChartView>(tester);
    final before = chart.data;

    await setSeekBar(tester, 0, 35);
    final data = chart.data!;
    expect(data, isNot(same(before)));
    expect([for (final set in data.dataSets) set.entryCount], [35, 35, 35]);
    expect(find.text('35'), findsOneWidget);

    await setSeekBar(tester, 1, 10);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(3, 13)));
    expect(find.text('10'), findsOneWidget);

    // A rebuild of the page hands the host the chart's own data, so the host leaves it alone.
    final shown = chart.data;
    tester.element(find.byType(MultiLineChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const MultiLineChartPage());
    final chart = chartOf<LineChartView>(tester);
    List<LineDataSet> sets() => chart.data!.dataSets.cast<LineDataSet>();

    await selectMenuItem(tester, 'Toggle Values');
    expect([for (final set in sets()) set.isDrawValuesEnabled], everyElement(isFalse));
    await selectMenuItem(tester, 'Toggle Filled');
    expect([for (final set in sets()) set.isDrawFilledEnabled], everyElement(isTrue));
    await selectMenuItem(tester, 'Toggle Circles');
    expect([for (final set in sets()) set.isDrawCirclesEnabled], everyElement(isFalse));
    await selectMenuItem(tester, 'Toggle Cubic');
    expect([for (final set in sets()) set.mode], everyElement(LineDataSetMode.CUBIC_BEZIER));
    await selectMenuItem(tester, 'Toggle Stepped');
    expect([for (final set in sets()) set.mode], everyElement(LineDataSetMode.STEPPED));
    await selectMenuItem(tester, 'Toggle Horizontal Cubic');
    expect([for (final set in sets()) set.mode], everyElement(LineDataSetMode.HORIZONTAL_BEZIER));
    await selectMenuItem(tester, 'Toggle Horizontal Cubic');
    expect([for (final set in sets()) set.mode], everyElement(LineDataSetMode.LINEAR));
    await selectMenuItem(tester, 'Toggle PinchZoom');
    expect(chart.isPinchZoomEnabled, isTrue);
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
    await pumpPage(tester, const MultiLineChartPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

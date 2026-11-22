import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/line_chart2_page.dart';

import '../support/pages.dart';

/// res/menu/line.xml as LineChartActivity2 shows it, without the items this app leaves out.
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
  testWidgets('the page shows LineChartActivity2\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const LineChart2Page());

    expect(find.widgetWithText(AppBar, 'Dual Axis'), findsOneWidget);
    expect(seekBars(tester), [20, 30]);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);

    final chart = chartOf<LineChartView>(tester);
    // animateX(1500) from onCreate.
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);

    expect(await menuTitles(tester), _menu);

    final background = tester.widget<ColoredBox>(
      find.ancestor(of: chartHosts, matching: find.byType(ColoredBox)).first,
    );
    expect(background.color, const Color(0xFFCCCCCC));

    expect(chart.description.isEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isTrue);
    expect(chart.isHighlightPerDragEnabled, isTrue);
    expect(chart.legend.form, LegendForm.LINE);
    expect(chart.legend.verticalAlignment, LegendVerticalAlignment.BOTTOM);
    expect(chart.legend.horizontalAlignment, LegendHorizontalAlignment.LEFT);
    expect(chart.legend.textColor, const Color(0xFFFFFFFF));
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisLeft.textColor, ColorTemplate.holoBlue);
    expect([chart.axisLeft.axisMinimum, chart.axisLeft.axisMaximum], [0, 200]);
    expect(chart.axisRight.textColor, const Color(0xFFFF0000));
    expect([chart.axisRight.axisMinimum, chart.axisRight.axisMaximum], [-200, 900]);
    expect(chart.axisRight.isDrawGridLinesEnabled, isFalse);

    final data = chart.data!;
    final sets = data.dataSets.cast<LineDataSet>();
    expect([for (final set in sets) set.label], ['DataSet 1', 'DataSet 2', 'DataSet 3']);
    expect([for (final set in sets) set.entryCount], [20, 20, 20]);
    expect(
      [for (final set in sets) set.axisDependency],
      [AxisDependency.LEFT, AxisDependency.RIGHT, AxisDependency.RIGHT],
    );
    expect(
      [for (final set in sets) set.color],
      [ColorTemplate.holoBlue, const Color(0xFFFF0000), const Color(0xFFFFFF00)],
    );
    expect(sets[2].fillColor, ColorTemplate.colorWithAlpha(const Color(0xFFFFFF00), 200));
    // (Math.random() * (range / 2f)) + 50, (Math.random() * range) + 450 and + 500, with range 30.
    List<double> ys(int index) => [for (final e in sets[index].entries) e.y];
    expect(ys(0), everyElement(inInclusiveRange(50, 65)));
    expect(ys(1), everyElement(inInclusiveRange(450, 480)));
    expect(ys(2), everyElement(inInclusiveRange(500, 530)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const LineChart2Page());
    final first = ysOf(chartOf<LineChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const LineChart2Page());
    expect(ysOf(chartOf<LineChartView>(tester).data!), first);
  });

  testWidgets('the seek bars give the same sets new entries, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const LineChart2Page());
    await tester.pumpAndSettle();
    final chart = chartOf<LineChartView>(tester);
    final data = chart.data!;
    final sets = [...data.dataSets];

    await selectMenuItem(tester, 'Toggle Filled');
    await setSeekBar(tester, 0, 35);
    expect(chart.data, same(data));
    expect(chart.data!.dataSets, sets);
    expect([for (final set in sets) set.entryCount], [35, 35, 35]);
    expect([for (final set in sets) set.isDrawFilledEnabled], everyElement(isTrue));
    expect(find.text('35'), findsOneWidget);

    await setSeekBar(tester, 1, 10);
    expect([for (final e in (sets[0] as LineDataSet).entries) e.y], everyElement(inInclusiveRange(50, 55)));
    expect([for (final e in (sets[1] as LineDataSet).entries) e.y], everyElement(inInclusiveRange(450, 460)));
    expect(chart.data!.yMax, lessThanOrEqualTo(510));
    expect(find.text('10'), findsOneWidget);

    await setSeekBar(tester, 0, 0);
    expect([for (final set in sets) set.entryCount], [0, 0, 0]);
    await tester.pump();
    await setSeekBar(tester, 0, 20);

    // A rebuild of the page hands the host the chart's own data, so the host leaves it alone.
    tester.element(find.byType(LineChart2Page)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a value centers the view on it', (tester) async {
    await pumpPage(tester, const LineChart2Page());
    await tester.pumpAndSettle();
    final chart = chartOf<LineChartView>(tester);

    chart.zoom(4, 1, 0, 0);
    await tester.pump();
    final before = chart.lowestVisibleX;

    chart.highlightValue(19, 0);
    await tester.pumpAndSettle();
    expect(chart.lowestVisibleX, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const LineChart2Page());
    await tester.pumpAndSettle();
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
    await pumpPage(tester, const LineChart2Page());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

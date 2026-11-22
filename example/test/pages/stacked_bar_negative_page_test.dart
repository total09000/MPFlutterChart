import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/demo_drawables.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/stacked_bar_negative_page.dart';

import '../support/pages.dart';

/// res/menu/bar.xml as StackedBarActivityNegative shows it, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Bar Borders',
  'Toggle Rounded Sections',
  'Toggle Values',
  'Toggle Icons',
  'Toggle Highlight',
  'Toggle PinchZoom',
  'Toggle Auto Scale',
  'Animate X',
  'Animate Y',
  'Animate XY',
];

void main() {
  testWidgets('the page shows StackedBarActivityNegative\'s chart and menu', (tester) async {
    await pumpPage(tester, const StackedBarNegativePage());

    expect(find.widgetWithText(AppBar, 'Stacked 2'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(
      find.ancestor(
        of: chartHosts,
        matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == demoChartBackground),
      ),
      findsOneWidget,
    );
    expect(await menuTitles(tester), _menu);

    final chart = chartOf<HorizontalBarChartView>(tester);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.isDrawBarShadowEnabled, isFalse);
    expect(chart.isDrawValueAboveBarEnabled, isTrue);
    expect(chart.isHighlightFullBarEnabled, isFalse);
    expect(chart.axisLeft.isEnabled, isFalse);

    final right = chart.axisRight;
    expect(right.axisMaximum, 25);
    expect(right.axisMinimum, -25);
    expect(right.isDrawGridLinesEnabled, isFalse);
    expect(right.isDrawZeroLineEnabled, isTrue);
    expect(right.labelCount, 7);
    expect(right.textSize, 9);
    expect([for (final v in [-25.0, -10.0, 0.0, 12.0, 25.0]) right.valueFormatter.getFormattedValue(v, right)], [
      '25m', '10m', '0m', '12m', '25m', //
    ]);

    final xAxis = chart.xAxis;
    expect(xAxis.position, XAxisPosition.BOTH_SIDED);
    expect(xAxis.isDrawGridLinesEnabled, isFalse);
    expect(xAxis.isDrawAxisLineEnabled, isFalse);
    expect(xAxis.textSize, 9);
    expect(xAxis.axisMinimum, 0);
    expect(xAxis.axisMaximum, 110);
    expect(xAxis.isCenterAxisLabelsEnabled, isTrue);
    expect(xAxis.labelCount, 12);
    expect(xAxis.granularity, 10);
    expect([for (final v in [0.0, 10.0, 100.0]) xAxis.valueFormatter.getFormattedValue(v, xAxis)], [
      '0-10', '10-20', '100-110', //
    ]);

    final legend = chart.legend;
    expect(legend.verticalAlignment, LegendVerticalAlignment.BOTTOM);
    expect(legend.horizontalAlignment, LegendHorizontalAlignment.RIGHT);
    expect(legend.orientation, LegendOrientation.HORIZONTAL);
    expect(legend.isDrawInsideEnabled, isFalse);
    expect(legend.formSize, 8);
    expect(legend.formToTextSpace, 4);
    expect(legend.xEntrySpace, 6);

    final data = chart.data!;
    expect(data.barWidth, 8.5);
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'Age Distribution');
    expect(set.isDrawIconsEnabled, isFalse);
    expect(set.valueTextSize, 7);
    expect(set.axisDependency, AxisDependency.RIGHT);
    expect(set.colors, [const Color.fromARGB(255, 67, 67, 72), const Color.fromARGB(255, 124, 181, 236)]);
    expect(set.stackLabels, ['Men', 'Women']);
    expect(set.stackSize, 2);

    final entries = [for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i)];
    expect([for (final e in entries) e.x], [5, 15, 25, 35, 45, 45, 55, 65, 75, 85, 95, 105]);
    expect([for (final e in entries) e.stackValues], [
      [-10, 10], [-12, 13], [-15, 15], [-17, 17], [-19, 20], [-19, 20], //
      [-19, 19], [-16, 16], [-13, 14], [-10, 11], [-5, 6], [-1, 2], //
    ]);
    expect([for (final e in entries) e.icon], [for (var i = 0; i < 12; i++) i == 5 ? same(starDrawable) : isNull]);
    expect(set.valueFormatter.getFormattedValue(-19, entries[4], 0, chart.viewPortHandler), '19m');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the data survives a rebuild of the page, and a stack value can be selected', (tester) async {
    await pumpPage(tester, const StackedBarNegativePage());
    final chart = chartOf<HorizontalBarChartView>(tester);
    final shown = chart.data;

    tester.element(find.byType(StackedBarNegativePage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));

    chart.highlightValue(25, 0, stackIndex: 1);
    await tester.pump();
    expect(chart.highlighted, hasLength(1));
    chart.highlightValue(25, -1);
    await tester.pump();
    expect(chart.highlighted, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const StackedBarNegativePage());
    final chart = chartOf<HorizontalBarChartView>(tester);
    BarDataSet set() => chart.data!.dataSets.single as BarDataSet;

    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect(set().barBorderWidth, 1);
    await selectMenuItem(tester, 'Toggle Values');
    expect(set().isDrawValuesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Icons');
    expect(set().isDrawIconsEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Highlight');
    expect(chart.data!.isHighlightEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle PinchZoom');
    expect(chart.isPinchZoomEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Auto Scale');
    expect(chart.isAutoScaleMinMaxEnabled, isTrue);

    for (final title in ['Animate X', 'Animate Y', 'Animate XY']) {
      await selectMenuItem(tester, title, settle: false);
      expect(chart.isAnimating, isTrue, reason: title);
      // 3000 ms here, where the other bar pages animate for 2000 ms.
      await tester.pump(const Duration(milliseconds: 2500));
      expect(chart.isAnimating, isTrue, reason: title);
      await tester.pumpAndSettle();
      expect(chart.isAnimating, isFalse, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const StackedBarNegativePage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

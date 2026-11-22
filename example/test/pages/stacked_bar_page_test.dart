import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/demo_drawables.dart';
import 'package:mp_flutter_chart_example/custom/my_axis_value_formatter.dart';
import 'package:mp_flutter_chart_example/custom/my_value_formatter.dart';
import 'package:mp_flutter_chart_example/pages/stacked_bar_page.dart';

import '../support/pages.dart';

/// res/menu/bar.xml as StackedBarActivity shows it, without the items this app leaves out.
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

/// Every stack value of [data], entry by entry.
List<double> _stackValuesOf(ChartData data) => [
  for (final set in data.dataSets)
    for (var i = 0; i < set.entryCount; i++) ...(set.getEntryForIndex(i) as BarEntry).stackValues!,
];

void main() {
  testWidgets('the page shows StackedBarActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const StackedBarPage());

    expect(find.widgetWithText(AppBar, 'Stacked'), findsOneWidget);
    expect(seekBars(tester), [12, 100]);
    expect(tester.widget<Slider>(find.byType(Slider).first).max, 1500);
    expect(tester.widget<Slider>(find.byType(Slider).last).max, 200);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    final chart = chartOf<BarChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.maxVisibleCount, 40);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.isDrawBarShadowEnabled, isFalse);
    expect(chart.isDrawValueAboveBarEnabled, isFalse);
    expect(chart.isHighlightFullBarEnabled, isFalse);
    expect(chart.isFitBarsEnabled, isTrue);
    expect(chart.marker, isNull);
    expect(chart.axisLeft.valueFormatter, isA<MyAxisValueFormatter>());
    expect(chart.axisLeft.axisMinimum, 0);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.xAxis.position, XAxisPosition.TOP);
    // fitBars, set after the data, adds half a bar (0.85 / 2) to the 0.5 of room BarChart gives the x axis.
    expect(chart.xAxis.axisMinimum, closeTo(-0.925, 1e-6));
    expect(chart.xAxis.axisMaximum, closeTo(11.925, 1e-6));

    final legend = chart.legend;
    expect(legend.verticalAlignment, LegendVerticalAlignment.BOTTOM);
    expect(legend.horizontalAlignment, LegendHorizontalAlignment.RIGHT);
    expect(legend.orientation, LegendOrientation.HORIZONTAL);
    expect(legend.isDrawInsideEnabled, isFalse);
    expect(legend.formSize, 8);
    expect(legend.formToTextSpace, 4);
    expect(legend.xEntrySpace, 6);
    expect(legend.isWordWrapEnabled, isFalse);

    final data = chart.data!;
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'Statistics Vienna 2014');
    expect(set.entryCount, 12);
    expect([for (final e in set.entries) e.x], [for (var i = 0; i < 12; i++) i.toDouble()]);
    expect([for (final e in set.entries) e.stackValues!.length], everyElement(3));
    // (Math.random() * 101) + 101 / 3
    expect(_stackValuesOf(data), everyElement(inInclusiveRange(101 / 3, 101 + 101 / 3)));
    expect([for (final e in set.entries) e.icon], everyElement(same(starDrawable)));
    expect(set.isDrawIconsEnabled, isFalse);
    expect(set.colors, ColorTemplate.MATERIAL_COLORS.take(3).toList());
    expect(set.stackLabels, ['Births', 'Divorces', 'Marriages']);
    expect(set.valueFormatter, isA<MyValueFormatter>());
    expect(set.valueTextColor, const Color(0xFFFFFFFF));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const StackedBarPage());
    final first = _stackValuesOf(chartOf<BarChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const StackedBarPage());
    expect(_stackValuesOf(chartOf<BarChartView>(tester).data!), first);
  });

  testWidgets('a seek bar gives the set new entries, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const StackedBarPage());
    final chart = chartOf<BarChartView>(tester);
    final data = chart.data!;
    final set = data.dataSets.single;

    await setSeekBar(tester, 0, 20);
    expect(chart.data, same(data));
    expect(chart.data!.dataSets.single, same(set));
    expect(set.entryCount, 20);
    expect(find.text('20'), findsOneWidget);

    await setSeekBar(tester, 1, 8);
    expect(_stackValuesOf(chart.data!), everyElement(inInclusiveRange(3, 12)));
    expect(find.text('8'), findsOneWidget);

    tester.element(find.byType(StackedBarPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(set.entryCount, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a highlighted stack value calls the listener without an exception', (tester) async {
    await pumpPage(tester, const StackedBarPage());
    final chart = chartOf<BarChartView>(tester);

    chart.highlightValue(4, 0, stackIndex: 1);
    await tester.pump();
    expect(chart.highlighted, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('seekBar1 at 0 leaves the set without entries, as on Android', (tester) async {
    await pumpPage(tester, const StackedBarPage());
    final chart = chartOf<BarChartView>(tester);

    await setSeekBar(tester, 0, 0);
    expect(chart.data!.dataSets.single.entryCount, 0);
    expect(tester.takeException(), isNull);

    await setSeekBar(tester, 0, 5);
    expect(chart.data!.dataSets.single.entryCount, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const StackedBarPage());
    final chart = chartOf<BarChartView>(tester);
    BarDataSet set() => chart.data!.dataSets.single as BarDataSet;

    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect(set().barBorderWidth, 1);
    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect(set().barBorderWidth, 0);
    await selectMenuItem(tester, 'Toggle Rounded Sections');
    expect(set().isStackSectionsRounded, isTrue);
    expect(set().barCornerRadius, 6);
    await selectMenuItem(tester, 'Toggle Rounded Sections');
    expect(set().isStackSectionsRounded, isFalse);
    expect(set().barCornerRadius, 0);
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
      await tester.pumpAndSettle();
      expect(chart.isAnimating, isFalse, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const StackedBarPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

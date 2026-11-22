import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/demo_drawables.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/horizontal_bar_negative_chart_page.dart';

import '../support/pages.dart';

/// res/menu/bar.xml as HorizontalBarNegativeChartActivity shows it, without the items this app leaves out.
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
  testWidgets('the page shows HorizontalBarNegativeChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const HorizontalBarNegativeChartPage());

    expect(find.widgetWithText(AppBar, 'Negative Horizontal'), findsOneWidget);
    expect(seekBars(tester), [12, 50]);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(
      find.ancestor(
        of: chartHosts,
        matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == demoChartBackground),
      ),
      findsOneWidget,
    );

    final chart = chartOf<HorizontalBarChartView>(tester);
    // animateY(2500) from onCreate.
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);
    expect(await menuTitles(tester), _menu);

    expect(chart.isDrawBarShadowEnabled, isFalse);
    expect(chart.isDrawValueAboveBarEnabled, isTrue);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.maxVisibleCount, 60);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.isFitBarsEnabled, isTrue);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.xAxis.isDrawAxisLineEnabled, isTrue);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.xAxis.granularity, 10);
    expect(chart.axisLeft.isDrawGridLinesEnabled, isTrue);
    expect(chart.axisRight.isDrawGridLinesEnabled, isFalse);

    final legend = chart.legend;
    expect(legend.verticalAlignment, LegendVerticalAlignment.BOTTOM);
    expect(legend.horizontalAlignment, LegendHorizontalAlignment.LEFT);
    expect(legend.orientation, LegendOrientation.HORIZONTAL);
    expect(legend.isDrawInsideEnabled, isFalse);
    expect(legend.formSize, 8);
    expect(legend.xEntrySpace, 4);

    final data = chart.data!;
    expect(data.barWidth, 9);
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'DataSet 1');
    expect(set.isDrawIconsEnabled, isFalse);
    expect(set.valueTextSize, 10);
    expect(set.entryCount, 12);
    final entries = [for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i)];
    expect([for (final e in entries) e.x], [for (var i = 0; i < 12; i++) i * 10]);
    expect([for (final e in entries) e.icon], everyElement(same(starDrawable)));
    // Math.random() * 50 - 50 / 2
    expect(ysOf(data), everyElement(inInclusiveRange(-25, 25)));
    expect(ysOf(data).where((y) => y < 0), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const HorizontalBarNegativeChartPage());
    final first = ysOf(chartOf<HorizontalBarChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const HorizontalBarNegativeChartPage());
    expect(ysOf(chartOf<HorizontalBarChartView>(tester).data!), first);
  });

  testWidgets('a seek bar puts new values into the data set, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const HorizontalBarNegativeChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<HorizontalBarChartView>(tester);
    final data = chart.data!;
    final set = data.dataSets.single;

    await setSeekBar(tester, 0, 30);
    expect(chart.data, same(data));
    expect(chart.data!.dataSets.single, same(set));
    expect(set.entryCount, 30);
    expect(set.getEntryForIndex(29).x, 290);
    expect(find.text('30'), findsOneWidget);

    await setSeekBar(tester, 1, 200);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(-100, 100)));
    expect(find.text('200'), findsOneWidget);

    final shown = chart.data;
    tester.element(find.byType(HorizontalBarNegativeChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a bar runs onValueSelected', (tester) async {
    await pumpPage(tester, const HorizontalBarNegativeChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<HorizontalBarChartView>(tester);

    chart.highlightValue(50, 0, callListener: true);
    await tester.pump();
    expect(chart.highlighted, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const HorizontalBarNegativeChartPage());
    await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      expect(chart.isAnimating, isFalse, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const HorizontalBarNegativeChartPage());
    await tester.pumpAndSettle();
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

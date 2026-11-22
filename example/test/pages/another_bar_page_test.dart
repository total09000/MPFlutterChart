import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/another_bar_page.dart';

import '../support/pages.dart';

/// res/menu/bar.xml as AnotherBarActivity shows it, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Bar Borders',
  'Toggle Rounded Sections',
  'Toggle Values',
  'Toggle Highlight',
  'Toggle PinchZoom',
  'Toggle Auto Scale',
  'Animate X',
  'Animate Y',
  'Animate XY',
];

void main() {
  testWidgets('the page shows AnotherBarActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const AnotherBarPage());

    expect(find.widgetWithText(AppBar, 'Basic 2'), findsOneWidget);
    expect(seekBars(tester), [10, 100]);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);

    final chart = chartOf<BarChartView>(tester);
    // animateY(1500) from onCreate.
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);
    expect(await menuTitles(tester), _menu);

    expect(chart.description.isEnabled, isFalse);
    expect(chart.maxVisibleCount, 60);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.isDrawBarShadowEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisLeft.isDrawGridLinesEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);
    expect(chart.isFitBarsEnabled, isTrue);

    final data = chart.data!;
    expect(data.dataSets, hasLength(1));
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'Data Set');
    expect(set.colors, ColorTemplate.VORDIPLOM_COLORS);
    expect(set.isDrawValuesEnabled, isFalse);
    expect(set.entryCount, 10);
    expect([for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).x], [for (var i = 0; i < 10; i++) i]);
    // Math.random() * 101 + 101 / 3
    expect(ysOf(data), everyElement(inInclusiveRange(101 / 3, 101 + 101 / 3)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const AnotherBarPage());
    final first = ysOf(chartOf<BarChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const AnotherBarPage());
    expect(ysOf(chartOf<BarChartView>(tester).data!), first);
  });

  testWidgets('a seek bar puts new values into the data set, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const AnotherBarPage());
    await tester.pumpAndSettle();
    final chart = chartOf<BarChartView>(tester);
    final data = chart.data!;
    final set = data.dataSets.single;

    await setSeekBar(tester, 0, 35);
    // The data set is kept and only its entries are replaced.
    expect(chart.data, same(data));
    expect(chart.data!.dataSets.single, same(set));
    expect(set.entryCount, 35);
    expect(find.text('35'), findsOneWidget);

    await setSeekBar(tester, 1, 20);
    expect(set.entryCount, 35);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(21 / 3, 21 + 21 / 3)));
    expect(find.text('20'), findsOneWidget);

    await setSeekBar(tester, 0, 0);
    expect(set.entryCount, 0);

    final shown = chart.data;
    tester.element(find.byType(AnotherBarPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const AnotherBarPage());
    await tester.pumpAndSettle();
    final chart = chartOf<BarChartView>(tester);
    BarDataSet set() => chart.data!.dataSets.single as BarDataSet;

    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect(set().barBorderWidth, 1);
    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect(set().barBorderWidth, 0);
    await selectMenuItem(tester, 'Toggle Values');
    expect(set().isDrawValuesEnabled, isTrue);
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
    await pumpPage(tester, const AnotherBarPage());
    await tester.pumpAndSettle();
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

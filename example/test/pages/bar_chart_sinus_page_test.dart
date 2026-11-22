import 'dart:io';

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/bar_chart_sinus_page.dart';

import '../support/pages.dart';

/// res/menu/bar.xml as BarChartActivitySinus shows it, without the items this app leaves out.
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

/// The y values of assets/othersine.txt, "y#x" per line.
List<double> _sine() => [
  for (final line in File('assets/othersine.txt').readAsLinesSync()) double.parse(line.split('#')[0]),
];

void main() {
  testWidgets('the page shows BarChartActivitySinus\'s chart, seek bar and menu', (tester) async {
    await pumpPage(tester, const BarChartSinusPage());

    expect(find.widgetWithText(AppBar, 'Sine'), findsOneWidget);
    expect(seekBars(tester), [150]);
    expect(find.text('150'), findsOneWidget);

    final chart = chartOf<BarChartView>(tester);
    // animateXY(1500, 1500) from onCreate.
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
    expect(chart.xAxis.isEnabled, isFalse);
    for (final axis in [chart.axisLeft, chart.axisRight]) {
      expect(axis.labelCount, 6);
      expect(axis.axisMinimum, -2.5);
      expect(axis.axisMaximum, 2.5);
      expect(axis.isGranularityEnabled, isTrue);
      expect(axis.granularity, closeTo(0.1, 1e-6));
    }
    expect(chart.axisLeft.isDrawGridLinesEnabled, isTrue);
    expect(chart.axisRight.isDrawGridLinesEnabled, isFalse);

    final legend = chart.legend;
    expect(legend.verticalAlignment, LegendVerticalAlignment.BOTTOM);
    expect(legend.horizontalAlignment, LegendHorizontalAlignment.LEFT);
    expect(legend.orientation, LegendOrientation.HORIZONTAL);
    expect(legend.isDrawInsideEnabled, isFalse);
    expect(legend.form, LegendForm.SQUARE);
    expect(legend.formSize, 9);
    expect(legend.textSize, 11);
    expect(legend.xEntrySpace, 4);

    final data = chart.data!;
    expect(data.barWidth, 0.8);
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'Sinus Function');
    expect(set.color, const Color.fromARGB(255, 240, 120, 124));
    expect(set.isDrawValuesEnabled, isFalse);
    expect(set.valueTextSize, 10);
    expect(set.entryCount, 150);
    expect([for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).x], [for (var i = 0; i < 150; i++) i]);
    expect(ysOf(data), _sine().take(150).toList());
    expect(tester.takeException(), isNull);
  });

  testWidgets('the seek bar shows that many values of the asset, which a later rebuild keeps', (tester) async {
    await pumpPage(tester, const BarChartSinusPage());
    await tester.pumpAndSettle();
    final chart = chartOf<BarChartView>(tester);
    final before = chart.data!;
    final set = before.dataSets.single;

    await setSeekBar(tester, 0, 8000);
    // A new BarData around the same data set, as setData builds one each time.
    final data = chart.data!;
    expect(data, isNot(same(before)));
    expect(data.dataSets.single, same(set));
    expect(set.entryCount, 8000);
    expect(ysOf(data), _sine());
    expect(find.text('8000'), findsOneWidget);

    await setSeekBar(tester, 0, 3);
    expect(chart.data!.dataSets.single.entryCount, 3);
    expect(chart.data!.dataSets.single.isDrawValuesEnabled, isFalse);

    final shown = chart.data;
    tester.element(find.byType(BarChartSinusPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const BarChartSinusPage());
    await tester.pumpAndSettle();
    final chart = chartOf<BarChartView>(tester);
    BarDataSet set() => chart.data!.dataSets.single as BarDataSet;

    await selectMenuItem(tester, 'Toggle Bar Borders');
    expect(set().barBorderWidth, 1);
    await selectMenuItem(tester, 'Toggle Values');
    expect(set().isDrawValuesEnabled, isTrue);
    // onOptionsItemSelected has no branch for actionToggleIcons.
    final icons = set().isDrawIconsEnabled;
    await selectMenuItem(tester, 'Toggle Icons');
    expect(set().isDrawIconsEnabled, icons);
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
    await pumpPage(tester, const BarChartSinusPage());
    await tester.pumpAndSettle();
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/custom_scatter_shape_renderer.dart';
import 'package:mp_flutter_chart_example/pages/scatter_chart_page.dart';

import '../support/pages.dart';

/// res/menu/scatter.xml as ScatterChartActivity shows it, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Values',
  'Toggle Icons',
  'Toggle Highlight',
  'Animate X',
  'Animate Y',
  'Animate XY',
  'Toggle PinchZoom',
  'Toggle Auto Scale',
];

void main() {
  testWidgets('the page shows ScatterChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const ScatterChartPage());

    expect(find.widgetWithText(AppBar, 'Scatter Plot'), findsOneWidget);
    expect(seekBars(tester), [45, 100]);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    final chart = chartOf<ScatterChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.maxHighlightDistance, 50);
    expect(chart.maxVisibleCount, 200);
    expect(chart.isPinchZoomEnabled, isTrue);
    expect(chart.legend.verticalAlignment, LegendVerticalAlignment.TOP);
    expect(chart.legend.horizontalAlignment, LegendHorizontalAlignment.RIGHT);
    expect(chart.legend.orientation, LegendOrientation.VERTICAL);
    expect(chart.legend.xOffset, 5);
    expect(chart.axisLeft.axisMinimum, 0);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.xAxis.position, XAxisPosition.TOP);

    final data = chart.data!;
    final sets = data.dataSets.cast<ScatterDataSet>();
    expect([for (final set in sets) set.label], ['DS 1', 'DS 2', 'DS 3']);
    expect([for (final set in sets) set.entryCount], [45, 45, 45]);
    expect([for (final set in sets) set.getEntryForIndex(2).x], [2, closeTo(2.33, 1e-6), closeTo(2.66, 1e-6)]);
    // (Math.random() * 100) + 3
    expect(ysOf(data), everyElement(inInclusiveRange(3, 103)));
    expect([for (final set in sets) set.color], ColorTemplate.COLORFUL_COLORS.take(3));
    expect([for (final set in sets) set.scatterShapeSize], [4, 4, 4]);
    expect(sets[1].scatterShapeHoleRadius, 1.5);
    expect(sets[1].scatterShapeHoleColor, ColorTemplate.COLORFUL_COLORS[3]);
    expect(sets[2].shapeRenderer, isA<CustomScatterShapeRenderer>());
    expect([for (final set in sets) set.isDrawValuesEnabled], everyElement(isTrue));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const ScatterChartPage());
    final first = ysOf(chartOf<ScatterChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const ScatterChartPage());
    expect(ysOf(chartOf<ScatterChartView>(tester).data!), first);
  });

  testWidgets('a seek bar sets new data, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const ScatterChartPage());
    final chart = chartOf<ScatterChartView>(tester);
    final before = chart.data;

    await setSeekBar(tester, 0, 12);
    final data = chart.data!;
    expect(data, isNot(same(before)));
    expect([for (final set in data.dataSets) set.entryCount], [12, 12, 12]);
    expect(find.text('12'), findsOneWidget);

    await setSeekBar(tester, 1, 20);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(3, 23)));
    expect(find.text('20'), findsOneWidget);

    final shown = chart.data;
    tester.element(find.byType(ScatterChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const ScatterChartPage());
    final chart = chartOf<ScatterChartView>(tester);

    await selectMenuItem(tester, 'Toggle Values');
    expect([for (final set in chart.data!.dataSets) set.isDrawValuesEnabled], everyElement(isFalse));
    final data = chart.data;
    await selectMenuItem(tester, 'Toggle Icons');
    expect(chart.data, same(data));
    expect([for (final set in chart.data!.dataSets) set.isDrawIconsEnabled], everyElement(isTrue));
    await selectMenuItem(tester, 'Toggle Highlight');
    expect(chart.data!.isHighlightEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle PinchZoom');
    expect(chart.isPinchZoomEnabled, isFalse);
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
    await pumpPage(tester, const ScatterChartPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/demo_drawables.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/bubble_chart_page.dart';

import '../support/pages.dart';

/// res/menu/bubble.xml as BubbleChartActivity shows it, without the items this app leaves out.
const List<String> _menu = [
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
  testWidgets('the page shows BubbleChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const BubbleChartPage());

    expect(find.widgetWithText(AppBar, 'Bubble Chart'), findsOneWidget);
    expect(seekBars(tester), [10, 50]);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(await menuTitles(tester), _menu);
    // android:background="@android:color/white"
    final white = find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == demoChartBackground);
    expect(find.ancestor(of: chartHosts, matching: white), findsOneWidget);

    final chart = chartOf<BubbleChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.maxVisibleCount, 200);
    expect(chart.isPinchZoomEnabled, isTrue);
    expect(chart.legend.verticalAlignment, LegendVerticalAlignment.TOP);
    expect(chart.legend.horizontalAlignment, LegendHorizontalAlignment.RIGHT);
    expect(chart.legend.orientation, LegendOrientation.VERTICAL);
    expect(chart.axisLeft.spaceTop, 30);
    expect(chart.axisLeft.spaceBottom, 30);
    expect(chart.axisLeft.isDrawZeroLineEnabled, isFalse);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);

    final data = chart.data!;
    final sets = data.dataSets.cast<BubbleDataSet>();
    expect([for (final set in sets) set.label], ['DS 1', 'DS 2', 'DS 3']);
    expect([for (final set in sets) set.entryCount], [10, 10, 10]);
    // (Math.random() * 50) for the values and the sizes.
    expect(ysOf(data), everyElement(inInclusiveRange(0, 50)));
    final sizes = [
      for (final set in sets)
        for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).size,
    ];
    expect(sizes, everyElement(inInclusiveRange(0, 50)));
    expect(sets[0].getEntryForIndex(0).icon, same(starDrawable));
    expect(sets[1].getEntryForIndex(0).icon, same(starDrawable));
    expect(sets[2].getEntryForIndex(0).icon, isNull);
    expect([for (final set in sets) set.isDrawIconsEnabled], [false, false, true]);
    expect([for (final set in sets) set.isDrawValuesEnabled], everyElement(isFalse));
    expect(sets[0].color, ColorTemplate.COLORFUL_COLORS[0].withAlpha(130));
    expect(sets[1].iconsOffset.y, 15);
    expect(sets[0].highlightCircleWidth, 1.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const BubbleChartPage());
    final first = ysOf(chartOf<BubbleChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const BubbleChartPage());
    expect(ysOf(chartOf<BubbleChartView>(tester).data!), first);
  });

  testWidgets('a seek bar sets new data, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const BubbleChartPage());
    final chart = chartOf<BubbleChartView>(tester);
    final before = chart.data;

    await setSeekBar(tester, 0, 30);
    final data = chart.data!;
    expect(data, isNot(same(before)));
    expect([for (final set in data.dataSets) set.entryCount], [30, 30, 30]);
    expect(find.text('30'), findsOneWidget);

    await setSeekBar(tester, 1, 5);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(0, 5)));
    expect(find.text('5'), findsOneWidget);

    final shown = chart.data;
    tester.element(find.byType(BubbleChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const BubbleChartPage());
    final chart = chartOf<BubbleChartView>(tester);

    await selectMenuItem(tester, 'Toggle Values');
    expect([for (final set in chart.data!.dataSets) set.isDrawValuesEnabled], everyElement(isTrue));
    await selectMenuItem(tester, 'Toggle Icons');
    expect([for (final set in chart.data!.dataSets) set.isDrawIconsEnabled], [true, true, false]);
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
    await pumpPage(tester, const BubbleChartPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

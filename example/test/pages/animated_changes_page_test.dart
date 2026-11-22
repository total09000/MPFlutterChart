import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/animated_changes_page.dart';

import '../support/pages.dart';

/// The buttons of res/layout/activity_animated_changes.xml, in capitals as AppCompat shows them.
const List<String> _buttons = ['RANDOMIZE', 'ADD', 'REMOVE'];

Future<void> _press(WidgetTester tester, String text) async {
  await tester.tap(find.widgetWithText(ElevatedButton, text));
  await tester.pump();
}

int _count(BarChartView chart) => chart.data!.dataSets.single.entryCount;

void main() {
  testWidgets('the page shows AnimatedChangesActivity\'s chart, hint and buttons', (tester) async {
    await pumpPage(tester, const AnimatedChangesPage());

    expect(find.widgetWithText(AppBar, 'Animated data changes'), findsOneWidget);
    // The Activity has no options menu.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Tap a bar to animate it to a new value.'), findsOneWidget);
    for (final text in _buttons) {
      expect(find.widgetWithText(ElevatedButton, text), findsOneWidget, reason: text);
    }

    final chart = chartOf<BarChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.xAxis.granularity, 1);
    expect(chart.axisLeft.axisMinimum, 0);
    expect(chart.axisRight.isEnabled, isFalse);

    final data = chart.data!;
    expect(data.barWidth, 0.7);
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'Values');
    expect(set.entryCount, 8);
    expect(set.colors, ColorTemplate.MATERIAL_COLORS);
    expect(set.valueTextSize, 10);
    expect([for (var i = 0; i < 8; i++) set.getEntryForIndex(i).x], [0, 1, 2, 3, 4, 5, 6, 7]);
    // Random.nextInt(10, 100)
    expect(ysOf(data), everyElement(inInclusiveRange(10, 99)));
    expect(ysOf(data).every((y) => y == y.roundToDouble()), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const AnimatedChangesPage());
    final first = ysOf(chartOf<BarChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const AnimatedChangesPage());
    expect(ysOf(chartOf<BarChartView>(tester).data!), first);
  });

  testWidgets('Randomize, Add and Remove animate in new data, which a later rebuild keeps', (tester) async {
    await pumpPage(tester, const AnimatedChangesPage());
    final chart = chartOf<BarChartView>(tester);
    final before = ysOf(chart.data!);

    await _press(tester, 'RANDOMIZE');
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);
    expect(_count(chart), 8);
    final randomized = ysOf(chart.data!);
    expect(randomized, isNot(before));
    expect(randomized, everyElement(inInclusiveRange(10, 99)));

    await _press(tester, 'ADD');
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(_count(chart), 9);
    expect(ysOf(chart.data!).take(8), randomized);
    expect(chart.data!.dataSets.single.getEntryForIndex(8).x, 8);

    await _press(tester, 'REMOVE');
    await tester.pumpAndSettle();
    await _press(tester, 'REMOVE');
    await tester.pumpAndSettle();
    expect(_count(chart), 7);
    expect(ysOf(chart.data!), randomized.take(7));

    // A rebuild of the page hands the host the chart's own data, so the host leaves it alone.
    final shown = chart.data;
    tester.element(find.byType(AnimatedChangesPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Remove keeps the last bar and still animates new data', (tester) async {
    await pumpPage(tester, const AnimatedChangesPage());
    final chart = chartOf<BarChartView>(tester);
    for (var i = 0; i < 8; i++) {
      await _press(tester, 'REMOVE');
      await tester.pumpAndSettle();
    }
    expect(_count(chart), 1);
    final data = chart.data;
    final last = ysOf(chart.data!);
    await _press(tester, 'REMOVE');
    expect(chart.data, isNot(same(data)));
    await tester.pumpAndSettle();
    expect(_count(chart), 1);
    expect(ysOf(chart.data!), last);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a bar animates that bar alone to a new value', (tester) async {
    await pumpPage(tester, const AnimatedChangesPage());
    final chart = chartOf<BarChartView>(tester);
    final data = chart.data;
    final before = ysOf(chart.data!);

    // A tap on the bar at x 3 selects it, which calls onValueSelected.
    chart.highlightValue(3, 0);
    await tester.pump();
    expect(chart.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);
    expect(chart.data, same(data));
    final after = ysOf(chart.data!);
    for (var i = 0; i < before.length; i++) {
      if (i != 3) expect(after[i], before[i], reason: 'bar $i');
    }
    expect(after[3], inInclusiveRange(10, 99));

    // The new value is kept for the next data change.
    await _press(tester, 'ADD');
    await tester.pumpAndSettle();
    expect(ysOf(chart.data!).take(8), after);

    // A real tap near the bottom of the plot, inside every bar, selects a bar and animates it.
    final bars = ysOf(chart.data!);
    await tester.tapAt(tester.getCenter(chartHosts) + const Offset(0, 300));
    await tester.pump();
    expect(chart.highlighted, hasLength(1));
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    final tapped = chart.highlighted.single.x.toInt();
    final now = ysOf(chart.data!);
    for (var i = 0; i < bars.length; i++) {
      if (i != tapped) expect(now[i], bars[i], reason: 'bar $i');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every button can be pressed twice', (tester) async {
    await pumpPage(tester, const AnimatedChangesPage());
    for (final text in _buttons) {
      for (var round = 0; round < 2; round++) {
        await _press(tester, text);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: '$text, round ${round + 1}');
      }
    }
    await tester.pumpAndSettle();
  });
}

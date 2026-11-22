import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/realtime_line_chart_page.dart';

import '../support/pages.dart';

/// res/menu/realtime.xml, without the items this app leaves out.
const List<String> _menu = ['Add Entry', 'Clear chart', 'Add Multiple'];

/// The number of entries the chart shows.
int _count(LineChartView chart) => chart.data!.entryCount;

void main() {
  testWidgets('the page shows RealtimeLineChartActivity\'s empty chart and menu', (tester) async {
    await pumpPage(tester, const RealtimeLineChartPage());

    expect(find.widgetWithText(AppBar, 'Realtime'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    final background =
        tester.widget<ColoredBox>(find.ancestor(of: chartHosts, matching: find.byType(ColoredBox)).first);
    expect(background.color, const Color(0xFFCCCCCC));

    final chart = chartOf<LineChartView>(tester);
    expect(chart.description.isEnabled, isTrue);
    expect(chart.isPinchZoomEnabled, isTrue);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.legend.form, LegendForm.LINE);
    expect(chart.legend.textColor, const Color(0xFFFFFFFF));
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.xAxis.isAvoidFirstLastClippingEnabled, isTrue);
    expect(chart.axisLeft.axisMinimum, 0);
    expect(chart.axisLeft.axisMaximum, 100);
    expect(chart.axisLeft.isDrawGridLinesEnabled, isTrue);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.data!.dataSetCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Entry creates the set and adds one entry, Clear chart keeps the data', (tester) async {
    await pumpPage(tester, const RealtimeLineChartPage());
    final chart = chartOf<LineChartView>(tester);
    final data = chart.data!;

    await selectMenuItem(tester, 'Add Entry');
    await selectMenuItem(tester, 'Add Entry');
    final set = data.dataSets.single as LineDataSet;
    expect(set.label, 'Dynamic Data');
    expect(set.color, ColorTemplate.holoBlue);
    expect(set.lineWidth, 2);
    expect(set.circleRadius, 4);
    expect(set.fillAlpha, 65);
    expect(set.isDrawValuesEnabled, isFalse);
    expect([set.getEntryForIndex(0).x, set.getEntryForIndex(1).x], [0, 1]);
    // (Math.random() * 40) + 30
    expect(ysOf(data), everyElement(inInclusiveRange(30, 70)));

    await selectMenuItem(tester, 'Clear chart');
    expect(find.text('Chart cleared!'), findsOneWidget);
    expect(chart.data, same(data));
    expect(data.dataSetCount, 0);

    await selectMenuItem(tester, 'Add Entry');
    expect(data.dataSets.single, isNot(same(set)));
    expect(data.dataSets.single.getEntryForIndex(0).x, 0);

    tester.element(find.byType(RealtimeLineChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(_count(chart), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page add the same values', (tester) async {
    Future<List<double>> run() async {
      await pumpPage(tester, const RealtimeLineChartPage());
      for (var i = 0; i < 5; i++) {
        await selectMenuItem(tester, 'Add Entry');
      }
      return ysOf(chartOf<LineChartView>(tester).data!);
    }

    final first = await run();
    await tester.pumpWidget(const SizedBox());
    expect(await run(), first);
  });

  testWidgets('Add Multiple adds 1000 entries, one every 25 ms, and a new one restarts the feed', (tester) async {
    await pumpPage(tester, const RealtimeLineChartPage());
    final chart = chartOf<LineChartView>(tester);

    await selectMenuItem(tester, 'Add Multiple', settle: false);
    final started = _count(chart);
    expect(started, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_count(chart), started + 10);

    // Leave the feed running long enough for all of it, then some more: it stops at 1000.
    await tester.pump(const Duration(seconds: 30));
    expect(_count(chart), 1000);
    await tester.pump(const Duration(seconds: 1));
    expect(_count(chart), 1000);
    // setVisibleXRangeMaximum(120) and moveViewToX(entryCount): the view ends at the newest entries.
    expect(chart.highestVisibleX, closeTo(999, 1));
    expect(chart.highestVisibleX - chart.lowestVisibleX, closeTo(120, 1));

    // A second Add Multiple while one runs cancels the first.
    await selectMenuItem(tester, 'Add Multiple', settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    final before = _count(chart);
    await selectMenuItem(tester, 'Add Multiple', settle: false);
    await tester.pump(const Duration(seconds: 30));
    final restarted = _count(chart);
    expect(restarted, greaterThan(before + 1000 - 1));
    expect(restarted, lessThan(before + 1000 + 50));
    await tester.pump(const Duration(seconds: 1));
    expect(_count(chart), restarted);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the feed stops when the app becomes inactive and when the page goes away', (tester) async {
    await pumpPage(tester, const RealtimeLineChartPage());
    final chart = chartOf<LineChartView>(tester);

    await selectMenuItem(tester, 'Add Multiple', settle: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final paused = _count(chart);
    await tester.pump(const Duration(seconds: 1));
    expect(_count(chart), paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    // Removing the page with the feed running leaves no timer behind, which testWidgets would report.
    await selectMenuItem(tester, 'Add Multiple', settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the options menu and a route above the page leave the feed running', (tester) async {
    await pumpPage(tester, const RealtimeLineChartPage());
    final chart = chartOf<LineChartView>(tester);

    await selectMenuItem(tester, 'Add Multiple', settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    // Clear chart while the feed runs: the menu's popup route does not stop it, and it goes on in a new set.
    await selectMenuItem(tester, 'Clear chart', settle: false);
    final cleared = _count(chart);
    expect(cleared, lessThan(30));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_count(chart), cleared + 10);

    final navigator = Navigator.of(tester.element(find.byType(RealtimeLineChartPage)));
    navigator.push(MaterialPageRoute<void>(builder: (context) => const SizedBox()));
    await tester.pump();
    final covered = _count(chart);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_count(chart), covered + 10);
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('popping the page stops the feed at once', (tester) async {
    await pumpPage(tester, const SizedBox());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (context) => const RealtimeLineChartPage()));
    await tester.pumpAndSettle();
    final chart = chartOf<LineChartView>(tester);

    await selectMenuItem(tester, 'Add Multiple', settle: false);
    navigator.pop();
    await tester.pump();
    final popped = _count(chart);
    // The page is still shown while its route animates out, but adds nothing more.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RealtimeLineChartPage), findsOneWidget);
    expect(_count(chart), lessThanOrEqualTo(popped + 1));
    final stopped = _count(chart);
    await tester.pumpAndSettle();
    expect(find.byType(RealtimeLineChartPage), findsNothing);
    expect(_count(chart), stopped);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const RealtimeLineChartPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title, settle: false);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}

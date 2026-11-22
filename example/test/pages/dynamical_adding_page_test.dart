import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/dynamical_adding_page.dart';

import '../support/pages.dart';

/// res/menu/dynamical.xml, without the items this app leaves out.
const List<String> _menu = ['Add Entry', 'Remove Entry', 'Add Data Set', 'Remove Data Set', 'Clear chart'];

/// Rebuilds the page, as any setState of it would.
Future<void> _rebuild(WidgetTester tester) async {
  tester.element(find.byType(DynamicalAddingPage)).markNeedsBuild();
  await tester.pump();
}

void main() {
  testWidgets('the page starts with an empty chart and DynamicalAddingActivity\'s menu', (tester) async {
    await pumpPage(tester, const DynamicalAddingPage());

    expect(find.widgetWithText(AppBar, 'Dynamic'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    final chart = chartOf<LineChartView>(tester);
    expect(chart.data, isNull);
    expect(chart.noDataText, 'Use the menu to add entries and data sets');
    expect(chart.description.isEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Entry creates the data and its first set, and adds to a random set', (tester) async {
    await pumpPage(tester, const DynamicalAddingPage());
    final chart = chartOf<LineChartView>(tester);

    await selectMenuItem(tester, 'Add Entry');
    expect(find.text('Entry<*> added!'), findsOneWidget);
    final data = chart.data!;
    final first = data.dataSets.single as LineDataSet;
    expect(first.label, 'DataSet 1');
    expect(first.lineWidth, 2.5);
    expect(first.circleRadius, 4.5);
    expect(first.color, const Color.fromARGB(255, 240, 99, 99));
    expect(first.highlightColor, const Color.fromARGB(255, 190, 190, 190));
    expect(first.axisDependency, AxisDependency.LEFT);
    expect(first.entryCount, 1);
    expect(first.getEntryForIndex(0).x, 0);
    // (Math.random() * 50) + 50 * (0 + 1)
    expect(first.getEntryForIndex(0).y, inInclusiveRange(50, 100));

    // The data the menu created survives a rebuild of the page.
    await _rebuild(tester);
    expect(chart.data, same(data));

    await selectMenuItem(tester, 'Add Data Set');
    expect(find.text('DataSet added!'), findsOneWidget);
    final second = data.dataSets[1] as LineDataSet;
    expect(second.label, 'DataSet 2');
    expect(second.entryCount, 1);
    expect(second.color, ColorTemplate.VORDIPLOM_COLORS[2]);
    expect(second.valueTextColor, ColorTemplate.VORDIPLOM_COLORS[2]);
    // (Math.random() * 50) + 50 * 2
    expect(second.getEntryForIndex(0).y, inInclusiveRange(100, 150));

    for (var i = 0; i < 10; i++) {
      await selectMenuItem(tester, 'Add Entry');
    }
    expect(first.entryCount + second.entryCount, 12);
    for (final (index, set) in [first, second].indexed) {
      for (var i = 0; i < set.entryCount; i++) {
        expect(set.getEntryForIndex(i).x, i);
        expect(set.getEntryForIndex(i).y, inInclusiveRange(50.0 * (index + 1), 50.0 * (index + 2)));
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page add the same values', (tester) async {
    Future<List<double>> run() async {
      await pumpPage(tester, const DynamicalAddingPage());
      await selectMenuItem(tester, 'Add Entry');
      await selectMenuItem(tester, 'Add Data Set');
      await selectMenuItem(tester, 'Add Entry');
      await selectMenuItem(tester, 'Add Entry');
      return ysOf(chartOf<LineChartView>(tester).data!);
    }

    final first = await run();
    await tester.pumpWidget(const SizedBox());
    expect(await run(), first);
  });

  testWidgets('the remove items and Clear chart do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const DynamicalAddingPage());
    final chart = chartOf<LineChartView>(tester);

    await selectMenuItem(tester, 'Add Entry');
    await selectMenuItem(tester, 'Add Entry');
    await selectMenuItem(tester, 'Add Entry');
    final data = chart.data!;
    final first = data.dataSets.single;
    expect(first.entryCount, 3);
    final kept = [first.getEntryForIndex(0), first.getEntryForIndex(1)];

    await selectMenuItem(tester, 'Remove Entry');
    expect(find.text('Entry<*> removed!'), findsOneWidget);
    expect([for (var i = 0; i < first.entryCount; i++) first.getEntryForIndex(i)], kept);

    await selectMenuItem(tester, 'Add Data Set');
    expect(data.dataSetCount, 2);
    expect(data.dataSets[1].entryCount, 2);
    await selectMenuItem(tester, 'Remove Data Set');
    expect(find.text('DataSet removed!'), findsOneWidget);
    expect(data.dataSets, [first]);

    await selectMenuItem(tester, 'Clear chart');
    expect(find.text('Chart cleared!'), findsOneWidget);
    expect(chart.data, isNull);
    await _rebuild(tester);
    expect(chart.data, isNull);

    // Without data, Add Data Set only sets an empty LineData.
    await selectMenuItem(tester, 'Add Data Set');
    final empty = chart.data!;
    expect(empty.dataSetCount, 0);
    await _rebuild(tester);
    expect(chart.data, same(empty));
    // A second one has no first set to take the entry count from.
    await selectMenuItem(tester, 'Add Data Set');
    expect(empty.dataSetCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const DynamicalAddingPage());
    for (final title in [..._menu, ..._menu]) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

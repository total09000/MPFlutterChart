import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/design/kotlin_random.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/pages/compose_chart_page.dart';

import '../support/pages.dart';

/// `revenueSet(seed)`'s values: a walk from 28 by `Random(seed).nextInt(-5, 15)`, kept within 18 to 92.
List<double> revenue(int seed) {
  final random = KotlinRandom(seed);
  var value = 28.0;
  return [
    for (var i = 0; i < 12; i++) value = (value + random.nextIntRange(-5, 15)).clamp(18, 92).toDouble(),
  ];
}

LineChartView lineChart(WidgetTester tester) => chartOf<LineChartView>(tester, 0);
PieChartView pieChart(WidgetTester tester) => chartOf<PieChartView>(tester, 1);
BarChartView barChart(WidgetTester tester) => chartOf<BarChartView>(tester, 2);

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pump();
}

void main() {
  testWidgets('the page shows ComposeChartScreen\'s three cards', (tester) async {
    await pumpPage(tester, const ComposeChartPage());

    expect(find.widgetWithText(AppBar, 'Compose'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    for (final text in [
      'Revenue',
      'Driven by Compose state',
      'Sessions by platform',
      'New data animates in',
      'Orders per quarter',
      'Rounded bars with a gradient',
      'Tap a point to select it',
      'Add point',
      'New data',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(chartHosts, findsNWidgets(3));
    for (final description in ['Revenue line chart', 'Sessions pie chart', 'Orders bar chart']) {
      expect(find.bySemanticsLabel(description), findsOneWidget, reason: description);
    }
    final scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scroll.dragStartBehavior, chartScrollDragStartBehavior);

    final line = lineChart(tester);
    expect(line.description.isEnabled, isFalse);
    expect(line.legend.isEnabled, isFalse);
    expect(line.isDragEnabled, isFalse);
    expect(line.xAxis.axisMinimum, -0.5);
    expect(line.xAxis.axisMaximum, 11.5);
    expect(line.xAxis.labelCount, 12);
    expect(line.xAxis.granularity, 1);
    expect(line.xAxis.valueFormatter.getFormattedValue(13, line.xAxis), 'Feb');
    expect(line.axisLeft.axisMinimum, 0);
    expect(line.axisLeft.axisMaximum, 100);
    expect(line.axisLeft.labelCount, 5);
    expect(line.axisLeft.isForceLabelsEnabled, isTrue);

    final lineData = line.data!;
    final set = lineData.dataSets.single as LineDataSet;
    expect(set.label, 'Revenue');
    expect(set.mode, LineDataSetMode.CUBIC_BEZIER);
    expect(set.color, Nightfall.accent);
    expect(set.circleHoleColor, Nightfall.light.card);
    expect([for (var i = 0; i < 12; i++) set.getEntryForIndex(i).x], [for (var i = 0; i < 12; i++) i]);
    expect(ysOf(lineData), revenue(0));
    expect(ysOf(lineData), everyElement(inInclusiveRange(18, 92)));

    final pie = pieChart(tester);
    final pieSet = pie.data!.dataSets.single;
    expect([for (var i = 0; i < 4; i++) pieSet.getEntryForIndex(i).label], ['Mobile', 'Web', 'Desktop', 'Other']);
    final random = KotlinRandom(0);
    expect(ysOf(pie.data!), [for (var i = 0; i < 4; i++) random.nextIntRange(10, 50).toDouble()]);
    expect(pieSet.colors, Nightfall.palette.take(4).toList());

    final bar = barChart(tester);
    expect(bar.axisLeft.axisMaximum, 100);
    expect(bar.axisLeft.isForceLabelsEnabled, isTrue);
    expect(bar.xAxis.valueFormatter.getFormattedValue(4, bar.xAxis), 'Q1');
    expect(bar.data!.barWidth, 0.55);
    final barRandom = KotlinRandom(0);
    expect(ysOf(bar.data!), [for (var i = 0; i < 8; i++) barRandom.nextIntRange(30, 90).toDouble()]);
    final barSet = bar.data!.dataSets.single as BarDataSet;
    expect(barSet.barCornerRadius, 7);
    expect(barSet.fills, hasLength(8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the LaunchedEffects animate the line chart and highlight the sixth bar', (tester) async {
    await pumpPage(tester, const ComposeChartPage());
    expect(lineChart(tester).isAnimating, isTrue);
    final bar = barChart(tester);
    expect(bar.highlighted.single.x, 5);

    await tester.pumpAndSettle();
    expect(lineChart(tester).isAnimating, isFalse);
    // The bar marker shows the highlighted value.
    expect(find.text('${bar.data!.dataSets.single.getEntryForIndex(5).y.round()}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add point appends an entry, selects it and widens the x axis', (tester) async {
    await pumpPage(tester, const ComposeChartPage());
    await tester.pumpAndSettle();
    final line = lineChart(tester);
    final data = line.data;

    await tapButton(tester, 'Add point');
    await tester.pumpAndSettle();
    expect(line.data, same(data));
    final set = line.data!.dataSets.single;
    expect(set.entryCount, 13);
    final added = set.getEntryForIndex(12);
    expect(added.x, 12);
    expect(added.y, inInclusiveRange(18, 92));
    // nextRevenue: previous + Random.nextInt(-9, 14), within 18 to 92.
    expect(added.y - set.getEntryForIndex(11).y, inInclusiveRange(-9, 13));
    expect(line.xAxis.axisMaximum, 12.5);
    expect(line.xAxis.labelCount, 12);
    expect(line.highlighted.single.x, 12);
    expect(find.text('Selected Jan: ${added.y.round()}'), findsOneWidget);
    // The marker of the line chart.
    expect(find.text('Jan · ${added.y.round()}'), findsOneWidget);

    await tapButton(tester, 'Add point');
    await tester.pumpAndSettle();
    expect(set.entryCount, 14);
    expect(find.textContaining('Selected Feb: '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('New data gives every chart the data of the next seed', (tester) async {
    await pumpPage(tester, const ComposeChartPage());
    await tester.pumpAndSettle();
    await tapButton(tester, 'Add point');
    await tester.pumpAndSettle();

    final pie = pieChart(tester).data;
    await tapButton(tester, 'New data');
    expect(lineChart(tester).isAnimating, isTrue);
    await tester.pumpAndSettle();

    final line = lineChart(tester);
    expect(ysOf(line.data!), revenue(1));
    expect(line.xAxis.axisMaximum, 11.5);
    expect(pieChart(tester).data, isNot(same(pie)));
    final random = KotlinRandom(1);
    expect(ysOf(pieChart(tester).data!), [for (var i = 0; i < 4; i++) random.nextIntRange(10, 50).toDouble()]);
    final barRandom = KotlinRandom(1);
    expect(ysOf(barChart(tester).data!), [for (var i = 0; i < 8; i++) barRandom.nextIntRange(30, 90).toDouble()]);
    expect(barChart(tester).highlighted.single.x, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values and add the same points', (tester) async {
    Future<List<double>> run() async {
      await pumpPage(tester, const ComposeChartPage());
      await tester.pumpAndSettle();
      await tapButton(tester, 'Add point');
      await tapButton(tester, 'Add point');
      await tester.pumpAndSettle();
      return [...ysOf(lineChart(tester).data!), ...ysOf(pieChart(tester).data!), ...ysOf(barChart(tester).data!)];
    }

    final first = await run();
    await tester.pumpWidget(const SizedBox());
    expect(await run(), first);
  });

  testWidgets('a rebuild of the page keeps the data', (tester) async {
    await pumpPage(tester, const ComposeChartPage());
    await tester.pumpAndSettle();
    final shown = [lineChart(tester).data, pieChart(tester).data, barChart(tester).data];
    tester.element(find.byType(ComposeChartPage)).markNeedsBuild();
    await tester.pumpAndSettle();
    expect(lineChart(tester).data, same(shown[0]));
    expect(pieChart(tester).data, same(shown[1]));
    expect(barChart(tester).data, same(shown[2]));
  });

  testWidgets('every button can be pressed twice', (tester) async {
    await pumpPage(tester, const ComposeChartPage());
    for (final label in ['Add point', 'New data']) {
      for (var round = 0; round < 2; round++) {
        await tapButton(tester, label);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label, round ${round + 1}');
      }
    }
  });
}

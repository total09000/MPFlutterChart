import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/pages/list_view_multi_chart_page.dart';

import '../support/pages.dart';

/// The chart of the row at [position], which must be built.
C rowChart<C extends Chart>(WidgetTester tester, int position) => tester
    .widget<ChartHostWidget>(find.descendant(of: find.byKey(ValueKey(position)), matching: chartHosts))
    .chart as C;

ScrollPosition listPosition(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable)).position;

Future<void> jumpTo(WidgetTester tester, double pixels) async {
  listPosition(tester).jumpTo(pixels);
  await tester.pump();
}

void main() {
  testWidgets('the page shows ListViewMultiChartActivity\'s list of line, bar and pie charts', (tester) async {
    await pumpPage(tester, const ListViewMultiChartPage());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Multiple'), findsOneWidget);
    // only_github.xml has nothing but "View on GitHub", which is not ported.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(tester.widget<ListView>(find.byType(ListView)).dragStartBehavior, chartScrollDragStartBehavior);

    final line = rowChart<LineChartView>(tester, 0);
    expect(line.description.isEnabled, isFalse);
    expect(line.xAxis.position, XAxisPosition.BOTTOM);
    expect(line.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(line.axisLeft.labelCount, 5);
    expect(line.axisLeft.axisMinimum, 0);
    expect(line.axisRight.isDrawGridLinesEnabled, isFalse);
    final lineData = line.data!;
    expect([for (final set in lineData.dataSets) set.label], ['New DataSet 1, (1)', 'New DataSet 1, (2)']);
    expect([for (final set in lineData.dataSets) set.entryCount], [12, 12]);
    final ys = ysOf(lineData);
    // (Math.random() * 65).toInt() + 40, and the second set 30 lower.
    expect(ys.sublist(0, 12), everyElement(allOf(inInclusiveRange(40, 104), predicate<double>((y) => y == y.floor()))));
    expect(ys.sublist(12), [for (final y in ys.sublist(0, 12)) y - 30]);
    expect([for (final set in lineData.dataSets) set.isDrawValuesEnabled], [false, false]);

    final bar = rowChart<BarChartView>(tester, 1);
    expect(bar.isFitBarsEnabled, isTrue);
    expect(bar.axisLeft.spaceTop, 20);
    expect(bar.axisRight.axisMinimum, 0);
    final barData = bar.data!;
    expect(barData.barWidth, 0.9);
    expect(barData.dataSets.single.label, 'New DataSet 2');
    expect((barData.dataSets.single as BarDataSet).highlightAlpha, 255);
    // (Math.random() * 70).toInt() + 30
    expect(ysOf(barData), everyElement(allOf(inInclusiveRange(30, 99), predicate<double>((y) => y == y.floor()))));
    expect(ysOf(barData), hasLength(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pie row and a row far down the list build when scrolled to', (tester) async {
    await pumpPage(tester, const ListViewMultiChartPage());
    await tester.pumpAndSettle();

    await jumpTo(tester, 400);
    final pie = rowChart<PieChartView>(tester, 2);
    expect(pie.holeRadius, 52);
    expect(pie.transparentCircleRadius, 57);
    expect(pie.centerText, 'MPAndroidChart\ncreated by\nPhilipp Jahoda');
    expect(pie.isUsePercentValuesEnabled, isTrue);
    expect(pie.legend.orientation, LegendOrientation.VERTICAL);
    final pieData = pie.data!;
    expect(pieData.dataSets.single.entryCount, 4);
    expect(pieData.dataSets.single.valueFormatter, isA<PercentFormatter>());
    // Math.random() * 70 + 30
    expect(ysOf(pieData), everyElement(inInclusiveRange(30, 100)));

    await jumpTo(tester, listPosition(tester).maxScrollExtent);
    expect(find.byKey(const ValueKey(29)), findsOneWidget);
    expect(rowChart<PieChartView>(tester, 29).data!.dataSets.single.entryCount, 4);
    expect(rowChart<BarChartView>(tester, 28).data!.dataSets.single.label, 'New DataSet 29');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row that scrolls away and back shows the same data', (tester) async {
    await pumpPage(tester, const ListViewMultiChartPage());
    await tester.pumpAndSettle();
    final first = rowChart<LineChartView>(tester, 0);
    final data = first.data;

    await jumpTo(tester, listPosition(tester).maxScrollExtent);
    expect(find.byKey(const ValueKey(0)), findsNothing);
    await jumpTo(tester, 0);
    await tester.pumpAndSettle();
    expect(rowChart<LineChartView>(tester, 0).data, same(data));

    // A rebuild of the page keeps the data too.
    tester.element(find.byType(ListViewMultiChartPage)).markNeedsBuild();
    await tester.pump();
    expect(rowChart<LineChartView>(tester, 0).data, same(data));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a vertical swipe that starts on the chart of a row scrolls the list', (tester) async {
    await pumpPage(tester, const ListViewMultiChartPage());
    await tester.pumpAndSettle();
    expect(listPosition(tester).pixels, 0);

    await tester.fling(find.byKey(const ValueKey(0)), const Offset(0, -600), 1500);
    await tester.pumpAndSettle();
    expect(listPosition(tester).pixels, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const ListViewMultiChartPage());
    final line = ysOf(rowChart<LineChartView>(tester, 0).data!);
    final bar = ysOf(rowChart<BarChartView>(tester, 1).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const ListViewMultiChartPage());
    expect(ysOf(rowChart<LineChartView>(tester, 0).data!), line);
    expect(ysOf(rowChart<BarChartView>(tester, 1).data!), bar);
    await tester.pumpAndSettle();
  });

  testWidgets('a row animates when it is built', (tester) async {
    await pumpPage(tester, const ListViewMultiChartPage());
    expect(rowChart<LineChartView>(tester, 0).isAnimating, isTrue);
    expect(rowChart<BarChartView>(tester, 1).isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(rowChart<LineChartView>(tester, 0).isAnimating, isFalse);
  });
}

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/list_view_bar_chart_page.dart';

import '../support/pages.dart';

/// The chart of the row at [position], which must be built.
BarChartView rowChart(WidgetTester tester, int position) => tester
    .widget<ChartHostWidget>(find.descendant(of: find.byKey(ValueKey(position)), matching: chartHosts))
    .chart as BarChartView;

ScrollPosition listPosition(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable)).position;

Future<void> jumpTo(WidgetTester tester, double pixels) async {
  listPosition(tester).jumpTo(pixels);
  await tester.pump();
}

void main() {
  testWidgets('the page shows ListViewBarChartActivity\'s list of bar charts', (tester) async {
    await pumpPage(tester, const ListViewBarChartPage());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Many Bar Charts'), findsOneWidget);
    // only_github.xml has nothing but "View on GitHub", which is not ported.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(tester.widget<ListView>(find.byType(ListView)).dragStartBehavior, chartScrollDragStartBehavior);
    expect(tester.getSize(find.byKey(const ValueKey(0))).height, 200);

    final chart = rowChart(tester, 0);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.isFitBarsEnabled, isTrue);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.xAxis.typeface, tfLight);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisLeft.labelCount, 5);
    expect(chart.axisLeft.spaceTop, 15);
    expect(chart.axisRight.labelCount, 5);
    expect(chart.axisRight.spaceTop, 15);

    final data = chart.data!;
    expect(data.barWidth, 0.9);
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'New DataSet 1');
    expect(set.entryCount, 12);
    expect(set.colors, ColorTemplate.VORDIPLOM_COLORS);
    expect(set.barShadowColor, const Color.fromARGB(255, 203, 203, 203));
    expect(set.valueTextColor, const Color(0xFF000000));
    expect(set.valueTypeface, tfLight);
    // (Math.random() * 70) + 30
    expect(ysOf(data), everyElement(inInclusiveRange(30, 100)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the last row builds when scrolled to, and a row that comes back shows the same data', (tester) async {
    await pumpPage(tester, const ListViewBarChartPage());
    await tester.pumpAndSettle();
    final data = rowChart(tester, 0).data;

    await jumpTo(tester, listPosition(tester).maxScrollExtent);
    expect(find.byKey(const ValueKey(19)), findsOneWidget);
    expect(find.byKey(const ValueKey(0)), findsNothing);
    final last = rowChart(tester, 19);
    expect(last.data!.dataSets.single.label, 'New DataSet 20');
    expect(last.isAnimating, isTrue);
    await tester.pumpAndSettle();

    await jumpTo(tester, 0);
    expect(rowChart(tester, 0).data, same(data));

    tester.element(find.byType(ListViewBarChartPage)).markNeedsBuild();
    await tester.pump();
    expect(rowChart(tester, 0).data, same(data));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a vertical swipe that starts on the chart of a row scrolls the list', (tester) async {
    await pumpPage(tester, const ListViewBarChartPage());
    await tester.pumpAndSettle();
    expect(listPosition(tester).pixels, 0);

    await tester.fling(find.byKey(const ValueKey(0)), const Offset(0, -600), 1500);
    await tester.pumpAndSettle();
    expect(listPosition(tester).pixels, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const ListViewBarChartPage());
    final first = ysOf(rowChart(tester, 0).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const ListViewBarChartPage());
    expect(ysOf(rowChart(tester, 0).data!), first);
    await tester.pumpAndSettle();
  });
}

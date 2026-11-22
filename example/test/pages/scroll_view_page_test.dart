import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/pages/scroll_view_page.dart';

import '../support/pages.dart';

void main() {
  testWidgets('the page shows ScrollViewActivity\'s bar chart between the placeholders', (tester) async {
    await pumpPage(tester, const ScrollViewPage());

    expect(find.widgetWithText(AppBar, 'Tall Bar Chart'), findsOneWidget);
    // only_github.xml has nothing but "View on GitHub", which is not ported.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(
      tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView)).dragStartBehavior,
      chartScrollDragStartBehavior,
    );
    expect(find.text('START OF SCROLLVIEW'), findsOneWidget);
    expect(tester.getSize(chartHosts).height, 450);
    // 30dp of text and 350dp of placeholder above the chart.
    expect(tester.getTopLeft(chartHosts).dy - tester.getTopLeft(find.byType(SingleChildScrollView)).dy, 380);

    final chart = chartOf<BarChartView>(tester);
    // setData's animateY(800).
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);

    expect(chart.description.isEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.isDrawBarShadowEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisLeft.isDrawGridLinesEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);
    expect(chart.isFitBarsEnabled, isTrue);

    final data = chart.data!;
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'Data Set');
    expect(set.entryCount, 10);
    expect(set.isDrawValuesEnabled, isFalse);
    expect(set.colors, ColorTemplate.VORDIPLOM_COLORS);
    // ((Math.random() * 10) + 15).toInt()
    expect(ysOf(data), everyElement(allOf(inInclusiveRange(15, 24), predicate<double>((y) => y == y.floor()))));
    // Fitted bars, once the chart was laid out: half the default bar width of 0.85 beyond the first and the last bar,
    // plus BarChart's xAxis.spaceMin and spaceMax of 0.5.
    expect(chart.xChartMin, closeTo(-0.925, 1e-6));
    expect(chart.xChartMax, closeTo(9.925, 1e-6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the end of the scroll view can be scrolled to, and a rebuild keeps the data', (tester) async {
    await pumpPage(tester, const ScrollViewPage());
    await tester.pumpAndSettle();
    final chart = chartOf<BarChartView>(tester);
    final data = chart.data;

    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(find.text('END OF SCROLLVIEW').hitTestable(), findsOneWidget);

    tester.element(find.byType(ScrollViewPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a vertical swipe that starts on the chart scrolls the page', (tester) async {
    // A surface lower than the scroll view's 1560dp, with the chart in view.
    await pumpPage(tester, const ScrollViewPage(), size: const Size(800, 1000));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, 0);

    await tester.fling(chartHosts, const Offset(0, -400), 1500);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const ScrollViewPage());
    final first = ysOf(chartOf<BarChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const ScrollViewPage());
    expect(ysOf(chartOf<BarChartView>(tester).data!), first);
    await tester.pumpAndSettle();
  });
}

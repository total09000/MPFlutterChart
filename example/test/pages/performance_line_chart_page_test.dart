import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/performance_line_chart_page.dart';

import '../support/pages.dart';

void main() {
  testWidgets('the page shows PerformanceLineChart\'s chart, seek bar and no menu', (tester) async {
    await pumpPage(tester, const PerformanceLineChartPage());

    expect(find.widgetWithText(AppBar, 'Performance'), findsOneWidget);
    // res/menu/only_github.xml has only the item this app leaves out.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(seekBars(tester), [9000]);
    expect(tester.widget<Slider>(find.byType(Slider)).max, 29000);
    // tvValueCount shows the progress + 1000.
    expect(find.text('10000'), findsOneWidget);

    final chart = chartOf<LineChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.axisLeft.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.xAxis.isDrawGridLinesEnabled, isTrue);
    expect(chart.xAxis.isDrawAxisLineEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);

    final data = chart.data!;
    final set = data.dataSets.single as LineDataSet;
    expect(set.entryCount, 10000);
    expect(set.color, const Color(0xFF000000));
    expect(set.lineWidth, 0.5);
    expect(set.isDrawValuesEnabled, isFalse);
    expect(set.isDrawCirclesEnabled, isFalse);
    expect(set.isDrawFilledEnabled, isFalse);
    expect(set.mode, LineDataSetMode.LINEAR);
    // x is i * 0.001f, y (Math.random() * (range + 1)) + 3 with range 500.
    expect(set.getEntryForIndex(0).x, 0);
    expect(set.getEntryForIndex(9999).x, closeTo(9.999, 1e-9));
    expect(ysOf(data), everyElement(inInclusiveRange(3, 504)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const PerformanceLineChartPage());
    final first = ysOf(chartOf<LineChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const PerformanceLineChartPage());
    expect(ysOf(chartOf<LineChartView>(tester).data!), first);
  });

  testWidgets('the seek bar sets new data, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const PerformanceLineChartPage());
    final chart = chartOf<LineChartView>(tester);
    final before = chart.data;

    await setSeekBar(tester, 0, 29000);
    final data = chart.data!;
    expect(data, isNot(same(before)));
    expect(data.dataSets.single.entryCount, 30000);
    expect(find.text('30000'), findsOneWidget);

    await setSeekBar(tester, 0, 0);
    expect(chart.data!.dataSets.single.entryCount, 1000);
    expect(find.text('1000'), findsOneWidget);

    // A rebuild of the page hands the host the chart's own data, so the host leaves it alone.
    final shown = chart.data;
    tester.element(find.byType(PerformanceLineChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });
}

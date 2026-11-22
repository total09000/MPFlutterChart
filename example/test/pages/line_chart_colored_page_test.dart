import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/line_chart_colored_page.dart';

import '../support/pages.dart';

/// LineChartActivityColored's `colors`.
const List<Color> _colors = [
  Color.fromARGB(255, 137, 230, 81),
  Color.fromARGB(255, 240, 240, 30),
  Color.fromARGB(255, 89, 199, 250),
  Color.fromARGB(255, 250, 104, 104),
];

void main() {
  testWidgets('the page shows LineChartActivityColored\'s four charts and no menu', (tester) async {
    await pumpPage(tester, const LineChartColoredPage());

    expect(find.widgetWithText(AppBar, 'Colorful'), findsOneWidget);
    // res/menu/only_github.xml has only the item this app leaves out.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(chartHosts, findsNWidgets(4));

    // animateX(2500) in setupChart.
    final charts = [for (var i = 0; i < 4; i++) chartOf<LineChartView>(tester, i)];
    expect([for (final chart in charts) chart.isAnimating], everyElement(isTrue));
    await tester.pumpAndSettle();
    expect([for (final chart in charts) chart.isAnimating], everyElement(isFalse));

    // The charts share the height of the page.
    final heights = {for (var i = 0; i < 4; i++) tester.getSize(chartHosts.at(i)).height};
    expect(heights, hasLength(1));

    for (var i = 0; i < 4; i++) {
      final chart = charts[i];
      final background = tester.widget<ColoredBox>(
        find.ancestor(of: chartHosts.at(i), matching: find.byType(ColoredBox)).first,
      );
      expect(background.color, _colors[i], reason: 'chart ${i + 1}');
      expect(chart.description.isEnabled, isFalse);
      expect(chart.isPinchZoomEnabled, isFalse);
      expect(chart.legend.isEnabled, isFalse);
      expect(chart.axisLeft.isEnabled, isFalse);
      expect([chart.axisLeft.spaceTop, chart.axisLeft.spaceBottom], [40, 40]);
      expect(chart.axisRight.isEnabled, isFalse);
      expect(chart.xAxis.isEnabled, isFalse);
      // setViewPortOffsets(10f, 0f, 10f, 0f).
      final viewPort = chart.viewPortHandler;
      expect([viewPort.contentLeft, viewPort.contentTop, viewPort.offsetRight, viewPort.offsetBottom], [10, 0, 10, 0]);

      final set = chart.data!.dataSets.single as LineDataSet;
      expect(set.entryCount, 36);
      expect(set.circleHoleColor, _colors[i]);
      expect(set.color, const Color(0xFFFFFFFF));
      expect(set.isDrawValuesEnabled, isFalse);
      expect(set.valueTypeface, tfBold);
      // (Math.random() * range) + 3, with range 100.
      expect(ysOf(chart.data!), everyElement(inInclusiveRange(3, 103)));
    }
    // Every chart has data of its own.
    expect({for (final chart in charts) ysOf(chart.data!).first}, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const LineChartColoredPage());
    final first = [for (var i = 0; i < 4; i++) ysOf(chartOf<LineChartView>(tester, i).data!)];

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const LineChartColoredPage());
    expect([for (var i = 0; i < 4; i++) ysOf(chartOf<LineChartView>(tester, i).data!)], first);
  });

  testWidgets('a rebuild of the page keeps the data of the charts', (tester) async {
    await pumpPage(tester, const LineChartColoredPage());
    await tester.pumpAndSettle();
    final shown = [for (var i = 0; i < 4; i++) chartOf<LineChartView>(tester, i).data];

    tester.element(find.byType(LineChartColoredPage)).markNeedsBuild();
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      expect(chartOf<LineChartView>(tester, i).data, same(shown[i]));
    }
    expect(tester.takeException(), isNull);
  });
}

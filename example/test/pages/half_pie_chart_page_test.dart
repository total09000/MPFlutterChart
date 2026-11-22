import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/half_pie_chart_page.dart';

import '../support/pages.dart';

void main() {
  testWidgets('the page shows HalfPieChartActivity\'s half pie and no menu', (tester) async {
    await pumpPage(tester, const HalfPieChartPage());

    expect(find.widgetWithText(AppBar, 'Half Pie'), findsOneWidget);
    // res/menu/only_github.xml holds only "View on GitHub", which is not ported.
    expect(find.byIcon(Icons.more_vert), findsNothing);

    final chart = chartOf<PieChartView>(tester);
    // animateY(1400, Easing.EaseInOutQuad) from onCreate.
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);

    expect(chart.description.isEnabled, isFalse);
    expect(chart.isUsePercentValuesEnabled, isTrue);
    expect(chart.centerText, 'MPAndroidChart\ndeveloped by Philipp Jahoda');
    expect(chart.holeRadius, 58);
    expect(chart.transparentCircleRadius, 61);
    expect(chart.isRotationEnabled, isFalse);
    expect(chart.maxAngle, 180);
    expect(chart.rotationAngle, 180);
    expect(chart.centerTextOffset.y, -20);
    expect(chart.entryLabelColor, const Color(0xFFFFFFFF));
    expect(chart.entryLabelTextSize, 12);

    final legend = chart.legend;
    expect(legend.verticalAlignment, LegendVerticalAlignment.TOP);
    expect(legend.horizontalAlignment, LegendHorizontalAlignment.CENTER);
    expect(legend.orientation, LegendOrientation.HORIZONTAL);
    expect(legend.isDrawInsideEnabled, isFalse);
    expect(legend.xEntrySpace, 7);
    expect(legend.yEntrySpace, 0);

    final data = chart.data!;
    final set = data.dataSets.single as PieDataSet;
    expect(set.label, 'Election Results');
    expect([for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).label], [
      'Party A', 'Party B', 'Party C', 'Party D', //
    ]);
    // (Math.random() * 100) + 100 / 5
    expect(ysOf(data), everyElement(inInclusiveRange(20, 120)));
    expect(set.colors, ColorTemplate.MATERIAL_COLORS);
    expect(set.valueFormatter, isA<PercentFormatter>());
    expect(set.valueTextColor, const Color(0xFFFFFFFF));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the chart reaches 65 % of the screen height below the page, on white', (tester) async {
    await pumpPage(tester, const HalfPieChartPage());
    await tester.pumpAndSettle();

    final clip = find.ancestor(of: chartHosts, matching: find.byType(ClipRect)).first;
    final body = tester.getRect(clip);
    final host = tester.getRect(chartHosts);
    expect(host.topLeft, body.topLeft);
    expect(host.width, body.width);
    // pumpPage's surface is 1600 logical px high.
    expect(host.height, closeTo(body.height + 1600 * 0.65, 1e-6));

    final background =
        tester.widget<ColoredBox>(find.ancestor(of: chartHosts, matching: find.byType(ColoredBox)).first);
    expect(background.color, demoChartBackground);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values, which a rebuild keeps', (tester) async {
    await pumpPage(tester, const HalfPieChartPage());
    final chart = chartOf<PieChartView>(tester);
    final first = ysOf(chart.data!);

    final shown = chart.data;
    tester.element(find.byType(HalfPieChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const HalfPieChartPage());
    expect(ysOf(chartOf<PieChartView>(tester).data!), first);
    await tester.pumpAndSettle();
  });
}

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/bar_chart_positive_negative_page.dart';

import '../support/pages.dart';

const Color _green = Color.fromARGB(255, 110, 190, 102);
const Color _red = Color.fromARGB(255, 211, 74, 88);

void main() {
  testWidgets('the page shows BarChartPositiveNegative\'s chart and no menu', (tester) async {
    await pumpPage(tester, const BarChartPositiveNegativePage());

    expect(find.widgetWithText(AppBar, 'Negative'), findsOneWidget);
    // only_github.xml holds only "View on GitHub", which this app leaves out.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(
      find.ancestor(
        of: chartHosts,
        matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == demoChartBackground),
      ),
      findsOneWidget,
    );

    final chart = chartOf<BarChartView>(tester);
    expect(chart.extraTopOffset, -30);
    expect(chart.extraBottomOffset, 10);
    expect(chart.extraLeftOffset, 70);
    expect(chart.extraRightOffset, 70);
    expect(chart.isDrawBarShadowEnabled, isFalse);
    expect(chart.isDrawValueAboveBarEnabled, isTrue);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isFalse);

    final xAxis = chart.xAxis;
    expect(xAxis.position, XAxisPosition.BOTTOM);
    expect(xAxis.isDrawGridLinesEnabled, isFalse);
    expect(xAxis.isDrawAxisLineEnabled, isFalse);
    expect(xAxis.textColor, const Color(0xFFCCCCCC));
    expect(xAxis.textSize, 13);
    expect(xAxis.labelCount, 5);
    expect(xAxis.isCenterAxisLabelsEnabled, isTrue);
    expect(xAxis.granularity, 1);
    expect([for (var x = -1; x <= 5; x++) xAxis.valueFormatter.getFormattedValue(x.toDouble(), xAxis)], [
      '12-29', '12-29', '12-30', '12-31', '01-01', '01-02', '01-02', //
    ]);

    final left = chart.axisLeft;
    expect(left.isDrawLabelsEnabled, isFalse);
    expect(left.spaceTop, 25);
    expect(left.spaceBottom, 25);
    expect(left.isDrawAxisLineEnabled, isFalse);
    expect(left.isDrawGridLinesEnabled, isFalse);
    expect(left.isDrawZeroLineEnabled, isTrue);
    expect(left.zeroLineColor, const Color(0xFF888888));
    expect(left.zeroLineWidth, closeTo(0.7, 1e-6));
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);

    final data = chart.data!;
    expect(data.barWidth, 0.8);
    final set = data.dataSets.single as BarDataSet;
    expect(set.label, 'Values');
    expect([for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).x], [0, 1, 2, 3, 4]);
    expect(ysOf(data), [-224.1, 238.5, 1280.1, -442.3, -2280.1]);
    expect(set.colors, [_green, _red, _red, _green, _green]);
    expect(set.valueTextColors, [_green, _red, _red, _green, _green]);
    expect(set.valueTextSize, 13);
    final formatter = set.valueFormatter;
    expect([
      for (var i = 0; i < set.entryCount; i++)
        formatter.getFormattedValue(set.getEntryForIndex(i).y, set.getEntryForIndex(i), 0, chart.viewPortHandler),
    ], ['-224.1', '238.5', '1280.1', '-442.3', '-2280.1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the data survives a rebuild of the page', (tester) async {
    await pumpPage(tester, const BarChartPositiveNegativePage());
    final chart = chartOf<BarChartView>(tester);
    final shown = chart.data;

    tester.element(find.byType(BarChartPositiveNegativePage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/design/kotlin_random.dart';
import 'package:mp_flutter_chart_example/design/nightfall.dart';
import 'package:mp_flutter_chart_example/pages/compose_list_page.dart';

import '../support/pages.dart';

const List<String> _names = [
  'Vienna', 'Graz', 'Linz', 'Salzburg', 'Innsbruck', 'Klagenfurt', 'Villach', 'Wels', //
  'Sankt Pölten', 'Dornbirn', 'Wiener Neustadt', 'Steyr', 'Feldkirch', 'Bregenz', 'Leonding', 'Klosterneuburg', //
  'Baden', 'Leoben', 'Krems', 'Eisenstadt', 'Freistadt',
];

/// `regions()`'s values, region by region: a start from `Random(7).nextInt(40, 80)`, then 24 steps of
/// `nextInt(-8, 11)` kept within 12 to 100.
List<List<double>> regionValues() {
  final random = KotlinRandom(7);
  return [
    for (final _ in _names)
      () {
        var value = random.nextIntRange(40, 80).toDouble();
        return [
          for (var i = 0; i < 24; i++) value = (value + random.nextIntRange(-8, 11)).clamp(12, 100).toDouble(),
        ];
      }(),
  ];
}

/// `((last - first) / first * 100).roundToInt()`; the values are whole numbers, so this is exact.
int change(List<double> values) => ((values.last - values.first) / values.first * 100 + 0.5).floor();

String changeText(int change) => change >= 0 ? '+$change% this quarter' : '$change% this quarter';

void main() {
  testWidgets('the page shows RegionList\'s first cards', (tester) async {
    await pumpPage(tester, const ComposeListPage());

    expect(find.widgetWithText(AppBar, 'Compose list'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.dragStartBehavior, chartScrollDragStartBehavior);
    expect(list.childrenDelegate.estimatedChildCount, 21);

    final values = regionValues();
    expect(find.text('Vienna'), findsOneWidget);
    expect(find.text(changeText(change(values[0]))), findsWidgets);
    expect(find.bySemanticsLabel('Vienna, ${change(values[0])} percent this quarter'), findsOneWidget);

    final chart = chartOf<LineChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);
    expect(chart.axisLeft.isEnabled, isFalse);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.xAxis.isEnabled, isFalse);
    expect(chart.isDragEnabled, isFalse);
    expect(chart.isScaleEnabled, isFalse);
    expect(chart.isHighlightPerDragEnabled, isFalse);
    expect(chart.isHighlightPerTapEnabled, isTrue);
    expect(chart.xAxis.axisMaximum, 23);
    expect(chart.xAxis.labelCount, 24);
    expect(tester.getSize(chartHosts.first).height, 110);

    final set = chart.data!.dataSets.single as LineDataSet;
    expect(set.label, 'Vienna');
    expect(set.color, Nightfall.palette[0]);
    expect(set.isDrawCirclesEnabled, isFalse);
    expect(set.isDrawValuesEnabled, isFalse);
    expect(set.mode, LineDataSetMode.CUBIC_BEZIER);
    expect(ysOf(chart.data!), values[0]);
    expect(chartOf<LineChartView>(tester, 1).data!.dataSets.single.color, Nightfall.palette[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every region has 24 values from Random(7) within 12 to 100, and the last one shows', (tester) async {
    final values = regionValues();
    for (final region in values) {
      expect(region, hasLength(24));
      expect(region, everyElement(inInclusiveRange(12, 100)));
    }

    await pumpPage(tester, const ComposeListPage());
    await tester.scrollUntilVisible(find.text('Freistadt'), 400);
    await tester.pumpAndSettle();
    expect(find.text(changeText(change(values[20]))), findsWidgets);
    final hosts = tester.widgetList<ChartHostWidget>(chartHosts);
    final last = hosts.map((host) => host.chart).whereType<LineChartView>().firstWhere(
      (chart) => chart.data!.dataSets.single.label == 'Freistadt',
    );
    expect(ysOf(last.data!), values[20]);
    expect(last.data!.dataSets.single.color, Nightfall.palette[20 % 5]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling back shows the remembered data, and two runs show the same values', (tester) async {
    await pumpPage(tester, const ComposeListPage());
    final first = chartOf<LineChartView>(tester).data;
    final ys = ysOf(first!);

    await tester.scrollUntilVisible(find.text('Freistadt'), 400);
    await tester.pumpAndSettle();
    expect(find.text('Vienna'), findsNothing);
    await tester.scrollUntilVisible(find.text('Vienna'), -400);
    await tester.pumpAndSettle();
    expect(chartOf<LineChartView>(tester).data, same(first));

    tester.element(find.byType(ComposeListPage)).markNeedsBuild();
    await tester.pump();
    expect(chartOf<LineChartView>(tester).data, same(first));

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const ComposeListPage());
    expect(ysOf(chartOf<LineChartView>(tester).data!), ys);
  });

  testWidgets('a tap selects a point', (tester) async {
    await pumpPage(tester, const ComposeListPage());
    await tester.tapAt(tester.getCenter(chartHosts.first));
    await tester.pumpAndSettle();
    expect(chartOf<LineChartView>(tester).highlighted, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

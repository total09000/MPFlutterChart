import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/filled_line_page.dart';

import '../support/pages.dart';

void main() {
  testWidgets('the page shows FilledLineActivity\'s chart and no menu', (tester) async {
    await pumpPage(tester, const FilledLinePage());

    expect(find.widgetWithText(AppBar, 'Filled'), findsOneWidget);
    // res/menu/only_github.xml has only the item this app leaves out.
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byType(Slider), findsNothing);

    final background = tester.widget<ColoredBox>(
      find.ancestor(of: chartHosts, matching: find.byType(ColoredBox)).first,
    );
    expect(background.color, demoChartBackground);

    final chart = chartOf<LineChartView>(tester);
    expect(chart.gridBackgroundColor, const Color.fromARGB(150, 51, 181, 229));
    expect(chart.isDrawGridBackgroundEnabled, isTrue);
    expect(chart.isDrawBordersEnabled, isTrue);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);
    expect(chart.xAxis.isEnabled, isFalse);
    expect([chart.axisLeft.axisMinimum, chart.axisLeft.axisMaximum], [-250, 900]);
    expect(chart.axisLeft.isDrawAxisLineEnabled, isFalse);
    expect(chart.axisLeft.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisRight.isEnabled, isFalse);

    final data = chart.data!;
    final sets = data.dataSets.cast<LineDataSet>();
    expect([for (final set in sets) set.label], ['DataSet 1', 'DataSet 2']);
    expect([for (final set in sets) set.entryCount], [100, 100]);
    expect([for (final set in sets) set.isDrawFilledEnabled], everyElement(isTrue));
    expect([for (final set in sets) set.isDrawValuesEnabled], everyElement(isFalse));
    expect([for (final set in sets) set.fillColor], everyElement(const Color(0xFFFFFFFF)));
    expect([for (final set in sets) set.fillAlpha], everyElement(255));
    // The lower set fills down to the bottom of the axis, the upper one up to its top.
    expect(sets[0].fillFormatter.getFillLinePosition(sets[0], chart), -250);
    expect(sets[1].fillFormatter.getFillLinePosition(sets[1], chart), 900);
    // (Math.random() * range) + 50 and + 450, with range 60.
    expect([for (final e in sets[0].entries) e.y], everyElement(inInclusiveRange(50, 110)));
    expect([for (final e in sets[1].entries) e.y], everyElement(inInclusiveRange(450, 510)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const FilledLinePage());
    final first = ysOf(chartOf<LineChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const FilledLinePage());
    expect(ysOf(chartOf<LineChartView>(tester).data!), first);
  });

  testWidgets('a rebuild of the page keeps the data', (tester) async {
    await pumpPage(tester, const FilledLinePage());
    final chart = chartOf<LineChartView>(tester);
    final shown = chart.data;

    tester.element(find.byType(FilledLinePage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });
}

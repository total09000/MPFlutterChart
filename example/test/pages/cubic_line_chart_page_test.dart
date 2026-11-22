import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/pages/cubic_line_chart_page.dart';

import '../support/pages.dart';

/// res/menu/line.xml as CubicLineChartActivity shows it, without the items this app leaves out.
const List<String> _menu = [
  'Toggle Values',
  'Toggle Highlight Line Span',
  'Toggle Icons',
  'Toggle Filled',
  'Toggle Circles',
  'Toggle Cubic',
  'Toggle Stepped',
  'Toggle Horizontal Cubic',
  'Toggle PinchZoom',
  'Toggle Auto Scale',
  'Toggle Highlight',
  'Animate X',
  'Animate Y',
  'Animate XY',
];

void main() {
  testWidgets('the page shows CubicLineChartActivity\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const CubicLineChartPage());

    expect(find.widgetWithText(AppBar, 'Cubic'), findsOneWidget);
    expect(seekBars(tester), [45, 100]);
    expect(tester.widget<Slider>(find.byType(Slider).first).max, 700);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);

    final chart = chartOf<LineChartView>(tester);
    // animateXY(2000, 2000) from onCreate.
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);

    expect(await menuTitles(tester), _menu);

    final background = tester.widget<ColoredBox>(
      find.ancestor(of: chartHosts, matching: find.byType(ColoredBox)).first,
    );
    expect(background.color, const Color.fromARGB(255, 104, 241, 175));

    // setViewPortOffsets(0f, 0f, 0f, 0f): the content fills the chart.
    final viewPort = chart.viewPortHandler;
    expect([viewPort.contentLeft, viewPort.contentTop, viewPort.offsetRight, viewPort.offsetBottom], [0, 0, 0, 0]);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isFalse);
    expect(chart.maxHighlightDistance, 300);
    expect(chart.xAxis.isEnabled, isFalse);
    expect(chart.axisLeft.labelCount, 6);
    expect(chart.axisLeft.labelPosition, YAxisLabelPosition.INSIDE_CHART);
    expect(chart.axisLeft.isDrawGridLinesEnabled, isFalse);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);

    final data = chart.data!;
    final set = data.dataSets.single as LineDataSet;
    expect(set.entryCount, 45);
    expect(set.mode, LineDataSetMode.CUBIC_BEZIER);
    expect(set.isDrawFilledEnabled, isTrue);
    expect(set.isDrawCirclesEnabled, isFalse);
    expect(set.isDrawValuesEnabled, isFalse);
    expect(set.fillAlpha, 100);
    expect(set.isHorizontalHighlightIndicatorEnabled, isFalse);
    expect(set.fillFormatter.getFillLinePosition(set, chart), chart.axisLeft.axisMinimum);
    // (Math.random() * (range + 1)) + 20, with range 100.
    expect(ysOf(data), everyElement(inInclusiveRange(20, 121)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const CubicLineChartPage());
    final first = ysOf(chartOf<LineChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const CubicLineChartPage());
    expect(ysOf(chartOf<LineChartView>(tester).data!), first);
  });

  testWidgets('the seek bars give the same set new entries, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const CubicLineChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<LineChartView>(tester);
    final data = chart.data!;
    final set = data.dataSets.single;

    await selectMenuItem(tester, 'Toggle Circles');
    await setSeekBar(tester, 0, 700);
    expect(chart.data, same(data));
    expect(chart.data!.dataSets.single, same(set));
    expect(set.entryCount, 700);
    expect((set as LineDataSet).isDrawCirclesEnabled, isTrue);
    expect(find.text('700'), findsOneWidget);

    await setSeekBar(tester, 1, 10);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(20, 31)));
    // The ranges follow the new entries.
    expect(chart.data!.yMax, lessThanOrEqualTo(31));
    expect(chart.axisLeft.axisMaximum, lessThan(40));
    expect(find.text('10'), findsOneWidget);

    await setSeekBar(tester, 0, 0);
    expect(set.entryCount, 0);
    await tester.pump();
    await setSeekBar(tester, 0, 45);

    // A rebuild of the page hands the host the chart's own data, so the host leaves it alone.
    tester.element(find.byType(CubicLineChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const CubicLineChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<LineChartView>(tester);
    LineDataSet set() => chart.data!.dataSets.single as LineDataSet;

    await selectMenuItem(tester, 'Toggle Values');
    expect(set().isDrawValuesEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Filled');
    expect(set().isDrawFilledEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Circles');
    expect(set().isDrawCirclesEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Cubic');
    expect(set().mode, LineDataSetMode.LINEAR);
    await selectMenuItem(tester, 'Toggle Stepped');
    expect(set().mode, LineDataSetMode.STEPPED);
    await selectMenuItem(tester, 'Toggle Horizontal Cubic');
    expect(set().mode, LineDataSetMode.HORIZONTAL_BEZIER);
    await selectMenuItem(tester, 'Toggle Cubic');
    expect(set().mode, LineDataSetMode.CUBIC_BEZIER);
    await selectMenuItem(tester, 'Toggle PinchZoom');
    expect(chart.isPinchZoomEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Auto Scale');
    expect(chart.isAutoScaleMinMaxEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Highlight');
    expect(chart.data!.isHighlightEnabled, isFalse);

    for (final title in ['Animate X', 'Animate Y', 'Animate XY']) {
      await selectMenuItem(tester, title, settle: false);
      expect(chart.isAnimating, isTrue, reason: title);
      await tester.pumpAndSettle();
      expect(chart.isAnimating, isFalse, reason: title);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every menu item can be chosen twice', (tester) async {
    await pumpPage(tester, const CubicLineChartPage());
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

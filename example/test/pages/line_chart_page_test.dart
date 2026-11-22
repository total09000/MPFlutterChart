import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/demo_drawables.dart';
import 'package:mp_flutter_chart_example/custom/my_marker_view.dart';
import 'package:mp_flutter_chart_example/pages/line_chart_page.dart';

import '../support/pages.dart';

/// res/menu/line.xml as LineChartActivity1 shows it, without the items this app leaves out.
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
  testWidgets('the page shows LineChartActivity1\'s chart, seek bars and menu', (tester) async {
    await pumpPage(tester, const LineChartPage());
    final chart = chartOf<LineChartView>(tester);
    // onCreate's animateX(1500).
    expect(chart.isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(chart.isAnimating, isFalse);

    expect(find.widgetWithText(AppBar, 'Basic'), findsOneWidget);
    expect(seekBars(tester), [45, 180]);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('180'), findsOneWidget);
    expect(await menuTitles(tester), _menu);
    // setBackgroundColor(Color.WHITE).
    final white = find.byWidgetPredicate((w) => w is ColoredBox && w.color == const Color(0xFFFFFFFF));
    expect(find.ancestor(of: chartHosts, matching: white), findsOneWidget);

    expect(chart.description.isEnabled, isFalse);
    expect(chart.isTouchEnabled, isTrue);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.isDragEnabled, isTrue);
    expect(chart.isPinchZoomEnabled, isTrue);
    expect(chart.marker, isA<MyMarkerView>());
    expect(chart.legend.form, LegendForm.LINE);

    expect(chart.xAxis.isGridDashedLineEnabled, isTrue);
    expect(chart.xAxis.isDrawLimitLinesBehindDataEnabled, isTrue);
    expect(chart.axisRight.isEnabled, isFalse);
    final yAxis = chart.axisLeft;
    expect(yAxis.isGridDashedLineEnabled, isTrue);
    expect(yAxis.axisMaximum, 200);
    expect(yAxis.axisMinimum, -50);
    expect(yAxis.isDrawLimitLinesBehindDataEnabled, isTrue);
    expect([for (final l in yAxis.limitLines) l.label], ['Upper Limit', 'Lower Limit']);
    expect([for (final l in yAxis.limitLines) l.limit], [150, -30]);
    expect([for (final l in yAxis.limitLines) l.labelPosition], [
      LimitLabelPosition.RIGHT_TOP,
      LimitLabelPosition.RIGHT_BOTTOM,
    ]);
    expect([for (final l in yAxis.limitLines) l.lineWidth], [4, 4]);

    final data = chart.data!;
    expect([for (final set in data.dataSets) set.label], ['DataSet 1']);
    final set = data.dataSets.single as LineDataSet;
    expect(set.entryCount, 45);
    expect([for (final e in set.entries) e.x], [for (var i = 0; i < 45; i++) i.toDouble()]);
    // (Math.random() * 180) - 30
    expect(ysOf(data), everyElement(inInclusiveRange(-30, 150)));
    expect([for (final e in set.entries) e.icon], everyElement(same(starDrawable)));
    expect(set.isDrawIconsEnabled, isFalse);
    expect(set.isDashedLineEnabled, isTrue);
    expect(set.color, const Color(0xFF000000));
    expect(set.isDrawCircleHoleEnabled, isFalse);
    expect(set.formSize, 15);
    expect(set.formLineDashEffect!.intervals, [10, 5]);
    expect(set.isDrawFilledEnabled, isTrue);
    expect(set.fillDrawable, same(fadeRedDrawable));
    expect(set.fillFormatter.getFillLinePosition(set, chart), -50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpPage(tester, const LineChartPage());
    final first = ysOf(chartOf<LineChartView>(tester).data!);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const LineChartPage());
    expect(ysOf(chartOf<LineChartView>(tester).data!), first);
    await tester.pumpAndSettle();
  });

  testWidgets('a seek bar gives the set new entries, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, const LineChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<LineChartView>(tester);
    final data = chart.data!;
    final set = data.dataSets.single;

    await setSeekBar(tester, 0, 35);
    // setData keeps the set and gives it new entries.
    expect(chart.data, same(data));
    expect(chart.data!.dataSets.single, same(set));
    expect(set.entryCount, 35);
    expect(find.text('35'), findsOneWidget);

    await setSeekBar(tester, 1, 10);
    expect(ysOf(chart.data!), everyElement(inInclusiveRange(-30, -20)));
    expect(set.entryCount, 35);
    expect(find.text('10'), findsOneWidget);

    tester.element(find.byType(LineChartPage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(set.entryCount, 35);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a highlighted value calls the listener and shows MyMarkerView', (tester) async {
    await pumpPage(tester, const LineChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<LineChartView>(tester);
    final entry = chart.data!.dataSets.single.getEntryForIndex(7);

    chart.highlightValue(7, 0);
    await tester.pump();
    expect(chart.highlighted, hasLength(1));
    expect((chart.marker! as MyMarkerView).text, Utils.formatNumber(entry.y, 0, true));
    expect(tester.takeException(), isNull);
  });

  testWidgets('seekBar1 at 0 leaves the set without entries, as on Android', (tester) async {
    await pumpPage(tester, const LineChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<LineChartView>(tester);

    await setSeekBar(tester, 0, 0);
    expect(chart.data!.dataSets.single.entryCount, 0);
    expect(tester.takeException(), isNull);

    await setSeekBar(tester, 0, 5);
    expect(chart.data!.dataSets.single.entryCount, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, const LineChartPage());
    await tester.pumpAndSettle();
    final chart = chartOf<LineChartView>(tester);
    LineDataSet set() => chart.data!.dataSets.single as LineDataSet;

    await selectMenuItem(tester, 'Toggle Values');
    expect(set().isDrawValuesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Highlight Line Span');
    expect(set().verticalHighlightIndicatorSpan, HighlightLineSpan.TO_ENTRY);
    await selectMenuItem(tester, 'Toggle Highlight Line Span');
    expect(set().verticalHighlightIndicatorSpan, HighlightLineSpan.FROM_ENTRY);
    await selectMenuItem(tester, 'Toggle Highlight Line Span');
    expect(set().verticalHighlightIndicatorSpan, HighlightLineSpan.FULL);
    await selectMenuItem(tester, 'Toggle Icons');
    expect(set().isDrawIconsEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Filled');
    expect(set().isDrawFilledEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Circles');
    expect(set().isDrawCirclesEnabled, isFalse);
    await selectMenuItem(tester, 'Toggle Cubic');
    expect(set().mode, LineDataSetMode.CUBIC_BEZIER);
    await selectMenuItem(tester, 'Toggle Stepped');
    expect(set().mode, LineDataSetMode.STEPPED);
    await selectMenuItem(tester, 'Toggle Horizontal Cubic');
    expect(set().mode, LineDataSetMode.HORIZONTAL_BEZIER);
    await selectMenuItem(tester, 'Toggle Horizontal Cubic');
    expect(set().mode, LineDataSetMode.LINEAR);
    await selectMenuItem(tester, 'Toggle PinchZoom');
    expect(chart.isPinchZoomEnabled, isFalse);
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
    await pumpPage(tester, const LineChartPage());
    await tester.pumpAndSettle();
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });
}

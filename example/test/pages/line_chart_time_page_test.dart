import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart' hide Description;
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/notimportant/demo_base.dart';
import 'package:mp_flutter_chart_example/pages/line_chart_time_page.dart';

import '../support/pages.dart';

/// res/menu/line.xml as LineChartTime shows it, without the items this app leaves out.
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

/// The fixed clock of the tests.
final DateTime _now = DateTime.utc(2026, 11, 22, 10, 42, 17);

DateTime _clock() => _now;

/// The current hour of [_clock] in hours since the epoch, `TimeUnit.MILLISECONDS.toHours`.
final int _hour = _now.millisecondsSinceEpoch ~/ Duration.millisecondsPerHour;

String _two(int n) => n.toString().padLeft(2, '0');

void main() {
  testWidgets('the page shows LineChartTime\'s chart, seek bar and menu', (tester) async {
    await pumpPage(tester, LineChartTimePage(now: _clock));

    expect(find.widgetWithText(AppBar, 'Hourly'), findsOneWidget);
    expect(seekBars(tester), [100]);
    expect(find.text('100'), findsOneWidget);
    expect(await menuTitles(tester), _menu);

    final background =
        tester.widget<ColoredBox>(find.ancestor(of: chartHosts, matching: find.byType(ColoredBox)).first);
    expect(background.color, demoChartBackground);

    final chart = chartOf<LineChartView>(tester);
    expect(chart.description.isEnabled, isFalse);
    expect(chart.dragDecelerationFrictionCoef, closeTo(0.9, 1e-6));
    expect(chart.isHighlightPerDragEnabled, isTrue);
    expect(chart.legend.isEnabled, isFalse);
    // setViewPortOffsets(0f, 0f, 0f, 0f)
    final viewPort = chart.viewPortHandler;
    expect([viewPort.offsetLeft, viewPort.offsetTop, viewPort.offsetRight, viewPort.offsetBottom], [0, 0, 0, 0]);

    final xAxis = chart.xAxis;
    expect(xAxis.position, XAxisPosition.TOP_INSIDE);
    expect(xAxis.textSize, 10);
    expect(xAxis.textColor, const Color.fromARGB(255, 255, 192, 56));
    expect(xAxis.isDrawAxisLineEnabled, isFalse);
    expect(xAxis.isDrawGridLinesEnabled, isTrue);
    expect(xAxis.isCenterAxisLabelsEnabled, isTrue);
    expect(xAxis.granularity, 1);

    final axisLeft = chart.axisLeft;
    expect(axisLeft.labelPosition, YAxisLabelPosition.INSIDE_CHART);
    expect(axisLeft.textColor, const Color.fromARGB(255, 255, 192, 56));
    expect(axisLeft.isGranularityEnabled, isTrue);
    expect(axisLeft.axisMinimum, 0);
    expect(axisLeft.axisMaximum, 170);
    expect(axisLeft.yOffset, -9);
    expect(chart.axisRight.isEnabled, isFalse);

    final data = chart.data!;
    final set = data.dataSets.single as LineDataSet;
    expect(set.label, 'DataSet 1');
    expect(set.color, ColorTemplate.holoBlue);
    expect(set.lineWidth, 1.5);
    expect(set.isDrawCirclesEnabled, isFalse);
    expect(set.isDrawValuesEnabled, isFalse);
    expect(set.fillAlpha, 65);
    expect(set.isDrawCircleHoleEnabled, isFalse);
    // One entry per hour from the current hour on.
    expect([for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).x], [
      for (var i = 0; i < 100; i++) (_hour + i).toDouble(),
    ]);
    // getRandom(50f, 50f)
    expect(ysOf(data), everyElement(inInclusiveRange(50, 100)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the x axis shows each hour as "dd MMM HH:mm" in local time', (tester) async {
    await pumpPage(tester, LineChartTimePage(now: _clock));
    final xAxis = chartOf<LineChartView>(tester).xAxis;
    String label(double hours) => xAxis.valueFormatter.getFormattedValue(hours, xAxis);

    for (final hours in [_hour, _hour + 13, _hour + 1499]) {
      final date = DateTime.fromMillisecondsSinceEpoch(hours * Duration.millisecondsPerHour);
      final expected = '${_two(date.day)} ${months[date.month - 1]} ${_two(date.hour)}:${_two(date.minute)}';
      expect(label(hours.toDouble()), expected);
      // value.toLong() drops the fraction of a centered label.
      expect(label(hours + 0.5), expected);
    }
    expect(label(_hour.toDouble()), matches(RegExp(r'^\d\d [A-Z][a-z]{2} \d\d:\d\d$')));

    // A local hour that is a whole number of hours since the epoch, as in every zone with a whole-hour offset.
    final local = DateTime(2026, 3, 5, 7);
    final localHours = local.millisecondsSinceEpoch ~/ Duration.millisecondsPerHour;
    if (localHours * Duration.millisecondsPerHour == local.millisecondsSinceEpoch) {
      expect(label(localHours.toDouble()), '05 Mar 07:00');
    }
  });

  testWidgets('two runs of the page show the same values; another clock moves them', (tester) async {
    await pumpPage(tester, LineChartTimePage(now: _clock));
    final first = ysOf(chartOf<LineChartView>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, LineChartTimePage(now: _clock));
    expect(ysOf(chartOf<LineChartView>(tester).data!), first);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, LineChartTimePage(now: () => _now.add(const Duration(hours: 5))));
    final set = chartOf<LineChartView>(tester).data!.dataSets.single;
    expect(set.getEntryForIndex(0).x, _hour + 5);
    expect(ysOf(chartOf<LineChartView>(tester).data!), first);
  });

  testWidgets('the seek bar sets new data, which a later rebuild of the page keeps', (tester) async {
    await pumpPage(tester, LineChartTimePage(now: _clock));
    final chart = chartOf<LineChartView>(tester);
    final before = chart.data;

    await setSeekBar(tester, 0, 30);
    final data = chart.data!;
    expect(data, isNot(same(before)));
    expect(data.dataSets.single.entryCount, 30);
    expect(data.dataSets.single.getEntryForIndex(29).x, _hour + 29);
    expect(find.text('30'), findsOneWidget);

    tester.element(find.byType(LineChartTimePage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(data));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the seek bar can reach both ends', (tester) async {
    await pumpPage(tester, LineChartTimePage(now: _clock));
    final chart = chartOf<LineChartView>(tester);

    await setSeekBar(tester, 0, 0);
    await tester.pump();
    expect(chart.data!.dataSets.single.entryCount, 0);
    expect(tester.takeException(), isNull);

    await setSeekBar(tester, 0, 1500);
    await tester.pump();
    final set = chart.data!.dataSets.single;
    expect(set.entryCount, 1500);
    expect(set.getEntryForIndex(1499).x, _hour + 1499);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu items do what onOptionsItemSelected does', (tester) async {
    await pumpPage(tester, LineChartTimePage(now: _clock));
    final chart = chartOf<LineChartView>(tester);
    LineDataSet set() => chart.data!.dataSets.single as LineDataSet;

    await selectMenuItem(tester, 'Toggle Values');
    expect(set().isDrawValuesEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Filled');
    expect(set().isDrawFilledEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Circles');
    expect(set().isDrawCirclesEnabled, isTrue);
    await selectMenuItem(tester, 'Toggle Cubic');
    expect(set().mode, LineDataSetMode.CUBIC_BEZIER);
    await selectMenuItem(tester, 'Toggle Stepped');
    expect(set().mode, LineDataSetMode.STEPPED);
    // LineChartTime has no branch for Toggle Horizontal Cubic, Toggle Highlight Line Span and Toggle Icons.
    await selectMenuItem(tester, 'Toggle Horizontal Cubic');
    expect(set().mode, LineDataSetMode.STEPPED);
    await selectMenuItem(tester, 'Toggle Stepped');
    expect(set().mode, LineDataSetMode.LINEAR);
    final highlightLines = set().isHorizontalHighlightIndicatorEnabled;
    await selectMenuItem(tester, 'Toggle Highlight Line Span');
    expect(set().isHorizontalHighlightIndicatorEnabled, highlightLines);
    final icons = set().isDrawIconsEnabled;
    await selectMenuItem(tester, 'Toggle Icons');
    expect(set().isDrawIconsEnabled, icons);
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
    await pumpPage(tester, LineChartTimePage(now: _clock));
    for (final title in _menu) {
      for (var round = 0; round < 2; round++) {
        await selectMenuItem(tester, title);
        expect(tester.takeException(), isNull, reason: '$title, round ${round + 1}');
      }
    }
  });

  testWidgets('the page builds with the default clock', (tester) async {
    await pumpPage(tester, const LineChartTimePage());
    final hour = DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerHour;
    final x = chartOf<LineChartView>(tester).data!.dataSets.single.getEntryForIndex(0).x;
    expect(x, inInclusiveRange(hour - 1, hour));
  });
}

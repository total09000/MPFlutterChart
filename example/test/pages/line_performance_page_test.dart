import 'dart:typed_data';

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/frame_times.dart';
import 'package:mp_flutter_chart_example/custom/timed_line_chart.dart';
import 'package:mp_flutter_chart_example/pages/line_performance_page.dart';

import '../support/pages.dart';

/// [value] as a Kotlin `Float`.
double f32(double value) => (Float32List(1)..[0] = value)[0];

/// A clock that moves on by [step] nanoseconds on every read.
int Function() steppingClock(int step) {
  var now = 0;
  return () => now += step;
}

/// The text of the readout below the chart.
String readout(WidgetTester tester) => tester
    .widget<Text>(find.byWidgetPredicate((widget) => widget is Text && widget.style?.fontFamily == 'monospace'))
    .data!;

/// The chart's data set, once the page built it.
LineDataSet lineSet(WidgetTester tester) => chartOf<TimedLineChart>(tester).data!.dataSets.single as LineDataSet;

/// Shows the page and lets the build of its data run.
Future<void> pumpBuilt(WidgetTester tester, Widget page) async {
  await pumpPage(tester, page);
  await tester.pump(Duration.zero);
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await tester.tap(find.text(text));
  await tester.pump();
}

bool switchValue(WidgetTester tester, String title) =>
    tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title)).value;

void main() {
  group('FrameTimes', () {
    test('recentMillis is the mean of the last 30 draws in whole nanoseconds, 0 before the first', () {
      final times = FrameTimes(nanoTime: () => 0);
      expect(times.recentMillis, 0);
      for (var i = 1; i <= 40; i++) {
        times.record(i * 1000000);
      }
      // The draws 11..40 ms: a mean of 25.5 ms.
      expect(times.recentMillis, 25.5);
      times
        ..clear()
        ..record(1000001)
        ..record(1000000);
      // (2000001 / 2) is cut to 1000000 ns before it becomes milliseconds, as Kotlin's Long division does.
      expect(times.recentMillis, 1.0);
    });

    test('worstMillisLastSecond takes only the draws of the last second', () {
      var now = 0;
      final times = FrameTimes(nanoTime: () => now);
      expect(times.worstMillisLastSecond, 0);
      times.record(9000000);
      now = 500000000;
      times.record(2000000);
      now = 1200000000;
      times.record(3000000);
      // The 9 ms draw at 0 s is older than a second at 1.2 s.
      expect(times.worstMillisLastSecond, 3.0);
      now = 1400000000;
      expect(times.worstMillisLastSecond, 3.0);
      now = 2300000000;
      expect(times.worstMillisLastSecond, 0);
    });

    test('the ring keeps the last 256 draws', () {
      var now = 0;
      final times = FrameTimes(nanoTime: () => now);
      for (var i = 0; i < 300; i++) {
        now = i;
        times.record(i == 10 ? 50000000 : 1000000);
      }
      // The 50 ms draw was overwritten.
      expect(times.worstMillisLastSecond, 1.0);
    });

    test('the default clock is monotonic nanoseconds', () {
      final a = FrameTimes.systemNanoTime();
      final b = FrameTimes.systemNanoTime();
      expect(b, greaterThanOrEqualTo(a));
    });
  });

  testWidgets('TimedLineChart records a draw with the time its onDraw took', (tester) async {
    final chart = TimedLineChart(frameTimes: FrameTimes(nanoTime: steppingClock(2000000)));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ChartHostWidget<LineChartView, LineData>(chart: chart, data: null),
      ),
    );
    expect(chart.frameTimes.recentMillis, 2.0);
  });

  testWidgets('the page shows LinePerformanceActivity\'s chart and controls, building the data first', (tester) async {
    await pumpPage(tester, const LinePerformancePage());

    expect(find.widgetWithText(AppBar, 'Line chart'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    final chart = chartOf<TimedLineChart>(tester);
    expect(chart.data, isNull);
    expect(chart.noDataText, 'Building 10,000 entries...');
    expect(readout(tester), 'Building 10,000 entries...');

    expect(chart.description.isEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isTrue);
    expect(chart.isHighlightPerTapEnabled, isFalse);
    expect(chart.isHighlightPerDragEnabled, isFalse);
    expect(chart.maxVisibleCount, 100);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    // The switch starts checked, the chart's decimation stays off until the switch changes.
    expect(switchValue(tester, 'Decimation'), isTrue);
    expect(chart.isDecimationEnabled, isFalse);

    for (final text in ['Entries', '1k', '10k', '50k', '100k', '500k', 'Line shape', 'Linear', 'Stepped', 'Cubic']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final tiles = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
    expect([for (final tile in tiles) (tile.title! as Text).data], [
      'Decimation',
      'Value labels',
      'A circle at every point',
      'Fill under the line',
      'A color per line segment',
    ]);
    expect(seekBars(tester), [100]);
    expect(find.text('Labels up to'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);

    await tester.pump(Duration.zero);
    await tester.pump();
    final set = lineSet(tester);
    expect(set.label, '10,000 entries');
    expect(set.entryCount, 10000);
    expect(set.lineWidth, 1);
    expect(set.circleRadius, 2);
    expect(set.isDrawCircleHoleEnabled, isFalse);
    expect(set.circleColors, [const Color.fromARGB(255, 28, 88, 154)]);
    expect(set.fillColor, const Color.fromARGB(255, 28, 88, 154));
    expect(set.colors, [const Color.fromARGB(255, 28, 88, 154)]);
    expect(set.valueTextSize, 8);
    expect(set.mode, LineDataSetMode.LINEAR);
    expect(set.isDrawCirclesEnabled, isFalse);
    expect(set.isDrawValuesEnabled, isFalse);
    expect(set.isDrawFilledEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the data equals java.util.Random(count) with Kotlin\'s Float arithmetic', (tester) async {
    await pumpBuilt(tester, const LinePerformancePage());
    // From the JVM: sin(i * 0.002f) * 40f + Random(10000L).nextFloat() * 20f.
    final set = lineSet(tester);
    expect([for (final i in [0, 1, 2, 3, 9999]) set.getEntryForIndex(i).y], [
      f32(17.677732), f32(16.081802), f32(9.206951), f32(15.374115), f32(37.93902), //
    ]);
    expect([for (var i = 0; i < set.entryCount; i++) set.getEntryForIndex(i).x], [for (var i = 0; i < 10000; i++) i]);
    expect(ysOf(chartOf<TimedLineChart>(tester).data!), everyElement(inInclusiveRange(-40, 60)));

    await tapText(tester, '1k');
    await tester.pump(Duration.zero);
    final small = lineSet(tester);
    expect(small.entryCount, 1000);
    expect([for (final i in [0, 1, 2, 3, 999]) small.getEntryForIndex(i).y], [
      f32(14.203697), f32(5.018309), f32(11.656726), f32(9.44576), f32(50.25865), //
    ]);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpBuilt(tester, const LinePerformancePage());
    final first = ysOf(chartOf<TimedLineChart>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpBuilt(tester, const LinePerformancePage());
    expect(ysOf(chartOf<TimedLineChart>(tester).data!), first);
  });

  testWidgets('the readout shows the draw times and the entries on screen, every 200 ms', (tester) async {
    await pumpBuilt(tester, LinePerformancePage(nanoTime: steppingClock(4000000)));
    expect(readout(tester), 'Building 10,000 entries...');

    await tester.pump(const Duration(milliseconds: 200));
    // Each draw reads the clock twice, 4 ms apart.
    expect(
      readout(tester),
      '4.0 ms per frame, 250 fps\n'
      'worst frame in the last second 4.0 ms\n'
      '10,000 of 10,000 entries on screen',
    );

    final chart = chartOf<TimedLineChart>(tester);
    chart.zoom(10, 1, 0, 0);
    chart.invalidate();
    await tester.pump(const Duration(milliseconds: 200));
    expect(readout(tester), endsWith(' of 10,000 entries on screen'));
    expect(readout(tester), isNot(startsWith('10,000 of')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a readout without a frame says so', (tester) async {
    await pumpBuilt(tester, LinePerformancePage(nanoTime: () => 0));
    // Draws that take no time leave the readout waiting.
    await tester.pump(const Duration(milliseconds: 200));
    expect(readout(tester), 'Waiting for a frame\nno frame in the last second\n10,000 of 10,000 entries on screen');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the entry count radio buttons rebuild the data, dropping a superseded build', (tester) async {
    await pumpBuilt(tester, const LinePerformancePage());
    final chart = chartOf<TimedLineChart>(tester);

    await tapText(tester, '1k');
    expect(chart.data, isNull);
    expect(chart.noDataText, 'Building 1,000 entries...');
    expect(readout(tester), 'Building 1,000 entries...');
    await tapText(tester, '50k');
    expect(readout(tester), 'Building 50,000 entries...');

    await tester.pump(Duration.zero);
    await tester.pump();
    expect(lineSet(tester).entryCount, 50000);
    expect(lineSet(tester).label, '50,000 entries');

    // Tapping the checked button again changes nothing.
    final shown = chart.data;
    await tapText(tester, '50k');
    expect(chart.data, same(shown));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the line shape radio buttons, the switches and the seek bar change the chart', (tester) async {
    await pumpBuilt(tester, const LinePerformancePage());
    final chart = chartOf<TimedLineChart>(tester);

    await tapText(tester, 'Stepped');
    expect(lineSet(tester).mode, LineDataSetMode.STEPPED);
    await tapText(tester, 'Cubic');
    expect(lineSet(tester).mode, LineDataSetMode.CUBIC_BEZIER);

    await tapText(tester, 'Decimation');
    expect(switchValue(tester, 'Decimation'), isFalse);
    expect(chart.isDecimationEnabled, isFalse);
    await tapText(tester, 'Decimation');
    expect(chart.isDecimationEnabled, isTrue);

    await tapText(tester, 'Value labels');
    expect(lineSet(tester).isDrawValuesEnabled, isTrue);
    await tapText(tester, 'A circle at every point');
    expect(lineSet(tester).isDrawCirclesEnabled, isTrue);
    await tapText(tester, 'Fill under the line');
    expect(lineSet(tester).isDrawFilledEnabled, isTrue);
    await tapText(tester, 'A color per line segment');
    expect(lineSet(tester).colors, hasLength(5));

    await setSeekBar(tester, 0, 2500);
    expect(chart.maxVisibleCount, 2500);
    expect(find.text('2,500'), findsOneWidget);

    // A new build keeps what the controls chose.
    await tapText(tester, '1k');
    await tester.pump(Duration.zero);
    final set = lineSet(tester);
    expect(set.mode, LineDataSetMode.CUBIC_BEZIER);
    expect(set.isDrawValuesEnabled, isTrue);
    expect(set.isDrawCirclesEnabled, isTrue);
    expect(set.isDrawFilledEnabled, isTrue);
    expect(set.colors, hasLength(5));

    await tapText(tester, 'A color per line segment');
    expect(lineSet(tester).colors, [const Color.fromARGB(255, 28, 88, 154)]);
    await tapText(tester, 'Linear');
    expect(lineSet(tester).mode, LineDataSetMode.LINEAR);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controls work while the data is being built', (tester) async {
    await pumpPage(tester, const LinePerformancePage());
    await tapText(tester, 'Value labels');
    await tapText(tester, 'Stepped');
    await tester.pump(Duration.zero);
    expect(lineSet(tester).isDrawValuesEnabled, isTrue);
    expect(lineSet(tester).mode, LineDataSetMode.STEPPED);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rebuild of the page keeps the data it built', (tester) async {
    await pumpBuilt(tester, const LinePerformancePage());
    final chart = chartOf<TimedLineChart>(tester);
    final shown = chart.data;
    tester.element(find.byType(LinePerformancePage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
  });

  testWidgets('leaving the page cancels its build and its readout tick', (tester) async {
    await pumpPage(tester, const LinePerformancePage());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}

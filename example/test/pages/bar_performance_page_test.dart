import 'dart:typed_data';

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/mp_flutter_chart.dart';
import 'package:mp_flutter_chart_example/custom/frame_times.dart';
import 'package:mp_flutter_chart_example/custom/timed_bar_chart.dart';
import 'package:mp_flutter_chart_example/pages/bar_performance_page.dart';

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
BarDataSet barSet(WidgetTester tester) => chartOf<TimedBarChart>(tester).data!.dataSets.single as BarDataSet;

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

const Color _blue = Color.fromARGB(255, 28, 88, 154);

void main() {
  testWidgets('TimedBarChart records a draw with the time its onDraw took', (tester) async {
    final chart = TimedBarChart(frameTimes: FrameTimes(nanoTime: steppingClock(3000000)));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ChartHostWidget<BarChartView, BarData>(chart: chart, data: null),
      ),
    );
    expect(chart.frameTimes.recentMillis, 3.0);
  });

  testWidgets('the page shows BarPerformanceActivity\'s chart and controls, building the data first', (tester) async {
    await pumpPage(tester, const BarPerformancePage());

    expect(find.widgetWithText(AppBar, 'Bar chart'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);

    final chart = chartOf<TimedBarChart>(tester);
    expect(chart.data, isNull);
    expect(chart.noDataText, 'Building 10,000 entries...');
    expect(readout(tester), 'Building 10,000 entries...');

    expect(chart.description.isEnabled, isFalse);
    expect(chart.legend.isEnabled, isFalse);
    expect(chart.isDrawGridBackgroundEnabled, isFalse);
    expect(chart.isPinchZoomEnabled, isTrue);
    expect(chart.isHighlightPerTapEnabled, isFalse);
    expect(chart.isHighlightPerDragEnabled, isFalse);
    expect(chart.isDrawValueAboveBarEnabled, isTrue);
    expect(chart.maxVisibleCount, 100);
    expect(chart.axisRight.isEnabled, isFalse);
    expect(chart.axisLeft.axisMinimum, 0);
    expect(chart.xAxis.position, XAxisPosition.BOTTOM);
    expect(chart.xAxis.isDrawGridLinesEnabled, isFalse);
    expect(chart.isDrawBarShadowEnabled, isFalse);
    // The switch starts checked, the chart's decimation stays off until the switch changes.
    expect(switchValue(tester, 'Decimation'), isTrue);
    expect(chart.isDecimationEnabled, isFalse);

    for (final text in ['Entries', '1k', '10k', '50k', '100k', '500k']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final tiles = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
    expect([for (final tile in tiles) (tile.title! as Text).data], [
      'Decimation',
      'Value labels',
      'Stacked bars',
      'Rounded bar corners',
      'Bar shadows',
    ]);
    expect(seekBars(tester), [100]);
    expect(find.text('Labels up to'), findsOneWidget);

    await tester.pump(Duration.zero);
    await tester.pump();
    final set = barSet(tester);
    expect(set.label, '10,000 entries');
    expect(set.entryCount, 10000);
    expect(set.isDrawIconsEnabled, isFalse);
    expect(set.valueTextSize, 8);
    expect(set.barShadowColor, const Color.fromARGB(255, 226, 226, 226));
    expect(set.barCornerRadius, 0);
    expect(set.isDrawValuesEnabled, isFalse);
    expect(set.colors, [_blue]);
    expect(chart.data!.barWidth, 0.9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the data equals java.util.Random(count) with Kotlin\'s Float arithmetic', (tester) async {
    await pumpBuilt(tester, const BarPerformancePage());
    // From the JVM: 30f + sin(i * 0.01f) * 20f + Random(10000L).nextFloat() * 15f.
    final set = barSet(tester);
    expect([for (final i in [0, 1, 2, 3, 9999]) set.getEntryForIndex(i).y], [
      f32(43.2583), f32(42.201347), f32(37.18519), f32(41.950497), f32(20.79113), //
    ]);
    expect(ysOf(chartOf<TimedBarChart>(tester).data!), everyElement(inInclusiveRange(10, 65)));

    await tapText(tester, 'Stacked bars');
    expect(chartOf<TimedBarChart>(tester).data, isNull);
    await tapText(tester, '1k');
    await tester.pump(Duration.zero);
    final stacked = barSet(tester);
    expect(stacked.entryCount, 1000);
    expect(stacked.isStacked, isTrue);
    expect(stacked.colors, [_blue, const Color.fromARGB(255, 106, 167, 79), const Color.fromARGB(255, 233, 168, 41)]);
    expect(stacked.getEntryForIndex(0).stackValues, [f32(20.326385), f32(12.195832), f32(8.130554)]);
    expect(stacked.getEntryForIndex(999).stackValues, [f32(14.8390465), f32(8.903428), f32(5.935619)]);
  });

  testWidgets('two runs of the page show the same values', (tester) async {
    await pumpBuilt(tester, const BarPerformancePage());
    final first = ysOf(chartOf<TimedBarChart>(tester).data!);

    await tester.pumpWidget(const SizedBox());
    await pumpBuilt(tester, const BarPerformancePage());
    expect(ysOf(chartOf<TimedBarChart>(tester).data!), first);
  });

  testWidgets('the readout shows the draw times and the entries on screen, every 200 ms', (tester) async {
    await pumpBuilt(tester, BarPerformancePage(nanoTime: steppingClock(5000000)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      readout(tester),
      '5.0 ms per frame, 200 fps\n'
      'worst frame in the last second 5.0 ms\n'
      '10,000 of 10,000 entries on screen',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the entry count radio buttons rebuild the data, dropping a superseded build', (tester) async {
    await pumpBuilt(tester, const BarPerformancePage());
    final chart = chartOf<TimedBarChart>(tester);

    await tapText(tester, '1k');
    expect(chart.data, isNull);
    expect(readout(tester), 'Building 1,000 entries...');
    await tapText(tester, '50k');
    expect(chart.noDataText, 'Building 50,000 entries...');

    await tester.pump(Duration.zero);
    await tester.pump();
    expect(barSet(tester).entryCount, 50000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the switches and the seek bar change the chart', (tester) async {
    await pumpBuilt(tester, const BarPerformancePage());
    final chart = chartOf<TimedBarChart>(tester);

    await tapText(tester, 'Decimation');
    expect(chart.isDecimationEnabled, isFalse);
    await tapText(tester, 'Decimation');
    expect(chart.isDecimationEnabled, isTrue);

    await tapText(tester, 'Value labels');
    expect(barSet(tester).isDrawValuesEnabled, isTrue);
    await tapText(tester, 'Rounded bar corners');
    expect(barSet(tester).barCornerRadius, 4);
    await tapText(tester, 'Bar shadows');
    expect(chart.isDrawBarShadowEnabled, isTrue);

    await setSeekBar(tester, 0, 5000);
    expect(chart.maxVisibleCount, 5000);
    expect(find.text('5,000'), findsOneWidget);

    // Stacked bars rebuild the data; the new set keeps what the other controls chose.
    await tapText(tester, 'Stacked bars');
    await tester.pump(Duration.zero);
    final set = barSet(tester);
    expect(set.isStacked, isTrue);
    expect(set.isDrawValuesEnabled, isTrue);
    expect(set.barCornerRadius, 4);

    await tapText(tester, 'Stacked bars');
    await tester.pump(Duration.zero);
    expect(barSet(tester).isStacked, isFalse);
    await tapText(tester, 'Rounded bar corners');
    expect(barSet(tester).barCornerRadius, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rebuild of the page keeps the data it built', (tester) async {
    await pumpBuilt(tester, const BarPerformancePage());
    final chart = chartOf<TimedBarChart>(tester);
    final shown = chart.data;
    tester.element(find.byType(BarPerformancePage)).markNeedsBuild();
    await tester.pump();
    expect(chart.data, same(shown));
  });

  testWidgets('leaving the page cancels its build and its readout tick', (tester) async {
    await pumpPage(tester, const BarPerformancePage());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}

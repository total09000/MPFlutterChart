// Ported from MPChartExample: custom/TimedBarChart.kt.
//
// A bar chart that times its own draw, for the readout of the Performance / Bar chart page. The Android View
// constructor (context, attrs, defStyle) has no counterpart; the chart takes the [FrameTimes] it records into, so a
// test can give it one with a fixed clock.
import 'dart:ui' as ui;

import 'package:mp_flutter_chart/mp_flutter_chart.dart';

import 'frame_times.dart';

/// Bar chart that times its own draw, so a readout can show what the chart costs rather than the window.
class TimedBarChart extends BarChartView {
  /// Creates a chart that records its draws into [frameTimes], a new [FrameTimes] by default.
  TimedBarChart({FrameTimes? frameTimes}) : frameTimes = frameTimes ?? FrameTimes();

  /// How long the draws of this chart took.
  final FrameTimes frameTimes;

  @override
  void onDraw(ui.Canvas canvas) {
    final startedAt = frameTimes.nanoTime();
    super.onDraw(canvas);
    frameTimes.record(frameTimes.nanoTime() - startedAt);
  }
}

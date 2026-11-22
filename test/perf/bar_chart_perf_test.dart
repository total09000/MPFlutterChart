// Not a port of a Kotlin test: the BarChart performance record of spec §9.5 (lane charter D③). A 30 000-bar
// BarDataSet (values off) on a core BarChart without a host, drawn into a RecordingCanvas and measured like the
// LineChart of line_chart_perf_test.dart by perf_support.dart's measureChart: the first frame, then 10 redraws each
// after the viewport, zoomed 8x along x, was moved. Cold, then warm with decimation off (the MPAndroidChart default)
// and on. Timings go to stdout in one `perf BarChart …` summary line; there are no thresholds.
//
// The numbers come from the flutter_test VM (JIT, debug asserts on) and include the RecordingCanvas's records of the
// draws, so they compare runs on one machine, not devices.
@Tags(['perf'])
library;

import 'dart:io' show stdout;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/core.dart';

import '../recording/recording_canvas.dart';
import 'perf_support.dart';

const int _barCount = 30000;

/// Bar color of the data set, so its rectangles can be told from anything else the chart draws.
const ui.Color _barColor = ui.Color(0xFF1E88E5);

BarData _data() => BarData([
  BarDataSet([
    for (var i = 0; i < _barCount; i++)
      BarEntry(
        x: i.toDouble(),
        y: 50 + 40 * math.sin(i * 0.01) + 5 * math.sin(i * 0.37),
      ),
  ], 'perf')
    ..color = _barColor
    ..isDrawValuesEnabled = false,
]);

bool _sameRgb(ui.Color a, ui.Color b) =>
    (a.toARGB32() & 0xFFFFFF) == (b.toARGB32() & 0xFFFFFF);

/// Whether [canvas] got the data set's bars: BarChartRenderer draws each bar as a `drawRect` in the bar color.
/// `> 1`, because the legend (on by default, form SQUARE) draws one square in that color as a `drawRect` too.
bool _drewBars(RecordingCanvas canvas) =>
    canvas.rects.where((d) => _sameRgb(d.color, _barColor)).length > 1;

PerfRun _measure({required bool decimation}) =>
    // Zoomed 8 times along x, 3 750 bars are visible; each step moves the viewport by 2 000.
    measureChart(
      create: BarChart.new,
      data: _data(),
      decimation: decimation,
      zoomX: 8,
      step: 2000,
      drewData: _drewBars,
      detail: (first) => '${first.drawRectCalls} rects',
    );

void main() {
  test('30 000 bars: first frame and redraws after translate', () {
    // The first chart of the isolate also pays for JIT compilation; it is reported, then measured again warm.
    final cold = _measure(decimation: false);
    final off = _measure(decimation: false);
    final on = _measure(decimation: true);

    stdout.writeln(
      perfLine(
        'BarChart $_barCount entries 400x300 RecordingCanvas',
        cold: cold,
        off: off,
        on: on,
      ),
    );
  });
}

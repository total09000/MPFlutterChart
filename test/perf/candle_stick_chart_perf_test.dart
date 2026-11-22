// Not a port of a Kotlin test: the CandleStickChart performance record of spec §9.5 (lane charter D③). A
// 100 000-candle CandleDataSet (values off) on a core CandleStickChart without a host, drawn into a RecordingCanvas
// and measured like the LineChart of line_chart_perf_test.dart by perf_support.dart's measureChart: the first frame,
// then 10 redraws each after the viewport, zoomed 8x along x, was moved. Cold, then warm with decimation off (the
// MPAndroidChart default) and on. Timings go to stdout in one `perf CandleStickChart …` summary line;
// there are no thresholds.
//
// Decimation off still reduces the candles here: CandleStickChartRenderer asks reduceVisible to reduce whenever more
// than two candles share a pixel column on average (`reduceWhenCrowded`, as Kotlin's renderer does), and every frame
// of this case is that crowded, so "off" and "on" draw the same candles.
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

const int _candleCount = 100000;

/// Body and shadow colors of the data set, so its draws can be told from anything else the chart draws.
const ui.Color _increasingColor = ui.Color(0xFF43A047);
const ui.Color _decreasingColor = ui.Color(0xFFE53935);
const ui.Color _shadowColor = ui.Color(0xFF616161);

/// Candles around a slow wave; open and close differ, and the shadow reaches 2 above and below the body.
CandleData _data() => CandleData([
  CandleDataSet([
    for (var i = 0; i < _candleCount; i++)
      _candle(i, 50 + 40 * math.sin(i * 0.003)),
  ], 'perf')
    ..increasingColor = _increasingColor
    ..decreasingColor = _decreasingColor
    ..shadowColor = _shadowColor
    ..isDrawValuesEnabled = false,
]);

CandleEntry _candle(int i, double mid) {
  final open = mid + 3 * math.sin(i * 0.37);
  final close = mid + 3 * math.cos(i * 0.53);
  return CandleEntry(
    x: i.toDouble(),
    high: math.max(open, close) + 2,
    low: math.min(open, close) - 2,
    open: open,
    close: close,
  );
}

bool _sameRgb(ui.Color a, ui.Color b) =>
    (a.toARGB32() & 0xFFFFFF) == (b.toARGB32() & 0xFFFFFF);

/// Candle bodies: CandleStickChartRenderer draws each body as a `drawRect` in the increasing color (stroked by
/// default) or the decreasing color (filled by default). The count includes the legend's two squares (see
/// [_drewCandles]).
int _bodies(RecordingCanvas canvas) => canvas.rects
    .where(
      (d) =>
          _sameRgb(d.color, _increasingColor) ||
          _sameRgb(d.color, _decreasingColor),
    )
    .length;

/// Shadow floats: the renderer draws each shadow as `drawLines` (4 floats per segment) in the shadow color.
int _shadowFloats(RecordingCanvas canvas) => canvas.rawPoints
    .where((d) => _sameRgb(d.color, _shadowColor))
    .fold(0, (sum, d) => sum + d.points.length);

int _rectsIn(RecordingCanvas canvas, ui.Color color) =>
    canvas.rects.where((d) => _sameRgb(d.color, color)).length;

/// Whether [canvas] got increasing and decreasing bodies and shadows. `> 1` per body color, because the legend (on
/// by default, form SQUARE) draws one square in the decreasing and one in the increasing color as `drawRect`s too.
bool _drewCandles(RecordingCanvas canvas) =>
    _rectsIn(canvas, _increasingColor) > 1 &&
    _rectsIn(canvas, _decreasingColor) > 1 &&
    _shadowFloats(canvas) > 0;

PerfRun _measure({required bool decimation}) =>
    // Zoomed 8 times along x, 12 500 candles are visible (the renderer draws the few it keeps of them, see the
    // header); each step moves the viewport by 6 000.
    measureChart(
      create: CandleStickChart.new,
      data: _data(),
      decimation: decimation,
      zoomX: 8,
      step: 6000,
      drewData: _drewCandles,
      detail: (first) =>
          '${_bodies(first)} bodies, ${_shadowFloats(first)} shadow floats',
    );

void main() {
  test('100 000 candles: first frame and redraws after translate', () {
    // The first chart of the isolate also pays for JIT compilation; it is reported, then measured again warm.
    final cold = _measure(decimation: false);
    final off = _measure(decimation: false);
    final on = _measure(decimation: true);

    stdout.writeln(
      perfLine(
        'CandleStickChart $_candleCount entries 400x300 RecordingCanvas',
        cold: cold,
        off: off,
        on: on,
      ),
    );
  });
}

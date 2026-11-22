// Not a port of a Kotlin test: the performance record of spec §9.5. A 30 000-entry LineDataSet (no circles) on a core
// LineChart without a host, drawn into a RecordingCanvas: the first frame, then 10 redraws each after the zoomed
// viewport was moved along x. Two cases: LINEAR without fill (lines through drawLines) and CUBIC_BEZIER with
// drawFilled (line and fill through paths, so Transformer.pathValueToPixel is on the hot path). Timings go to stdout
// in one summary line per case (measured and printed by perf_support.dart); there are no thresholds yet. Measured with decimation off (the MPAndroidChart default) and on.
//
// The numbers come from the flutter_test VM (JIT, debug asserts on) and include the RecordingCanvas's copies of the
// drawn floats, so they compare runs on one machine, not devices.
@Tags(['perf'])
library;

import 'dart:io' show stdout;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/core.dart';

import '../recording/recording_canvas.dart';
import 'perf_support.dart';

const int _entryCount = 30000;
const int _redraws = 10;

/// Line and fill colors of the data set, so the recorded line and fill paths can be told from the grid's.
const ui.Color _lineColor = ui.Color(0xFF1E88E5);
const ui.Color _fillColor = ui.Color(0xFF43A047);

LineData _data(LineDataSetMode mode, {required bool filled}) => LineData([
  LineDataSet([
    for (var i = 0; i < _entryCount; i++)
      Entry(
        x: i.toDouble(),
        y: 50 + 40 * math.sin(i * 0.01) + 5 * math.sin(i * 0.37),
      ),
  ], 'perf')
    ..mode = mode
    ..color = _lineColor
    ..fillColor = _fillColor
    ..isDrawFilledEnabled = filled
    ..isDrawCirclesEnabled = false
    ..isDrawValuesEnabled = false,
]);

int _lineFloats(RecordingCanvas canvas) =>
    canvas.rawPoints.fold(0, (sum, draw) => sum + draw.points.length);

bool _sameRgb(ui.Color a, ui.Color b) =>
    (a.toARGB32() & 0xFFFFFF) == (b.toARGB32() & 0xFFFFFF);

/// Whether [canvas] got the data set's line (line floats for LINEAR, a stroked path for CUBIC_BEZIER) and, when
/// [filled], its fill (a `drawColor` clipped to the fill path, as `LineRadarRenderer.drawFilledPath` draws it).
bool _drewDataSet(RecordingCanvas canvas, {required bool filled}) {
  final line =
      canvas.rawPoints.any((d) => _sameRgb(d.color, _lineColor)) ||
      canvas.paths.any(
        (d) =>
            d.style == ui.PaintingStyle.stroke && _sameRgb(d.color, _lineColor),
      );
  final fill = canvas.colors.any((c) => _sameRgb(c, _fillColor));
  return line && fill == filled;
}

PerfRun _measure({
  required bool decimation,
  LineDataSetMode mode = LineDataSetMode.LINEAR,
  bool filled = false,
}) =>
    // Zoomed 8 times along x, 3 750 entries are visible; each step moves the viewport by 2 000.
    measureChart(
      create: LineChart.new,
      data: _data(mode, filled: filled),
      decimation: decimation,
      zoomX: 8,
      step: 2000,
      redraws: _redraws,
      drewData: (canvas) => _drewDataSet(canvas, filled: filled),
      detail: (first) =>
          '${_lineFloats(first)} line floats, ${first.paths.length} paths',
    );

void main() {
  test('30 000 entries: first frame and redraws after translate', () {
    // The first chart of the isolate also pays for JIT compilation; it is reported, then measured again warm.
    final cold = _measure(decimation: false);
    final off = _measure(decimation: false);
    final on = _measure(decimation: true);

    stdout.writeln(
      perfLine(
        'LineChart $_entryCount entries LINEAR no circles 400x300 RecordingCanvas',
        cold: cold,
        off: off,
        on: on,
      ),
    );
  });

  test('30 000 entries CUBIC_BEZIER filled: first frame and redraws after translate', () {
    // The line and the fill are paths that Transformer.pathValueToPixel converts on every frame.
    const mode = LineDataSetMode.CUBIC_BEZIER;
    final cold = _measure(decimation: false, mode: mode, filled: true);
    final off = _measure(decimation: false, mode: mode, filled: true);
    final on = _measure(decimation: true, mode: mode, filled: true);

    stdout.writeln(
      perfLine(
        'LineChart $_entryCount entries CUBIC_BEZIER filled no circles 400x300 RecordingCanvas',
        cold: cold,
        off: off,
        on: on,
      ),
    );
  });
}

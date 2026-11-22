// Shared measurer of the perf record for the charts with x and y axes: a core chart without a host,
// drawn into a RecordingCanvas, timed for the setup, the first frame and the redraws after the zoomed viewport was
// moved along x. Extracted from line_chart_perf_test.dart so every chart prints the same summary line
// (`perf <subject> | cold: … | decimation off: … | decimation on: …`). Depends only on the LineChart core types; there are no thresholds.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/core.dart';

import '../recording/recording_canvas.dart';

/// The elapsed time of [sw] in ms, to the microsecond (`elapsedMicroseconds / 1000`); not rounded.
double elapsedMs(Stopwatch sw) => sw.elapsedMicroseconds / 1000;

/// The timings of one measured chart, in ms.
class PerfRun {
  PerfRun(this.setup, this.firstFrame, this.redraws, this.firstFrameDetail);

  /// Creating the chart and setting the decimation, the data and the size, in ms.
  final double setup;

  /// The first onDraw, in ms.
  final double firstFrame;

  /// Each onDraw after a move of the viewport, in ms.
  final List<double> redraws;

  /// What the first frame drew, such as `120000 line floats, 17 paths`.
  final String firstFrameDetail;

  double get average => redraws.reduce((a, b) => a + b) / redraws.length;

  double get max => redraws.reduce(math.max);

  String describe() =>
      'setup ${setup.toStringAsFixed(1)} ms, first frame ${firstFrame.toStringAsFixed(1)} ms '
      '($firstFrameDetail), ${redraws.length} redraws after translate avg '
      '${average.toStringAsFixed(1)} ms '
      'max ${max.toStringAsFixed(1)} ms';
}

/// Measures one chart: `create()` with [decimation], [data] and the size [width] x [height] (timed as the setup),
/// the first `onDraw` (timed), then a zoom by [zoomX] along x about the center and one untimed frame, then
/// [redraws] times `moveViewToX(i * step)` followed by a timed `onDraw`. Each move must change `lowestVisibleX`.
/// Throws an [ArgumentError] when [redraws] is less than 1, since [PerfRun.average] and [PerfRun.max] need one.
///
/// [drewData] is checked on the first frame and on every timed redraw; [detail] describes the first frame's canvas.
/// [data] is built by the caller, so building it is not part of the setup.
PerfRun measureChart<T extends BarLineScatterCandleBubbleData>({
  required BarLineChartBase<T> Function() create,
  required T data,
  required bool decimation,
  double width = 400,
  double height = 300,
  required double zoomX,
  required double step,
  int redraws = 10,
  required bool Function(RecordingCanvas canvas) drewData,
  required String Function(RecordingCanvas first) detail,
}) {
  if (redraws < 1) {
    throw ArgumentError.value(redraws, 'redraws', 'must be at least 1');
  }
  final sw = Stopwatch()..start();
  final chart = create()
    ..isDecimationEnabled = decimation
    ..data = data
    ..onSizeChanged(width, height);
  final setup = elapsedMs(sw);

  final first = RecordingCanvas();
  sw.reset();
  chart.onDraw(first);
  final firstFrame = elapsedMs(sw);
  expect(drewData(first), isTrue);

  chart.zoom(zoomX, 1, width / 2, height / 2);
  chart.onDraw(RecordingCanvas());
  final times = <double>[];
  var lowest = chart.lowestVisibleX;
  for (var i = 1; i <= redraws; i++) {
    chart.moveViewToX(i * step);
    expect(chart.lowestVisibleX, isNot(lowest), reason: 'move $i');
    lowest = chart.lowestVisibleX;

    final canvas = RecordingCanvas();
    sw.reset();
    chart.onDraw(canvas);
    times.add(elapsedMs(sw));
    expect(drewData(canvas), isTrue, reason: 'move $i');
  }
  return PerfRun(setup, firstFrame, times, detail(first));
}

/// The summary line of one chart: the cold run (the first chart of the isolate, which also pays for JIT
/// compilation), then the warm runs with decimation off and on.
String perfLine(
  String subject, {
  required PerfRun cold,
  required PerfRun off,
  required PerfRun on,
}) =>
    'perf $subject | cold: ${cold.describe()} | decimation off: ${off.describe()} | decimation on: ${on.describe()}';

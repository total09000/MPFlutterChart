// Not a port of a Kotlin test: pins the shared perf measurer (perf_support.dart) that the perf-tagged chart tests
// use. Not tagged perf, so it runs with the normal suite; its LineChart has 200 entries and takes milliseconds.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/core.dart';

import '../recording/recording_canvas.dart';
import 'perf_support.dart';

void main() {
  test('describe() keeps the Phase 0 wording', () {
    expect(
      PerfRun(1.23, 4.56, [1, 2, 3], '5 line floats, 1 paths').describe(),
      'setup 1.2 ms, first frame 4.6 ms (5 line floats, 1 paths), 3 redraws after translate avg 2.0 ms max 3.0 ms',
    );
  });

  test('perfLine joins cold, off and on', () {
    final cold = PerfRun(30, 15, [1, 2], 'a');
    final off = PerfRun(0.5, 1, [0.5, 0.7], 'b');
    final on = PerfRun(0.3, 4, [0.5], 'c');

    expect(
      perfLine('LineChart 200 entries', cold: cold, off: off, on: on),
      'perf LineChart 200 entries | '
      'cold: setup 30.0 ms, first frame 15.0 ms (a), 2 redraws after translate avg 1.5 ms max 2.0 ms | '
      'decimation off: setup 0.5 ms, first frame 1.0 ms (b), 2 redraws after translate avg 0.6 ms max 0.7 ms | '
      'decimation on: setup 0.3 ms, first frame 4.0 ms (c), 1 redraws after translate avg 0.5 ms max 0.5 ms',
    );
  });

  LineData lineData() => LineData([
    LineDataSet([
      for (var i = 0; i < 200; i++)
        Entry(x: i.toDouble(), y: 50 + 40 * math.sin(i * 0.1)),
    ], 'perf')
      ..isDrawCirclesEnabled = false
      ..isDrawValuesEnabled = false,
  ]);

  test('measureChart times a LineChart and checks every frame', () {
    final data = lineData();
    final checked = <RecordingCanvas>[];
    final detailed = <RecordingCanvas>[];

    final run = measureChart(
      create: LineChart.new,
      data: data,
      decimation: false,
      zoomX: 4,
      step: 20,
      redraws: 3,
      drewData: (canvas) {
        checked.add(canvas);
        return canvas.rawPoints.isNotEmpty;
      },
      detail: (first) {
        detailed.add(first);
        return '${first.rawPoints.length} raw point draws';
      },
    );

    expect(run.redraws, hasLength(3));
    expect(run.redraws, everyElement(greaterThanOrEqualTo(0)));
    expect(run.setup, greaterThanOrEqualTo(0));
    expect(run.firstFrame, greaterThanOrEqualTo(0));
    // The first frame and the three timed redraws; the untimed frame after the zoom is not checked.
    expect(checked, hasLength(4));
    expect(checked.toSet(), hasLength(4));
    // detail is asked once, of the first frame's canvas, and its answer is kept as is.
    expect(detailed, hasLength(1));
    expect(identical(detailed.single, checked.first), isTrue);
    expect(
      run.firstFrameDetail,
      '${checked.first.rawPoints.length} raw point draws',
    );
  });

  test('measureChart rejects fewer than one redraw', () {
    // PerfRun.average and max need at least one redraw; describe() would throw a StateError later.
    for (final redraws in [0, -1]) {
      var created = false;
      expect(
        () => measureChart(
          create: () {
            created = true;
            return LineChart();
          },
          data: lineData(),
          decimation: false,
          zoomX: 4,
          step: 20,
          redraws: redraws,
          drewData: (canvas) => true,
          detail: (first) => '',
        ),
        throwsArgumentError,
        reason: 'redraws: $redraws',
      );
      expect(created, isFalse, reason: 'redraws: $redraws');
    }
  });
}

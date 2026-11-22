// Not a port of a Kotlin test: found by the Phase 0 device acceptance (Task 19). After a few dozen redraws of a chart
// whose x values are more than one pixel apart, the y-axis labels and horizontal grid lines vanished for good.
// YAxisRenderer.getTransformedPositions maps a reused buffer and, like Kotlin, only refills the y slots; the stale x
// slots grow by the x scale on every call until they overflow to infinity. Android's SkMatrix maps a matrix without
// skew x and y independently, so y stays finite there; the Matrix shim must too.
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/line_chart.dart';
import 'package:mp_flutter_chart/src/data/entry.dart';
import 'package:mp_flutter_chart/src/data/line_data.dart';
import 'package:mp_flutter_chart/src/data/line_data_set.dart';

import '../recording/recording_canvas.dart';

/// A 400 x 300 line chart without a host with three entries, so one x unit is about 160 pixels.
LineChart _chart() => LineChart()
  ..data = LineData([
    LineDataSet([
      Entry(x: 0, y: 1),
      Entry(x: 1, y: 3),
      Entry(x: 2, y: 2),
    ], 'a'),
  ])
  ..onSizeChanged(400, 300);

void main() {
  test('y-axis labels stay where they are however often they are drawn', () {
    final chart = _chart();
    final first = RecordingCanvas();
    chart.rendererLeftYAxis.renderAxisLabels(first);
    expect(first.paragraphs, isNotEmpty);
    for (var i = 1; i < 100; i++) {
      final canvas = RecordingCanvas();
      chart.rendererLeftYAxis.renderAxisLabels(canvas);
      expect(
        [for (final p in canvas.paragraphs) p.offset],
        [for (final p in first.paragraphs) p.offset],
        reason: 'call $i',
      );
    }
  });

  test('the hundredth frame draws the same labels and lines as the first', () {
    final chart = _chart();
    final first = RecordingCanvas();
    chart.onDraw(first);
    var last = first;
    for (var i = 0; i < 99; i++) {
      last = RecordingCanvas();
      chart.onDraw(last);
    }

    expect(last.drawParagraphCalls, first.drawParagraphCalls);
    expect(last.drawPathCalls, first.drawPathCalls);
    for (final p in last.paragraphs) {
      expect(p.offset.isFinite, isTrue);
    }
    for (final p in last.paths) {
      expect(p.bounds.isFinite, isTrue);
    }
  });
}

// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/DecimationTest.kt
//
// Only DecimationTest.crowdedCandlesAreReducedWithOrWithoutDecimation is ported, on the recording canvas instead of a
// bitmap, on a chart laid out at the 1080 x 1200 of the device fixtures; Kotlin's RecordingCanvas
// counts the floats passed to `drawLines`, which here are the floats of the `drawRawPoints` calls that
// `ChartCanvas.drawLinesP` makes. The other tests are not ports, since MPAndroidChart v4.0.1 has no unit test for
// CandleStickChart: they check what charts/CandleStickChart.kt adds to BarLineChartBase (its renderer, the x axis
// spacing and the candle data), that its empty state shows the bar outline (as the device EmptyStateTest asserts),
// that Chart.animateValue refuses candle entries, and that hostile candles draw through the whole chart.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/bar_chart.dart';
import 'package:mp_flutter_chart/src/charts/candle_stick_chart.dart';
import 'package:mp_flutter_chart/src/data/candle_data.dart';
import 'package:mp_flutter_chart/src/data/candle_data_set.dart';
import 'package:mp_flutter_chart/src/data/candle_entry.dart';
import 'package:mp_flutter_chart/src/renderer/candle_stick_chart_renderer.dart';

import '../recording/recording_canvas.dart';
import 'support/fixtures.dart';
import 'support/strict_canvas.dart';

/// Kotlin's `DecimationTest.CANDLES`.
const int _CANDLES = 50000;

const _increasing = ui.Color(0xFF00FF00);
const _decreasing = ui.Color(0xFFFF0000);

/// Keeps the rounded rectangles in [keptRRects], because the Phase 0 RecordingCanvas only counts `drawRRect`.
/// Not named `rrects`: lane D's RecordingCanvas declares that as its own record list, and this class must compile
/// against both versions.
class _RRectCanvas extends StrictCanvas {
  final List<ui.RRect> keptRRects = [];

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    keptRRects.add(rrect);
    super.drawRRect(rrect, paint);
  }
}

/// What Kotlin's RecordingCanvas sums up over the `drawLines` calls: the floats drawn and the smallest and largest y.
typedef _LineFloats = ({int floats, double top, double bottom});

_LineFloats _lineFloats(RecordingCanvas canvas) {
  var floats = 0;
  var top = double.infinity;
  var bottom = double.negativeInfinity;
  for (final draw in canvas.rawPoints) {
    if (draw.mode != ui.PointMode.lines) continue;
    floats += draw.points.length;
    for (var y = 1; y < draw.points.length; y += 2) {
      top = math.min(top, draw.points[y]);
      bottom = math.max(bottom, draw.points[y]);
    }
  }
  return (floats: floats, top: top, bottom: bottom);
}

/// Draws [_CANDLES] candles with only the shadow lines on the canvas, so their extent is the extent of the data.
_LineFloats _candleShadows({required bool decimation}) {
  final chart = lay(CandleStickChart())
    ..isDrawGridBackgroundEnabled = false
    ..isDecimationEnabled = decimation;
  chart.xAxis.isEnabled = false;
  chart.axisLeft.isEnabled = false;
  chart.axisRight.isEnabled = false;
  chart.legend.isEnabled = false;
  chart.description.isEnabled = false;
  chart.data = CandleData([candleSet(candleEntries(_CANDLES))]);
  resetViewport(chart);

  final canvas = RecordingCanvas();
  chart.onDraw(canvas);
  return _lineFloats(canvas);
}

void main() {
  test(
    'a new candle chart draws with the candle renderer and pads the x axis by half a unit',
    () {
      final chart = CandleStickChart();

      expect(chart.renderer, isA<CandleStickChartRenderer>());
      expect(chart.xAxis.spaceMin, 0.5);
      expect(chart.xAxis.spaceMax, 0.5);
      expect(chart.candleData, isNull);

      final data = CandleData([
        CandleDataSet([
          CandleEntry(x: 0, high: 20, low: 10, open: 12, close: 18),
        ], 'candles'),
      ]);
      chart.data = data;
      expect(chart.candleData, same(data));
    },
  );

  test('the empty state shows the bar outline', () {
    final candle = CandleStickChart()..onSizeChanged(400, 300);
    final candleCanvas = _RRectCanvas();
    candle.onDraw(candleCanvas);

    final bar = BarChart()..onSizeChanged(400, 300);
    final barCanvas = _RRectCanvas();
    bar.onDraw(barCanvas);

    expect(candleCanvas.keptRRects, hasLength(3));
    expect(candleCanvas.keptRRects, barCanvas.keptRRects);
  });

  group('animateValue', () {
    test('a candle entry is refused, before the data check', () {
      final refused = throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'animateValue does not animate candle entries, use animateDataChange.',
        ),
      );
      final candle = CandleEntry(x: 0, high: 20, low: 10, open: 12, close: 18);
      final chart = CandleStickChart()
        ..data = CandleData([
          CandleDataSet([candle], 'candles'),
        ])
        ..onSizeChanged(400, 300);

      expect(() => chart.animateValue(candle, 30, 100), refused);
      expect([candle.y, candle.high, candle.low], [15, 20, 10]);

      // A candle that is not part of the data gets the candle message, not the data message.
      expect(
        () => chart.animateValue(
          CandleEntry(x: 1, high: 2, low: 1, open: 1, close: 2),
          3,
          100,
        ),
        refused,
      );
    });
  });

  test('hostile candles draw through the chart without NaN geometry', () {
    // The device HostileInputTest case "candle high below low", plus an infinite high and an infinite low.
    final set =
        CandleDataSet([
            CandleEntry(x: 0, high: 1, low: 10, open: 5, close: 3),
            CandleEntry(x: 1, high: 2, low: 2, open: 9, close: -9),
            CandleEntry(
              x: 2,
              high: double.nan,
              low: 1,
              open: 1,
              close: double.nan,
            ),
            CandleEntry(x: 3, high: double.infinity, low: 0, open: 1, close: 2),
            CandleEntry(
              x: 4,
              high: 3,
              low: double.negativeInfinity,
              open: 2,
              close: 1,
            ),
          ], 'candle')
          ..increasingColor = _increasing
          ..decreasingColor = _decreasing;
    final chart = CandleStickChart()
      ..data = CandleData([set])
      ..onSizeChanged(400, 300);
    // The legend would add a square of each direction color.
    chart.legend.isEnabled = false;

    for (final highlighted in [false, true]) {
      if (highlighted) chart.highlightValue(2, 0);
      final canvas = StrictCanvas();

      chart.onDraw(canvas);

      // Four bodies: the candle with a NaN open and close is neutral, and its line has a NaN end.
      final where = 'highlighted: $highlighted';
      final bodies = [for (final r in canvas.rects) r.color.toARGB32()];
      expect(
        bodies.where((c) => c == _decreasing.toARGB32()),
        hasLength(3),
        reason: 'decreasing bodies ($where)',
      );
      expect(
        bodies.where((c) => c == _increasing.toARGB32()),
        hasLength(1),
        reason: 'increasing bodies ($where)',
      );
      expect(canvas.rawPoints, hasLength(5), reason: 'shadows ($where)');
    }
  });

  group('DecimationTest', () {
    test('crowdedCandlesAreReducedWithOrWithoutDecimation', () {
      final decimated = _candleShadows(decimation: true);
      final plain = _candleShadows(decimation: false);

      // Eight floats per candle: the shadow is drawn as two lines.
      expect(
        plain.floats,
        lessThan(8 * _CANDLES ~/ 3),
        reason: '${plain.floats} of ${8 * _CANDLES} floats drawn',
      );
      expect(
        decimated.floats,
        plain.floats,
        reason: 'decimation changed a crowded candle chart',
      );
      expect(decimated.top, plain.top);
      expect(decimated.bottom, plain.bottom);
    });
  });
}

// Ported from MPAndroidChart v4.0.1: MPChartDeviceTest/src/androidTest/kotlin/com/github/mikephil/charting/devicetest/DecimationTest.kt
//
// Only DecimationTest.theBiggestBubbleOfAColumnSurvivesTheReduction is ported, on the recording canvas instead of a
// bitmap, on a chart laid out at the 1080 x 1200 of the device fixtures; Kotlin's RecordingCanvas
// collects the radius of every `drawCircle`, which here are `RecordingCanvas.circles`. The y values come from Dart's
// `Random(7)`, not Kotlin's, which the test does not depend on: every 500th bubble is big either way. The other tests
// are not ports, since MPAndroidChart v4.0.1 has no unit test for BubbleChart: they check what charts/BubbleChart.kt
// adds to BarLineChartBase (its renderer, the bubble data and the empty state outline of two circles), and that the
// bubbles of the device HostileInputTest cases "bubble zero, negative and NaN size" and "all bubbles size 0" draw
// through the whole chart without NaN geometry (Review Focus #5).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mp_flutter_chart/src/charts/bubble_chart.dart';
import 'package:mp_flutter_chart/src/data/bubble_data.dart';
import 'package:mp_flutter_chart/src/data/bubble_data_set.dart';
import 'package:mp_flutter_chart/src/data/bubble_entry.dart';
import 'package:mp_flutter_chart/src/graphics/chart_paint.dart';
import 'package:mp_flutter_chart/src/graphics/mutable_rect.dart';
import 'package:mp_flutter_chart/src/highlight/highlight.dart';
import 'package:mp_flutter_chart/src/renderer/bubble_chart_renderer.dart';

import '../recording/recording_canvas.dart';
import 'support/fixtures.dart';
import 'support/strict_canvas.dart';

/// Kotlin's `DecimationTest.BUBBLES`.
const int _BUBBLES = 20000;

/// Kotlin's `DecimationTest.BIG_EVERY`.
const int _BIG_EVERY = 500;

/// Kotlin's `DecimationTest.BIG_BUBBLES`.
const int _BIG_BUBBLES = _BUBBLES ~/ _BIG_EVERY;

/// Kotlin's `DecimationTest.BIG_BUBBLE_PIXELS`.
const double _BIG_BUBBLE_PIXELS = 10;

const _c0 = ui.Color(0xFF110000);
const _c1 = ui.Color(0xFF002200);
const _c2 = ui.Color(0xFF000033);
const _c3 = ui.Color(0xFF444400);

/// The color of [circle] as an ARGB int; the recorded `ui.Color` does not compare equal to a constant one.
int _argb(CircleDraw circle) => circle.color.toARGB32();

/// Exposes the protected members of [BubbleChart].
class _TestBubbleChart extends BubbleChart {
  void drawOutline(ui.Canvas canvas, MutableRect bounds, ChartPaint paint) =>
      drawNoDataIcon(canvas, bounds, paint);
}

/// Pixel radii of the bubbles drawn for a set whose x values sit close enough together for a bubble to be tens of
/// pixels wide, whose y values are spread over the whole axis, and where every [_BIG_EVERY] entries carries a big
/// bubble. The spread is what matters: a column holds bubbles reaching well above and well below the big one, so
/// keeping only the lowest and the highest of the column would drop it.
List<double> _bubbleRadii({required bool decimation}) {
  final random = math.Random(7);
  final entries = [
    for (var it = 0; it < _BUBBLES; it++)
      BubbleEntry(
        x: it * 0.001,
        y: random.nextDouble() * 100,
        size: it % _BIG_EVERY == 0 ? 50 : 1,
      ),
  ];
  final chart = lay(BubbleChart())
    ..isDrawGridBackgroundEnabled = false
    ..isDecimationEnabled = decimation;
  chart.xAxis.isEnabled = false;
  chart.axisLeft.isEnabled = false;
  chart.axisRight.isEnabled = false;
  chart.legend.isEnabled = false;
  chart.description.isEnabled = false;
  chart.data = BubbleData([bubbleSet(entries)]);
  resetViewport(chart);

  final canvas = RecordingCanvas();
  chart.onDraw(canvas);
  return [for (final c in canvas.circles) c.radius];
}

/// The hostile bubbles drawn through a 400 x 300 chart with every entry highlighted, on a [StrictCanvas]: the data
/// circles (filled) and the highlight rings (stroked) by the color of their entry.
({List<CircleDraw> bubbles, List<CircleDraw> rings}) _drawHostile(
  List<BubbleEntry> entries, {
  required bool normalize,
}) {
  final set = BubbleDataSet(entries, 'bubble')
    ..colors = [_c0, _c1, _c2, _c3]
    ..isNormalizeSizeEnabled = normalize;
  final chart = BubbleChart()
    ..data = BubbleData([set])
    ..onSizeChanged(400, 300);
  // The legend would add a square in the first color.
  chart.legend.isEnabled = false;
  // The renderer rings an entry only for a highlight with its y.
  chart.highlightValues([for (final e in entries) Highlight(e.x, e.y, 0)]);

  final canvas = StrictCanvas();
  chart.onDraw(canvas);

  expect(
    canvas.circles.where((c) => c.x.isNaN || c.y.isNaN || c.radius.isNaN),
    isEmpty,
  );
  return (
    bubbles: [
      for (final c in canvas.circles)
        if (c.style == ui.PaintingStyle.fill) c,
    ],
    rings: [
      for (final c in canvas.circles)
        if (c.style == ui.PaintingStyle.stroke) c,
    ],
  );
}

void main() {
  test('a new bubble chart draws with the bubble renderer and leaves the x '
      'axis unpadded', () {
    final chart = BubbleChart();

    expect(chart.renderer, isA<BubbleChartRenderer>());
    expect(chart.xAxis.spaceMin, 0);
    expect(chart.xAxis.spaceMax, 0);
    expect(chart.bubbleData, isNull);

    final data = BubbleData([
      BubbleDataSet([BubbleEntry(x: 0, y: 1, size: 2)], 'bubbles'),
    ]);
    chart.data = data;
    expect(chart.bubbleData, same(data));
  });

  test('the empty state outline is two filled circles', () {
    final chart = _TestBubbleChart();
    final canvas = StrictCanvas();
    final paint = ChartPaint()..style = PaintStyle.STROKE;

    chart.drawOutline(canvas, MutableRect(10, 20, 100, 90), paint);

    expect(paint.style, PaintStyle.FILL);
    // 90 wide and 70 high from (10, 20).
    expect(canvas.circles, hasLength(2));
    final (small, big) = (canvas.circles[0], canvas.circles[1]);
    expect(small.x, closeTo(10 + 90 * 0.25, 1e-4));
    expect(small.y, closeTo(20 + 70 * 0.62, 1e-4));
    expect(small.radius, closeTo(70 * 0.24, 1e-4));
    expect(big.x, closeTo(10 + 90 * 0.66, 1e-4));
    expect(big.y, closeTo(20 + 70 * 0.38, 1e-4));
    expect(big.radius, closeTo(70 * 0.34, 1e-4));
    expect([small.style, big.style], everyElement(ui.PaintingStyle.fill));

    // Drawn by the empty state of a chart without data.
    final empty = BubbleChart()..onSizeChanged(400, 300);
    final emptyCanvas = StrictCanvas();
    empty.onDraw(emptyCanvas);
    expect(emptyCanvas.circles, hasLength(2));
  });

  group('HostileInputTest bubbles draw through the chart without NaN '
      'geometry', () {
    // "bubble zero, negative and NaN size", plus Kotlin's infinite size.
    List<BubbleEntry> zeroNegativeNaN() => [
      BubbleEntry(x: 0, y: 1, size: 0),
      BubbleEntry(x: 1, y: 2, size: -5),
      BubbleEntry(x: 2, y: 3, size: double.nan),
      BubbleEntry(x: 3, y: 1, size: double.infinity),
    ];

    test('zero, negative, NaN and infinite sizes, normalized', () {
      // maxSize is ∞: the zero and the negative bubble shrink to radius 0, which Android's canvas draws nothing for
      // (T18 BU4); ∞ / ∞ and the NaN are NaN. No bubble and no ring is drawn.
      final drawn = _drawHostile(zeroNegativeNaN(), normalize: true);

      expect(drawn.bubbles, isEmpty);
      expect(drawn.rings, isEmpty);
    });

    test('zero, negative, NaN and infinite sizes, not normalized', () {
      final drawn = _drawHostile(zeroNegativeNaN(), normalize: false);

      final colors = drawn.bubbles.map(_argb).toList();
      // Size 0 gives a radius of 0, which Android's canvas draws nothing for (T18 BU4).
      expect(colors, isNot(contains(_c0.toARGB32())), reason: 'size 0');
      expect(colors, isNot(contains(_c2.toARGB32())), reason: 'size NaN');
      expect(
        drawn.bubbles.firstWhere((c) => _argb(c) == _c3.toARGB32()).radius,
        double.infinity,
        reason: 'size ∞',
      );
      // Size -5 gives a radius of -2.5 times the reference size, about -267 px here. The bounds checks of
      // drawDataSet and drawHighlighted add that radius to the center, see the bubble beyond the content rect and
      // cull it before it reaches drawCircleP, as in Kotlin; the r <= 0 guard of drawCircleP (T18 BU4) would leave
      // it out as well.
      expect(colors, isNot(contains(_c1.toARGB32())), reason: 'size -5');
      expect(colors, [_c3.toARGB32()]);
      expect(drawn.rings, hasLength(drawn.bubbles.length));
    });

    test('all bubbles size 0', () {
      final entries = [
        BubbleEntry(x: 0, y: 1, size: 0),
        BubbleEntry(x: 1, y: 1, size: 0),
      ];

      // maxSize is 0, so normalizing draws every bubble at the full reference size.
      final normalized = _drawHostile(entries, normalize: true);
      expect(normalized.bubbles, hasLength(2));
      expect(normalized.bubbles.map((c) => c.radius), everyElement(isPositive));
      expect(normalized.bubbles[0].radius, normalized.bubbles[1].radius);
      expect(normalized.rings, hasLength(2));

      // Without normalizing the radius is 0, which Android's canvas draws nothing for (T18 BU4).
      final plain = _drawHostile(entries, normalize: false);
      expect(plain.bubbles, isEmpty);
      expect(plain.rings, isEmpty);
    });
  });

  test('a highlighted bubble of size 0 gets no highlight ring, its size-4 '
      'neighbour does (T18 BU4)', () {
    // The example's Bubble Chart page: a bubble of size 0 next to one of size 4 at the same y, both highlighted with
    // a 1.5 dp ring. Android's canvas draws nothing for the radius-0 ring; Flutter's stroked a dot there.
    final set = BubbleDataSet([
      BubbleEntry(x: 2, y: 3, size: 2),
      BubbleEntry(x: 3, y: 5, size: 0),
      BubbleEntry(x: 4, y: 5, size: 4),
      BubbleEntry(x: 5, y: 2, size: 1),
    ], 'bubbles')..highlightCircleWidth = 1.5;
    final chart = BubbleChart()
      ..data = BubbleData([set])
      ..onSizeChanged(400, 300);
    chart.legend.isEnabled = false;
    final zero = Highlight(3, 5, 0);
    final four = Highlight(4, 5, 0);
    chart.highlightValues([zero, four]);

    final canvas = StrictCanvas();
    chart.onDraw(canvas);

    // Both highlights reached the ring: the renderer set their drawn positions inside the content rect.
    final content = chart.viewPortHandler.contentRect;
    for (final high in [zero, four]) {
      expect(content.contains(high.drawX, high.drawY), isTrue);
    }
    List<CircleDraw> at(Highlight high, ui.PaintingStyle style) => [
      for (final c in canvas.circles)
        if (c.style == style &&
            (c.x - high.drawX).abs() < 1e-3 &&
            (c.y - high.drawY).abs() < 1e-3)
          c,
    ];
    expect(at(zero, ui.PaintingStyle.stroke), isEmpty, reason: 'ring');
    expect(at(zero, ui.PaintingStyle.fill), isEmpty, reason: 'bubble');
    expect(at(four, ui.PaintingStyle.stroke).single.radius, isPositive);
  });

  group('DecimationTest', () {
    test('theBiggestBubbleOfAColumnSurvivesTheReduction', () {
      final decimated = _bubbleRadii(decimation: true);
      final plain = _bubbleRadii(decimation: false);

      expect(
        plain,
        hasLength(_BUBBLES),
        reason: 'with decimation off every bubble is drawn',
      );
      expect(
        decimated.length,
        lessThan(plain.length / 4),
        reason: 'decimated ${decimated.length} vs ${plain.length} bubbles',
      );
      expect(
        plain.where((it) => it > _BIG_BUBBLE_PIXELS),
        hasLength(_BIG_BUBBLES),
        reason: 'big bubbles an undecimated chart drew',
      );
      expect(
        decimated.where((it) => it > _BIG_BUBBLE_PIXELS).length,
        plain.where((it) => it > _BIG_BUBBLE_PIXELS).length,
        reason: 'big bubbles left after the reduction',
      );
    });
  });
}
